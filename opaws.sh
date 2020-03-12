#!/usr/bin/env bash

#
# opaws <1Password AWS account title> <domain>.1password.com <aws email address>
#

AWS_ACCOUNT="${1}"
OP_DOMAIN="${2}"
AWS_EMAIL="${3}"

# Exit script if we don't have the necessary environment variables
if
  [[ -z "${AWS_ACCOUNT}" ]] ||
  [[ -z "${OP_DOMAIN}" ]] ||
  [[ -z "${AWS_EMAIL}" ]];
then
  echo "Error: Missing variables, see README.md"
  exit 1
fi

# Verify all the command line tools are installed
need() {
  if ! [ -x "$(command -v $1)" ]; then
    echo "Error: $1 is not installed, see README.md"
    exit 1
  fi
}

need "jq"
need "op"
need "aws"

echo "Signing into 1Password"

# Sign into 1Password
eval $(op signin "${OP_DOMAIN}")

# Retrieve the item from 1Password
op_item_json=$(op get item ${AWS_ACCOUNT})

# Extract AWS account ID from Website URL
account_url=$(op get item AWS-Explorer | jq -r '.overview.url')
echo "DEBUG - Account URL: ${account_url}"
account_id=$(echo $account_url | awk -F[/:] '{print $4}' | awk -F[.] '{print $1}')
echo "DEBUG - Account ID: ${account_id}"

# Extract Section labels and values from 1Password for access and secret keys
account_access_key=$(echo ${op_item_json} | jq -r '.details.sections[] | select(.title=="Keys") .fields[] | select(.t=="access") | .v')
echo "DEBUG - Account Access Key: ${account_access_key}"
account_secret_key=$(echo ${op_item_json} | jq -r '.details.sections[] | select(.title=="Keys") .fields[] | select(.t=="secret") | .v')
echo "DEBUG - Account Secret Key: ${account_secret_key}"

# Set the aws profiles keys
aws --profile "${AWS_ACCOUNT}-default" configure set aws_access_key_id "$account_access_key"
aws --profile "${AWS_ACCOUNT}-default" configure set aws_secret_access_key "$account_secret_key"

aws_arn="arn:aws:iam::${account_id}:mfa/${AWS_EMAIL}"
echo "DEBUG - AWS ARN: ${aws_arn}"

read aws_access_key_id aws_secret_access_key aws_session_token <<< $( aws \
  --profile "${AWS_ACCOUNT}-default" sts get-session-token \
  --duration "129600" \
  --serial-number "${aws_arn}" \
  --token-code $(op get totp ${AWS_ACCOUNT} || exit 5) \
  --output text  | awk '{ print $2, $4, $5 }')

# Set the aws profile session tokens
aws --profile "default" configure set aws_access_key_id "$aws_access_key_id"
aws --profile "default" configure set aws_secret_access_key "$aws_secret_access_key"
aws --profile "default" configure set aws_session_token "$aws_session_token"

# Verify success or failure
if aws sts get-caller-identity; then
  echo "Successfully logged in"
else
  echo "Error unable to log in"
fi