#!/usr/bin/env bash

set -euo pipefail

function branchForTerraform {
  STR=tfupdate
  if [ "$TFUPDATE_PATH" != "." ]; then
    # Trim $TFUPDATE_PATH to remove leading and trailing slashes ("/")
    STR="$STR/$(echo "$TFUPDATE_PATH" | sed 's:^/*::;s:/*$::')"
  fi
  echo "${STR}/terraform-v${VERSION}"
}

function branchForProvider {
  STR=tfupdate
  if [ "$TFUPDATE_PATH" != "." ]; then
    # Trim $TFUPDATE_PATH to remove leading and trailing slashes ("/")
    STR="$STR/$(echo "$TFUPDATE_PATH" | sed 's:^/*::;s:/*$::')"
  fi
  echo "${STR}/terraform-provider/${TFUPDATE_PROVIDER_NAME}-v${VERSION}"
}

function subcommandTerraform {
  VERSION=$(tfupdate release latest hashicorp/terraform)

  VERSION_BRANCH=$(branchForTerraform)
  UPDATE_MESSAGE="[tfupdate] Update terraform to v${VERSION} in ${TFUPDATE_PATH}"
  PR_COUNT="$(gh pr list --state all --head "${VERSION_BRANCH}" --json number --jq 'length')"
  if [ "$PR_COUNT" -ne 0 ]; then
    echo "A pull request already exists for branch ${VERSION_BRANCH}"
  else
    git checkout -b "${VERSION_BRANCH}" "origin/${PR_BASE_BRANCH}"
    tfupdate terraform -v "${VERSION}" ${TFUPDATE_OPTIONS} "${TFUPDATE_PATH}"

    git add .
    if git diff --cached --exit-code --quiet; then
      echo "No changes"
    else
      if [ "${UPDATE_TFENV_VERSION_FILES}" == "1" ]; then
        for UPDATED_HCL in $(git diff --cached --name-only); do
          TFENV_VERSION_FILE="$(dirname "$UPDATED_HCL")/.terraform-version"
          if [ -f "$TFENV_VERSION_FILE" ]; then
            echo "$VERSION" > "$TFENV_VERSION_FILE"
          fi
        done
        if [ -f ".terraform-version" ]; then
          echo "$VERSION" > ".terraform-version"
        fi
        git add .
      fi

      if [ "${UPDATE_TOOL_VERSIONS_FILES}" == "1" ]; then
        for UPDATED_HCL in $(git diff --cached --name-only); do
          TOOL_VERSIONS_FILE="$(dirname "$UPDATED_HCL")/.tool-versions"
          if [ -f "$TOOL_VERSIONS_FILE" ] && grep -q '^terraform ' "$TOOL_VERSIONS_FILE"; then
            sed -i "s/^terraform .*/terraform ${VERSION}/" "$TOOL_VERSIONS_FILE"
          fi
        done
        if [ -f ".tool-versions" ] && grep -q '^terraform ' ".tool-versions"; then
          sed -i "s/^terraform .*/terraform ${VERSION}/" ".tool-versions"
        fi
        git add .
      fi

      git commit -m "$UPDATE_MESSAGE"
      PR_BODY="For details see: https://github.com/hashicorp/terraform/releases"
      git push origin HEAD
      if [ -n "$ASSIGNEES" ]; then
        gh pr create --title "$UPDATE_MESSAGE" --body "$PR_BODY" --base "${PR_BASE_BRANCH}" --assignee "${ASSIGNEES}"
      else
        gh pr create --title "$UPDATE_MESSAGE" --body "$PR_BODY" --base "${PR_BASE_BRANCH}"
      fi
    fi
  fi
}

function subcommandProvider {
  VERSION=$(tfupdate release latest terraform-providers/terraform-provider-${TFUPDATE_PROVIDER_NAME})

  VERSION_BRANCH=$(branchForProvider)
  UPDATE_MESSAGE="[tfupdate] Update terraform-provider-${TFUPDATE_PROVIDER_NAME} to v${VERSION} in ${TFUPDATE_PATH}"
  PR_COUNT="$(gh pr list --state all --head "${VERSION_BRANCH}" --json number --jq 'length')"
  if [ "$PR_COUNT" -ne 0 ]; then
    echo "A pull request already exists for branch ${VERSION_BRANCH}"
  else
    git checkout -b "${VERSION_BRANCH}" "origin/${PR_BASE_BRANCH}"
    tfupdate provider "${TFUPDATE_PROVIDER_NAME}" -v "${VERSION}" ${TFUPDATE_OPTIONS} "${TFUPDATE_PATH}"
    git add .
    if git diff --cached --exit-code --quiet; then
      echo "No changes"
    else
      git commit -m "$UPDATE_MESSAGE"
      PR_BODY="For details see: https://github.com/terraform-providers/terraform-provider-${TFUPDATE_PROVIDER_NAME}/releases"
      git push origin HEAD
      if [ -n "$ASSIGNEES" ]; then
        gh pr create --title "$UPDATE_MESSAGE" --body "$PR_BODY" --base "${PR_BASE_BRANCH}" --assignee "${ASSIGNEES}"
      else
        gh pr create --title "$UPDATE_MESSAGE" --body "$PR_BODY" --base "${PR_BASE_BRANCH}"
      fi
    fi
  fi
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

