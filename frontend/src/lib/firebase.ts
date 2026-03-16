/**
 * Firebase initialization stub for MVP.
 * Replace with actual Firebase config when ready.
 */

interface FirebaseConfig {
  apiKey: string;
  authDomain: string;
  projectId: string;
}

function getFirebaseConfig(): FirebaseConfig {
  return {
    apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? '',
    authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN ?? '',
    projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? '',
  };
}

let initialized = false;

export function initFirebase(): void {
  if (initialized) return;
  const config = getFirebaseConfig();
  if (!config.apiKey) {
    console.warn('[MirrorMind] Firebase not configured. Gallery persistence disabled.');
    return;
  }
  // Future: initialize Firebase app here
  // const app = initializeApp(config);
  initialized = true;
}

export function isFirebaseReady(): boolean {
  return initialized;
}
