#!/usr/bin/env bash

#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

show_help() {
cat << EOF
Usage: $(basename "$0") <options>
    -h, --help               Display help
    -a, --aws-account        AWS Account as specified by title in 1Password (required)
    -d, --domain             1Password domain to use (required)
    -e, --email              1Password email address to use (required)
    -v, --vault              1Password vault to use (default: Personal)
    --debug                  Enable debug mode
EOF
}

main() {
    local domain=
    local email=
    local vault=
    local aws_account=
    local debug=

    parse_command_line "$@"

    check "op"
    check "jq"
    check "aws"

    local session=
    login
    declare "OP_SESSION_${domain}=${session}"
    credentials
    verify
}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            -d|--domain)
                if [[ -n "${2:-}" ]]; then
                    domain="$2"
                    shift
                else
                    echo "ERROR: '-d|--domain' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -e|--email)
                if [[ -n "${2:-}" ]]; then
                    email="$2"
                    shift
                else
                    echo "ERROR: '-e|--email' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -v|--vault)
                if [[ -n "${2:-}" ]]; then
                    vault="$2"
                    shift
                else
                    echo "ERROR: '-v|--vault' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -a|--aws-account)
                if [[ -n "${2:-}" ]]; then
                    aws_account="$2"
                    shift
                else
                    echo "ERROR: '-a|--aws-account' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            --debug)
                debug=1
                ;;
            *)
                break
                ;;
        esac

        shift
    done

    if [[ -z "$domain" ]]; then
        echo "ERROR: '-d|--domain' is required." >&2
        show_help
        exit 1
    fi

    if [[ -z "$email" ]]; then
        echo "ERROR: '-e|--email' is required." >&2
        show_help
        exit 1
    fi

    if [[ -z "$vault" ]]; then
        vault="Personal"
    fi

    if [[ -z "$aws_account" ]]; then
        echo "ERROR: '-a|--aws-account' is required." >&2
        show_help
        exit 1
    fi

    if [[ -z "$debug" ]]; then
        debug=0
    fi
}

check() {
    command -v "${1}" >/dev/null 2>&1 || {
        echo >&2 "ERROR: ${1} is not installed or not found in \$PATH" >&2
        exit 1
    }
}

login() {
    if [ -v "${session}" ]; then
        echo "OP_SESSION_${domain} variable exists"
        if ! op get user "${email}" --session "${!session}" >/dev/null 2>&1; then
            echo "OP_SESSION_${domain} token invalid"
            session=$(op signin "${domain}" --raw)
        else
            echo "OP_SESSION_${domain} token valid"
            session="${!session}"
        fi
    else
        echo "OP_SESSION_${domain} variable does not exist"
        session=$(op signin "${domain}" --raw)
    fi
}

credentials() {
    op_item_json="$(op --session "${session}" get item "${aws_account}")"

    # Extract AWS account information from 1Password
    account_email=$(op --session "${session}" get item ${aws_account} | jq -r '.overview.ainfo')
    [[ ${debug} -gt 0 ]] && echo "DEBUG - Account Email: ${account_email}"
    account_url=$(op --session "${session}" get item ${aws_account} | jq -r '.overview.url')
    [[ ${debug} -gt 0 ]] && echo "DEBUG - Account URL: ${account_url}"
    account_id=$(echo $account_url | awk -F[/:] '{print $4}' | awk -F[.] '{print $1}')
    [[ ${debug} -gt 0 ]] && echo "DEBUG - Account ID: ${account_id}"
    account_access_key=$(echo ${op_item_json} | jq -r '.details.sections[] | select(.title=="Keys") .fields[] | select(.t=="access") | .v')
    [[ ${debug} -gt 0 ]] && echo "DEBUG - Account Access Key: ${account_access_key}"
    account_secret_key=$(echo ${op_item_json} | jq -r '.details.sections[] | select(.title=="Keys") .fields[] | select(.t=="secret") | .v')
    [[ ${debug} -gt 0 ]] && echo "DEBUG - Account Secret Key: ${account_secret_key}"

    # Set the aws profiles keys
    aws --profile "${aws_account}-default" configure set aws_access_key_id "${account_access_key}"
    aws --profile "${aws_account}-default" configure set aws_secret_access_key "${account_secret_key}"

    # Set the full arn url
    aws_arn="arn:aws:iam::${account_id}:mfa/${account_email}"
    [[ ${debug} -gt 0 ]] && echo "DEBUG - AWS ARN: ${aws_arn}"

    # Get the MFA code
    token=$(op --session "${session}" get totp ${aws_account} >/dev/null 2>&1)

    # No token? Use standard credentials
    if [[ -z $token ]]; then
        aws --profile "default" configure set aws_access_key_id "${account_access_key}"
        aws --profile "default" configure set aws_secret_access_key "${account_secret_key}"
    else
        [[ ${debug} -gt 0 ]] && echo "DEBUG - MFA Token: ${token}"

        # Sign in and get the AWS Credential information
        creds=$(aws \
            --profile "${aws_account}-default" sts get-session-token \
            --duration "86400" \
            --serial-number "${aws_arn}" \
            --token-code "${token}" \
            --output json
        )

        # Set the AWS account information
        aws_access_key_id=$(echo ${creds} | jq -r '.Credentials.AccessKeyId')
        [[ ${debug} -gt 0 ]] && echo "DEBUG - Temporary access key id: ${aws_access_key_id}"
        aws_secret_access_key=$(echo ${creds} | jq -r '.Credentials.SecretAccessKey')
        [[ ${debug} -gt 0 ]] && echo "DEBUG - Temporary secret access key: ${aws_secret_access_key}"
        aws_session_token=$(echo ${creds} | jq -r '.Credentials.SessionToken')
        [[ ${debug} -gt 0 ]] && echo "DEBUG - Temporary session token: ${aws_session_token}"

        # Set the aws profile session tokens
        aws --profile "default" configure set aws_access_key_id "${aws_access_key_id}"
        aws --profile "default" configure set aws_secret_access_key "${aws_secret_access_key}"
        aws --profile "default" configure set aws_session_token "${aws_session_token}"
    fi
}

verify() {
    if aws sts get-caller-identity >/dev/null 2>&1; then
      echo "SUCCESS - AWS CLI is ready to roll"
    else
      echo "ERROR - Unable to log in use --debug to view logs"
    fi
}

main "$@"
