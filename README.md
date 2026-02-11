# tfupdate-github-actions

Github Actions for [tfupdate](https://github.com/minamijoyo/tfupdate).

This action runs tfupdate, and create Pull Requests if new versions of terraform or providers are found.

:bulb: This repository is a fork from [daisaru11/tfupdate-github-actions](https://github.com/daisaru11/tfupdate-github-actions). See [v1.0.0...HEAD](https://github.com/masutaka/tfupdate-github-actions/compare/v1.0.0...HEAD) for the differences.

## Usage

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

You can see examples of Pull Requests to be created [here](https://github.com/daisaru11/tfupdate-github-actions-example/pulls).
