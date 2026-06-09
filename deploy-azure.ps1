<#
.SYNOPSIS
    Deploy the D365FO CLI MCP server to Azure Container Apps.

.DESCRIPTION
    Builds the Docker image via Azure Container Registry (ACR) build,
    provisions a Container Apps Environment if needed, deploys the Container App
    with an external HTTPS ingress, and outputs the MCP server URL to paste
    into manifest.json.

.PARAMETER ResourceGroup
    Azure resource group name. Created automatically if it does not exist.

.PARAMETER Location
    Azure region (e.g. westeurope, eastus, australiaeast).

.PARAMETER AcrName
    Azure Container Registry name — must be globally unique, alphanumeric only.

.PARAMETER AppName
    Container App name.

.PARAMETER EnvironmentName
    Container Apps Environment name. Shared across apps in the same region.

.NOTES
    Security: this script creates an Azure AD app registration and enables Easy Auth
    on the Container App so only callers holding a valid Azure AD token from your
    tenant can reach the MCP endpoint. Anonymous requests receive HTTP 401.

.PARAMETER Cleanup
    When specified, deletes all Azure resources created by this script (ACR, Container App,
    Container Apps Environment, resource group) so you can do a clean retry.
    The Azure AD app registration is NOT deleted (it survives redeployments).

.PARAMETER TestOnly
    Skip all deployment steps and run only the smoke tests against the live app.
    Only -AppName and -ResourceGroup are needed (the FQDN and provisioning state are
    looked up from Azure). -ClientId and -ClientSecret are no longer required.

.PARAMETER ClientId
    Ignored. Kept for backwards compatibility only.

.PARAMETER ClientSecret
    Ignored. Kept for backwards compatibility only.

.EXAMPLE
    # Full deploy
    .\.deploy-azure.ps1 `
        -ResourceGroup  "rg-d365fo-tools" `
        -Location       "northeurope" `
        -AcrName        "acrd365fotools" `
        -AppName        "d365fo-mcp" `
        -EnvironmentName "cae-d365fo-tools"

.EXAMPLE
    # Re-run smoke tests only (no redeploy)
    .\.deploy-azure.ps1 `
        -ResourceGroup   "rg-d365fo-tools" `
        -Location        "northeurope" `
        -AcrName         "acrd365fotools" `
        -AppName         "d365fo-mcp" `
        -EnvironmentName "cae-d365fo-tools" `
        -TestOnly

.EXAMPLE
    # Clean up everything and start fresh
    .\.deploy-azure.ps1 `
        -ResourceGroup  "rg-d365fo-tools" `
        -Location       "northeurope" `
        -AcrName        "acrd365fotools" `
        -AppName        "d365fo-mcp" `
        -EnvironmentName "cae-d365fo-tools" `
        -Cleanup
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$Location,
    [Parameter(Mandatory)][string]$AcrName,
    [Parameter(Mandatory)][string]$AppName,
    [Parameter(Mandatory)][string]$EnvironmentName,
    [switch]$Cleanup,
    [switch]$TestOnly,
    [string]$ClientId,
    [string]$ClientSecret
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ACR names must be lowercase alphanumeric (Azure requirement)
$AcrName = $AcrName.ToLower() -replace '[^a-z0-9]', ''

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---------------------------------------------------------------------------
# Cleanup mode — delete all resources for a clean retry
# ---------------------------------------------------------------------------
if ($Cleanup) {
    Write-Host "" 
    Write-Host "CLEANUP MODE — deleting Azure resources for a fresh retry" -ForegroundColor Yellow
    Write-Host "  (Azure AD app registration is preserved)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Deleting Container App '$AppName'..." -ForegroundColor White
    az containerapp delete --name $AppName --resource-group $ResourceGroup --yes 2>$null
    Write-Host "  Deleting Container Apps Environment '$EnvironmentName'..." -ForegroundColor White
    az containerapp env delete --name $EnvironmentName --resource-group $ResourceGroup --yes --no-wait 2>$null
    Write-Host "  Deleting ACR '$AcrName'..." -ForegroundColor White
    az acr delete --name $AcrName --resource-group $ResourceGroup --yes 2>$null
    Write-Host ""
    Write-Host "  NOTE: ACR deletion propagates globally and may take 2-3 minutes." -ForegroundColor Yellow
    Write-Host "        Wait before redeploying to avoid 'name still reserved' errors." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  All resources deleted. Re-run without -Cleanup to redeploy." -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# TestOnly mode — skip deployment, run smoke tests against live app
# ---------------------------------------------------------------------------
if ($TestOnly) {
    if (-not (Get-Command "az" -ErrorAction SilentlyContinue)) {
        Write-Error "Azure CLI (az) not found. Install from https://aka.ms/installazurecli"
        exit 1
    }
    $account = az account show --output json 2>$null | ConvertFrom-Json
    if (-not $account) { Write-Error "Not logged in. Run: az login"; exit 1 }
    $tenantId = $account.tenantId

    Write-Host ""
    Write-Host "TEST-ONLY MODE — running smoke tests against live app" -ForegroundColor Cyan
    Write-Host ""

    $fqdn = az containerapp show `
        --name $AppName `
        --resource-group $ResourceGroup `
        --query "properties.configuration.ingress.fqdn" -o tsv 2>$null
    if (-not $fqdn) {
        Write-Error "Could not find Container App '$AppName' in '$ResourceGroup'. Is it deployed?"
        exit 1
    }
    $baseUrl    = "https://$fqdn"
    $mcpUrl     = "$baseUrl/mcp"
    $appRegName = "$AppName-server"
    $passed = 0; $failed = 0

    Write-Host "  Endpoint: $mcpUrl" -ForegroundColor DarkGray
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
if (-not $TestOnly) {
    Write-Host ""
    Write-Host "D365FO Cowork Plugin - Azure Deployment" -ForegroundColor Cyan
    Write-Host ""
}

