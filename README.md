# opaws

CLI tool to sign into AWS accounts using 1Password

## Usage

```sh
Usage: opaws.sh <options>
    -h, --help               Display help
    -a, --aws-account        AWS Account as specified by title in 1Password (required)
    -d, --domain             1Password domain to use (required)
    -e, --email              1Password email address to use (required)
    -v, --vault              1Password vault to use (default: Personal)
    --debug                  Enable debug mode
```

## Setup Guide

Make sure each of your AWS entries in 1Password follow this structure

![1Password AWS Account Example](/1password-aws-account-config.png "1Password")
