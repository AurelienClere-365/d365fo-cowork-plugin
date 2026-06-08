<#
.SYNOPSIS
    Validate ASKILL rules and package the D365FO Cowork plugin as a ZIP.

.DESCRIPTION
    Runs P001-P008 validation checks against all skills referenced in manifest.json.
    If all checks pass, creates d365fo-cowork-plugin.zip ready for Cowork installation.
    Exits with code 1 if any validation fails — no ZIP is produced on failure.

.EXAMPLE
    .\package.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root        = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifestPath = Join-Path $root "manifest.json"
$zipPath      = Join-Path $root "d365fo-cowork-plugin.zip"

# ---------------------------------------------------------------------------
# Load manifest
# ---------------------------------------------------------------------------
if (-not (Test-Path $manifestPath)) {
    Write-Error "manifest.json not found at: $manifestPath"
    exit 1
}

$manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
$skills   = $manifest.agentSkills

if (-not $skills -or $skills.Count -eq 0) {
    Write-Error "manifest.json has no agentSkills entries."
    exit 1
}

# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------
$pass = $true

function Test-Rule {
    param([string]$Code, [bool]$Ok, [string]$Message)
    if ($Ok) {
        Write-Host ("  [PASS] {0}" -f $Code) -ForegroundColor Green
    } else {
        Write-Host ("  [FAIL] {0}  {1}" -f $Code, $Message) -ForegroundColor Red
        $script:pass = $false
    }
}

Write-Host ""
Write-Host "D365FO Cowork Plugin - ASKILL Validation" -ForegroundColor Cyan
Write-Host ("  Manifest : {0}" -f $manifestPath)
Write-Host ("  Skills   : {0}" -f $skills.Count)
Write-Host ""

# ---------------------------------------------------------------------------
# P001 - Each agentSkills folder exists
# ---------------------------------------------------------------------------
Write-Host "P001  Folder exists" -ForegroundColor DarkCyan
foreach ($skill in $skills) {
    $fullPath = Join-Path $root $skill.folder.Replace('/', '\')
    Test-Rule "P001" (Test-Path $fullPath -PathType Container) "Folder not found: $($skill.folder)"
}

# ---------------------------------------------------------------------------
# P002 - Each folder contains SKILL.md
# ---------------------------------------------------------------------------
Write-Host "P002  SKILL.md present" -ForegroundColor DarkCyan
foreach ($skill in $skills) {
    $mdPath = Join-Path (Join-Path $root $skill.folder.Replace('/', '\')) "SKILL.md"
    Test-Rule "P002" (Test-Path $mdPath) "SKILL.md missing in: $($skill.folder)"
}

# ---------------------------------------------------------------------------
# P003-P007 - Frontmatter checks per skill
# ---------------------------------------------------------------------------
Write-Host "P003-P007  Frontmatter" -ForegroundColor DarkCyan
foreach ($skill in $skills) {
    $mdPath = Join-Path (Join-Path $root $skill.folder.Replace('/', '\')) "SKILL.md"
    if (-not (Test-Path $mdPath)) { continue }

    $content = [IO.File]::ReadAllText($mdPath)

    # P003 - has --- delimiters
    $hasFm = $content -match '(?s)^---\s*\r?\n.*?\r?\n---'
    Test-Rule "P003" $hasFm "No valid YAML frontmatter (--- delimiters) in: $($skill.folder)/SKILL.md"

    if (-not $hasFm) { continue }

    $fmBlock = [regex]::Match($content, '(?s)^---\s*\r?\n(.*?)\r?\n---').Groups[1].Value

    # P004 - has name field
    $nameMatch = [regex]::Match($fmBlock, '(?m)^name:\s*(\S+)')
    Test-Rule "P004" $nameMatch.Success "No 'name' field in frontmatter: $($skill.folder)/SKILL.md"

    # P005 - has description field
    $hasDesc = $fmBlock -match '(?m)^description:'
    Test-Rule "P005" $hasDesc "No 'description' field in frontmatter: $($skill.folder)/SKILL.md"

    if (-not $nameMatch.Success) { continue }
    $nameValue  = $nameMatch.Groups[1].Value.Trim().Trim('"').Trim("'")
    $folderName = Split-Path $skill.folder -Leaf

    # P006 - name matches folder (case-sensitive)
    Test-Rule "P006" ($nameValue -ceq $folderName) `
        "name '$nameValue' != folder '$folderName' (case-sensitive): $($skill.folder)/SKILL.md"

    # P007 - name is kebab-case
    Test-Rule "P007" ($nameValue -cmatch '^[a-z][a-z0-9]*(-[a-z0-9]+)*$') `
        "name '$nameValue' is not valid kebab-case: $($skill.folder)/SKILL.md"
}

# ---------------------------------------------------------------------------
# P008 - No duplicate folder entries
# ---------------------------------------------------------------------------
Write-Host "P008  No duplicates" -ForegroundColor DarkCyan
$dupes = @($skills | Group-Object { $_.folder } | Where-Object { $_.Count -gt 1 })
$dupesMsg = if ($dupes.Count -gt 0) { "Duplicate agentSkills entries: $(($dupes | ForEach-Object { $_.Name }) -join ', ')" } else { "" }
Test-Rule "P008" ($dupes.Count -eq 0) $dupesMsg

Write-Host ""

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------
if (-not $pass) {
    Write-Host "Validation FAILED. Fix the errors above before packaging." -ForegroundColor Red
    exit 1
}

Write-Host "All validations passed." -ForegroundColor Green
Write-Host ""

# ---------------------------------------------------------------------------
# Build ZIP via temp directory to preserve skills/ folder structure
# ---------------------------------------------------------------------------
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$tempDir = Join-Path $env:TEMP "d365fo-cowork-pkg-$(New-Guid)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

foreach ($file in @('manifest.json','d365fo-mcp-tools.json','color.png','outline.png',
                     'README.md','CHANGELOG.md','CONTRIBUTING.md','PRIVACY.md',
                     'SECURITY.md','LICENSE','EXAMPLES.md')) {
    $src = Join-Path $root $file
    if (Test-Path $src) { Copy-Item $src $tempDir }
}

# Copy skills/ preserving full directory tree
$skillsSrc = Join-Path $root "skills"
if (Test-Path $skillsSrc) {
    Copy-Item $skillsSrc (Join-Path $tempDir "skills") -Recurse
}

Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath
Remove-Item $tempDir -Recurse -Force

$sizeKb = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
Write-Host ("Package created: {0}  ({1} KB)" -f $zipPath, $sizeKb) -ForegroundColor Green
Write-Host ""
Write-Host "Install options:"
Write-Host "  Sideload   : admin.microsoft.com > Manage apps > Upload custom app"
Write-Host "  Org-wide   : admin.microsoft.com > Copilot > Agents > All agents > Deploy"
Write-Host ""
