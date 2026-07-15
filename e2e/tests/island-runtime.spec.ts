import { test, expect } from '@playwright/test';

// These tests exercise the REAL shipped island runtime JS
// (packages/hydraline_flutter/web/*.js) in a real Chrome, with a mocked
// Flutter engine, closing the gap left by the string-content unit tests.

declare global {
  interface Window {
    __addView: Array<{ initialData: { islandId: string; state: unknown } }>;
    __removeView: number[];
    __errors: Array<{ id: string; reason: string }>;
    __enter: string[];
    __leave: string[];
    hydraline: {
      version: string;
      hydrate: (id: string) => void;
      hydrateAll: () => void;
      dehydrate: (id: string) => void;
      views: Record<string, number>;
    };
  }
}

const hydration = (page: import('@playwright/test').Page, id: string) =>
  page.getAttribute(`#${id}`, 'data-hydration');

test.describe('dispatcher: hydrateOnLoad', () => {
  test('hydrates on load and mounts one view with { islandId, state }', async ({
    page,
  }) => {
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(String(e)));

    await page.goto('/e2e/fixtures/dispatcher-onload.html');

    await expect.poll(() => hydration(page, 'calc')).toBe('hydrated');
    expect(await page.getAttribute('#calc', 'aria-busy')).toBe('false');

    const views = await page.evaluate(() => window.__addView);
    expect(views).toHaveLength(1);
    expect(views[0].initialData).toEqual({
      islandId: 'calc',
      state: { price: 9 },
    });
    expect(errors).toEqual([]);
  });

  test('exposes the window.hydraline API', async ({ page }) => {
    await page.goto('/e2e/fixtures/dispatcher-onload.html');
    const api = await page.evaluate(() => ({
      version: window.hydraline.version,
      hydrate: typeof window.hydraline.hydrate,
      hydrateAll: typeof window.hydraline.hydrateAll,
      dehydrate: typeof window.hydraline.dehydrate,
    }));
    expect(api.hydrate).toBe('function');
    expect(api.hydrateAll).toBe('function');
    expect(api.dehydrate).toBe('function');
    expect(api.version).toBeTruthy();
  });

  test('re-evaluating the dispatcher does not double-mount', async ({
    page,
  }) => {
    await page.goto('/e2e/fixtures/dispatcher-onload.html');
    await expect.poll(() => hydration(page, 'calc')).toBe('hydrated');

    await page.addScriptTag({
      url: '/packages/hydraline_flutter/web/hydraline-dispatcher.js',
    });

    const count = await page.evaluate(() => window.__addView.length);
    expect(count).toBe(1);
  });

  test('dehydrate removes the captured view and resets state', async ({
    page,
  }) => {
    await page.goto('/e2e/fixtures/dispatcher-onload.html');
    await expect.poll(() => hydration(page, 'calc')).toBe('hydrated');

    await page.evaluate(() => window.hydraline.dehydrate('calc'));

    await expect.poll(() => hydration(page, 'calc')).toBe('pending');
    const removed = await page.evaluate(() => window.__removeView);
    expect(removed).toEqual([42]);
  });
});

test.describe('dispatcher: hydrateOnInteraction', () => {
  test('stays pending until a user interaction, then hydrates', async ({
    page,
  }) => {
    await page.goto('/e2e/fixtures/dispatcher-interaction.html');

    expect(await hydration(page, 'chart')).not.toBe('hydrated');
    expect(await page.evaluate(() => window.__addView.length)).toBe(0);

    await page.click('#outside');
    await page.click('#inside');

    await expect.poll(() => hydration(page, 'chart')).toBe('hydrated');
    expect(await page.evaluate(() => window.__addView.length)).toBe(1);
  });
});

test.describe('dispatcher: failure handling', () => {
  test('marks failed and emits island-error when the engine rejects', async ({
    page,
  }) => {
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(String(e)));

    await page.goto('/e2e/fixtures/dispatcher-error.html');

    await expect.poll(() => hydration(page, 'broken')).toBe('failed');
    const captured = await page.evaluate(() => window.__errors);
    expect(captured).toHaveLength(1);
    expect(captured[0].id).toBe('broken');
    // A rejected engine must never surface as an uncaught page error.
    expect(errors).toEqual([]);
  });

  test('parks a bootstrap rejection while no island has hydrated', async ({
    page,
  }) => {
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(String(e)));

    await page.goto('/e2e/fixtures/dispatcher-prerejected.html');

    // Give the deferred bootstrap rejection time to settle unhandled.
    await page.waitForTimeout(200);
    expect(errors).toEqual([]);

    // A later manual hydration still receives the failure per island.
    await page.evaluate(() => window.hydraline.hydrate('early'));
    await expect.poll(() => hydration(page, 'early')).toBe('failed');
    const captured = await page.evaluate(() => window.__errors);
    expect(captured).toHaveLength(1);
    expect(captured[0].id).toBe('early');
    expect(errors).toEqual([]);
  });
});

test.describe('custom element', () => {
  test('reserves the data-size dimensions on :host (anti-CLS)', async ({
    page,
  }) => {
    await page.goto('/e2e/fixtures/custom-element.html');

    const css = await page.evaluate(() => {
      const el = document.getElementById('sized')!;
      const style = el.shadowRoot!.querySelector('style')!;
      return style.textContent ?? '';
    });
    expect(css).toContain('width:480px');
    expect(css).toContain('height:270px');
    expect(css).toContain('contain:layout style paint');
  });

  test('keeps the declarative shadow root and its slotted fallback', async ({
    page,
  }) => {
    await page.goto('/e2e/fixtures/custom-element.html');

    const hasShadow = await page.evaluate(
      () => !!document.getElementById('sized')!.shadowRoot,
    );
    expect(hasShadow).toBe(true);
    await expect(page.locator('#fallback')).toHaveText(
      'server-rendered fallback',
    );
  });
});

test.describe('virtual views', () => {
  test('emits segment-enter for an in-viewport segment', async ({ page }) => {
    await page.goto('/e2e/fixtures/virtual-views.html');
    await expect.poll(() => page.evaluate(() => window.__enter)).toContain(
      'seg-1',
    );
  });
});
