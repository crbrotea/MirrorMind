import { test, expect } from '@playwright/test';

/**
 * Mock getUserMedia to provide synthetic audio so tests don't need a real mic.
 * Must run before the page loads.
 */
async function mockGetUserMedia(page: import('@playwright/test').Page) {
  await page.addInitScript(() => {
    // Override getUserMedia with a synthetic audio stream
    const originalGetUserMedia = navigator.mediaDevices.getUserMedia.bind(
      navigator.mediaDevices
    );

    navigator.mediaDevices.getUserMedia = async (constraints) => {
      // If requesting audio, return a synthetic stream
      if (constraints && (constraints as MediaStreamConstraints).audio) {
        try {
          const ctx = new AudioContext({ sampleRate: 16000 });
          const oscillator = ctx.createOscillator();
          oscillator.frequency.value = 440;
          const dest = ctx.createMediaStreamDestination();
          oscillator.connect(dest);
          oscillator.start();
          return dest.stream;
        } catch {
          // Fallback: create a silent MediaStream
          const ctx = new AudioContext();
          const dest = ctx.createMediaStreamDestination();
          return dest.stream;
        }
      }
      return originalGetUserMedia(constraints);
    };
  });
}

test.describe('Session Flow', () => {
  test('shows loading state then session UI', async ({ page }) => {
    await mockGetUserMedia(page);
    await page.goto('/session');

    // Should show loading initially
    await expect(page.getByText('Preparando tu espacio...')).toBeVisible();

    // After loading, session UI should appear
    await expect(page.getByTestId('session-active')).toBeVisible({
      timeout: 10_000,
    });

    // Key UI elements should be present
    await expect(page.getByTestId('session-header')).toBeVisible();
    await expect(page.getByTestId('emotional-canvas')).toBeVisible();
    await expect(page.getByTestId('voice-controls')).toBeVisible();
  });

  test('connects to WebSocket and receives welcome stage', async ({ page }) => {
    await mockGetUserMedia(page);
    await page.goto('/session');

    // Wait for session to load
    await expect(page.getByTestId('session-active')).toBeVisible({
      timeout: 10_000,
    });

    // Stage label should show welcome (Bienvenida in Spanish)
    await expect(page.getByTestId('stage-label')).toContainText('Bienvenida', {
      timeout: 10_000,
    });
  });

  test('receives agent transcript from mock backend', async ({ page }) => {
    await mockGetUserMedia(page);
    await page.goto('/session');

    await expect(page.getByTestId('session-active')).toBeVisible({
      timeout: 10_000,
    });

    // Mock backend sends a transcript after welcome
    await expect(page.getByTestId('agent-transcript')).toBeVisible({
      timeout: 10_000,
    });
  });

  test('transitions through stages and receives images', async ({ page }) => {
    await mockGetUserMedia(page);
    await page.goto('/session');

    await expect(page.getByTestId('session-active')).toBeVisible({
      timeout: 10_000,
    });

    // Wait for mirror stage (mock backend transitions after ~3.5s)
    await expect(page.getByTestId('stage-label')).toContainText('Espejo', {
      timeout: 15_000,
    });

    // An image should appear in the canvas
    await expect(
      page.getByTestId('emotional-canvas').locator('img')
    ).toBeVisible({ timeout: 10_000 });
  });

  test('shows breathing guide during shift stage', async ({ page }) => {
    await mockGetUserMedia(page);
    await page.goto('/session');

    await expect(page.getByTestId('session-active')).toBeVisible({
      timeout: 10_000,
    });

    // Wait for shift stage (mock backend transitions after ~6.5s)
    await expect(page.getByTestId('stage-label')).toContainText(
      'Transformación',
      { timeout: 20_000 }
    );

    // Breathing guide should appear
    await expect(page.getByTestId('breathing-guide')).toBeVisible({
      timeout: 5_000,
    });
  });

  test('full session completes and shows completion UI', async ({ page }) => {
    await mockGetUserMedia(page);
    await page.goto('/session');

    await expect(page.getByTestId('session-active')).toBeVisible({
      timeout: 10_000,
    });

    // Wait for session complete (mock runs ~12s total)
    await expect(page.getByTestId('session-complete')).toBeVisible({
      timeout: 30_000,
    });

    // Completion UI elements
    await expect(page.getByText('Sesión completada')).toBeVisible();
    await expect(page.getByText('Ver galería')).toBeVisible();
    await expect(page.getByText('Inicio')).toBeVisible();
  });

  test('end session button navigates back to landing', async ({ page }) => {
    await mockGetUserMedia(page);
    await page.goto('/session');

    await expect(page.getByTestId('session-active')).toBeVisible({
      timeout: 10_000,
    });

    // Click end session
    await page.getByRole('button', { name: 'Finalizar sesión' }).click();

    // Should navigate to landing
    await expect(page).toHaveURL('/', { timeout: 5_000 });
  });
});
