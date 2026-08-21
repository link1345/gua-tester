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
    "artifact-key:",
    "build-player:",
    "test-player:",
    "uses: game-ci/unity-builder@v4",
    "GUA_UNITY_PLAYER:",
    "GUA_UNITY_ARTIFACT_PLAYER:",
    "Collect Unity Player logs",
    "Set-DisplayResolution -Width 1920 -Height 1080 -Force",
    "com.link1345.gua-*.tgz",
    "targetPlatform: StandaloneWindows64"
)) {
    Assert-True ($unityWorkflow.Contains($required)) "Unity workflow contract is missing '$required'."
}

Assert-True ($unityWorkflow.Contains('-guaScene "${{ inputs.scene-path }}"')) "Unity workflow must quote scene-path in custom parameters."
Assert-True ($unityWorkflow.Contains("inputs.checkout-repository != '' && inputs.checkout-ref == ''")) "Repository overrides without a ref must use the default branch."
Assert-True ($unityWorkflow.Contains('gua-unity-player-${{ github.run_id }}-${{ github.run_attempt }}-${{ inputs.artifact-key }}')) "Unity artifact names must include the invocation artifact key."
Assert-True ($unityWorkflow.Contains('${{ steps.paths.outputs.artifact-path }}')) "Unity artifact upload must use the validated artifact path."
$buildUploadStart = $unityWorkflow.IndexOf("- name: Upload Unity build diagnostics")
$buildUploadEnd = $unityWorkflow.IndexOf("- name: Upload Unity Player", $buildUploadStart)
$buildUpload = $unityWorkflow.Substring($buildUploadStart, $buildUploadEnd - $buildUploadStart)
Assert-True ($buildUpload.Contains('${{ steps.build-paths.outputs.project-logs }}')) "Unity build upload must use the validated project logs path."
Assert-True (!$buildUpload.Contains('${{ inputs.project-path }}')) "Unity build upload must not use the raw project-path input."
$testUpload = $unityWorkflow.Substring($unityWorkflow.IndexOf("- name: Upload Unity test artifacts"))
Assert-True (!$testUpload.Contains('${{ inputs.artifact-path }}')) "Unity artifact upload must not use the raw artifact-path input."

foreach ($readme in @("README.md", "README.ja.md")) {
    $content = Get-Content -LiteralPath (Join-Path $root $readme) -Raw
    Assert-True ($content.Contains("link1345/gua-tester/godot@v2.2")) "$readme does not document the v2.2 Godot action."
    Assert-True ($content.Contains("link1345/gua-tester/.github/workflows/unity.yml@v2.2")) "$readme does not document the v2.2 Unity reusable workflow."
    Assert-True ($content.Contains('artifact-key: game')) "$readme does not document the required artifact-key."
    Assert-True ($content.Contains('UNITY_SERIAL: ${{ secrets.UNITY_SERIAL }}')) "$readme does not map UNITY_SERIAL."
}

Write-Host "Action contract smoke passed."
