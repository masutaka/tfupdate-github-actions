#!/usr/bin/env bash

set -euo pipefail

function branchPrefix {
  local prefix=tfupdate
  if [ "$TFUPDATE_PATH" != "." ]; then
    # Trim $TFUPDATE_PATH to remove leading and trailing slashes ("/")
    prefix="${prefix}/$(echo "$TFUPDATE_PATH" | sed 's:^/*::;s:/*$::')"
  fi
  echo "$prefix"
}

function branchForTerraform {
  local version="$1"
  echo "$(branchPrefix)/terraform-v${version}"
}

function branchForProvider {
  local version="$1"
  echo "$(branchPrefix)/terraform-provider/${TFUPDATE_PROVIDER_NAME}-v${version}"
}

function hasExistingPR {
  local branch="$1"
  local pr_count
  pr_count="$(gh pr list --state all --head "${branch}" --json number --jq 'length')"
  [ "$pr_count" -ne 0 ]
}

function commitAndCreatePR {
  local message="$1"
  local body="$2"
  local base_branch="$3"
  local assignees="$4"

  git commit -m "$message"
  git push origin HEAD
  if [ -n "$assignees" ]; then
    gh pr create --title "$message" --body "$body" --base "${base_branch}" --assignee "${assignees}"
  else
    gh pr create --title "$message" --body "$body" --base "${base_branch}"
  fi
}

function subcommandTerraform {
  local version
  version=$(tfupdate release latest hashicorp/terraform)

  local version_branch
  version_branch=$(branchForTerraform "$version")
  local update_message="[tfupdate] Update terraform to v${version} in ${TFUPDATE_PATH}"
  local updated_hcl
  local tfenv_version_file
  local tool_versions_file

  if hasExistingPR "${version_branch}"; then
    echo "A pull request already exists for branch ${version_branch}"
    return
  fi

  git checkout -b "${version_branch}" "origin/${PR_BASE_BRANCH}"
  # shellcheck disable=SC2086
  tfupdate terraform -v "${version}" ${TFUPDATE_OPTIONS} "${TFUPDATE_PATH}"

  git add .
  if git diff --cached --exit-code --quiet; then
    echo "No changes"
    return
  fi

  if [ "${UPDATE_TFENV_VERSION_FILES}" == "1" ]; then
    for updated_hcl in $(git diff --cached --name-only); do
      tfenv_version_file="$(dirname "$updated_hcl")/.terraform-version"
      if [ -f "$tfenv_version_file" ]; then
        echo "$version" > "$tfenv_version_file"
      fi
    done
    if [ -f ".terraform-version" ]; then
      echo "$version" > ".terraform-version"
    fi
    git add .
  fi

  if [ "${UPDATE_TOOL_VERSIONS_FILES}" == "1" ]; then
    for updated_hcl in $(git diff --cached --name-only); do
      tool_versions_file="$(dirname "$updated_hcl")/.tool-versions"
      if [ -f "$tool_versions_file" ] && grep -q '^terraform ' "$tool_versions_file"; then
        sed -i "s/^terraform .*/terraform ${version}/" "$tool_versions_file"
      fi
    done
    if [ -f ".tool-versions" ] && grep -q '^terraform ' ".tool-versions"; then
      sed -i "s/^terraform .*/terraform ${version}/" ".tool-versions"
    fi
    git add .
  fi

  commitAndCreatePR "$update_message" "For details see: https://github.com/hashicorp/terraform/releases" "$PR_BASE_BRANCH" "$ASSIGNEES"
}

function subcommandProvider {
  local version
  version=$(tfupdate release latest "terraform-providers/terraform-provider-${TFUPDATE_PROVIDER_NAME}")

  local version_branch
  version_branch=$(branchForProvider "$version")
  local update_message="[tfupdate] Update terraform-provider-${TFUPDATE_PROVIDER_NAME} to v${version} in ${TFUPDATE_PATH}"

  if hasExistingPR "${version_branch}"; then
    echo "A pull request already exists for branch ${version_branch}"
    return
  fi

  git checkout -b "${version_branch}" "origin/${PR_BASE_BRANCH}"
  # shellcheck disable=SC2086
  tfupdate provider "${TFUPDATE_PROVIDER_NAME}" -v "${version}" ${TFUPDATE_OPTIONS} "${TFUPDATE_PATH}"

  git add .
  if git diff --cached --exit-code --quiet; then
    echo "No changes"
    return
  fi

  commitAndCreatePR "$update_message" "For details see: https://github.com/terraform-providers/terraform-provider-${TFUPDATE_PROVIDER_NAME}/releases" "$PR_BASE_BRANCH" "$ASSIGNEES"
}

TFUPDATE_SUBCOMMAND=""
if [ "${INPUT_TFUPDATE_SUBCOMMAND}" != "" ]; then
  TFUPDATE_SUBCOMMAND=${INPUT_TFUPDATE_SUBCOMMAND}
else
  echo "tfupdate_subcommand is required"
  exit 1
fi

TFUPDATE_PATH="."
if [ "${INPUT_TFUPDATE_PATH}" != "" ]; then
  TFUPDATE_PATH=${INPUT_TFUPDATE_PATH}
fi

TFUPDATE_OPTIONS="-r"
if [ "${INPUT_TFUPDATE_OPTIONS}" != "" ]; then
  TFUPDATE_OPTIONS=${INPUT_TFUPDATE_OPTIONS}
fi

TFUPDATE_PROVIDER_NAME=""
if [ "${INPUT_TFUPDATE_PROVIDER_NAME}" != "" ]; then
  TFUPDATE_PROVIDER_NAME=${INPUT_TFUPDATE_PROVIDER_NAME}
fi
if [ "${TFUPDATE_PROVIDER_NAME}" == "" ] && [ "${TFUPDATE_SUBCOMMAND}" == "provider" ]; then
  echo "tfupdate_provider_name is required if you are using the provider subcommand"
  exit 1
fi

UPDATE_TFENV_VERSION_FILES=0
if [ "${INPUT_UPDATE_TFENV_VERSION_FILES}" == "1" ] || [ "${INPUT_UPDATE_TFENV_VERSION_FILES}" == "true" ]; then
  UPDATE_TFENV_VERSION_FILES=1
fi

UPDATE_TOOL_VERSIONS_FILES=0
if [ "${INPUT_UPDATE_TOOL_VERSIONS_FILES}" == "1" ] || [ "${INPUT_UPDATE_TOOL_VERSIONS_FILES}" == "true" ]; then
  UPDATE_TOOL_VERSIONS_FILES=1
fi

PR_BASE_BRANCH="${GITHUB_REF##*/}"
if [ "${INPUT_PR_BASE_BRANCH}" != "" ]; then
  PR_BASE_BRANCH=${INPUT_PR_BASE_BRANCH}
fi

ASSIGNEES=""
if [ "${INPUT_ASSIGNEES}" != "" ]; then
  ASSIGNEES=$(echo "${INPUT_ASSIGNEES}" | tr -d ' ')
fi

GITHUB_TOKEN="${INPUT_GITHUB_TOKEN}"

cd "${GITHUB_WORKSPACE}/"

git config --global --add safe.directory "$GITHUB_WORKSPACE"
git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
git config --global user.email "action@github.com"
git config --global user.name "GitHub Action"

tfupdate --version
gh --version

case "${TFUPDATE_SUBCOMMAND}" in
  terraform)
    subcommandTerraform
    ;;
  provider)
    subcommandProvider
    ;;
  *)
    echo "invalid tfupdate_subcommand is provided"
    exit 1
    ;;
esac
