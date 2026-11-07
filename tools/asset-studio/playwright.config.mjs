import { defineConfig } from '@playwright/test';
import { existsSync } from 'node:fs';
import path from 'node:path';
const edge = [process.env['ProgramFiles(x86)'], process.env.ProgramFiles].filter(Boolean).map(p => path.join(p, 'Microsoft/Edge/Application/msedge.exe')).find(existsSync);
export default defineConfig({
  testDir: './test/browser', timeout: 45000, workers: 1,
  outputDir: '.cache/test-results', reporter: 'list',
  use: { baseURL: 'http://127.0.0.1:4173', viewport: { width: 1440, height: 1000 }, launchOptions: { executablePath: process.env.PLAYWRIGHT_BROWSER ?? edge }, screenshot: 'only-on-failure' },
  webServer: { command: 'npm run dev', url: 'http://127.0.0.1:4173/api/catalog', reuseExistingServer: true, timeout: 60000 },
});
