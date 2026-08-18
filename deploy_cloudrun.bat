@echo off
REM ============================================================
REM  去狸的岛 · Cloud Run API 部署（xiaoli-api）
REM  需已安装 CloudBase CLI 并登录：npm i -g @cloudbase/cli && tcb login
REM  密钥通过 CloudBase 控制台环境变量注入，勿写进仓库。
REM ============================================================

set ROOT=%~dp0cloudrun\xiaoli-api
cd /d "%ROOT%"

echo [1/2] 部署 xiaoli-api 到 CloudBase Cloud Run ...
tcb run deploy --dir . --name xiaoli-api
if errorlevel 1 (
    echo 部署失败：确认已 tcb login，且 cloudbaserc.json 的 envId 正确
    pause
    exit /b 1
)

echo [2/2] 部署完成。客户端 api_url 见 config/npc_config.json
pause
