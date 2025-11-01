FROM python:3.11-slim

WORKDIR /app
COPY metrics-exporter.py .

RUN chmod +x metrics-exporter.py

ENTRYPOINT ["python3", "metrics-exporter.py"]

