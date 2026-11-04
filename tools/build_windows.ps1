$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    $env:APPDATA = Join-Path $projectRoot '.runtime'
    $env:TEMP = Join-Path $projectRoot '.runtime/export-temp'
    $env:TMP = $env:TEMP
    New-Item -ItemType Directory -Force $env:TEMP | Out-Null
    $releaseRoot = Join-Path (Split-Path -Parent $projectRoot) 'release'
    $gameDir = Join-Path $releaseRoot 'FiveLaneLords'
    New-Item -ItemType Directory -Force $gameDir | Out-Null
    & godot_console --headless --path . --export-release 'Windows Desktop' (Join-Path $gameDir 'FiveLaneLords.exe')
    if ($LASTEXITCODE -ne 0) { throw "Godot export failed: $LASTEXITCODE" }
    Compress-Archive -LiteralPath $gameDir -DestinationPath (Join-Path $releaseRoot 'FiveLaneLords-Windows.zip') -Force
    Get-FileHash -Algorithm SHA256 (Join-Path $gameDir 'FiveLaneLords.exe')
} finally {
    Pop-Location
}
