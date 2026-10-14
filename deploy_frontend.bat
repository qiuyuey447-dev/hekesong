@echo off
REM ============================================================
REM  去狸的岛 · 前端一条龙部署（Godot 导出 Web + 上传静态托管）
REM
REM  前置条件（只需做一次）：
REM    1. npm i -g @cloudbase/cli
REM    2. tcb login
REM
REM  流程：
REM    [1] Godot 导出 Web 版到 build\web
REM    [2] 清理 *.import 垃圾文件
REM    [3] 上传到 CloudBase 静态托管 /hekesong/
REM
REM  只想导出不想上传？用 deploy_web.bat
REM ============================================================

setlocal

set GODOT=E:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe
set PROJECT=E:\hekesong
set OUT=%PROJECT%\build\web\index.html
set ENV_ID=goldfish-d4g2xlhzl229a1f53
set CLOUD_PATH=hekesong

echo ============================================================
echo  去狸的岛 · 前端部署（导出 + 上传）
echo ============================================================
echo.

REM --- [1/3] 导出 ---
echo [1/3] 正在用 Godot 导出 Web 版 ...
"%GODOT%" --headless --path "%PROJECT%" --export-release "Web" "%OUT%"
if errorlevel 1 (
    echo.
    echo [错误] 导出失败。检查：
    echo   1. %GODOT% 路径是否正确
    echo   2. Godot 编辑器是否正开着这个项目（先关掉）
    echo   3. Web 导出模板是否已安装
    pause
    exit /b 1
)

REM --- [2/3] 清理 ---
echo [2/3] 清理 *.import 垃圾文件 ...
del /q /s "%PROJECT%\build\web\*.import" >nul 2>&1

REM --- [3/3] 上传 ---
echo [3/3] 正在上传到 CloudBase 静态托管 /%CLOUD_PATH%/ ...
echo       （约 60MB，视网速 1-5 分钟）
echo.
tcb hosting deploy "%PROJECT%\build\web" %CLOUD_PATH% -e %ENV_ID% --ignore "**/*.import"
if errorlevel 1 (
    echo.
    echo [错误] 上传失败。检查：
    echo   1. 是否登录 -> tcb login
    echo   2. 网络是否正常
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  部署完成！
echo.
echo  游戏地址：
echo  https://goldfish-d4g2xlhzl229a1f53-1457975289.tcloudbaseapp.com/hekesong/
echo.
echo  !! 重要：请按 Ctrl+Shift+R 强制刷新，否则可能看到旧版本 !!
echo  （看不到变化？见 docs\部署说明.md 第 4.2 节）
echo ============================================================
pause
