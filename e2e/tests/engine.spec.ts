import { test, expect } from '@playwright/test';

// The REAL thing: a `flutter build web` engine bundle overlaid with the SSG
// output of the example app (example/TEMP/e2e-dist, built by
// `melos run e2e:engine`). No mocks - the dispatcher loads the actual engine
// via flutter_bootstrap.js and mounts IslandMultiViewApp views per island.

declare global {
  interface Window {
    hydraline: { views: Record<string, number> };
    __cls: number;
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

test('cumulative layout shift stays under 0.01 (anti-CLS invariant)', async ({
  page,
}) => {
  // Inject the observer as early as possible so it catches layout shifts
  // during the initial paint and subsequent island hydration.
  await page.addInitScript(() => {
    window.__cls = 0;
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        if (!(entry as any).hadRecentInput) {
          window.__cls += (entry as any).value;
        }
      }
    }).observe({ type: 'layout-shift', buffered: true });
  });

  await page.goto('/product/espresso.html');
  const island = page.locator('#calculator-espresso');

  // Let the initial layout settle, then trigger hydration.
  await page.waitForTimeout(500);
  await island.scrollIntoViewIfNeeded();

  // The island reserves 640×320 via data-size; any layout shift during
  // engine boot and view attachment pushes CLS above the threshold.
  await expect(island).toHaveAttribute('data-hydration', 'hydrated', {
    timeout: 90000,
  });

  // Give the engine one extra frame to render and stabilise.
  await page.waitForTimeout(1000);

  const cls = await page.evaluate(() => window.__cls as number);
  expect(cls).toBeLessThan(0.01);
});

test('service worker caches engine assets for warm visits', async ({
  page,
}) => {
  await page.goto('/product/espresso.html');

  // The SSG runner copies service-worker.js but the page does not register
  // it - the host site bootstrap is responsible. Register it here and
  // wait for activation so the fetch handler caches engine subresources.
  await page.evaluate(async () => {
    if (!navigator.serviceWorker.controller) {
      await navigator.serviceWorker.register('/service-worker.js');
      await navigator.serviceWorker.ready;
      // The SW's activate handler calls clients.claim(); give it a tick.
      await new Promise((r) => setTimeout(r, 500));
    }
  });

  const island = page.locator('#calculator-espresso');
  await island.scrollIntoViewIfNeeded();
  await expect(island).toHaveAttribute('data-hydration', 'hydrated', {
    timeout: 90000,
  });

  const cacheEntries = await page.evaluate(async () => {
    const cache = await caches.open('hydraline-v1');
    const keys = await cache.keys();
    return keys.map((k) => k.url).filter(
      (u) => u.includes('main.dart.js') || u.includes('canvaskit'),
    );
  });
  expect(cacheEntries.length).toBeGreaterThan(0);
});

