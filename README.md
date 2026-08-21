# Gua Godot Actions

English | [日本語](README.ja.md)

GitHub Actions building blocks for setting up CI with Gua in Godot GDScript
projects.

This repository is not a sample game repository. It provides reusable actions
that prepare the CI environment for a consumer repository's Godot project and
.NET test project.

## What It Does

- Downloads a selected Godot Windows build from the official release archive
- Downloads the latest stable `gua-v*` release containing a matching Godot addon asset from `link1345/gua`
- Extracts the released `addons/gua` package, including the built Windows DLLs
- Copies the released addon into the consumer project's `game/addons/gua`
- Sets `GODOT_EXECUTABLE` and runs `dotnet test`

`Gua.Testing.Godot` is a .NET test host, but the launched Godot project can be a
GDScript project. As long as the game starts the Gua addon bridge at
`ws://127.0.0.1:8765`, external .NET tests can validate the live UI tree.

## Minimal Workflow

Place this in the consumer repository at `.github/workflows/godot-gdscript.yml`.

```yaml
name: Godot GDScript CI

on:
  pull_request:
  push:
    branches:
      - main

jobs:
  godot:
    runs-on: windows-latest
    steps:
      - name: Check out game repository
        uses: actions/checkout@v4

      - name: Run Godot Gua tests
        uses: link1345/gua-tester@v1.3
        with:
          project-path: game
          test-project: tests/GuaTester.Tests.csproj
          godot-version: "4.7"
          godot-status: stable
          # Optional. Leave unset to use the latest stable gua-v* release.
          # gua-plugin-tag: gua-v0.15.0
```

`uses: link1345/gua-tester@main` uses the currently published action. Once a
stable `v1` tag is available, consumers can pin to `@v1` instead.

## Root Action Inputs

The root `action.yml` is an all-in-one action.

- `project-path`: Path to the Godot project. Default: `game`
- `test-project`: Path to the .NET test `.csproj` that references
  `Gua.Testing.Godot`
- `godot-version`: For example, `4.7`
- `godot-status`: For example, `stable`, `rc1`, or `dev1`
- `godot-executable-suffix`: Default: `win64.exe`
- `dotnet-version`: Default: `10.0.x`
- `gua-repository`: Default: `link1345/gua`
- `gua-plugin-tag`: Specific Gua release tag, such as `gua-v0.15.0`. By
  default, the latest stable `gua-v*` release containing a matching addon asset
  is used. Legacy `godot-plugin-*` releases remain as a fallback.
- `gua-plugin-asset-pattern`: Default: `gua-godot-plugin-*.zip`
- `configuration`: Default: `Release`
- `test-logger`: Default: `trx;LogFileName=godot-gdscript.trx`

## Individual Actions

You can also use the smaller actions separately.

### setup-godot

```yaml
- uses: link1345/gua-tester/setup-godot@main
  with:
    godot-version: "4.7"
    godot-status: stable
```

This sets the `GODOT_EXECUTABLE` environment variable.

### link-gua-gdscript-addon

```yaml
- uses: link1345/gua-tester/link-gua-gdscript-addon@main
  with:
    project-path: game
    # Optional. Leave unset to use the latest stable gua-v* release.
    # gua-plugin-tag: gua-v0.15.0
```

This downloads the released `link1345/gua` Godot plugin asset and copies its
`addons/gua` directory to `game/addons/gua`.

### visual-report

`Gua.Testing.Visual` writes `comparison.json` and the available PNG files for
each failed comparison. The `visual-report` action converts that raw data into a
public `report.json`, combines it with the bundled Astro-built static viewer,
and uploads either a Pages artifact or a regular workflow artifact. Consumers do
not install Astro, Node.js, or npm dependencies.

```yaml
- name: Run Godot Gua tests
  id: gua-tests
  uses: link1345/gua-tester@main
  with:
    project-path: game
    test-project: tests/GuaTester.Tests.csproj

- name: Prepare latest main visual report
  id: visual-report
  if: always() && github.event_name != 'pull_request'
  uses: link1345/gua-tester/visual-report@main
  with:
    artifact-path: artifacts/gua
    test-outcome: ${{ steps.gua-tests.outcome }}
    upload-target: pages
```

The action accepts:

- `artifact-path`: Visual artifact directory. Default: `artifacts/gua`
- `test-outcome`: Required test step outcome: `success`, `failure`, or `cancelled`
- `upload-target`: `pages` or `workflow`. Default: `pages`
- `pages-artifact-name`: Pages artifact name. Default: `github-pages`
- `workflow-artifact-name`: Workflow artifact name. Default: `gua-visual-report`
- `retention-days`: Artifact retention period. Default: `7`

It outputs `comparison-count` and `artifact-id`. Deployment remains a separate job
owned by the consumer workflow, where `pages: write`, `id-token: write`, and the
`github-pages` environment can be reviewed explicitly. Configure the repository's
Pages source as **GitHub Actions** before the first deployment. See the complete
[`examples/godot-gdscript-ci.yml`](examples/godot-gdscript-ci.yml) workflow.
If `pages-artifact-name` is customized, pass the same value as `artifact_name`
to `actions/deploy-pages`.

Use `upload-target: pages` for `main` or manually dispatched runs. On failed pull
requests use `upload-target: workflow`; the downloaded artifact already contains
the viewer and normalized report. Because the viewer loads `report.json`, serve
the extracted directory over local HTTP rather than opening `index.html` through
`file://` (for example, `python -m http.server`). A successful main run publishes
a success status page so a previous failure is not presented as current.

> [!WARNING]
> Screenshots can contain rendered secrets or personal information. Review the
> captured content before enabling Pages, especially for public repositories.

## Addon Linking

Git submodules work at repository granularity, so they cannot directly link only
the subdirectory
`https://github.com/link1345/gua/tree/main/examples/godot-gdscript/addons/gua`.

For that reason, these actions download the matching Godot addon asset from a
`gua-v*` release in `link1345/gua` and copy only the released `addons/gua`
directory into the consumer Godot project. Legacy `godot-plugin-*` releases are
supported as a fallback. The release asset already includes the built Windows
GDExtension DLLs, so the consumer workflow does not build the addon from source.

## Consumer Repository Requirements

- A Godot GDScript project
- Game-side code that starts the Gua bridge through the Gua addon
- A .NET test project that references `Gua.Testing.Godot`

Example test project:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Gua.Testing.Godot" Version="0.5.0-preview.3" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.1" />
    <PackageReference Include="NUnit" Version="4.3.2" />
    <PackageReference Include="NUnit3TestAdapter" Version="4.6.0" />
  </ItemGroup>

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
</Project>
```
