#!/usr/bin/env bash

#
# Usage: set the input environment variables and then run: $ ./create-app.sh
# Required input env vars:
# * BITRISE_PERSONAL_ACCESS_TOKEN : your Bitrise.io API Token / Personal Access Token
# * REPO_URL : Repository URL for git clone.
# Optional intput env vars:
# * BITRISE_YML_PATH : path to the bitrise.yml file to set as the config of the app.
#     If not set then a very basic, generic config will be used on bitrise.io
#     which basically just clones the repository.
#

# fail if any command fails
set -e
# enable debug mode
# set -x

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function check_required_env_var {
    env_var_key="$1"
    eval env_var='$'"${env_var_key}"
    if [ -z "$env_var" ] ; then
        echo -e "${RED}[!] Missing required input (env var)${NC}: ${env_var_key}"
        exit 1
    fi
}

check_required_env_var 'BITRISE_PERSONAL_ACCESS_TOKEN'
check_required_env_var 'REPO_URL'

# register repo
echo
echo -e "${YELLOW}# Register repository ($REPO_URL) ...${NC}"
app_id="$(curl -H "Authorization: token ${BITRISE_PERSONAL_ACCESS_TOKEN}" \
  'https://api.bitrise.io/v0.1/apps/register' \
  -d '{"provider":"custom","is_public":false,"repo_url":"'"${REPO_URL}"""'''","type":"git"}' | jq -r '.slug')"
echo "Registered app ID: ${app_id}"

# finish
echo
echo -e "${YELLOW}# Set stack and finish registration ...${NC}"
finish_call_response="$(curl --fail \
  -H "Authorization: token ${BITRISE_PERSONAL_ACCESS_TOKEN}" \
  "https://api.bitrise.io/v0.1/apps/${app_id}/finish" \
  -d '{"stack_id":"osx-xcode-edge","mode":"manual"}')"

# Upload bitrise.yml / build config if specified
echo
echo -e "${YELLOW}# Upload bitrise.yml ...${NC}"
if [ ! -z "${BITRISE_YML_PATH}" ] ; then
    echo " Uploading from file: ${BITRISE_YML_PATH}"
    jq -n --arg yml_content "$(cat "$BITRISE_YML_PATH")" \
        '{app_config_datastore_yaml: $yml_content }' | curl --fail \
        -X POST \
        -H "Authorization: token ${BITRISE_PERSONAL_ACCESS_TOKEN}" \
        "https://api.bitrise.io/v0.1/apps/${app_id}/bitrise.yml" \
        -d@-
else
    echo "No bitrise.yml path specified (BITRISE_YML_PATH env var),"
    echo " so a very basic config will be used."
    echo "You can of course change this any time on the Workflow tab of the app on bitrise.io"
fi
echo

# Auto-register an incoming webhook on supported services (GitHub, Bitbucket, GitLab)
# so that a code push will trigger a build automatically.
# First check if the service is supported & that we have the required
# connected account so that Bitrise can register the webhook:
echo
echo -e "${YELLOW}# Register incoming webhook ...${NC}"
is_webhook_auto_reg_supported="$(echo "$finish_call_response" | jq -r '.is_webhook_auto_reg_supported')"
if [[ "$is_webhook_auto_reg_supported" == "true" ]] ; then
    curl --fail \
        -X POST \
        -H "Authorization: token ${BITRISE_PERSONAL_ACCESS_TOKEN}" \
        "https://api.bitrise.io/v0.1/apps/${app_id}/register-webhook"
else
    echo "Auto webhook registration is not supported for this repository, please register one yourself."
    echo "You can find the related instructions on the Code tab of the app on bitrise.io,"
    echo " in the INCOMING WEBHOOKS section: https://app.bitrise.io/app/${app_id}#/code"
fi
echo

# TODO:
# - register SSH key
#     - step 1: generate ssh key
#     - step 2: register it for the project
