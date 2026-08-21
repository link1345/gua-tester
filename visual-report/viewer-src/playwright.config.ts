import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  use: {
    baseURL: "http://127.0.0.1:4323/sample-repo/",
    channel: "chromium",
  },
  webServer: {
    command: "bun tests/server.mjs",
    url: "http://127.0.0.1:4323/sample-repo/",
    reuseExistingServer: false,
  },
});
