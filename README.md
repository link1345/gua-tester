# Gua Tester Actions

English | [日本語](README.ja.md)

GitHub Actions building blocks for running Gua UI tests in Godot 4.7 and
Unity 6 projects.

This repository is not a sample game repository. It provides a Godot composite
action, a Unity reusable workflow, and engine-neutral visual report tooling for
consumer repositories.

## Godot 4.7

The Godot action:

- Downloads a selected Godot Windows build from the official release archive
- Downloads the latest stable `gua-v*` release containing a matching Godot addon asset from `link1345/gua`
- Extracts the released `addons/gua` package, including the built Windows DLLs
- Copies the released addon into the consumer project's `game/addons/gua`
- Sets `GODOT_EXECUTABLE` and runs `dotnet test`

`Gua.Testing.Godot` is a .NET test host, but the launched Godot project can be a
GDScript project. As long as the game starts the Gua addon bridge at
`ws://127.0.0.1:8765`, external .NET tests can validate the live UI tree.

## Minimal Godot Workflow

Place this in the consumer repository at `.github/workflows/godot.yml`.

```yaml
name: Godot Gua UI Tests

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
        uses: link1345/gua-tester/godot@v2.2
        with:
          project-path: game
          test-project: tests/GuaTester.Tests.csproj
          godot-version: "4.7"
          godot-status: stable
          # Optional. Leave unset to use the latest stable gua-v* release.
          # gua-plugin-tag: gua-v1.18.0
```

