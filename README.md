# Gua Godot Actions

English | [日本語](README.ja.md)

GitHub Actions building blocks for setting up CI with Gua in Godot GDScript
projects.

This repository is not a sample game repository. It provides reusable actions
that prepare the CI environment for a consumer repository's Godot project and
.NET test project.

## What It Does

- Downloads a selected Godot Windows build from the official release archive
- Downloads the latest `godot-plugin-*` release from `link1345/gua`
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
        uses: link1345/gua-tester@v1.2
        with:
          project-path: game
          test-project: tests/GuaTester.Tests.csproj
          godot-version: "4.7"
          godot-status: stable
          # Optional. Leave unset to use the latest godot-plugin-* release.
          # gua-plugin-tag: gua-v0.15.0
```

`uses: link1345/gua-tester@v1.2` assumes this actions repository is published and
tagged as `v1.2`. Change the owner/repository name if you publish it elsewhere.

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
- `gua-plugin-tag`: Specific `godot-plugin-*` release tag. By default, the
  latest matching release is used.
- `gua-plugin-asset-pattern`: Default: `gua-godot-plugin-*.zip`
- `configuration`: Default: `Release`
- `test-logger`: Default: `trx;LogFileName=godot-gdscript.trx`

## Individual Actions

You can also use the smaller actions separately.

### setup-godot

```yaml
- uses: link1345/gua-tester/setup-godot@v1
  with:
    godot-version: "4.7"
    godot-status: stable
```

This sets the `GODOT_EXECUTABLE` environment variable.

### link-gua-gdscript-addon

```yaml
- uses: link1345/gua-tester/link-gua-gdscript-addon@v1
  with:
    project-path: game
    # Optional. Leave unset to use the latest godot-plugin-* release.
    # gua-plugin-tag: godot-plugin-f448370cf009
```

This downloads the released `link1345/gua` Godot plugin asset and copies its
`addons/gua` directory to `game/addons/gua`.

## Addon Linking

Git submodules work at repository granularity, so they cannot directly link only
the subdirectory
`https://github.com/link1345/gua/tree/main/examples/godot-gdscript/addons/gua`.

For that reason, these actions download the `godot-plugin-*` release asset from
`link1345/gua` and copy only the released `addons/gua` directory into the
consumer Godot project. The release asset already includes the built Windows
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
