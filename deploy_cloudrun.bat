@echo off
REM ============================================================
REM  去狸的岛 · 后端 xiaoli-api 一键部署（CloudBase 云托管）
REM
REM  前置条件（只需做一次）：
REM    1. npm i -g @cloudbase/cli
REM    2. tcb login
REM
REM  本脚本会做三件事：
REM    [1] 把 tools/local_llm_server.py 同步到打包目录  ← 最容易忘的一步
REM    [2] 把 config/*.json 同步到打包目录
REM    [3] tcb cloudrun deploy 部署到云端
REM ============================================================

setlocal

set ENV_ID=goldfish-d4g2xlhzl229a1f53
set SVC=xiaoli-api
set PROJECT=E:\hekesong
set PKG=%PROJECT%\cloudrun\xiaoli-api

echo ============================================================
echo  去狸的岛 · 部署后端 xiaoli-api
echo  环境: %ENV_ID%
echo ============================================================
echo.

REM --- [1/3] 同步后端源码 ---
echo [1/3] 同步 tools\local_llm_server.py ...
copy /Y "%PROJECT%\tools\local_llm_server.py" "%PKG%\tools\" >nul
if errorlevel 1 (
    echo [错误] 源码同步失败，检查 E:\hekesong\tools\local_llm_server.py 是否存在
    pause
    exit /b 1
)

REM --- [2/3] 同步配置 ---
echo [2/3] 同步 config\*.json ...
if not exist "%PKG%\config" mkdir "%PKG%\config"
copy /Y "%PROJECT%\config\*.json" "%PKG%\config\" >nul

REM --- [3/3] 部署 ---
echo [3/3] 正在部署到云托管（容器构建约 3-8 分钟，请耐心等待）...
echo.
cd /d "%PKG%"
tcb cloudrun deploy -e %ENV_ID% -s %SVC% --source . --port 8080 --open-access-types PUBLIC --min-num 0 --max-num 5
if errorlevel 1 (
    echo.
    echo [错误] 部署失败。常见原因：
    echo   1. 没登录 -> 运行: tcb login
    echo   2. 云托管没开通 -> 控制台进云托管点一次「开通」
    echo   3. 资源包耗尽被隔离 -> 控制台续额度（见 docs\部署说明.md 4.3）
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  部署命令已提交。
echo  查状态: tcb cloudrun detail -e %ENV_ID% -s %SVC%
echo  验证:   浏览器打开 https://xiaoli-api-288258-10-1457975289.sh.run.tcloudbase.com/health
echo          正常应返回 {"status":"ok","mode":"llm","has_api_key":true}
echo ============================================================
pause
