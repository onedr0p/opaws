# opaws

CLI tool to sign into AWS (MFA) accounts using 1Password

## Usage

After following the guide below you can finally use opaws

```bash
# Copy script to /usr/local/bin
cp opaws.sh /usr/local/bin/opaws
# Run opaws and then provide your 1Password Password at the prompt
opaws <1Password AWS account title> <domain>.1password.com <aws email address>
```

## Setup Guide

### 1. Install CLI Tools

- Install [1Password CLI](https://app-updates.agilebits.com/product_history/CLI)
- Install [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
- Install [jq](https://stedolan.github.io/jq/download/)

### 2. Set up Global Environment Variables

Place the follow code in your `~/.bashrc` file then source it or restart your terminal

```bash
# 1Password Domain
export OP_DOMAIN="<domain>.1password.com"
# 1Password Titles for AWS accounts
export OP_AWS_ACCOUNTS=("AWS-Development" "AWS-Production" "AWS-Explorer")
# Your AWS Email address
export AWS_EMAIL=""
```

### 3. Sign into 1Password on the CLI

```bash
# Sign into 1Password on the CLI and provide 1Password Secret Key
op signin ${OP_DOMAIN} ${AWS_EMAIL}
```

### 4. 1Password & AWS Account Configuration

Make sure each of your AWS entries in 1Password follow this structure

![1Password AWS Account Example](/1password-aws-account-config.png "1Password")
