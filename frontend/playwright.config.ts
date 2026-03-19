import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  timeout: 60_000,
  expect: { timeout: 15_000 },
  fullyParallel: false, // Session tests depend on sequential flow
  retries: 1,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    permissions: ['microphone'],
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: [
    {
      // Backend in test mode
      command: 'cd ../backend && TEST_MODE=true .venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8080',
      port: 8080,
      reuseExistingServer: !process.env.CI,
      timeout: 30_000,
    },
    {
      // Frontend dev server
      command: 'npm run dev',
      port: 3000,
      reuseExistingServer: !process.env.CI,
      timeout: 30_000,
    },
  ],
});
