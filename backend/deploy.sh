#!/usr/bin/env bash
# GozVision backend deployment — ADK agent on Cloud Run.
#
# Usage: ./deploy.sh [PROJECT_ID] [REGION]
set -euo pipefail

PROJECT_ID="${1:-gozai-app}"
REGION="${2:-us-central1}"
SERVICE_NAME="gozvision-backend"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "=== GozVision Backend Deployment ==="
echo "Project: ${PROJECT_ID}  Region: ${REGION}"

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    for env_file in ".env" "backend/.env" "../.env"; do
        if [[ -f "$env_file" ]]; then
            export $(grep GEMINI_API_KEY "$env_file" | xargs) && break || true
        fi
    done
fi
if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    echo "ERROR: GEMINI_API_KEY is not set (env or .env file)."
    exit 1
fi

# Supabase service credentials (backend writes: SOS, scribe drafts, recall)
if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_SERVICE_KEY:-}" ]]; then
    for env_file in "backend/.env" "../backend/.env"; do
        if [[ -f "$env_file" ]]; then
            export $(grep -E 'SUPABASE_URL|SUPABASE_SERVICE_KEY' "$env_file" | xargs) && break || true
        fi
    done
fi
if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_SERVICE_KEY:-}" ]]; then
    echo "ERROR: SUPABASE_URL / SUPABASE_SERVICE_KEY not set (backend/.env or environment)."
    exit 1
fi

gcloud config set project "${PROJECT_ID}"

echo "[1/4] Enabling APIs..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com \
    aiplatform.googleapis.com generativelanguage.googleapis.com --quiet

echo "[2/4] Building container..."
cd "$(dirname "$0")"
gcloud builds submit --tag "${IMAGE_NAME}" --quiet

echo "[3/4] Deploying to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
    --image "${IMAGE_NAME}" \
    --region "${REGION}" \
    --platform managed \
    --allow-unauthenticated \
    --memory 1Gi --cpu 1 \
    --min-instances 0 --max-instances 10 \
    --set-env-vars "GOOGLE_CLOUD_PROJECT=${PROJECT_ID},GEMINI_API_KEY=${GEMINI_API_KEY},SUPABASE_URL=${SUPABASE_URL},SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY}" \
    --quiet

SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" --region "${REGION}" --format "value(status.url)")
echo ""
echo "=== Deployed: ${SERVICE_URL} ==="
echo "Test: curl ${SERVICE_URL}/health"
