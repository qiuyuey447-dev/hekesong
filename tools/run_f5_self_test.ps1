# F5 / D35 自测 headless runner
# 用法：
#   .\tools\run_f5_self_test.ps1
#   $env:GODOT_EXE = "D:\Godot\Godot_v4.7-stable_win64.exe"; .\tools\run_f5_self_test.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

function Find-Godot {
    if ($env:GODOT_EXE -and (Test-Path $env:GODOT_EXE)) {
        return $env:GODOT_EXE
    }
    $candidates = @(
        "$env:USERPROFILE\Desktop\Godot_v4.7-stable_win64.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot*.exe",
        "$env:USERPROFILE\scoop\apps\godot*\current\Godot*.exe",
        "E:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe",
        "C:\Program Files\Godot\Godot*.exe"
    )
    foreach ($pattern in $candidates) {
        $hit = Get-ChildItem $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$godot = Find-Godot
if (-not $godot) {
    Write-Host "Godot not found. Set `$env:GODOT_EXE to your Godot 4.7 executable." -ForegroundColor Yellow
    exit 2
}

Write-Host "Using Godot: $godot"
& $godot --headless --path $Root "res://tools/story_test_runner.tscn"
exit $LASTEXITCODE
