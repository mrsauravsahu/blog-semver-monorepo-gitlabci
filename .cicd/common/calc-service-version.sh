GITVERSION='gittools/gitversion:5.10.0-alpine.3.14-6.0'

BRANCH="$1"
shift
SERVICES=("$@")

echo 'Checkout to branch'
git checkout "${BRANCH}"
# try to unshallow if CI system performed shallow clone
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