Pin production workflows to `@v2.2`. The root action was removed in v2; see the
[v2 migration](#v2-migration) section.

## Godot Action Inputs

`godot/action.yml` is the all-in-one Godot action.

- `project-path`: Path to the Godot project. Default: `game`
- `test-project`: Path to the .NET test `.csproj` that references
  `Gua.Testing.Godot`
- `godot-version`: For example, `4.7`
- `godot-status`: For example, `stable`, `rc1`, or `dev1`
- `godot-executable-suffix`: Default: `win64.exe`
- `dotnet-version`: Default: `10.0.x`
- `gua-repository`: Default: `link1345/gua`
- `gua-plugin-tag`: Specific Gua release tag, such as `gua-v1.18.0`. By
  default, the latest stable `gua-v*` release containing a matching addon asset
  is used. Legacy `godot-plugin-*` releases remain as a fallback.
- `gua-plugin-asset-pattern`: Default: `gua-godot-plugin-*.zip`
- `configuration`: Default: `Release`
- `test-logger`: Default: `trx;LogFileName=godot.trx`

## Godot Component Actions

You can also use the smaller actions separately.

### setup-godot

```yaml
- uses: link1345/gua-tester/setup-godot@v2.2
  with:
    godot-version: "4.7"
    godot-status: stable
```

This sets the `GODOT_EXECUTABLE` environment variable.

### link-gua-gdscript-addon

```yaml
- uses: link1345/gua-tester/link-gua-gdscript-addon@v2.2
  with:
    project-path: game
    # Optional. Leave unset to use the latest stable gua-v* release.
    # gua-plugin-tag: gua-v1.18.0
```

This downloads the released `link1345/gua` Godot plugin asset and copies its
`addons/gua` directory to `game/addons/gua`.

## Unity 6 Windows x64

Unity uses a reusable workflow because the Unity Player is built on Linux and
the resulting Windows x64 Mono Player is exercised by external NUnit tests on a
Windows runner.

```yaml
name: Unity Gua UI Tests

on:
  pull_request:
  push:
    branches: [main]

jobs:
  unity:
    if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository
    uses: link1345/gua-tester/.github/workflows/unity.yml@v2.2
    with:
      project-path: game
      scene-path: Assets/Scenes/Title.unity
      test-project: tests/GuaTester.Unity.Tests.csproj
      artifact-key: game
      unity-version: auto
      gua-tag: gua-v1.18.0
    secrets:
      UNITY_EMAIL: ${{ secrets.UNITY_EMAIL }}
      UNITY_PASSWORD: ${{ secrets.UNITY_PASSWORD }}
      UNITY_LICENSE: ${{ secrets.UNITY_LICENSE }}
      UNITY_SERIAL: ${{ secrets.UNITY_SERIAL }}
```

Professional licenses can pass `UNITY_SERIAL` instead of `UNITY_LICENSE`.
Fork pull requests do not receive Actions secrets, so the calling workflow must
skip the Unity job for untrusted forks. Do not use `pull_request_target` to run
untrusted game code with Unity credentials.

Required inputs are `project-path`, `scene-path`, `test-project`, and a unique
`artifact-key` for each reusable workflow invocation. Optional
inputs are `unity-version` (`auto`), `gua-repository` (`link1345/gua`),
`gua-tag`, `dotnet-version` (`10.0.x`), `configuration` (`Release`),
`test-logger` (`trx;LogFileName=unity.trx`), and `artifact-path`
(`artifacts/gua`). `checkout-repository` and `checkout-ref` are advanced
overrides used when the project and tests come from another repository.
Use a matrix value or another stable caller-specific value for `artifact-key`
when the reusable workflow is invoked more than once in the same workflow run.

The workflow installs the released `com.link1345.gua-*.tgz` as an embedded UPM
package, builds a rendered Windows x64 Mono Player, and sets both
`GUA_UNITY_PLAYER` and `GUA_UNITY_ARTIFACT_PLAYER` for `dotnet test`. Unity
build logs, the Player, TRX results, and Gua diagnostic/visual artifacts are
retained as workflow artifacts. The Windows test runner display is fixed at
1920x1080 before launching the Player. Unity 6000.0+ is required; IL2CPP, non-Windows
Players, Editor Play Mode CI, IMGUI, and EditorWindow automation are outside the
v2 workflow scope.

Keep the UPM release selected by `gua-tag` aligned with the
`Gua.Testing.Unity` NuGet version used by the test project.

## Visual reports

`Gua.Testing.Visual` writes `comparison.json` and the available PNG files for
each comparison. A successful comparison includes its current `actual.png`, so a
report with no visual differences can still show the current screen. The
`visual-report` action converts that raw data into a
public `report.json`, combines it with the bundled Astro-built static viewer,
and uploads either a Pages artifact or a regular workflow artifact. Consumers do
not install Astro, Node.js, or npm dependencies.

```yaml
- name: Run Godot Gua tests
  id: gua-tests
  uses: link1345/gua-tester/godot@v2.2
  with:
    project-path: game
    test-project: tests/GuaTester.Tests.csproj

- name: Prepare latest main visual report
  id: visual-report
  if: always() && github.event_name != 'pull_request'
  uses: link1345/gua-tester/visual-report@v2.2
  with:
    artifact-path: artifacts/gua
    test-outcome: ${{ steps.gua-tests.outcome }}
    upload-target: pages
```

The action accepts:

- `artifact-path`: Visual artifact directory. Default: `artifacts/gua`
- `test-outcome`: Required test step outcome: `success`, `failure`, or `cancelled`
- `include-comparisons-on-success`: Also include failed comparison artifacts while keeping a successful report status. Matched current screens are always included. Default: `false`
- `upload-target`: `pages` or `workflow`. Default: `pages`
- `pages-artifact-name`: Pages artifact name. Default: `github-pages`
- `workflow-artifact-name`: Workflow artifact name. Default: `gua-visual-report`
- `retention-days`: Artifact retention period. Default: `7`

It outputs `comparison-count` and `artifact-id`. Deployment remains a separate job
owned by the consumer workflow, where `pages: write`, `id-token: write`, and the
`github-pages` environment can be reviewed explicitly. Configure the repository's
Pages source as **GitHub Actions** before the first deployment. See the complete
[`examples/godot-ci.yml`](examples/godot-ci.yml) workflow.
If `pages-artifact-name` is customized, pass the same value as `artifact_name`
to `actions/deploy-pages`.

Use `upload-target: pages` for `main` or manually dispatched runs. On failed pull
requests use `upload-target: workflow`; the downloaded artifact already contains
the viewer and normalized report. Because the viewer loads `report.json`, serve
the extracted directory over local HTTP rather than opening `index.html` through
`file://` (for example, `python -m http.server`). A successful main run publishes
matched current screens but filters out failure artifacts unless
`include-comparisons-on-success` is enabled, so a previous failure is not
presented as current.

> [!WARNING]
> Screenshots can contain rendered secrets or personal information. Review the
> captured content before enabling Pages, especially for public repositories.

## Godot Addon Linking

Git submodules work at repository granularity, so they cannot directly link only
the subdirectory
`https://github.com/link1345/gua/tree/main/examples/godot-gdscript/addons/gua`.

For that reason, these actions download the matching Godot addon asset from a
`gua-v*` release in `link1345/gua` and copy only the released `addons/gua`
directory into the consumer Godot project. Legacy `godot-plugin-*` releases are
supported as a fallback. The release asset already includes the built Windows
GDExtension DLLs, so the consumer workflow does not build the addon from source.

## Godot Consumer Repository Requirements

- A Godot GDScript project
- Game-side code that starts the Gua bridge through the Gua addon
- A .NET test project that references `Gua.Testing.Godot`

Example test project:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Gua.Testing.Godot" Version="1.18.0" />
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

## v2 migration

v2 removes the root Godot action so that the repository can expose both engine
workflows without implying that Godot is the default engine. Update:

```diff
-- uses: link1345/gua-tester@v1.3
+- uses: link1345/gua-tester/godot@v2.2
```

The Godot component action paths remain `setup-godot` and
`link-gua-gdscript-addon`. `visual-report` remains engine-neutral. The default
Godot TRX file changed from `godot-gdscript.trx` to `godot.trx`.
