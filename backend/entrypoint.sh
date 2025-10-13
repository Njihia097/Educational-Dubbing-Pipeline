#!/usr/bin/env bash
set -euo pipefail

POSTGRES_HOST=${POSTGRES_HOST:-postgres}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_WAIT_SECONDS=${POSTGRES_WAIT_SECONDS:-60}
MINIO_ENDPOINT=${S3_ENDPOINT:-http://minio:9000}
MINIO_WAIT_SECONDS=${MINIO_WAIT_SECONDS:-60}

echo "Waiting for Postgres at ${POSTGRES_HOST} (timeout ${POSTGRES_WAIT_SECONDS}s)..."
if command -v pg_isready >/dev/null 2>&1; then
  SECONDS=0
  until pg_isready -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" >/dev/null 2>&1; do
    if (( SECONDS >= POSTGRES_WAIT_SECONDS )); then
      echo "Postgres readiness check timed out after ${POSTGRES_WAIT_SECONDS}s; continuing."
      break
    fi
    sleep 1
  done
else
  echo "pg_isready not found; skipping explicit Postgres wait."
fi
echo "Postgres check complete."

echo "Waiting for MinIO at ${MINIO_ENDPOINT} (timeout ${MINIO_WAIT_SECONDS}s)..."
if command -v curl >/dev/null 2>&1; then
  SECONDS=0
  until curl -sf "${MINIO_ENDPOINT%/}/minio/health/live" >/dev/null; do
    if (( SECONDS >= MINIO_WAIT_SECONDS )); then
      echo "MinIO readiness check timed out after ${MINIO_WAIT_SECONDS}s; continuing."
      break
    fi
    sleep 1
  done
else
  echo "curl not found; skipping explicit MinIO wait."
fi
echo "MinIO check complete."

echo "Running migrations..."
flask db upgrade || echo "Migration step skipped or already applied."

echo "Starting Flask app..."
exec python run.py

