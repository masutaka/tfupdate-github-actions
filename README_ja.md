# tfupdate-github-actions

<p>
  <a href="./README.md"><img alt="README in English" src="https://img.shields.io/badge/English-d9d9d9"></a>
  <a href="./README_ja.md"><img alt="日本語のREADME" src="https://img.shields.io/badge/日本語-d9d9d9"></a>
</p>

[tfupdate](https://github.com/minamijoyo/tfupdate) 用の GitHub Actions です。

このアクションは tfupdate を実行し、Terraform 本体やプロバイダーの新バージョンが見つかった場合に Pull Request を自動作成します。

> [!NOTE]
> このリポジトリは [daisaru11/tfupdate-github-actions](https://github.com/daisaru11/tfupdate-github-actions) のフォークです。差分は [v1.0.0...HEAD](https://github.com/masutaka/tfupdate-github-actions/compare/v1.0.0...HEAD) を参照してください。

## 前提条件

ワークフロージョブに以下の権限が必要です:

```yaml
permissions:
  contents: write       # 新しいブランチの push 用
  pull-requests: write  # Pull Request の作成用
```

## 入力パラメータ

| 名前 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| `github_token` | Yes | — | GitHub Token |
| `tfupdate_subcommand` | Yes | — | 実行するサブコマンド (`terraform` or `provider`) |
| `tfupdate_path` | No | `.` | tfupdate に渡すパス |
| `tfupdate_options` | No | `-r` | tfupdate に渡すオプション |
| `tfupdate_provider_name` | No | — | プロバイダー名 (サブコマンドが `provider` の場合は必須) |
| `update_tfenv_version_files` | No | `false` | `.terraform-version` ファイルも更新するか (`terraform` サブコマンド専用) |
| `update_tool_versions_files` | No | `false` | `.tool-versions` ファイルも更新するか (`terraform` サブコマンド専用) |
| `pr_base_branch` | No | トリガーブランチ | Pull Request のベースブランチ |
| `assignees` | No | — | PR にアサインする GitHub ハンドルのカンマ区切りリスト (カンマの前後にスペース不可) |

## サブコマンド

### `terraform`

最新の Terraform バージョンを取得し、`.tf` ファイル内のバージョン制約を更新します。

- `update_tfenv_version_files`: `.terraform-version` ファイルも更新
- `update_tool_versions_files`: `.tool-versions` ファイル内の `terraform` エントリも更新

これらのバージョンファイルの更新対象は、変更された `.tf` ファイルと同じディレクトリ、およびリポジトリルートに存在するファイルのみです。

```yaml
- uses: masutaka/tfupdate-github-actions@v2.1.0
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    tfupdate_subcommand: terraform
    tfupdate_path: './workspaces'
    assignees: 'alice'
```

### `provider`

指定された Terraform プロバイダーの最新バージョンを取得し、バージョン制約を更新します。このサブコマンドでは `tfupdate_provider_name` が必須です。

```yaml
- uses: masutaka/tfupdate-github-actions@v2.1.0
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    tfupdate_subcommand: provider
    tfupdate_path: './workspaces'
    tfupdate_provider_name: aws
    assignees: 'alice,bob'
```

## ブランチ命名と PR 重複防止

### ブランチ命名

以下のパターンでブランチが作成されます:

- `terraform`: `tfupdate/[path/]terraform-v{VERSION}`
- `provider`: `tfupdate/[path/]terraform-provider/{name}-v{VERSION}`

`tfupdate_path` が `.` の場合、パス部分は省略されます。

### PR 重複防止

PR 作成前に、同じタイトルの PR が既に存在するか (open または merged) を確認します。一致する PR が見つかった場合、新しい PR の作成はスキップされます。

## 使用例

```yaml
on:
  schedule:
    - cron: '0 0 * * *'

jobs:
  tfupdate_terraform:
    runs-on: ubuntu-latest
    name: Update terraform versions
    timeout-minutes: 5
    permissions:
      contents: write
      pull-requests: write
    steps:
    - uses: actions/checkout@v6
    - name: Create terraform update PR if need
      uses: masutaka/tfupdate-github-actions@v2.1.0
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        tfupdate_subcommand: terraform
        tfupdate_path: './workspaces'
        assignees: 'alice'
  tfupdate_provider:
    runs-on: ubuntu-latest
    name: Update terraform provider versions
    timeout-minutes: 5
    permissions:
      contents: write
      pull-requests: write
    steps:
    - uses: actions/checkout@v6
    - name: Create terraform provider update PR if need
      uses: masutaka/tfupdate-github-actions@v2.1.0
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        tfupdate_subcommand: provider
        tfupdate_path: './workspaces'
        tfupdate_provider_name: aws
        assignees: 'alice,bob'
```

作成される Pull Request の例は[こちら](https://github.com/daisaru11/tfupdate-github-actions-example/pulls)で確認できます。
