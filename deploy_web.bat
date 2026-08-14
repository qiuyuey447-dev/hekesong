@echo off
REM ============================================================
REM  河可松 Web 一键导出脚本
REM  用途：把 Godot 项目重新导出成浏览器版（覆盖 build/web）
REM  用法：改完游戏后，双击本文件即可
REM  导出完成后，再让 WorkBuddy 帮你「上传到 CloudBase」
REM ============================================================

set GODOT="E:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
set PROJECT=E:\hekesong
set OUT=E:\hekesong\build\web\index.html

echo [1/3] 正在用 Godot 导出 Web 版 ...
%GODOT% --headless --path "%PROJECT%" --export-release "Web" "%OUT%"
if errorlevel 1 (
    echo ❌ 导出失败，请检查 Godot 路径或项目是否打开中
    pause
    exit /b 1
)

echo [2/3] 清理编辑器垃圾文件（*.import）...
for /r "%PROJECT%\build\web" %%f in (*.import) do del /q "%%f" 2>nul

echo [3/3] 导出完成！产物在：%OUT%
echo ------------------------------------------------
echo 下一步：告诉 WorkBuddy「上传」或「部署」，
echo 它会把 build/web 上传到 CloudBase 静态托管覆盖旧版本。
echo ------------------------------------------------
pause
