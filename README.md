# opaws

## Usage

- Install and configure 1Password
- Install [1Password CLI](https://app-updates.agilebits.com/product_history/CLI)
- Install [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)

### Set up Global Environment Variables

Place the follow code in your `~/.bashrc` file then source it or restart your terminal

```bash
# 1Password Domain
export OP_DOMAIN="<domain>.1password.com"
# 1Password Titles for AWS accounts
export OP_AWS_ACCOUNTS=("AWS-Development" "AWS-Production" "AWS-Explorer")
# Your AWS Email address
export AWS_EMAIL=""
```

### Sign into 1Password on the CLI

```bash
# Sign into 1Password on the CLI and provide 1Password Secret Key
op signin ${OP_DOMAIN} ${AWS_EMAIL}
```

### opaws Setup and usage

```bash
# Copy script to /usr/local/bin
cp opaws.sh /usr/local/bin/opaws
# Run opaws and then provide your 1Password Password
opaws AWS-Development
```
