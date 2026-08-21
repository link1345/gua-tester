[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$ArtifactPath,
    [Parameter(Mandatory = $true)] [ValidateSet("success", "failure", "cancelled")] [string]$TestOutcome,
    [ValidateSet("true", "false")] [string]$IncludeComparisonsOnSuccess = "false",
    [Parameter(Mandatory = $true)] [string]$OutputPath,
    [Parameter(Mandatory = $true)] [string]$AllowedOutputRoot,
    [Parameter(Mandatory = $true)] [string]$ViewerTemplatePath,
    [string]$Repository = "",
    [string]$RunId = "",
    [string]$RunNumber = "",
    [string]$CommitSha = "",
    [string]$GithubOutput = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-MetadataValue([object]$Metadata, [string]$Name, [object]$Default = $null) {
    $property = $Metadata.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function Assert-SafeChildPath([string]$Root, [string]$Child) {
    $relative = [System.IO.Path]::GetRelativePath($Root, $Child)
    if ($Child -eq $Root -or [System.IO.Path]::IsPathRooted($relative) -or $relative -eq ".." -or
        $relative.StartsWith("..$([System.IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)) {
        throw "Refusing to replace unsafe visual report output path '$Child'."
    }
}

$artifactFullPath = [System.IO.Path]::GetFullPath($ArtifactPath)
$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
$allowedOutputFullPath = [System.IO.Path]::GetFullPath($AllowedOutputRoot)
$viewerFullPath = [System.IO.Path]::GetFullPath($ViewerTemplatePath)
Assert-SafeChildPath $allowedOutputFullPath $outputFullPath
if ($outputFullPath -eq $artifactFullPath) { throw "The visual report output must not replace the raw artifact directory." }
if (-not (Test-Path -LiteralPath (Join-Path $viewerFullPath "index.html") -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $viewerFullPath "viewer.js") -PathType Leaf)) {
    throw "The prebuilt visual report viewer is incomplete at '$viewerFullPath'."
}

if (Test-Path -LiteralPath $outputFullPath) { Remove-Item -LiteralPath $outputFullPath -Recurse -Force }
New-Item -ItemType Directory -Path $outputFullPath -Force | Out-Null
Get-ChildItem -LiteralPath $viewerFullPath -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $outputFullPath -Recurse -Force
}

$comparisons = [System.Collections.Generic.List[object]]::new()
$shouldIncludeComparisons = $TestOutcome -ne "success" -or $IncludeComparisonsOnSuccess -eq "true"
if ($shouldIncludeComparisons -and (Test-Path -LiteralPath $artifactFullPath -PathType Container)) {
    $metadataFiles = @(Get-ChildItem -LiteralPath $artifactFullPath -Filter "comparison.json" -File -Recurse | Sort-Object FullName)
    foreach ($metadataFile in $metadataFiles) {
        try {
            $metadata = Get-Content -LiteralPath $metadataFile.FullName -Raw | ConvertFrom-Json
        }
        catch {
            Write-Warning "Skipping unreadable visual comparison metadata '$($metadataFile.FullName)': $($_.Exception.Message)"
            continue
        }

        $number = $comparisons.Count + 1
        $id = "{0:D3}" -f $number
        $comparisonOutput = Join-Path $outputFullPath ("comparisons/$id")
        New-Item -ItemType Directory -Path $comparisonOutput -Force | Out-Null
        $images = [ordered]@{ expected = $null; actual = $null; diff = $null }
        foreach ($imageName in @("expected", "actual", "diff")) {
            $source = Join-Path $metadataFile.Directory.FullName "$imageName.png"
            if (Test-Path -LiteralPath $source -PathType Leaf) {
                Copy-Item -LiteralPath $source -Destination (Join-Path $comparisonOutput "$imageName.png")
                $images[$imageName] = "comparisons/$id/$imageName.png"
            }
        }

        $comparisons.Add([ordered]@{
            id = $id
            name = [string](Get-MetadataValue $metadata "name" "Visual comparison $number")
            variant = [string](Get-MetadataValue $metadata "variant" "")
            reason = [string](Get-MetadataValue $metadata "reason" "pixel_difference")
            width = Get-MetadataValue $metadata "width" 0
            height = Get-MetadataValue $metadata "height" 0
            expectedWidth = Get-MetadataValue $metadata "expectedWidth" $null
            expectedHeight = Get-MetadataValue $metadata "expectedHeight" $null
            metrics = [ordered]@{
                comparedPixels = Get-MetadataValue $metadata "comparedPixels" 0
                differentPixels = Get-MetadataValue $metadata "differentPixels" 0
                differentPixelRatio = Get-MetadataValue $metadata "differentPixelRatio" 0
                pixelThreshold = Get-MetadataValue $metadata "pixelThreshold" 0
                maxDifferentPixelRatio = Get-MetadataValue $metadata "maxDifferentPixelRatio" 0
            }
            images = $images
        })
    }
}

$report = [ordered]@{
    schemaVersion = 1
    outcome = $TestOutcome
    generatedAt = [DateTimeOffset]::UtcNow.ToString("O")
    run = [ordered]@{ repository = $Repository; id = $RunId; number = $RunNumber; commit = $CommitSha }
    comparisons = @($comparisons)
}
[System.IO.File]::WriteAllText(
    (Join-Path $outputFullPath "report.json"),
    ($report | ConvertTo-Json -Depth 8),
    [System.Text.UTF8Encoding]::new($false)
)

if (-not [string]::IsNullOrWhiteSpace($GithubOutput)) {
    [System.IO.File]::AppendAllText($GithubOutput, "comparison-count=$($comparisons.Count)$([Environment]::NewLine)")
    [System.IO.File]::AppendAllText($GithubOutput, "site-path=$outputFullPath$([Environment]::NewLine)")
}
