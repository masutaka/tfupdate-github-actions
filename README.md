# tfupdate-github-actions

<p>
  <a href="./README.md"><img alt="README in English" src="https://img.shields.io/badge/English-d9d9d9"></a>
  <a href="./README_ja.md"><img alt="日本語のREADME" src="https://img.shields.io/badge/日本語-d9d9d9"></a>
</p>

GitHub Actions for [tfupdate](https://github.com/minamijoyo/tfupdate).

This action runs tfupdate to check for new versions of Terraform or providers, and automatically creates a Pull Request if updates are found.

> [!NOTE]
> This repository is a fork from [daisaru11/tfupdate-github-actions](https://github.com/daisaru11/tfupdate-github-actions). See [v1.0.0...HEAD](https://github.com/masutaka/tfupdate-github-actions/compare/v1.0.0...HEAD) for the differences.

## Prerequisites

The workflow job requires the following permissions:

```yaml
permissions:
  contents: write       # To push a new branch
  pull-requests: write  # To create a pull request
```

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `github_token` | Yes | — | GitHub Token |
| `tfupdate_subcommand` | Yes | — | Subcommand to execute (`terraform` or `provider`) |
| `tfupdate_path` | No | `.` | A path provided to tfupdate |
| `tfupdate_options` | No | `-r` | Options provided to tfupdate |
| `tfupdate_provider_name` | No | — | Provider name (required when subcommand is `provider`) |
| `update_tfenv_version_files` | No | `false` | Whether to update `.terraform-version` files (only for `terraform` subcommand) |
| `update_tool_versions_files` | No | `false` | Whether to update `.tool-versions` files (only for `terraform` subcommand) |
| `pr_base_branch` | No | Trigger branch | The base branch of a Pull Request |
| `assignees` | No | — | Comma-separated list of GitHub handles to assign to the PR |

## Subcommands

### `terraform`

Fetches the latest Terraform version and updates version constraints in `.tf` files.

- `update_tfenv_version_files`: also updates `.terraform-version` files
- `update_tool_versions_files`: also updates the `terraform` entry in `.tool-versions` files

These version file updates target files in the same directory as changed `.tf` files and at the repository root.

```yaml
- uses: masutaka/tfupdate-github-actions@v2.2.0
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    tfupdate_subcommand: terraform
    tfupdate_path: './workspaces'
    assignees: 'alice'
```

### `provider`

Fetches the latest version of the specified Terraform provider and updates version constraints. `tfupdate_provider_name` is required for this subcommand.

```yaml
- uses: masutaka/tfupdate-github-actions@v2.2.0
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    tfupdate_subcommand: provider
    tfupdate_path: './workspaces'
    tfupdate_provider_name: aws
    assignees: 'alice,bob'
```

## Branch naming and PR deduplication

### Branch naming

Branches are created with the following patterns:

- `terraform`: `tfupdate/[path/]terraform-v{VERSION}`
- `provider`: `tfupdate/[path/]terraform-provider/{name}-v{VERSION}`

When `tfupdate_path` is `.`, the path segment is omitted.

### PR deduplication

Before creating a PR, the action checks whether a PR for the same branch already exists (open or merged). If a matching PR is found, the action skips creating a new one.

## Full example

```yaml
on:
  schedule:
    - cron: '0 0 * * *'

jobs:
  tfupdate_terraform:
    runs-on: ubuntu-slim
    name: Update terraform versions
    timeout-minutes: 5
    permissions:
      contents: write
      pull-requests: write
    steps:
    - uses: actions/checkout@v6
    - name: Create terraform update PR if need
      uses: masutaka/tfupdate-github-actions@v2.2.0
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        tfupdate_subcommand: terraform
        tfupdate_path: './workspaces'
        assignees: 'alice'
  tfupdate_provider:
    runs-on: ubuntu-slim
    name: Update terraform provider versions
    timeout-minutes: 5
    permissions:
      contents: write
      pull-requests: write
    steps:
    - uses: actions/checkout@v6
    - name: Create terraform provider update PR if need
      uses: masutaka/tfupdate-github-actions@v2.2.0
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        tfupdate_subcommand: provider
        tfupdate_path: './workspaces'
        tfupdate_provider_name: aws
        assignees: 'alice,bob'
```

You can see examples of Pull Requests to be created [here](https://github.com/daisaru11/tfupdate-github-actions-example/pulls).
