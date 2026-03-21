# Getting Started

## Prerequisites

- **Node.js** 18+ and npm
- **Python** 3.12+
- **Google API Key** with access to Gemini API (Generative Language API)
- **Google Chrome** (recommended browser)
- Microphone access

## Environment Setup

### Backend

1. Navigate to the backend directory and create a virtual environment:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
```

2. Install dependencies:

```bash
pip install -e .
```

3. Configure environment variables:

```bash
cp .env.example .env
```

Edit `.env` with your values:

```env
GOOGLE_API_KEY=your-gemini-api-key
FIREBASE_PROJECT_ID=your-project-id    # Optional, in-memory fallback available
HOST=0.0.0.0
PORT=8080
CORS_ORIGINS=http://localhost:3000
LOG_LEVEL=INFO
TEST_MODE=false
```

4. Start the backend server:

```bash
uvicorn main:app --reload --port 8080
```

### Frontend

1. Navigate to the frontend directory:

```bash
cd frontend
npm install
```

2. Configure the WebSocket URL in `.env.local`:

```env
NEXT_PUBLIC_WS_URL=ws://localhost:8080/ws
```

3. Start the development server:

```bash
npm run dev
```

The app will be available at `http://localhost:3000`.

## Test Mode

For development without a Gemini API key, set `TEST_MODE=true` in the backend `.env`. This uses mock sessions with pre-defined responses and images.

## Verify Installation

1. Open `http://localhost:3000` in Chrome
2. You should see the MirrorMind landing page with a "Comenzar" button
3. Check the backend health endpoint at `http://localhost:8080/health`
