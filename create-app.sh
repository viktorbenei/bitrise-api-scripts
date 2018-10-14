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
app_id="$(curl -H "Authorization: token ${BITRISE_PERSONAL_ACCESS_TOKEN}" \
  'https://api.bitrise.io/v0.1/apps/register' \
  -d '{"provider":"custom","is_public":false,"repo_url":"'"${REPO_URL}"""'''","type":"git"}' | jq -r '.slug')"
echo "Registered app ID: ${app_id}"

# finish
finish_call_response="$(curl --fail \
  -H "Authorization: token ${BITRISE_PERSONAL_ACCESS_TOKEN}" \
  "https://api.bitrise.io/v0.1/apps/${app_id}/finish" \
  -d '{"stack_id":"osx-xcode-edge","mode":"manual"}')"

is_webhook_auto_reg_supported="$(echo "$finish_call_response" | jq -r '.is_webhook_auto_reg_supported')"

if [[ "$is_webhook_auto_reg_supported" == "true" ]] ; then
    # register a webhook on supported services (GitHub, Bitbucket, GitLab)
    # so that a code push will trigger a build automatically
    curl --fail \
        -X POST \
        -H "Authorization: token ${BITRISE_PERSONAL_ACCESS_TOKEN}" \
        "https://api.bitrise.io/v0.1/apps/${app_id}/register-webhook"
else
    echo "Auto webhook registration is not supported for this repository, please register one yourself."
    echo "You can find the related instructions on the Code tab of the app on bitrise.io,"
    echo " in the INCOMING WEBHOOKS section: https://app.bitrise.io/app/${app_id}#/code"
fi

# TODO:
# - upload the bitrise.yml / build config
# - register SSH key
#     - step 1: generate ssh key
#     - step 2: register it for the project
