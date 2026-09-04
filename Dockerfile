# --- Hardened, final version ---------------------------------------------
# Multi-stage build: the final image has no compiler, no package manager
# cache, and no build tooling — only the app and its runtime dependencies.

FROM python:3.11-slim AS builder

WORKDIR /build
COPY app/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ---------------------------------------------------------------------------
FROM python:3.11-slim

# Run as a dedicated, unprivileged, no-login user — never root.
RUN addgroup --system app && adduser --system --ingroup app --no-create-home app

WORKDIR /app
COPY --from=builder /root/.local /home/app/.local
COPY app/app.py .

RUN chown -R app:app /app
USER app
ENV HOME=/home/app \
    PATH=/home/app/.local/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')" || exit 1

CMD ["python", "app.py"]
