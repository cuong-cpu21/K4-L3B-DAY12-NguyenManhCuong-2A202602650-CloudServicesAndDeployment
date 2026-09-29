# ==============================================================================
# CP2 — Multi-stage Production-Ready Dockerfile
# ==============================================================================

# Stage 1: Builder
FROM python:3.11-slim AS builder

WORKDIR /build

# Cài đặt dependency vào venv tách biệt để layer cache tối ưu
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

WORKDIR /app

# Tạo non-root user và group để bảo mật
RUN groupadd -g 1000 appgroup && \
    useradd -u 1000 -g appgroup -m -s /bin/bash appuser

# Copy virtualenv từ builder stage
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

# Copy source code và phân quyền cho non-root user
COPY --chown=appuser:appgroup . .

# Chuyển sang user thường
USER appuser

EXPOSE 8000

# Healthcheck định kỳ gọi /health
HEALTHCHECK --interval=15s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request, os; urllib.request.urlopen(f'http://localhost:{os.environ.get(\"PORT\", 8000)}/health')" || exit 1

# Bind vào 0.0.0.0 và đọc cổng động từ $PORT (mặc định 8000)
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
