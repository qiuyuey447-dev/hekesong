# 下载站酷快乐体到 assets/fonts/，并校验是否为合法 TTF。
# 用法：
#   .\tools\download_ui_font.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$DestDir = Join-Path $Root "assets\fonts"
$Dest = Join-Path $DestDir "ZCOOLKuaiLe-Regular.ttf"
$Urls = @(
	"https://github.com/google/fonts/raw/main/ofl/zcoolkuaile/ZCOOLKuaiLe-Regular.ttf",
	"https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/zcoolkuaile/ZCOOLKuaiLe-Regular.ttf"
)

New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
if (Test-Path $Dest) {
	Remove-Item -Force $Dest
	Write-Host "Removed old file: $Dest"
}

$ok = $false
foreach ($Url in $Urls) {
	Write-Host "Trying $Url"
	try {
		curl.exe -L --retry 3 --fail -o $Dest $Url
	} catch {
		Write-Host "curl failed: $_"
		continue
	}
	if (-not (Test-Path $Dest)) { continue }
	$size = (Get-Item $Dest).Length
	$bytes = [System.IO.File]::ReadAllBytes($Dest)
	if ($size -lt 100000) {
		Write-Host "Too small ($size). Likely not a font. Retrying..."
		Remove-Item -Force $Dest -ErrorAction SilentlyContinue
		continue
	}
	# TTF magic 00 01 00 00 or OTTO
	$isTtf = ($bytes[0] -eq 0 -and $bytes[1] -eq 1 -and $bytes[2] -eq 0 -and $bytes[3] -eq 0)
	$isOtto = ($bytes[0] -eq 0x4F -and $bytes[1] -eq 0x54 -and $bytes[2] -eq 0x54 -and $bytes[3] -eq 0x4F)
	if (-not ($isTtf -or $isOtto)) {
		Write-Host "Bad magic header. Not a TTF/OTF. Retrying..."
		Remove-Item -Force $Dest -ErrorAction SilentlyContinue
		continue
	}
	Write-Host "OK size=$size bytes -> $Dest"
	$ok = $true
	break
}

if (-not $ok) {
	throw "Download failed from all mirrors. Open https://fonts.google.com/specimen/ZCOOL+KuaiLe and download manually to: $Dest"
}

Write-Host ""
Write-Host "Next: open Godot editor once (Project -> Reload Current Project) so it imports the font, then run the game."
