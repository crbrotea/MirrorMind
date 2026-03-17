# MirrorMind

An emotional mirror web app that generates real-time art reflecting your emotional state through voice interaction. Speak, and watch your emotions transform into evolving landscapes.

## Architecture

```
Browser (Next.js)  ←→  WebSocket  ←→  FastAPI (Cloud Run)
    ↓ mic audio                          ↓
    ↓ PCM 16kHz                     Google ADK Agent
    ↓                                    ↓
    ← art images ←                  Gemini Live API (voice/emotion)
    ← agent audio ←                 Gemini Image Gen (landscapes)
    ← transcripts ←                 Firestore (gallery)
```

## Prerequisites

- Node.js 20+
- Python 3.12+
- Google Cloud CLI (`gcloud`)
- Vercel CLI (`vercel`)
- A Google Cloud account with billing enabled

## Local Development

### 1. Backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -e .

# Configure environment
cp .env.example .env
# Edit .env with your GOOGLE_API_KEY

# Run
uvicorn main:app --reload --port 8080
```

### 2. Frontend

```bash
cd frontend
npm install

# Configure environment
cp .env.local.example .env.local
# Default WS_URL points to localhost:8080

# Run
npm run dev
```

Open http://localhost:3000, click "Comenzar", allow microphone, and speak.

---

## Production Deployment

### Step 1: Create GCP Project

```bash
# Create project
gcloud projects create mirrormind-app-2026 --name="MirrorMind"
gcloud config set project mirrormind-app-2026

# Link billing
gcloud billing accounts list
gcloud billing projects link mirrormind-app-2026 --billing-account=YOUR_BILLING_ACCOUNT_ID
```

### Step 2: Enable APIs

```bash
gcloud services enable \
  generativelanguage.googleapis.com \
  firestore.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  firebase.googleapis.com \
  apikeys.googleapis.com \
  --project=mirrormind-app-2026
```

### Step 3: Create Firestore Database

```bash
gcloud firestore databases create --location=us-central1 --project=mirrormind-app-2026
```

### Step 4: Create Gemini API Key

```bash
gcloud services api-keys create \
  --display-name="MirrorMind Gemini Key" \
  --api-target=service=generativelanguage.googleapis.com \
  --project=mirrormind-app-2026
```

Save the `keyString` from the output — you'll need it for the backend.

### Step 5: Add Firebase to the Project

```bash
curl -s -X POST \
  "https://firebase.googleapis.com/v1beta1/projects/mirrormind-app-2026:addFirebase" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -H "x-goog-user-project: mirrormind-app-2026"
```

### Step 6: Grant IAM Permissions for Cloud Build

```bash
SA="$(gcloud projects describe mirrormind-app-2026 --format='value(projectNumber)')-compute@developer.gserviceaccount.com"

gcloud projects add-iam-policy-binding mirrormind-app-2026 \
  --member="serviceAccount:$SA" \
  --role="roles/storage.objectViewer" --condition=None

gcloud projects add-iam-policy-binding mirrormind-app-2026 \
  --member="serviceAccount:$SA" \
  --role="roles/cloudbuild.builds.builder" --condition=None

gcloud projects add-iam-policy-binding mirrormind-app-2026 \
  --member="serviceAccount:$SA" \
  --role="roles/artifactregistry.writer" --condition=None

gcloud projects add-iam-policy-binding mirrormind-app-2026 \
  --member="serviceAccount:$SA" \
  --role="roles/logging.logWriter" --condition=None
```

### Step 7: Deploy Backend to Cloud Run

```bash
cd backend

gcloud run deploy mirrormind-backend \
  --source=. \
  --region=us-central1 \
  --allow-unauthenticated \
  --port=8080 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=3 \
  --set-env-vars="GOOGLE_API_KEY=YOUR_API_KEY,FIREBASE_PROJECT_ID=mirrormind-app-2026,CORS_ORIGINS=https://YOUR_VERCEL_URL,LOG_LEVEL=INFO" \
  --session-affinity \
  --timeout=300 \
  --project=mirrormind-app-2026 \
  --quiet
```

Note the Service URL from the output (e.g., `https://mirrormind-backend-XXXXX.us-central1.run.app`).

Verify:
```bash
curl https://mirrormind-backend-XXXXX.us-central1.run.app/health
```

### Step 8: Deploy Frontend to Vercel

```bash
cd frontend

# First deploy to get the URL
vercel --yes --prod

# Set the backend WebSocket URL
vercel env add NEXT_PUBLIC_WS_URL production
# Enter: wss://mirrormind-backend-XXXXX.us-central1.run.app/ws

# Redeploy with the env var
vercel --yes --prod
```

### Step 9: Update Backend CORS

After getting the Vercel URL, update the backend's CORS origins:

```bash
cd backend

gcloud run services update mirrormind-backend \
  --region=us-central1 \
  --update-env-vars="CORS_ORIGINS=https://YOUR_VERCEL_URL" \
  --project=mirrormind-app-2026
```

---

## Redeploying After Changes

### Backend only

```bash
cd backend
gcloud run deploy mirrormind-backend \
  --source=. \
  --region=us-central1 \
  --project=mirrormind-app-2026 \
  --quiet
```

### Frontend only

```bash
cd frontend
vercel --yes --prod
```

---

## Monitoring

```bash
# Backend health
curl https://mirrormind-backend-XXXXX.us-central1.run.app/health

# Backend logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=mirrormind-backend" \
  --project=mirrormind-app-2026 --limit=20 --freshness=5m --format="value(textPayload)"

# Error logs only
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=mirrormind-backend AND severity>=ERROR" \
  --project=mirrormind-app-2026 --limit=10 --freshness=10m --format="value(textPayload)"

# Frontend logs
vercel logs --prod
```

## Production URLs

| Service | URL |
|---------|-----|
| Frontend | https://frontend-two-rho-21.vercel.app |
| Backend | https://mirrormind-backend-759577962534.us-central1.run.app |
| GCP Project | `mirrormind-app-2026` |
| Firestore | us-central1 |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Next.js 15, React, TypeScript, Tailwind CSS |
| Backend | Python 3.12, FastAPI, Google ADK |
| Voice/Emotion | Gemini Live API (native audio) |
| Image Generation | Gemini 2.5 Flash Image |
| Database | Firebase/Firestore |
| Frontend Hosting | Vercel |
| Backend Hosting | Google Cloud Run |
