#!/usr/bin/env bash
# Expected to be run on Ubuntu docker images

set -o xtrace

echo 'AUTO GIT TAGGING'

FLAVOR="$1"
GITVERSION='gittools/gitversion:5.10.0-alpine.3.14-6.0'
VAR_EVENT_NAME='CI_PIPELINE_SOURCE'
VAR_PR_BRANCH='CI_MERGE_REQUEST_SOURCE_BRANCH_NAME'
VAR_PR_TARGET_BRANCH='CI_MERGE_REQUEST_TARGET_BRANCH_NAME'
VAR_PUSH_BRANCH='CI_COMMIT_BRANCH'

echo 'Fetch all history for all tags and branches'
git fetch --all && git checkout develop && git checkout main

echo 'Check base ref'
echo "CI_MERGE_REQUEST_SOURCE_BRANCH_NAME='$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME'"
echo "CI_MERGE_REQUEST_TARGET_BRANCH_NAME='$CI_MERGE_REQUEST_TARGET_BRANCH_NAME'"
echo "CI_COMMIT_BRANCH='$CI_COMMIT_BRANCH'"
echo "CI_PIPELINE_SOURCE='$CI_PIPELINE_SOURCE'"

echo 'Calculate changed services'
if [ "${!VAR_EVENT_NAME}" = 'push' ]; then
  DIFF_DEST="${!VAR_PUSH_BRANCH}"
  DIFF_SOURCE="${DIFF_DEST}~1"
else
  DIFF_DEST="${!VAR_PR_BRANCH}"
  DIFF_SOURCE="${!VAR_PR_TARGET_BRANCH}"
fi
changed_services=`git diff "origin/${DIFF_SOURCE}" "origin/${DIFF_DEST}" --name-only | grep -o '^apps/[a-zA-Z-]*' | sort | uniq`

echo 'Checkout to branch'
git checkout "${DIFF_DEST}"

echo 'Calculate service versions'
if [ "${#changed_services[@]}" = "0" ]; then
  service_versions_txt='## service changes\nNo services changed\n'
else
  service_versions_txt="## service changes\n"
  for svc in "${changed_services[@]}"; do
    echo "calculation for ${svc}"
    docker run --rm -v "$(pwd):/repo" ${{ env.GITVERSION }} /repo /config "/repo/${svc}/.gitversion.yml"
    gitversion_calc=$(docker run --rm -v "$(pwd):/repo" ${{ env.GITVERSION }} /repo /config "/repo/${svc}/.gitversion.yml")
    service_version=$(echo "${gitversion_calc}" | jq -r '.MajorMinorPatch')
    echo "${gitversion_calc}"
    service_versions_txt+="- ${svc} - v${service_version}\n"
  done
fi

# echo 'Update PR description'
# PR_NUMBER=$(echo $GITHUB_REF | awk 'BEGIN { FS = "/" } ; { print $3 }')
# # from https://github.com/actions/checkout/issues/58#issuecomment-614041550
# jq -nc '{"body": "${{ fromJSON(steps.calculate_service_versions.outputs.PR_BODY) }}" }' | \
# curl -sL  -X PATCH -d @- \
#   -H "Content-Type: application/json" \
#   -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}" \
#   "https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER"

