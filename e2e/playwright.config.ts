import { defineConfig, devices } from '@playwright/test';

// Uses the system-installed Google Chrome (channel: 'chrome'), so no browser
// download is needed. A tiny static server exposes the repo over http.
export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? 'line' : [['list']],
  use: {
    baseURL: 'http://localhost:4173',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chrome',
      use: { ...devices['Desktop Chrome'], channel: 'chrome' },
    },
  ],
  webServer: {
    command: 'node server.mjs',
    url: 'http://localhost:4173/e2e/fixtures/dispatcher-onload.html',
    reuseExistingServer: !process.env.CI,
    stdout: 'ignore',
    stderr: 'pipe',
  },
});
