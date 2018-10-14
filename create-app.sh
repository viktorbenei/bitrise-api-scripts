#!/usr/bin/env bash
set -ex

function check_required_env_var {
    env_var_key="$1"
    eval env_var='$'"${env_var_key}"
    if [ -z "$env_var" ] ; then
        echo "[!] Missing input (env var): ${env_var_key}"
        exit 1
    fi
    echo "(i) env_var_key: ${env_var}"
}

check_required_env_var 'BITRISE_PERSONAL_ACCESS_TOKEN'
check_required_env_var 'REPO_URL'

# register repo
app_id="$(curl -H "Authorization: token $BITRISE_PERSONAL_ACCESS_TOKEN" \
  'https://api.bitrise.io/v0.1/apps/register' \
  -d '{"provider":"custom","is_public":false,"repo_url":"'"$REPO_URL"""'''","type":"git"}' | jq -r '.slug')"
echo "Registered app ID: $app_id"

# register SSH key
# step 1: generate ssh key
# step 2: register it for the project

# finish
curl -H "Authorization: token $BITRISE_PERSONAL_ACCESS_TOKEN" \
  "https://api.bitrise.io/v0.1/apps/$app_id/finish" \
  -d '{"stack_id":"osx-xcode-edge","mode":"manual"}'
