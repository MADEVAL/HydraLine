import { test, expect } from '@playwright/test';

// L1 vanilla islands (packages/hydraline/web/vanilla-islands.js, kept
// byte-identical to the Dart constant) exercised in real Chrome. The fixture
// includes a broken carousel (no controls) BEFORE working islands, proving
// the hardened bootstrap isolates per-island failures.

test.beforeEach(async ({ page }) => {
  await page.goto('/e2e/fixtures/vanilla-islands.html');
});

test('page boots without errors despite a control-less carousel', async ({
  page,
}) => {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.reload();
  await page.waitForTimeout(100);
  expect(errors).toEqual([]);
});

test('accordion toggles details and mirrors aria-expanded', async ({
  page,
}) => {
  const details = page.locator('#acc details');
  await expect(details).not.toHaveAttribute('open', '');

  await page.click('#acc-summary');
  await expect(details).toHaveAttribute('open', '');
  await expect(details).toHaveAttribute('aria-expanded', 'true');

  await page.click('#acc-summary');
  await expect(details).not.toHaveAttribute('open', '');
  await expect(details).toHaveAttribute('aria-expanded', 'false');
});

test('tabs show the selected panel and update aria-selected', async ({
  page,
}) => {
  await page.click('#tab-b');
  await expect(page.locator('#panel-b')).toBeVisible();
  await expect(page.locator('#panel-a')).toBeHidden();
  await expect(page.locator('#tab-b')).toHaveAttribute(
    'aria-selected',
    'true',
  );
  await expect(page.locator('#tab-a')).toHaveAttribute(
    'aria-selected',
    'false',
  );

  await page.click('#tab-a');
  await expect(page.locator('#panel-a')).toBeVisible();
  await expect(page.locator('#panel-b')).toBeHidden();
});

test('carousel navigates with wrap-around', async ({ page }) => {
  const index = () => page.getAttribute('#car', 'data-slide-index');

  expect(await index()).toBe('0');
  await expect(page.locator('#slide-0')).toBeVisible();
  await expect(page.locator('#slide-1')).toBeHidden();

  await page.click('#car-next');
  expect(await index()).toBe('1');
  await expect(page.locator('#slide-1')).toBeVisible();

  await page.click('#car-prev');
  await page.click('#car-prev');
  expect(await index()).toBe('2'); // 0 -> -1 wraps to the last slide
  await expect(page.locator('#slide-2')).toBeVisible();
});

test('theme toggle flips data-theme and persists to localStorage', async ({
  page,
}) => {
  const theme = () =>
    page.evaluate(() => document.documentElement.getAttribute('data-theme'));

  const initial = await theme();
  expect(['light', 'dark']).toContain(initial);

  await page.click('#theme-btn');
  const flipped = await theme();
  expect(flipped).not.toBe(initial);
  expect(
    await page.evaluate(() => localStorage.getItem('hydraline-theme')),
  ).toBe(flipped);
});

test('lazy-image copies data-src into src once visible', async ({ page }) => {
  await expect
    .poll(() => page.getAttribute('#lazy img', 'src'))
    .toContain('/e2e/fixtures/vanilla-islands.html');
});

test('copy-button writes the target text to the clipboard', async ({
  page,
  context,
}) => {
  await context.grantPermissions(['clipboard-read', 'clipboard-write']);

  await page.click('#copy-btn');

  await expect.poll(() => page.getAttribute('#copy', 'data-copied')).toBe('1');
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(
    'copied text',
  );
});
