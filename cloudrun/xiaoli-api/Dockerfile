FROM python:3.12-slim

WORKDIR /app

COPY tools/ /app/tools/
COPY config/ /app/config/

ENV HOST=0.0.0.0
ENV PORT=8080

EXPOSE 8080

CMD ["python", "tools/local_llm_server.py", "--llm"]
