@echo off
REM ============================================================
REM  去狸的岛 Windows 一键导出
REM  产物：export/windows/hekesong.exe
REM ============================================================

set GODOT="E:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
set PROJECT=E:\hekesong
set OUT=E:\hekesong\export\windows\hekesong.exe

if not exist "%PROJECT%\export\windows" mkdir "%PROJECT%\export\windows"

echo [1/2] 正在用 Godot 导出 Windows 版 ...
%GODOT% --headless --path "%PROJECT%" --export-release "Windows Desktop" "%OUT%"
if errorlevel 1 (
    echo 导出失败：检查 Godot 路径、导出模板、或项目是否在编辑器中打开
    pause
    exit /b 1
)

echo [2/2] 导出完成：%OUT%
pause
