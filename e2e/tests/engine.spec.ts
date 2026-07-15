import { test, expect } from '@playwright/test';

// The REAL thing: a `flutter build web` engine bundle overlaid with the SSG
// output of the example app (example/TEMP/e2e-dist, built by
// `melos run e2e:engine`). No mocks - the dispatcher loads the actual engine
// via flutter_bootstrap.js and mounts IslandMultiViewApp views per island.

declare global {
  interface Window {
    hydraline: { views: Record<string, number> };
  }
}

test('SSG page hydrates a real Flutter island on scroll', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(String(e)));

  await page.goto('/product/espresso.html');

  // The server-rendered content is present before any engine work.
  await expect(page.locator('h1')).toHaveText('Product: espresso');

  const island = page.locator('#calculator-espresso');
  await island.scrollIntoViewIfNeeded();

  // Real engine boot: CanvasKit + main.dart.js + deferred island library.
  await expect(island).toHaveAttribute('data-hydration', 'hydrated', {
    timeout: 90000,
  });
  await expect(island).toHaveAttribute('aria-busy', 'false');

  // The dispatcher registered a real FlutterView for the island.
  const views = await page.evaluate(() => window.hydraline.views);
  expect(views['calculator-espresso']).toBeDefined();

  // The engine rendered into the island's shadow-root mount.
  const mounted = await page.evaluate(() => {
    const root = document.getElementById('calculator-espresso')!.shadowRoot!;
    const mount = root.querySelector('.hydraline-mount');
    return {
      hasMount: !!mount,
      hasEngineDom: !!mount && mount.childElementCount > 0,
    };
  });
  expect(mounted.hasMount).toBe(true);
  expect(mounted.hasEngineDom).toBe(true);

  expect(errors).toEqual([]);
});

test('the hydrated calculator island is actually interactive', async ({
  page,
}) => {
  await page.goto('/product/espresso.html');
  const island = page.locator('#calculator-espresso');
  await island.scrollIntoViewIfNeeded();
  await expect(island).toHaveAttribute('data-hydration', 'hydrated', {
    timeout: 90000,
  });

  // Flutter renders to canvas; the accessibility tree is the DOM contract.
  // Activate it the way assistive tech does - via the engine's placeholder.
  await page.evaluate(() => {
    document
      .querySelector('flt-semantics-placeholder')
      ?.dispatchEvent(
        new MouseEvent('click', { bubbles: true, cancelable: true }),
      );
  });

  // CalculatorIsland shows "1 pcs - total 249" and a "+" IconButton.
  await expect(island.getByText(/total 249/)).toBeVisible({ timeout: 30000 });

  await island.getByRole('button').last().click();
  await expect(island.getByText(/2 pcs - total 498/)).toBeVisible();
});

test('a document page never loads the Flutter engine (zero overhead)', async ({
  page,
}) => {
  const engineRequests: string[] = [];
  page.on('request', (req) => {
    const url = req.url();
    if (url.includes('main.dart.js') || url.includes('canvaskit')) {
      engineRequests.push(url);
    }
  });

  await page.goto('/index.html');
  await expect(page.locator('h1')).toHaveText('Hydraline Demo Shop');
  await page.waitForTimeout(1500);

  expect(engineRequests).toEqual([]);
});
