#!/usr/bin/env bash

set -o xtrace
set -o errexit

echo 'AUTO GIT TAGGING'

# FLAVOR=
GITVERSION='gittools/gitversion:5.10.0-alpine.3.14-6.0'
if [ "${FLAVOR}" == 'gitlab' ]; then
  VAR_EVENT_NAME='CI_PIPELINE_SOURCE'
  VAR_PR_BRANCH='CI_MERGE_REQUEST_SOURCE_BRANCH_NAME'
  VAR_PR_TARGET_BRANCH='CI_MERGE_REQUEST_TARGET_BRANCH_NAME'
  VAR_PUSH_BRANCH='CI_COMMIT_BRANCH'
elif [ "${FLAVOR}" == 'github' ]; then
  VAR_EVENT_NAME='GITHUB_EVENT_NAME'
  VAR_PR_BRANCH='GITHUB_HEAD_REF'
  VAR_PR_TARGET_BRANCH='GITHUB_BASE_REF'
  VAR_PUSH_BRANCH='GITHUB_REF_NAME'
else
  echo "ERROR: Trying auto tag on an unknown flavor of source control provider" >&2
  exit 1
fi

echo 'Fetch all history for all tags and branches'
git fetch --all && git checkout develop && git checkout main

echo 'Calculate changed services'
if [ "${!VAR_EVENT_NAME}" = 'push' ]; then
  DIFF_DEST="${!VAR_PUSH_BRANCH}"
  DIFF_SOURCE="${DIFF_DEST}~1"
else
  DIFF_DEST="${!VAR_PR_BRANCH}"
  DIFF_SOURCE="${!VAR_PR_TARGET_BRANCH}"
fi

file_diff_list=`(git diff "origin/${DIFF_SOURCE}" "origin/${DIFF_DEST}" --name-only | grep -o '^apps/[a-zA-Z-]*') || echo ''`
changed_services=(`echo "${file_diff_list}" | grep -o '^apps/[a-zA-Z-]*' | sort | uniq`) || true

echo 'Checkout to branch'
git checkout "${DIFF_DEST}"
# try to unshallow if CI system performed shallow clone
git pull --unshallow || true

echo 'Calculate service versions'
if [ "${#changed_services[@]}" = "0" ]; then
  service_versions_txt='## service changes\nNo services changed\n'
else
  service_versions_txt="## service changes\n"
  for svc in "${changed_services[@]}"; do
    echo "calculation for ${svc}"
    docker run --rm -v "$(pwd):/repo" $GITVERSION /repo /config "/repo/${svc}/.gitversion.yml"
    gitversion_calc=$(docker run --rm -v "$(pwd):/repo" $GITVERSION /repo /config "/repo/${svc}/.gitversion.yml")
    service_version=$(echo "${gitversion_calc}" | jq -r '.MajorMinorPatch')
    echo "${gitversion_calc}"
    service_versions_txt+="- ${svc} - v${service_version}\n"
  done
fi

echo "${service_versions_txt}"

# echo 'Update PR description'
# PR_NUMBER=$(echo $GITHUB_REF | awk 'BEGIN { FS = "/" } ; { print $3 }')
# # from https://github.com/actions/checkout/issues/58#issuecomment-614041550
# jq -nc '{"body": "${{ fromJSON(steps.calculate_service_versions.outputs.PR_BODY) }}" }' | \
# curl -sL  -X PATCH -d @- \
#   -H "Content-Type: application/json" \
#   -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}" \
#   "https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER"

