# opaws

CLI tool to sign into AWS (MFA) accounts using 1Password

## Usage

After following the guide below you can finally use opaws

```bash
# First signin to Password CLI if you haven't already
op signin <domain>.1password.com <op-email-address>
# Copy script to /usr/local/bin
ln -s opaws.sh /usr/local/bin/opaws
# Run opaws and then provide your 1Password Password at the prompt
opaws <domain>.1password.com <1password-aws-accounttitle>
```

## Setup Guide

Make sure each of your AWS entries in 1Password follow this structure

![1Password AWS Account Example](/1password-aws-account-config.png "1Password")
