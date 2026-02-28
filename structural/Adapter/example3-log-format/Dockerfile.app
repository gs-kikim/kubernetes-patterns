FROM python:3.11-slim

WORKDIR /app

COPY multi-format-app.py .

RUN chmod +x multi-format-app.py && \
    mkdir -p /var/log/app

EXPOSE 8080

CMD ["python", "multi-format-app.py"]
