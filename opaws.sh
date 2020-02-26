#!/usr/bin/env bash

# Optional parameter to set default account in AWS credentials
DEFAULT_ACCOUNT="${1}"

# Exit script if we don't have the necessary environment variables
if
    [[ -z "${OP_DOMAIN}" ]] ||
    [[ -z "${OP_AWS_ACCOUNTS}" ]] ||
    [[ -z "${AWS_EMAIL}" ]];
then
    die "Missing environment variables, see README.md"
fi

# Verify all the command line tools are installed
need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "jq"
need "op"
need "aws"

# Sign into 1Password
eval $(op signin "${OP_DOMAIN}")

# Get AWS Env ID, Access Key, and Secret Key
for account in ${OP_AWS_ACCOUNTS[@]}; do
  # Retrieve the item from 1Password
  op_item_json=$(op get item ${account})
  
  # Extract Section labels and values from 1Password
  account_id=$(echo ${op_item_json} | jq -r '.details.sections[] | select(.title=="AWS Environment") .fields[] | select(.t=="id") | .v')
  account_access_key=$(echo ${op_item_json} | jq -r '.details.sections[] | select(.title=="Keys") .fields[] | select(.t=="access") | .v')
  account_secret_key=$(echo ${op_item_json} | jq -r '.details.sections[] | select(.title=="Keys") .fields[] | select(.t=="secret") | .v')

  # Set the aws profiles keys
  aws --profile "${account}-default" configure set aws_access_key_id "$account_access_key"
  aws --profile "${account}-default" configure set aws_secret_access_key "$account_secret_key"

  aws_arn="arn:aws:iam::${account_id}:mfa/${AWS_EMAIL}"

  read aws_access_key_id aws_secret_access_key aws_session_token <<< $( aws \
    --profile "${account}-default" sts get-session-token \
    --duration "129600" \
    --serial-number "${aws_arn}" \
    --token-code $(op get totp ${account} || exit 5) \
    --output text  | awk '{ print $2, $4, $5 }')

  # Set the aws profile session tokens
  aws --profile "${account}" configure set aws_access_key_id "$aws_access_key_id"
  aws --profile "${account}" configure set aws_secret_access_key "$aws_secret_access_key"
  aws --profile "${account}" configure set aws_session_token "$aws_session_token"

  # Set default account based on first CLI parameter
  if [[ "${DEFAULT_ACCOUNT}" = "${account}" ]]; then
    aws --profile "default" configure set aws_access_key_id "$aws_access_key_id"
    aws --profile "default" configure set aws_secret_access_key "$aws_secret_access_key"
    aws --profile "default" configure set aws_session_token "$aws_session_token"
  fi
done
