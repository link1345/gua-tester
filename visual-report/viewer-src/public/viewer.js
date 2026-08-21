(() => {
  "use strict";

  const byId = (id) => document.getElementById(id);
  const reportUrl = new URL("./report.json", window.location.href);
  const allowedImage = /^comparisons\/\d{3}\/(expected|actual|diff)\.png$/;
  let report = null;

  const reasonLabels = {
    matched: "Comparison passed",
    baseline_missing: "Baseline missing",
    dimension_mismatch: "Dimension mismatch",
    pixel_difference: "Pixel difference",
  };

  const text = (id, value) => { byId(id).textContent = value == null || value === "" ? "Not available" : String(value); };
  const dimensions = (width, height) => Number.isInteger(width) && Number.isInteger(height) ? `${width}×${height}` : "Unavailable";
  const percentage = (value) => typeof value === "number" && Number.isFinite(value) ? `${(value * 100).toFixed(4)}%` : "Not available";

  function imageUrl(path) {
    if (typeof path !== "string" || !allowedImage.test(path)) return null;
    return new URL(path, reportUrl).href;
  }

  function setImage(kind, path, unavailableMessage) {
    const image = byId(`${kind}-image`);
    const placeholder = byId(`${kind}-placeholder`);
    const url = imageUrl(path);
    if (url === null) {
      image.hidden = true;
      image.removeAttribute("src");
      placeholder.hidden = false;
      placeholder.textContent = unavailableMessage;
      return null;
    }
    image.src = url;
    image.hidden = false;
    placeholder.hidden = true;
    placeholder.textContent = "";
    return url;
  }

  function selectMode(mode) {
    const slider = mode === "slider" && !byId("slider-tab").disabled;
    byId("triptych-tab").setAttribute("aria-selected", String(!slider));
    byId("slider-tab").setAttribute("aria-selected", String(slider));
    byId("triptych-panel").hidden = slider;
    byId("slider-panel").hidden = !slider;
  }

  function renderRun() {
    const status = byId("status");
    status.textContent = report.outcome.charAt(0).toUpperCase() + report.outcome.slice(1);
    status.className = `status ${report.outcome}`;
    const meta = byId("run-meta");
    meta.replaceChildren();
    const run = report.run || {};
    const values = [];
    if (run.repository && run.id) {
      const link = document.createElement("a");
      link.href = `https://github.com/${encodeURIComponent(run.repository).replace("%2F", "/")}/actions/runs/${encodeURIComponent(run.id)}`;
      link.textContent = run.number ? `Run #${run.number}` : "Workflow run";
      values.push(link);
    } else if (run.number) values.push(document.createTextNode(`Run #${run.number}`));
    if (run.commit) values.push(document.createTextNode(`Commit ${String(run.commit).slice(0, 12)}`));
    if (report.generatedAt) values.push(document.createTextNode(`Generated ${report.generatedAt}`));
    for (const value of values) { const span = document.createElement("span"); span.append(value); meta.append(span); }
  }

  function renderList() {
    const list = byId("comparison-list");
    list.replaceChildren();
    for (const comparison of report.comparisons) {
      const item = document.createElement("li");
      const link = document.createElement("a");
      link.href = `#comparison-${comparison.id}`;
      link.dataset.comparisonId = comparison.id;
      const name = document.createElement("strong");
      name.textContent = comparison.name;
      const variant = document.createElement("span");
      variant.textContent = comparison.variant;
      const reason = document.createElement("span");
      reason.textContent = reasonLabels[comparison.reason] || comparison.reason;
      link.append(name, variant, reason);
      item.append(link);
      list.append(item);
    }
  }

  function renderComparison(comparison) {
    for (const link of document.querySelectorAll("[data-comparison-id]")) link.setAttribute("aria-current", String(link.dataset.comparisonId === comparison.id));
    text("detail-name", comparison.name);
    text("detail-variant", comparison.variant);
    text("detail-reason", reasonLabels[comparison.reason] || comparison.reason);
    text("metric-size", dimensions(comparison.width, comparison.height));
    text("metric-ratio", percentage(comparison.metrics?.differentPixelRatio));
    text("metric-different", comparison.metrics?.differentPixels);
    text("metric-compared", comparison.metrics?.comparedPixels);
    text("metric-threshold", comparison.metrics?.pixelThreshold);
    text("metric-allowed", comparison.metrics?.maxDifferentPixelRatio);
    text("expected-size", dimensions(comparison.expectedWidth ?? comparison.width, comparison.expectedHeight ?? comparison.height));
    text("actual-size", dimensions(comparison.width, comparison.height));
    text("diff-size", comparison.images?.diff ? dimensions(comparison.width, comparison.height) : "Unavailable");

    const matched = comparison.reason === "matched";
    document.querySelector('[data-panel="expected"]').hidden = matched;
    document.querySelector('[data-panel="diff"]').hidden = matched;
    document.querySelector('[data-panel="actual"] strong').textContent = matched ? "Current screen" : "After / Actual";
    byId("triptych-panel").classList.toggle("current-screen", matched);

    const expected = setImage("expected", comparison.images?.expected, "Expected screenshot is unavailable.");
    const actual = setImage("actual", comparison.images?.actual, "Actual screenshot is unavailable.");
    setImage("diff", comparison.images?.diff, comparison.reason === "dimension_mismatch" ? "Diff is unavailable because dimensions do not match." : "Difference image is unavailable.");

    const sliderAvailable = !matched && expected !== null && actual !== null && comparison.reason !== "dimension_mismatch";
    const note = sliderAvailable ? "Drag the slider or use the arrow keys to compare both images."
      : matched ? "The visual comparison passed. The current screen is shown below."
      : comparison.reason === "dimension_mismatch" ? "The slider is unavailable because dimensions do not match."
      : "The slider is unavailable because the expected screenshot is missing.";
    byId("slider-tab").disabled = !sliderAvailable;
    byId("slider-tab").setAttribute("aria-disabled", String(!sliderAvailable));
    text("mode-note", note);
    byId("slider-unavailable").hidden = sliderAvailable;
    byId("slider-view").hidden = !sliderAvailable;
    byId("slider-unavailable").textContent = note;
    if (sliderAvailable) {
      byId("slider-expected").src = expected;
      byId("slider-actual").src = actual;
    }
    byId("comparison-position").value = "50";
    byId("comparison-output").value = "50%";
    document.documentElement.style.setProperty("--split", "50%");
    selectMode("triptych");
  }

  function selectFromHash() {
    if (!report || report.comparisons.length === 0) return;
    const requested = window.location.hash.replace(/^#comparison-/, "");
    const selected = report.comparisons.find((item) => item.id === requested) || report.comparisons[0];
    if (requested !== selected.id) history.replaceState(null, "", `#comparison-${selected.id}`);
    renderComparison(selected);
  }

  function renderEmpty() {
    byId("empty-state").hidden = false;
    if (report.outcome === "success") {
      text("empty-title", "No visual failures");
      text("empty-message", "The latest test run completed successfully.");
    } else {
      text("empty-title", "No visual comparisons were found");
      text("empty-message", "The test did not succeed, but the artifact directory contained no Gua visual comparison manifests.");
    }
  }

  async function load() {
    try {
      const response = await fetch(reportUrl, { credentials: "same-origin" });
      if (!response.ok) throw new Error(`Report request failed with status ${response.status}.`);
      report = await response.json();
      if (report?.schemaVersion !== 1 || !["success", "failure", "cancelled"].includes(report.outcome) || !Array.isArray(report.comparisons)) throw new Error("Unsupported or invalid report.json.");
      renderRun();
      if (report.comparisons.length === 0) renderEmpty();
      else {
        byId("report-layout").hidden = false;
        renderList();
        selectFromHash();
      }
    } catch (error) {
      const target = byId("load-error");
      target.hidden = false;
      target.textContent = `Could not load the visual report: ${error instanceof Error ? error.message : String(error)}`;
      byId("status").textContent = "Unavailable";
    }
  }

  byId("triptych-tab").addEventListener("click", () => selectMode("triptych"));
  byId("slider-tab").addEventListener("click", () => selectMode("slider"));
  byId("comparison-position").addEventListener("input", (event) => {
    const value = event.currentTarget.value;
    document.documentElement.style.setProperty("--split", `${value}%`);
    byId("comparison-output").value = `${value}%`;
  });
  window.addEventListener("hashchange", selectFromHash);
  load();
})();
