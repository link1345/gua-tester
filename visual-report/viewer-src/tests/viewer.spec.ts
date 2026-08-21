import { expect, test, type Page, type Route } from "@playwright/test";

const pixel = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgQIA6i7mWQAAAABJRU5ErkJggg==", "base64");

function report(outcome: "success" | "failure" | "cancelled" = "failure", includeComparisons = outcome !== "success") {
  return {
    schemaVersion: 1,
    outcome,
    generatedAt: "2026-08-21T12:00:00Z",
    run: { repository: "link1345/example", id: "123", number: "9", commit: "0123456789abcdef" },
    comparisons: includeComparisons ? [
      { id: "001", name: "Title <script>window.__pwned=true</script>", variant: "windows", reason: "pixel_difference", width: 960, height: 540, metrics: { comparedPixels: 518400, differentPixels: 120, differentPixelRatio: 120 / 518400, pixelThreshold: 0.01, maxDifferentPixelRatio: 0 }, images: { expected: "comparisons/001/expected.png", actual: "comparisons/001/actual.png", diff: "comparisons/001/diff.png" } },
      { id: "002", name: "Missing baseline", variant: "linux", reason: "baseline_missing", width: 800, height: 450, metrics: { comparedPixels: 0, differentPixels: 0, differentPixelRatio: 0, pixelThreshold: 0, maxDifferentPixelRatio: 0 }, images: { expected: null, actual: "comparisons/002/actual.png", diff: null } },
      { id: "003", name: "Wrong size", variant: "mobile", reason: "dimension_mismatch", width: 640, height: 360, expectedWidth: 800, expectedHeight: 450, metrics: { comparedPixels: 0, differentPixels: 0, differentPixelRatio: 0, pixelThreshold: 0, maxDifferentPixelRatio: 0 }, images: { expected: "comparisons/003/expected.png", actual: "comparisons/003/actual.png", diff: null } },
    ] : [],
  };
}

async function mock(page: Page, value = report()) {
  await page.route("**/report.json", (route: Route) => route.fulfill({ json: value }));
  await page.route("**/comparisons/**/*.png", (route: Route) => route.fulfill({ body: pixel, contentType: "image/png" }));
}

test("renders list, safe text, three panels, and slider under a Pages base path", async ({ page }) => {
  await mock(page);
  await page.goto("./");
  await expect(page).toHaveURL(/\/sample-repo\/#comparison-001$/);
  await expect(page.getByRole("heading", { name: "Title <script>window.__pwned=true</script>" })).toBeVisible();
  const panelText = await page.locator("figure").allTextContents();
  expect(panelText).toEqual(expect.arrayContaining([expect.stringContaining("Before / Expected"), expect.stringContaining("Diff"), expect.stringContaining("After / Actual")]));
  expect(await page.evaluate(() => (window as Window & { __pwned?: boolean }).__pwned)).toBeUndefined();
  await page.getByRole("button", { name: "Comparison slider" }).click();
  const slider = page.getByLabel("Expected image visibility percentage");
  await slider.fill("75");
  await expect(page.locator("#comparison-output")).toHaveText("75%");
  expect(await page.locator("html").evaluate((element) => (element as HTMLElement).style.getPropertyValue("--split"))).toBe("75%");
  await slider.press("ArrowRight");
  await expect(page.locator("#comparison-output")).toHaveText("76%");
});

test("disables unavailable modes for missing baselines and dimension mismatches", async ({ page }) => {
  await mock(page);
  await page.goto("./#comparison-002");
  await expect(page.getByRole("heading", { name: "Missing baseline" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Comparison slider" })).toBeDisabled();
  await expect(page.getByText("Expected screenshot is unavailable.")).toBeVisible();
  await page.getByRole("link", { name: /Wrong size/ }).click();
  await expect(page.getByText("Diff is unavailable because dimensions do not match.")).toBeVisible();
  await expect(page.getByRole("button", { name: "Comparison slider" })).toBeDisabled();
});

test("renders the successful state without comparison navigation", async ({ page }) => {
  await mock(page, report("success"));
  await page.goto("./");
  await expect(page.getByRole("heading", { name: "No visual failures" })).toBeVisible();
  await expect(page.locator("#report-layout")).toBeHidden();
});

test("renders comparisons without an error state for a successful visual review", async ({ page }) => {
  await mock(page, report("success", true));
  await page.goto("./");
  await expect(page.locator("#status")).toHaveText("Success");
  await expect(page.locator("#status")).toHaveClass(/success/);
  await expect(page.getByRole("heading", { name: "Title <script>window.__pwned=true</script>" })).toBeVisible();
  await expect(page.locator("#load-error")).toBeHidden();
});

test("stacks image panels on a narrow viewport", async ({ page }) => {
  await page.setViewportSize({ width: 480, height: 900 });
  await mock(page);
  await page.goto("./");
  const boxes = await Promise.all((await page.locator("figure").all()).map((figure) => figure.boundingBox()));
  expect(boxes[1]!.y).toBeGreaterThan(boxes[0]!.y + boxes[0]!.height - 1);
  expect(boxes[2]!.y).toBeGreaterThan(boxes[1]!.y + boxes[1]!.height - 1);
});
