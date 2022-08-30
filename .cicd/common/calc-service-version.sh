#!/usr/bin/env bash

set -o xtrace
set -o errexit

echo 'MonoTools: Service Version Calculator'

GITVERSION='gittools/gitversion:5.10.0-alpine.3.14-6.0'
GITVERSION_TAG_PROPERTY_DEFAULT='.SemVer'
GITVERSION_TAG_PROPERTY_DEVELOP='.SemVer'
GITVERSION_TAG_PROPERTY_RELEASE='.SemVer'
GITVERSION_TAG_PROPERTY_HOTFIX='.SemVer'
GITVERSION_TAG_PROPERTY_MAIN='.MajorMinorPatch'

BRANCH="$1"
shift
SERVICES=("$@")

echo 'Checkout to branch'
git fetch --all && git checkout "${BRANCH}"
# try to unshallow if CI system performed shallow clone
git checkout main && git checkout -
git checkout develop && git checkout -
git pull --unshallow || true

echo 'Calculate service versions'
if [ "${#SERVICES[@]}" = "0" ]; then
  service_versions_txt='## service changes\nNo services changed\n'
else
  service_versions_txt="## service changes\n"
  for svc in "${SERVICES[@]}"; do
    echo "calculation for ${svc}"
    docker run --rm -v "$(pwd):/repo" $GITVERSION /repo /config "/repo/${svc}/.gitversion.yml"
    gitversion_calc=$(docker run --rm -v "$(pwd):/repo" $GITVERSION /repo /config "/repo/${svc}/.gitversion.yml")
    service_version=$(echo "${gitversion_calc}" | jq -r '.MajorMinorPatch')
    echo "${gitversion_calc}"
    service_versions_txt+="- ${svc} - v${service_version}\n"
    echo "DIFF_DEST '$DIFF_DEST'"
    GITVERSION_TAG_PROPERTY_NAME="GITVERSION_TAG_PROPERTY_$(echo "${DIFF_DEST}" | sed 's|/.*$||' | tr '[[:lower:]]' '[[:upper:]]')"
    GITVERSION_TAG_PROPERTY=${!GITVERSION_TAG_PROPERTY_NAME}
    svc_without_prefix="$(echo "${svc}" | sed "s|^apps/||")"
    if [ "${GITVERSION_TAG_PROPERTY}" != ".MajorMinorPatch" ]; then
        previous_commit_count=$(git tag -l | grep "^${svc_without_prefix}/v$(echo "${gitversion_calc}" | jq -r ".MajorMinorPatch")-$(echo "${gitversion_calc}" | jq -r ".PreReleaseLabel")" | grep -o -E '\.[0-9]+$' | grep -o -E '[0-9]+$' | sort -nr | head -1)
        next_commit_count=$((previous_commit_count+1))
        version_without_count=$(echo "${gitversion_calc}" | jq -r "[.MajorMinorPatch,.PreReleaseLabelWithDash] | join(\"\")")
        full_service_version="${version_without_count}.${next_commit_count}"
    else
    echo "SERVICE_VERSION=v${service_version}" > versioning.env
  done
fi

echo "${service_versions_txt}"
