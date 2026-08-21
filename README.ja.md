# Gua Godot Actions

[English](README.md) | 日本語

Godot GDScript プロジェクトで Gua を使った CI を簡単に組むための
GitHub Actions 部品群です。

この repo 自体はテスト対象ゲームではありません。利用者の repo 側にある
Godot プロジェクトと .NET テストプロジェクトに対して、CI に必要な準備を
まとめて実行します。

## できること

- 任意の Godot Windows 版を公式 release からダウンロード
- 対象の Godot addon asset を含む `link1345/gua` の最新安定版 `gua-v*` リリースを取得
- ビルド済み Windows DLL を含む `addons/gua` package を展開
- 展開した addon を利用者の `game/addons/gua` へ配置
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
        uses: link1345/gua-tester@main
        with:
          project-path: game
          test-project: tests/GuaTester.Tests.csproj
          godot-version: "4.7"
          godot-status: stable
          # 省略時は最新安定版の gua-v* リリースを使います。
          # gua-plugin-tag: gua-v0.15.0
```

`uses: link1345/gua-tester@main` は現在公開中の action を使用します。
安定版の `v1` タグが公開された後は `@v1` に固定できます。

## root action inputs

root の `action.yml` は all-in-one action です。

- `project-path`: Godot プロジェクトのパス。既定値は `game`
- `test-project`: `Gua.Testing.Godot` を参照する .NET テスト csproj
- `godot-version`: `4.7` など
- `godot-status`: `stable`、`rc1`、`dev1` など
- `godot-executable-suffix`: 既定値 `win64.exe`
- `dotnet-version`: 既定値 `10.0.x`
- `gua-repository`: 既定値 `link1345/gua`
- `gua-plugin-tag`: `gua-v0.15.0` などの特定の Gua リリースタグ。省略時は
  対象 addon asset を含む最新安定版の `gua-v*` リリースを使います。旧形式の
  `godot-plugin-*` リリースにもフォールバックします。
- `gua-plugin-asset-pattern`: 既定値 `gua-godot-plugin-*.zip`
- `configuration`: 既定値 `Release`
- `test-logger`: 既定値 `trx;LogFileName=godot-gdscript.trx`

## 個別 action

必要なら all-in-one ではなく、部品ごとに使えます。

### setup-godot

```yaml
- uses: link1345/gua-tester/setup-godot@main
  with:
    godot-version: "4.7"
    godot-status: stable
```

`GODOT_EXECUTABLE` を環境変数に設定します。

### link-gua-gdscript-addon

```yaml
- uses: link1345/gua-tester/link-gua-gdscript-addon@main
  with:
    project-path: game
    # 省略時は最新安定版の gua-v* リリースを使います。
    # gua-plugin-tag: gua-v0.15.0
```

`link1345/gua` の Godot plugin リリース asset をダウンロードし、その中の
`addons/gua` を `game/addons/gua` にコピーします。

### visual-report

`Gua.Testing.Visual` は比較失敗ごとに `comparison.json` と利用可能なPNGを出力します。
`visual-report` action はrawデータを公開用 `report.json` へ変換し、同梱済みの
Astro製静的Viewerと合わせて、Pages artifactまたは通常のworkflow artifactとして
アップロードします。利用側CIでAstro、Node.js、npm依存をインストールする必要はありません。

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

入力は次のとおりです。

- `artifact-path`: Visual artifact directory。既定値は `artifacts/gua`
- `test-outcome`: 必須。テストstepの結果で、`success`、`failure`、`cancelled` のいずれか
- `upload-target`: `pages` または `workflow`。既定値は `pages`
- `pages-artifact-name`: Pages artifact名。既定値は `github-pages`
- `workflow-artifact-name`: 通常artifact名。既定値は `gua-visual-report`
- `retention-days`: artifactの保持日数。既定値は `7`

出力は `comparison-count` と `artifact-id` です。実際のdeployは利用側workflowの
専用jobで行い、`pages: write`、`id-token: write`、`github-pages` environmentを
明示してください。初回deploy前にrepositoryのPages sourceを **GitHub Actions**
へ設定します。完全な例は
[`examples/godot-gdscript-ci.yml`](examples/godot-gdscript-ci.yml) にあります。
`pages-artifact-name` を変更した場合は、同じ値を `actions/deploy-pages` の
`artifact_name` に渡してください。

`main` または手動実行では `upload-target: pages` を使います。pull requestの失敗時は
`upload-target: workflow` を使うと、Viewerと正規化済みreportを含む通常artifactを
保存できます。Viewerは `report.json` を読み込むため、ダウンロード後は `file://` で
直接開かず、展開先を `python -m http.server` などでHTTP配信してください。
mainが成功した場合は成功状態ページを公開し、以前の失敗を現在の結果に見せません。

> [!WARNING]
> Screenshotには、画面へ描画された秘密情報や個人情報が含まれる可能性があります。
> 特にpublic repositoryでPagesを有効にする前に、capture内容を確認してください。

## addon のリンク方式

Git submodule はリポジトリ単位なので、
`https://github.com/link1345/gua/tree/main/examples/godot-gdscript/addons/gua`
のようなサブディレクトリだけを直接 submodule にはできません。

そのため、この actions repo では `link1345/gua` の `gua-v*` リリースから対象の
Godot addon asset をダウンロードし、リリース内の `addons/gua` だけを利用者の
Godot project へコピーします。旧形式の `godot-plugin-*` リリースにもフォールバック
します。リリース asset にはビルド済み Windows GDExtension DLL が含まれるので、
利用者 workflow 側で addon をソースからビルドする必要はありません。

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