if (-not $TestOnly -and -not (Test-Path (Join-Path $scriptDir "d365fo-index.sqlite"))) {
    Write-Error (@"
d365fo-index.sqlite not found in the script directory.
Copy it first:
    Copy-Item `"`$env:LOCALAPPDATA\d365fo-cli\d365fo-index.sqlite`" .\d365fo-index.sqlite
"@)
    exit 1
}

if (-not (Get-Command "az" -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI (az) not found. Install from https://aka.ms/installazurecli"
    exit 1
}

# Confirm logged in
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Error "Not logged in to Azure CLI. Run: az login"
    exit 1
}
if (-not $TestOnly) {
    Write-Host ("  Subscription : {0} ({1})" -f $account.name, $account.id)
    Write-Host ("  Tenant       : {0}" -f $account.tenantId)
    Write-Host ""
}

$tenantId = $account.tenantId

if (-not $TestOnly) {
# ---------------------------------------------------------------------------
# Step 1 — Resource group
# ---------------------------------------------------------------------------
Write-Host "[1/7] Ensuring resource group '$ResourceGroup' in '$Location'..." -ForegroundColor White
az group create --name $ResourceGroup --location $Location --output none
Write-Host "      Done." -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# Step 2 — Build and push image via ACR Tasks
# ---------------------------------------------------------------------------
Write-Host "[2/7] Creating ACR '$AcrName' (if needed) and building image..." -ForegroundColor White

# Check if ACR already exists (globally unique name — may survive across region switches)
$acrExists = az acr show --name $AcrName --query "name" -o tsv 2>$null
if (-not $acrExists) {
    Write-Host "      Creating ACR..." -ForegroundColor DarkGray
    $createOut = az acr create --resource-group $ResourceGroup --name $AcrName --sku Basic --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "" 
        Write-Host "ERROR: ACR creation failed. Output:" -ForegroundColor Red
        Write-Host $createOut -ForegroundColor Red
        Write-Host ""
        Write-Host "Possible causes:" -ForegroundColor Yellow
        Write-Host "  - Name '$AcrName' is taken globally. Try a unique name, e.g. 'acrd365fo$($account.id.Substring(0,6))'." -ForegroundColor Yellow
        Write-Host "  - Previous cleanup did not complete. Wait a few minutes and retry." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "      ACR already exists, reusing." -ForegroundColor DarkGray
}

# Enable admin credentials so Container Apps can pull the image
az acr update --name $AcrName --admin-enabled true --output none
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to enable ACR admin credentials on '$AcrName'."
    exit 1
}

# ACR Tasks builds the image remotely — no local Docker required
Push-Location $scriptDir
try {
    az acr build --registry $AcrName --image "d365fo-mcp:latest" .
    if ($LASTEXITCODE -ne 0) { throw "ACR build failed." }
} finally {
    Pop-Location
}
Write-Host "      Image pushed: $AcrName.azurecr.io/d365fo-mcp:latest" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# Step 3 — Azure AD App Registration (protects the MCP endpoint)
# ---------------------------------------------------------------------------
Write-Host "[3/7] Configuring Azure AD app registration for MCP server..." -ForegroundColor White

$appRegName    = "$AppName-server"
# identifierUri is set to api://<clientId> after the app is created.
# Tenant policy requires the URI to contain the app ID, tenant ID, or a verified domain.
# api://<display-name> is rejected by default tenant policy.

# Check if the app registration already exists
$existingApp = az ad app list --display-name $appRegName --query "[0].appId" -o tsv 2>$null
if ($existingApp) {
    $clientId = $existingApp
    Write-Host "      App registration already exists ($clientId), reusing." -ForegroundColor DarkGray
} else {
    $appJson = az ad app create `
        --display-name $appRegName `
        --sign-in-audience AzureADMyOrg `
        --output json
    $clientId = ($appJson | ConvertFrom-Json).appId

    # Identifier URI must contain the app ID per default tenant policy
    # api://<clientId> is always valid; api://<name> is rejected unless name is a verified domain
    $identifierUri = "api://$clientId"
    az ad app update `
        --id $clientId `
        --identifier-uris $identifierUri `
        --output none

    # Create a service principal in the tenant
    az ad sp create --id $clientId --output none 2>$null

    Write-Host ("      App registration created: {0}  (clientId: {1})" -f $appRegName, $clientId) -ForegroundColor DarkGray
}

# Create a client secret (used by Cowork to obtain tokens)
$secretJson   = az ad app credential reset --id $clientId --years 2 --output json | ConvertFrom-Json
$clientSecret = $secretJson.password
Write-Host "      Client secret generated (valid 2 years)." -ForegroundColor DarkGray
# Ensure OperationalInsights provider is registered (required for Container Apps Environment)
az provider register --namespace Microsoft.OperationalInsights --wait --output none 2>$null

Write-Host "[4/7] Ensuring Container Apps Environment '$EnvironmentName'..." -ForegroundColor White
$envExists = az containerapp env show `
    --name $EnvironmentName `
    --resource-group $ResourceGroup `
    --query "name" -o tsv 2>$null
if (-not $envExists) {
    az containerapp env create `
        --name $EnvironmentName `
        --resource-group $ResourceGroup `
        --location $Location `
        --output none
    Write-Host "      Environment created." -ForegroundColor DarkGray
} else {
    Write-Host "      Environment already exists, reusing." -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# Step 5 — Container App
# ---------------------------------------------------------------------------
Write-Host "[5/7] Deploying Container App '$AppName'..." -ForegroundColor White

$loginServer = az acr show --name $AcrName --query loginServer -o tsv
$acrPassword = az acr credential show --name $AcrName --query "passwords[0].value" -o tsv

# Check if app already exists — update image if so, create otherwise
$appExists = az containerapp show `
    --name $AppName `
    --resource-group $ResourceGroup `
    --query "name" -o tsv 2>$null

if ($appExists) {
    Write-Host "      App exists, updating image..." -ForegroundColor DarkGray
    az containerapp update `
        --name $AppName `
        --resource-group $ResourceGroup `
        --image "$loginServer/d365fo-mcp:latest" `
        --output none
} else {
    az containerapp create `
        --name $AppName `
        --resource-group $ResourceGroup `
        --environment $EnvironmentName `
        --image "$loginServer/d365fo-mcp:latest" `
        --registry-server $loginServer `
        --registry-username $AcrName `
        --registry-password $acrPassword `
        --target-port 8080 `
        --ingress external `
        --min-replicas 1 `
        --max-replicas 3 `
        --cpu 0.5 `
        --memory 1.0Gi `
        --output none
}
Write-Host "      Container App deployed." -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# Step 6 — Enable Easy Auth (Azure AD) — blocks ALL unauthenticated requests
# ---------------------------------------------------------------------------
Write-Host "[6/7] Enabling Easy Auth (Azure AD tenant lock)..." -ForegroundColor White

# Enable authentication and return HTTP 401 to unauthenticated callers
# (API mode — do NOT redirect to login page, let the caller handle token acquisition)
az containerapp auth update `
    --name $AppName `
    --resource-group $ResourceGroup `
    --enabled true `
    --unauthenticated-client-action Return401 `
    --output none

# Wire the app registration as the identity provider
# Note: --issuer already encodes the tenant; --tenant-id is mutually exclusive with --issuer
az containerapp auth microsoft update `
    --name $AppName `
    --resource-group $ResourceGroup `
    --client-id $clientId `
    --issuer "https://login.microsoftonline.com/$tenantId/v2.0" `
    --allowed-audiences "api://$clientId" `
    --output none

Write-Host "      Easy Auth enabled. Unauthenticated calls now return HTTP 401." -ForegroundColor DarkGray
Write-Host ("      Only tokens issued by tenant '{0}' for audience 'api://{1}' are accepted." -f $tenantId, $clientId) -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# Step 7 — Output the URL + Cowork registration instructions
# ---------------------------------------------------------------------------
Write-Host "[7/7] Retrieving endpoint..." -ForegroundColor White
$fqdn = az containerapp show `
    --name $AppName `
    --resource-group $ResourceGroup `
    --query "properties.configuration.ingress.fqdn" -o tsv

$mcpUrl = "https://$fqdn/mcp"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Deployment complete — SECURE endpoint" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  MCP Server URL  : $mcpUrl" -ForegroundColor Yellow
Write-Host "  Tenant ID       : $tenantId" -ForegroundColor Yellow
Write-Host "  Client ID       : $clientId" -ForegroundColor Yellow
Write-Host ("  Client Secret   : {0}  <-- STORE SECURELY" -f $clientSecret) -ForegroundColor Red
Write-Host "  Audience        : api://$clientId" -ForegroundColor Yellow
Write-Host ""
Write-Host "NEXT STEPS (manual — cannot be automated)" -ForegroundColor White
Write-Host ""
Write-Host "  1. Register OAuth in Teams Developer Portal:"
Write-Host "       https://dev.teams.microsoft.com  > Tools > OAuth client registration > Register"
Write-Host "       Fill in:"
Write-Host "         Registration name  : D365FO Cowork"
Write-Host "         Base URL           : $mcpUrl"
Write-Host "         Org restriction    : My organization only"
Write-Host "         Teams app          : Existing Teams app  (use your manifest id)"
Write-Host "         Client ID          : $clientId"
Write-Host "         Client secret      : $clientSecret"
Write-Host "         Authorization URL  : https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize"
Write-Host "         Token URL          : https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
Write-Host "         Refresh URL        : https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
Write-Host "       Click Save — copy the OAuth registration ID shown."
Write-Host ""
Write-Host "  2. Open manifest.json and replace the two placeholders:"
Write-Host "       mcpServerUrl  -> $mcpUrl"
Write-Host "       referenceId   -> <OAuth registration ID from step 1>"
Write-Host ""
Write-Host "  3. Run .\package.ps1 to repackage the ZIP."
Write-Host "  4. Upload d365fo-cowork-plugin.zip via Admin Center:"
Write-Host "       - First time / personal sideload cleanup:"
Write-Host "           Teams > Apps > Manage your apps > D365FO Cowork > ... > Remove"
Write-Host "           Then: admin.microsoft.com > Agents > All agents > ... > Add agent"
Write-Host "       - Already in All agents as org-managed:"
Write-Host "           admin.microsoft.com > Agents > All agents > D365FO Cowork > ... > Update"
Write-Host ""
Write-Host "  SECURITY NOTE: Store the client secret in Azure Key Vault or your"
Write-Host "  password manager. Do NOT commit it to source control."
Write-Host ""

} # end if (-not $TestOnly)

# ---------------------------------------------------------------------------
# Step 8 — Smoke tests
# ---------------------------------------------------------------------------
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Smoke tests" -ForegroundColor White
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

$baseUrl = if ($TestOnly) { "https://$fqdn" } else { "https://$fqdn" }
$passed  = 0
$failed  = 0

function Test-Result([string]$name, [bool]$ok, [string]$detail) {
    if ($ok) {
        Write-Host ("  [PASS] {0}" -f $name) -ForegroundColor Green
        if ($detail) { Write-Host ("         {0}" -f $detail) -ForegroundColor DarkGray }
        $script:passed++
    } else {
        Write-Host ("  [FAIL] {0}" -f $name) -ForegroundColor Red
        if ($detail) { Write-Host ("         {0}" -f $detail) -ForegroundColor DarkGray }
        $script:failed++
    }
}

# Give the container a moment to be ready after a fresh deployment
if (-not $TestOnly) {
    Write-Host "  Waiting 15s for container to be ready..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 15
}

# ---------------------------------------------------------------------------
# Single HTTP probe shared by Tests 1 and 2
# POST /mcp with proper Accept header; short 5 s timeout intentional:
#   - timeout  → SSE stream held open (MCP streamable-http) = server IS running
#   - 401      → Easy Auth is configured and blocking correctly
#   - other 4xx/5xx → server responded = server IS running
#   - network error → server is down
# ---------------------------------------------------------------------------
$probeStatus   = $null
$probeTimeout  = $false
$probeErr      = $null
try {
    $probe = Invoke-WebRequest -Uri "$baseUrl/mcp" -Method POST -UseBasicParsing `
        -TimeoutSec 5 -SkipHttpErrorCheck -MaximumRedirection 0 `
        -Headers @{ Accept = "application/json, text/event-stream" } `
        -ContentType "application/json" `
        -Body '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}' `
        -ErrorAction Stop
    $probeStatus = $probe.StatusCode
} catch {
    if ($_.Exception.Message -match "HttpClient.Timeout|canceled|timed out") {
        $probeTimeout = $true   # SSE stream held open = server is running
    } else {
        $probeErr = $_.Exception.Message
    }
}

# Test 1 — Server is reachable
if ($probeErr) {
    Test-Result "Server endpoint is reachable" $false "Network error: $probeErr"
} elseif ($probeTimeout) {
    Test-Result "Server endpoint is reachable" $true "/mcp held SSE stream open (container is running)"
} else {
    Test-Result "Server endpoint is reachable" $true "/mcp => HTTP $probeStatus"
}

# Test 2 — Easy Auth blocks unauthenticated requests with 401
#   NOTE: this FAILS until the Easy Auth provider is configured (Step 6 fix).
#   A timeout here means requests are passing through to the MCP server (Easy Auth not set up).
if ($probeErr) {
    Test-Result "Easy Auth blocks unauthenticated requests (401)" $false "Network error: $probeErr"
} elseif ($probeTimeout) {
    Test-Result "Easy Auth blocks unauthenticated requests (401)" $false `
        "Server held SSE stream — Easy Auth not yet configured. Run the Step 6 az CLI fix (see README)."
} elseif ($probeStatus -eq 401) {
    Test-Result "Easy Auth blocks unauthenticated requests (401)" $true "/mcp unauthenticated => 401"
} else {
    Test-Result "Easy Auth blocks unauthenticated requests (401)" $false `
        "/mcp unauthenticated => $probeStatus — Easy Auth not configured. See README Step 6."
}

# Test 3 — Container App provisioning state (az CLI — no token needed)
$caState = az containerapp show `
    --name $AppName --resource-group $ResourceGroup `
    --query "properties.provisioningState" -o tsv 2>$null
Test-Result "Container App provisioning succeeded" ($caState -eq "Succeeded") "provisioningState=$caState"

# Test 4 — Latest revision is in a running state (az CLI)
$revState = az containerapp revision list `
    --name $AppName --resource-group $ResourceGroup `
    --query "[0].properties.runningState" -o tsv 2>$null
Test-Result "Latest revision is running" ($revState -eq "Running") "runningState=$revState"


Write-Host ""
Write-Host ("  Results: {0} passed, {1} failed" -f $passed, $failed) -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
Write-Host ""
if ($failed -gt 0) {
    Write-Host "  Some tests failed. Check Container App logs:" -ForegroundColor Yellow
    Write-Host "    az containerapp logs show --name $AppName --resource-group $ResourceGroup --follow" -ForegroundColor DarkGray
    Write-Host ""
}
