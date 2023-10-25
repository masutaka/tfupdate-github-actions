# tfupdate-github-actions

Github Actions for [tfupdate](https://github.com/minamijoyo/tfupdate).

This action runs tfupdate, and create Pull Requests if new versions of terraform or providers are found.

:bulb: This repository is a fork from [daisaru11/tfupdate-github-actions](https://github.com/daisaru11/tfupdate-github-actions). See [v1.0.0...HEAD](https://github.com/masutaka/tfupdate-github-actions/compare/v1.0.0...HEAD) for the differences.

## Usage

```
on:
  schedule:
    - cron:  '0 0 * * *'

jobs:
  test_terraform_job:
    runs-on: ubuntu-latest
    name: Update terraform versions
    steps:
    - name: "Checkout"
      uses: actions/checkout@v4
    - name: tfupdate
      uses: masutaka/tfupdate-github-actions@v2.1.0
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        tfupdate_subcommand: terraform
        tfupdate_path: './workspaces'
        assignees: 'alice'

  test_provider_job:
    runs-on: ubuntu-latest
    name: Update provider versions
    steps:
    - name: "Checkout"
      uses: actions/checkout@v4
    - name: tfupdate
      uses: masutaka/tfupdate-github-actions@v2.1.0
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        tfupdate_subcommand: provider
        tfupdate_path: './workspaces'
        tfupdate_provider_name: aws
        assignees: 'alice,bob'
```

You can see examples of Pull Requests to be created [here](https://github.com/daisaru11/tfupdate-github-actions-example/pulls).
