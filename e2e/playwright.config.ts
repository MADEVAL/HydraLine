import { defineConfig, devices } from '@playwright/test';

// Uses the system-installed Google Chrome (channel: 'chrome'), so no browser
// download is needed. Two static servers expose the repo and the generated
// real-engine dist over http.
//
// Projects:
//   chrome  fast suite against the shipped runtime JS with a mocked engine
//   engine  real Flutter engine (requires `melos run e2e:engine` prep step
//           that builds example/TEMP/e2e-dist first)
export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? 'line' : [['list']],
  use: {
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chrome',
      testIgnore: /engine\.spec\.ts/,
      use: {
        ...devices['Desktop Chrome'],
        channel: 'chrome',
        baseURL: 'http://localhost:4173',
      },
    },
    {
      name: 'engine',
      testMatch: /engine\.spec\.ts/,
      timeout: 120000,
      use: {
        ...devices['Desktop Chrome'],
        channel: 'chrome',
        baseURL: 'http://localhost:4174',
      },
    },
  ],
  webServer: [
    {
      command: 'node server.mjs',
      url: 'http://localhost:4173/__health',
      reuseExistingServer: !process.env.CI,
      stdout: 'ignore',
      stderr: 'pipe',
    },
    {
      command: 'node server.mjs',
      url: 'http://localhost:4174/__health',
      reuseExistingServer: !process.env.CI,
      stdout: 'ignore',
      stderr: 'pipe',
      env: { PORT: '4174', ROOT: 'example/TEMP/e2e-dist' },
    },
  ],
});
