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

.EXAMPLE
    .\deploy-azure.ps1 `
        -ResourceGroup  "rg-d365fo-tools" `
        -Location       "westeurope" `
        -AcrName        "acrD365FoTools" `
        -AppName        "d365fo-mcp" `
        -EnvironmentName "cae-d365fo-tools"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$Location,
    [Parameter(Mandatory)][string]$AcrName,
    [Parameter(Mandatory)][string]$AppName,
    [Parameter(Mandatory)][string]$EnvironmentName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "D365FO Cowork Plugin - Azure Deployment" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path (Join-Path $scriptDir "d365fo-index.sqlite"))) {
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
Write-Host ("  Subscription : {0} ({1})" -f $account.name, $account.id)
Write-Host ("  Tenant       : {0}" -f $account.tenantId)
Write-Host ""

$tenantId = $account.tenantId

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
az acr create --resource-group $ResourceGroup --name $AcrName --sku Basic --output none 2>$null
# ACR Tasks builds the image remotely — no local Docker required
Push-Location $scriptDir
try {
    az acr build --registry $AcrName --image "d365fo-mcp:latest" . --output none
} finally {
    Pop-Location
}
Write-Host "      Image pushed: $AcrName.azurecr.io/d365fo-mcp:latest" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# Step 3 — Azure AD App Registration (protects the MCP endpoint)
# ---------------------------------------------------------------------------
Write-Host "[3/7] Configuring Azure AD app registration for MCP server..." -ForegroundColor White

$appRegName    = "$AppName-server"
$identifierUri = "api://$appRegName"

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

    # Set audience URI  — tokens must carry  aud = api://<appRegName>
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
az containerapp auth microsoft update `
    --name $AppName `
    --resource-group $ResourceGroup `
    --client-id $clientId `
    --tenant-id $tenantId `
    --issuer "https://login.microsoftonline.com/$tenantId/v2.0" `
    --allowed-audiences "api://$appRegName" `
    --output none

Write-Host "      Easy Auth enabled. Unauthenticated calls now return HTTP 401." -ForegroundColor DarkGray
Write-Host ("      Only tokens issued by tenant '{0}' for audience 'api://{1}' are accepted." -f $tenantId, $appRegName) -ForegroundColor DarkGray

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
Write-Host "  Audience        : api://$appRegName" -ForegroundColor Yellow
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
