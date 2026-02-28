FROM python:3.11-slim

WORKDIR /app

# No additional dependencies needed for main app
COPY random-generator.py .

RUN chmod +x random-generator.py && \
    mkdir -p /var/log

EXPOSE 8080

CMD ["python", "random-generator.py"]
