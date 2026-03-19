import { test, expect } from '@playwright/test';

test.describe('Landing Page', () => {
  test('shows MirrorMind title and CTA', async ({ page }) => {
    await page.goto('/');

    await expect(page.getByRole('heading', { name: 'MirrorMind' })).toBeVisible();
    await expect(page.getByText('Tu Espejo Emocional')).toBeVisible();
    await expect(page.getByText('Comenzar')).toBeVisible();
    await expect(page.getByText('Ver galería de sesiones')).toBeVisible();
  });

  test('Comenzar navigates to /session', async ({ page }) => {
    await page.goto('/');
    await page.getByText('Comenzar').click();
    await expect(page).toHaveURL('/session');
  });

  test('gallery link navigates to /gallery', async ({ page }) => {
    await page.goto('/');
    await page.getByText('Ver galería de sesiones').click();
    await expect(page).toHaveURL('/gallery');
  });
});
