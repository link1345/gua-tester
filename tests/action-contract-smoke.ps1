$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

Assert-True (!(Test-Path -LiteralPath (Join-Path $root "action.yml"))) "The removed v1 root action must not be restored."

$godotActionPath = Join-Path $root "godot/action.yml"
Assert-True (Test-Path -LiteralPath $godotActionPath -PathType Leaf) "godot/action.yml is missing."
$godotAction = Get-Content -LiteralPath $godotActionPath -Raw
Assert-True ($godotAction.Contains("name: Gua Godot Tests")) "The Godot action has the wrong public name."
Assert-True ($godotAction.Contains("trx;LogFileName=godot.trx")) "The Godot action has the wrong default TRX name."

$unityWorkflowPath = Join-Path $root ".github/workflows/unity.yml"
Assert-True (Test-Path -LiteralPath $unityWorkflowPath -PathType Leaf) "The Unity reusable workflow is missing."
$unityWorkflow = Get-Content -LiteralPath $unityWorkflowPath -Raw
foreach ($required in @(
    "workflow_call:",
    "build-player:",
    "test-player:",
    "uses: game-ci/unity-builder@v4",
    "GUA_UNITY_PLAYER:",
    "GUA_UNITY_ARTIFACT_PLAYER:",
    "com.link1345.gua-*.tgz",
    "targetPlatform: StandaloneWindows64"
)) {
    Assert-True ($unityWorkflow.Contains($required)) "Unity workflow contract is missing '$required'."
}

foreach ($readme in @("README.md", "README.ja.md")) {
    $content = Get-Content -LiteralPath (Join-Path $root $readme) -Raw
    Assert-True ($content.Contains("link1345/gua-tester/godot@v2")) "$readme does not document the v2 Godot action."
    Assert-True ($content.Contains("link1345/gua-tester/.github/workflows/unity.yml@v2")) "$readme does not document the Unity reusable workflow."
}

Write-Host "Action contract smoke passed."
