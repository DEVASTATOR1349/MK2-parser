FROM python:3.12-slim

WORKDIR /app

# System deps for Playwright
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Python deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install Playwright browsers (Chromium for TikTok, etc.)
RUN playwright install --with-deps chromium

# Copy code
COPY . .

ENTRYPOINT ["python3", "-u", "workers/project_content_daily_worker.py"]
CMD ["--once"]
