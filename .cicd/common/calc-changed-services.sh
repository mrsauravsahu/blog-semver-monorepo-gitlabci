#!/usr/bin/env bash

set -o xtrace
set -o errexit

echo 'MonoTools: Changed Services Calculator'

# FLAVOR=
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
echo "${changed_services[@]}"

export MONOTOOLS_CHANGED_SERVICES="${changed_services[@]}"
