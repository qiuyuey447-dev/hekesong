# Package Godot Web export for itch.io upload.
# Prerequisite: Project -> Export -> Web -> export to export/web/index.html

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$webDir = Join-Path $root "export\web"
$outZip = Join-Path $root "export\hekesong-itch.zip"
$indexHtml = Join-Path $webDir "index.html"

if (-not (Test-Path $indexHtml)) {
    Write-Error "Missing export/web/index.html. In Godot: Project -> Export -> Web -> Export Project."
}

$exportDir = Join-Path $root "export"
if (-not (Test-Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir | Out-Null
}

if (Test-Path $outZip) {
    Remove-Item $outZip -Force
}

Compress-Archive -Path (Join-Path $webDir "*") -DestinationPath $outZip -Force
Write-Host "Created: $outZip"
Write-Host "Upload this zip to itch.io as an HTML (browser) game."
