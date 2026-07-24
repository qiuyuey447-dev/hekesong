@echo off
cd /d "%~dp0.."
where py >nul 2>&1
if %errorlevel%==0 (
  set PY=py -3
) else (
  set PY=python3
)

if defined DEEPSEEK_API_KEY goto llm
if defined OPENAI_API_KEY goto llm
if defined LLM_API_KEY goto llm

echo [warn] 未检测到 DEEPSEEK_API_KEY / OPENAI_API_KEY，以 mock 模式启动
echo        如需 LLM：set DEEPSEEK_API_KEY=sk-xxx 后重新运行
%PY% tools/local_llm_server.py %*
goto end

:llm
echo [info] 检测到 API Key，以 LLM 模式启动
%PY% tools/local_llm_server.py --llm %*

:end
