# Deployment

## Production Architecture

- **Frontend**: Vercel
- **Backend**: Google Cloud Run
- **Database**: Firebase Firestore (us-central1)

## Backend Deployment (Cloud Run)

### Prerequisites

1. Create a GCP project
2. Enable APIs: Generative Language, Firestore, Cloud Run, Artifact Registry
3. Create a Firestore database in `us-central1`
4. Generate a Gemini API key (restrict to `generativelanguage.googleapis.com`)

### Deploy

The backend includes a `Dockerfile` for containerized deployment:

```bash
cd backend

# Build and push to Artifact Registry
gcloud builds submit --tag gcr.io/YOUR_PROJECT/mirrormind-backend

# Deploy to Cloud Run
gcloud run deploy mirrormind-backend \
  --image gcr.io/YOUR_PROJECT/mirrormind-backend \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "GOOGLE_API_KEY=your-key,FIREBASE_PROJECT_ID=your-project,CORS_ORIGINS=https://your-frontend.vercel.app"
```

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GOOGLE_API_KEY` | Yes | Gemini API key |
| `FIREBASE_PROJECT_ID` | No | Firestore project (falls back to in-memory) |
| `HOST` | No | Defaults to `0.0.0.0` |
| `PORT` | No | Defaults to `8080` |
| `CORS_ORIGINS` | Yes | Comma-separated allowed origins |
| `LOG_LEVEL` | No | Defaults to `INFO` |
| `TEST_MODE` | No | `true` for mock sessions |

## Frontend Deployment (Vercel)

1. Connect your repository to Vercel
2. Set the root directory to `frontend`
3. Add environment variable:

| Variable | Value |
|----------|-------|
| `NEXT_PUBLIC_WS_URL` | `wss://your-backend.run.app/ws` |

4. Deploy

## Post-Deployment

1. Update the backend's `CORS_ORIGINS` with the production Vercel URL
2. Verify the health endpoint: `GET https://your-backend.run.app/health`
3. Test a full session flow end-to-end
