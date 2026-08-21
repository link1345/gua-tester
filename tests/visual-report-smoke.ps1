$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-Equal([object]$Actual, [object]$Expected, [string]$Message) {
    if ($Actual -ne $Expected) { throw "$Message Expected '$Expected', got '$Actual'." }
}

function Write-Fixture([string]$Directory, [hashtable]$Metadata, [string[]]$Images) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $Directory "comparison.json"), ($Metadata | ConvertTo-Json -Depth 5))
    foreach ($image in $Images) {
        [System.IO.File]::WriteAllBytes((Join-Path $Directory "$image.png"), [byte[]](137, 80, 78, 71))
    }
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("gua-visual-report-smoke-" + [Guid]::NewGuid().ToString("N"))
$artifactRoot = Join-Path $testRoot "artifacts"
$scriptPath = Join-Path $PSScriptRoot "../visual-report/build-report.ps1"
$viewerPath = Join-Path $PSScriptRoot "../visual-report/viewer"

try {
    Write-Fixture (Join-Path $artifactRoot "first") @{
        schemaVersion = 1; name = "Title screen"; variant = "windows"; reason = "pixel_difference"
        width = 960; height = 540; comparedPixels = 518400; differentPixels = 120
        differentPixelRatio = 0.00023148; pixelThreshold = 0.01; maxDifferentPixelRatio = 0
        baselinePath = "C:\private\screenshots\title.png"
    } @("expected", "actual", "diff")
    Write-Fixture (Join-Path $artifactRoot "second") @{
        schemaVersion = 1; name = "<script>alert(1)</script>"; variant = 'linux" onclick="alert(2)'
        reason = "baseline_missing"; width = 800; height = 450; comparedPixels = 0
        differentPixels = 0; differentPixelRatio = 0; pixelThreshold = 0; maxDifferentPixelRatio = 0
        baselinePath = "D:\secret\baseline.png"
    } @("actual")

    $failureOutput = Join-Path $testRoot "failure-site"
    $githubOutput = Join-Path $testRoot "github-output.txt"
    & $scriptPath -ArtifactPath $artifactRoot -TestOutcome failure -OutputPath $failureOutput -AllowedOutputRoot $testRoot -ViewerTemplatePath $viewerPath -Repository "link1345/example" -RunId "123" -RunNumber "9" -CommitSha "0123456789abcdef" -GithubOutput $githubOutput
    $reportText = Get-Content -LiteralPath (Join-Path $failureOutput "report.json") -Raw
    $report = $reportText | ConvertFrom-Json
    Assert-Equal $report.schemaVersion 1 "Unexpected schema version."
    Assert-Equal $report.outcome "failure" "Unexpected outcome."
    Assert-Equal @($report.comparisons).Count 2 "Unexpected comparison count."
    Assert-Equal $report.comparisons[0].images.diff "comparisons/001/diff.png" "Diff path was not normalized."
    Assert-Equal $report.comparisons[1].images.actual "comparisons/002/actual.png" "Actual path was not normalized."
    Assert-Equal $report.comparisons[1].images.expected $null "Missing expected image must stay null."
    Assert-Equal $report.comparisons[1].name "<script>alert(1)</script>" "JSON text did not round-trip."
    if ($reportText.Contains("baselinePath") -or $reportText.Contains("C:\private") -or $reportText.Contains("D:\secret")) { throw "Raw absolute paths leaked into report.json." }
    foreach ($path in @("index.html", "viewer.js", "comparisons/001/expected.png", "comparisons/001/actual.png", "comparisons/001/diff.png", "comparisons/002/actual.png")) {
        if (-not (Test-Path -LiteralPath (Join-Path $failureOutput $path) -PathType Leaf)) { throw "Missing generated site file '$path'." }
    }
    $viewerHtml = Get-Content -LiteralPath (Join-Path $failureOutput "index.html") -Raw
    if ($viewerHtml.Contains("<script>alert(1)</script>")) { throw "Comparison data was embedded into the HTML shell." }
    $outputs = Get-Content -LiteralPath $githubOutput -Raw
    if (-not $outputs.Contains("comparison-count=2") -or -not $outputs.Contains("site-path=$failureOutput")) { throw "Expected action outputs were not written." }

    $successOutput = Join-Path $testRoot "success-site"
    & $scriptPath -ArtifactPath $artifactRoot -TestOutcome success -OutputPath $successOutput -AllowedOutputRoot $testRoot -ViewerTemplatePath $viewerPath
    $success = Get-Content -LiteralPath (Join-Path $successOutput "report.json") -Raw | ConvertFrom-Json
    Assert-Equal $success.outcome "success" "Success outcome was not preserved."
    Assert-Equal @($success.comparisons).Count 0 "A success report must not publish stale comparisons."
    if (Test-Path -LiteralPath (Join-Path $successOutput "comparisons")) { throw "A success report must not copy comparison images." }

    Write-Fixture (Join-Path $artifactRoot "third") @{
        schemaVersion = 1; name = "Current title screen"; variant = "windows"; reason = "matched"; matched = $true
        width = 960; height = 540; comparedPixels = 518400; differentPixels = 0
        differentPixelRatio = 0; pixelThreshold = 0.01; maxDifferentPixelRatio = 0
        baselinePath = "C:\private\screenshots\title.png"
    } @("actual")

    $matchedOutput = Join-Path $testRoot "matched-site"
    & $scriptPath -ArtifactPath $artifactRoot -TestOutcome success -OutputPath $matchedOutput -AllowedOutputRoot $testRoot -ViewerTemplatePath $viewerPath
    $matched = Get-Content -LiteralPath (Join-Path $matchedOutput "report.json") -Raw | ConvertFrom-Json
    Assert-Equal @($matched.comparisons).Count 1 "A success report must include matched current screens."
    Assert-Equal $matched.comparisons[0].reason "matched" "The matched comparison reason was not preserved."
    Assert-Equal $matched.comparisons[0].images.actual "comparisons/001/actual.png" "The current screen path was not normalized."
    if (-not (Test-Path -LiteralPath (Join-Path $matchedOutput "comparisons/001/actual.png") -PathType Leaf)) { throw "A success report must copy its current screen." }
    if (Test-Path -LiteralPath (Join-Path $matchedOutput "comparisons/002")) { throw "A success report must not copy stale failures by default." }

    $reviewOutput = Join-Path $testRoot "review-site"
    & $scriptPath -ArtifactPath $artifactRoot -TestOutcome success -IncludeComparisonsOnSuccess true -OutputPath $reviewOutput -AllowedOutputRoot $testRoot -ViewerTemplatePath $viewerPath
    $review = Get-Content -LiteralPath (Join-Path $reviewOutput "report.json") -Raw | ConvertFrom-Json
    Assert-Equal $review.outcome "success" "A non-blocking visual review must preserve its success outcome."
    Assert-Equal @($review.comparisons).Count 3 "A non-blocking visual review must include comparison artifacts."
    if (-not (Test-Path -LiteralPath (Join-Path $reviewOutput "comparisons/001/diff.png") -PathType Leaf)) { throw "A non-blocking visual review must copy comparison images." }

    $emptyOutput = Join-Path $testRoot "empty-site"
    & $scriptPath -ArtifactPath (Join-Path $testRoot "missing") -TestOutcome failure -OutputPath $emptyOutput -AllowedOutputRoot $testRoot -ViewerTemplatePath $viewerPath
    $empty = Get-Content -LiteralPath (Join-Path $emptyOutput "report.json") -Raw | ConvertFrom-Json
    Assert-Equal @($empty.comparisons).Count 0 "Missing comparison data must produce an empty failure report."

    $unsafeRejected = $false
    try {
        & $scriptPath -ArtifactPath $artifactRoot -TestOutcome success -OutputPath $testRoot -AllowedOutputRoot $testRoot -ViewerTemplatePath $viewerPath
    }
    catch { $unsafeRejected = $true }
    if (-not $unsafeRejected) { throw "Expected the builder to reject replacing its allowed output root." }

    $action = Get-Content -LiteralPath (Join-Path $PSScriptRoot "../visual-report/action.yml") -Raw
    foreach ($expected in @("include-comparisons-on-success:", "upload-target:", "inputs.upload-target == 'pages'", "inputs.upload-target == 'workflow'", "actions/upload-pages-artifact@v4", "actions/upload-artifact@v4", "comparison-count:", "artifact-id:")) {
        if (-not $action.Contains($expected)) { throw "Action metadata is missing '$expected'." }
    }
}
finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
