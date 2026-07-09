# Gua Godot Actions

[English](README.md) | 日本語

Godot GDScript プロジェクトで Gua を使った CI を簡単に組むための
GitHub Actions 部品群です。

この repo 自体はテスト対象ゲームではありません。利用者の repo 側にある
Godot プロジェクトと .NET テストプロジェクトに対して、CI に必要な準備を
まとめて実行します。

## できること

- 任意の Godot Windows 版を公式 release からダウンロード
- `link1345/gua` から GDScript addon を取得
- `gua-godot` GDExtension を GitHub Actions 上でビルド
- `examples/godot-gdscript/addons/gua` を利用者の `game/addons/gua` へ配置
- `GODOT_EXECUTABLE` を設定して `dotnet test` を実行

`Gua.Testing.Godot` は .NET のテストホストですが、起動対象の Godot
プロジェクトは GDScript 版で構いません。ゲーム側が Gua addon で
`ws://127.0.0.1:8765` を立てれば、外部の .NET テストから検証できます。

## 最小 workflow

利用者 repo の `.github/workflows/godot-gdscript.yml` に置く想定です。

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
        uses: link1345/gua-tester@v1
        with:
          project-path: game
          test-project: tests/GuaTester.Tests.csproj
          godot-version: "4.7"
          godot-status: stable
          gua-ref: main
```

`uses: link1345/gua-tester@v1` は、この actions repo を公開して `v1` タグを
切った後の指定です。別の owner/repo 名で公開する場合はそこを変えます。

## root action inputs

root の `action.yml` は all-in-one action です。

- `project-path`: Godot プロジェクトのパス。既定値は `game`
- `test-project`: `Gua.Testing.Godot` を参照する .NET テスト csproj
- `godot-version`: `4.7` など
- `godot-status`: `stable`、`rc1`、`dev1` など
- `godot-executable-suffix`: 既定値 `win64.exe`
- `dotnet-version`: 既定値 `10.0.x`
- `gua-repository`: 既定値 `link1345/gua`
- `gua-ref`: 既定値 `main`
- `gua-checkout-path`: 既定値 `_deps/gua`
- `configuration`: 既定値 `Release`
- `test-logger`: 既定値 `trx;LogFileName=godot-gdscript.trx`

## 個別 action

必要なら all-in-one ではなく、部品ごとに使えます。

### setup-godot

```yaml
- uses: link1345/gua-tester/setup-godot@v1
  with:
    godot-version: "4.7"
    godot-status: stable
```

`GODOT_EXECUTABLE` を環境変数に設定します。

### link-gua-gdscript-addon

```yaml
- uses: link1345/gua-tester/link-gua-gdscript-addon@v1
  with:
    project-path: game
    gua-ref: main
```

`link1345/gua` を checkout し、`gua-godot` をビルドして、
`examples/godot-gdscript/addons/gua` を `game/addons/gua` にコピーします。

## addon のリンク方式

Git submodule はリポジトリ単位なので、
`https://github.com/link1345/gua/tree/main/examples/godot-gdscript/addons/gua`
のようなサブディレクトリだけを直接 submodule にはできません。

そのため、この actions repo では GitHub Actions 内で `link1345/gua` を
checkout し、対象 addon ディレクトリだけを利用者の Godot project へコピーします。
利用者 repo に addon のコピーを commit しなくて済むのが利点です。

## 利用者 repo 側に必要なもの

- Godot GDScript project
- Gua addon を使って bridge を起動するゲーム側コード
- `Gua.Testing.Godot` を参照する .NET テストプロジェクト

テストプロジェクト例:

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
