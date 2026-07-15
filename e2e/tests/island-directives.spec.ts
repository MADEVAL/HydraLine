import { test, expect } from '@playwright/test';

// Directive coverage against the real dispatcher in real Chrome:
// hydrateOnVisible (IntersectionObserver), hydrateOnIdle (requestIdleCallback),
// hydrateOnMedia (matchMedia) and N islands sharing one engine.

declare global {
  interface Window {
    __addView: Array<{ initialData: { islandId: string; state: unknown } }>;
    hydraline: { views: Record<string, number> };
  }
}

const hydration = (page: import('@playwright/test').Page, id: string) =>
  page.getAttribute(`#${id}`, 'data-hydration');

test('hydrateOnVisible: cold below the fold, hydrates on scroll', async ({
  page,
}) => {
  await page.goto('/e2e/fixtures/dispatcher-onvisible.html');

  expect(await hydration(page, 'below')).not.toBe('hydrated');
  expect(await page.evaluate(() => window.__addView.length)).toBe(0);

  await page.locator('#below').scrollIntoViewIfNeeded();

  await expect.poll(() => hydration(page, 'below')).toBe('hydrated');
  const views = await page.evaluate(() => window.__addView);
  expect(views).toHaveLength(1);
  expect(views[0].initialData).toEqual({
    islandId: 'below',
    state: { kind: 'visible' },
  });
});

test('hydrateOnIdle: hydrates when the main thread goes idle', async ({
  page,
}) => {
  await page.goto('/e2e/fixtures/dispatcher-onidle.html');

  await expect.poll(() => hydration(page, 'lazy')).toBe('hydrated');
  expect(await page.evaluate(() => window.__addView.length)).toBe(1);
});

test('hydrateOnMedia: cold on a narrow viewport, hydrates when it matches', async ({
  page,
}) => {
  await page.setViewportSize({ width: 500, height: 600 });
  await page.goto('/e2e/fixtures/dispatcher-onmedia.html');

  expect(await hydration(page, 'wide')).not.toBe('hydrated');
  expect(await page.evaluate(() => window.__addView.length)).toBe(0);

  await page.setViewportSize({ width: 900, height: 600 });

  await expect.poll(() => hydration(page, 'wide')).toBe('hydrated');
  expect(await page.evaluate(() => window.__addView.length)).toBe(1);
});

test('multi-island: one engine, one view per island, distinct state', async ({
  page,
}) => {
  await page.goto('/e2e/fixtures/dispatcher-multi.html');

  await expect.poll(() => hydration(page, 'first')).toBe('hydrated');
  await expect.poll(() => hydration(page, 'second')).toBe('hydrated');

  const views = await page.evaluate(() => window.__addView);
  expect(views).toHaveLength(2);
  const byId = Object.fromEntries(
    views.map((v) => [v.initialData.islandId, v.initialData.state]),
  );
  expect(byId).toEqual({ first: { n: 1 }, second: { n: 2 } });

  const mapping = await page.evaluate(() => window.hydraline.views);
  expect(Object.keys(mapping).sort()).toEqual(['first', 'second']);
  expect(mapping['first']).not.toBe(mapping['second']);
});
