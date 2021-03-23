#!/usr/bin/env bash

#
# opaws <1Password AWS account title> <domain>.1password.com <aws email address>
#

OP_DOMAIN="${1}"
OP_AWS_ACCOUNT="${2}"
LOG_LEVEL=${3:-1}


# Exit script if we don't have the necessary environment variables
if
  [[ -z "${OP_AWS_ACCOUNT}" ]] ||
  [[ -z "${OP_DOMAIN}" ]];
then
  echo "Missing arguments. Aborting."
  exit 1
fi

# Verify all the command line tools are installed
command -v op >/dev/null 2>&1 || {
    echo >&2 "op is not installed. Aborting."
    exit 1
}
command -v aws >/dev/null 2>&1 || {
    echo >&2 "aws is not installed. Aborting."
    exit 1
}
command -v jq >/dev/null 2>&1 || {
    echo >&2 "jq is not installed. Aborting."
    exit 1
}

echo "Signing into 1Password..."

# Sign into 1Password
eval $(op signin "${OP_DOMAIN}")

echo "Signing into aws..."

# Retrieve the item from 1Password
op_item_json=$(op get item ${OP_AWS_ACCOUNT})

# Extract AWS account information from 1Password
account_email=$(op get item ${OP_AWS_ACCOUNT} | jq -r '.overview.ainfo')
[[ ${LOG_LEVEL} -ge 2 ]] && echo "DEBUG - Account Email: ${account_email}"
account_url=$(op get item ${OP_AWS_ACCOUNT} | jq -r '.overview.url')
[[ ${LOG_LEVEL} -ge 2 ]] && echo "DEBUG - Account URL: ${account_url}"
account_id=$(echo $account_url | awk -F[/:] '{print $4}' | awk -F[.] '{print $1}')
[[ ${LOG_LEVEL} -ge 2 ]] && echo "DEBUG - Account ID: ${account_id}"
account_access_key=$(echo ${op_item_json} | jq -r '.details.sections[] | select(.title=="Keys") .fields[] | select(.t=="access") | .v')
[[ ${LOG_LEVEL} -ge 2 ]] && echo "DEBUG - Account Access Key: ${account_access_key}"
account_secret_key=$(echo ${op_item_json} | jq -r '.details.sections[] | select(.title=="Keys") .fields[] | select(.t=="secret") | .v')
[[ ${LOG_LEVEL} -ge 2 ]] && echo "DEBUG - Account Secret Key: ${account_secret_key}"

# Set the aws profiles keys
aws --profile "${OP_AWS_ACCOUNT}-default" configure set aws_access_key_id "${account_access_key}"
aws --profile "${OP_AWS_ACCOUNT}-default" configure set aws_secret_access_key "${account_secret_key}"

# Set the full arn url
aws_arn="arn:aws:iam::${account_id}:mfa/${account_email}"
[[ ${LOG_LEVEL} -ge 2 ]] && echo "DEBUG - AWS ARN: ${aws_arn}"

# Get the MFA code
token=$(op get totp ${OP_AWS_ACCOUNT} >/dev/null 2>&1)

# No token? Use standard credentials
if [[ -z $token ]]; then
  aws --profile "default" configure set aws_access_key_id "${account_access_key}"
  aws --profile "default" configure set aws_secret_access_key "${account_secret_key}"
else
  [[ ${LOG_LEVEL} -ge 2 ]] && echo "DEBUG - MFA Token: ${token}"

  # Sign in and get the AWS Credential information
  creds=$(aws \
    --profile "${OP_AWS_ACCOUNT}-default" sts get-session-token \
    --duration "86400" \
    --serial-number "${aws_arn}" \
    --token-code "${token}" \
    --output json
  )

  # Set the AWS account information
  aws_access_key_id=$(echo ${creds} | jq -r '.Credentials.AccessKeyId')
  [[ ${LOG_LEVEL} -ge 2 ]] && echo "DEBUG - Temporary access key id: ${aws_access_key_id}"
  aws_secret_access_key=$(echo ${creds} | jq -r '.Credentials.SecretAccessKey')
  [[ ${LOG_LEVEL} -ge 2 ]] && echo "DEBUG - Temporary secret access key: ${aws_secret_access_key}"
  aws_session_token=$(echo ${creds} | jq -r '.Credentials.SessionToken')
  [[ ${LOG_LEVEL} -ge 2 ]] && echo "DEBUG - Temporary session token: ${aws_session_token}"

  # Set the aws profile session tokens
  aws --profile "default" configure set aws_access_key_id "${aws_access_key_id}"
  aws --profile "default" configure set aws_secret_access_key "${aws_secret_access_key}"
  aws --profile "default" configure set aws_session_token "${aws_session_token}"
fi

# Verify success or failure
if aws sts get-caller-identity >/dev/null 2>&1; then
  echo "aws cli is ready to roll"
else
  echo "Unable to log in, try to run again with a third parameter set to 2"
fi