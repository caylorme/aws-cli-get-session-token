#!/bin/bash

# INPUT PARAMETERS
# origin_profile (prompt iniailly, store in config)
# mfa_profile (prompt-only)
# mfa_serial (prompt initially, store in config)
# mfa_token_code (prompt-only)

# Dependencies: awscli, jq
test ! $(command -v jq) && echo "jq is required, please install and ensure the binary is in your \$PATH." && exit 1
test ! $(command -v aws) && echo "awscli is required, please install and ensure the binary is in your \$PATH." && exit 1

# Prompt for the mfa_profile
while [ -z "${TMP_AWS_MFA_PROFILE}" ]
do
echo "Please specify which aws profile you want to configure, or enter a new one [ this will be the profile that uses the temporary mfa credentials ]:"
aws configure list-profiles
read -p "MFA Profile: " TMP_AWS_MFA_PROFILE
done

# read the origin_profile value from the mfa_profile config
read TMP_AWS_ORIGIN_PROFILE < <(aws configure get profile.${TMP_AWS_MFA_PROFILE}.origin_profile)

# prompt for origin_profile if it did not exist within the mfa_profile
while [ -z "${TMP_AWS_ORIGIN_PROFILE}" ]
do
echo "Please enter the origin profile [ This is the profile used to make the aws sts get-session-token call ]:"
read -p "Origin Profile: " TMP_AWS_ORIGIN_PROFILE
done

# store the origin_profile value in the mfa_profile config
aws configure set profile.${TMP_AWS_MFA_PROFILE}.origin_profile ${TMP_AWS_ORIGIN_PROFILE}

# read the mfa_serial from the mfa_profile config
read TMP_MFA_SERIAL_ARN < <(aws configure get profile.${TMP_AWS_MFA_PROFILE}.mfa_serial)

# prompt for the mfa_serial if it did not exist within the mfa_profile
while [ -z "${TMP_MFA_SERIAL_ARN}" ]
do
echo "Please enter your MFA Serial ARN [ example: arn:aws:iam::1234567890:user/my.username ]:"
read -p "MFA Serial ARN: " TMP_MFA_SERIAL_ARN
done

# store the mfa_serial value in the mfa_profile config
aws configure set profile.${TMP_AWS_MFA_PROFILE}.mfa_serial ${TMP_MFA_SERIAL_ARN}

# prompt for the mfa_token_code
while [ -z "${TMP_MFA_TOKEN_CODE}" ]
do
echo "Please enter your MFA Token Code:"
read -p "MFA Token Code: " TMP_MFA_TOKEN_CODE
done

# run get-session-token using the mfa_serial and mfa_token_code using the origin_profile and capture the temporary credentials
read TMP_ACCESS_KEY_ID TMP_SECRET_ACCESS_KEY TMP_SESSION_TOKEN TMP_EXPIRATION < \
    <(echo $(aws sts get-session-token --serial-number ${TMP_MFA_SERIAL_ARN} --token ${TMP_MFA_TOKEN_CODE} --profile ${TMP_AWS_ORIGIN_PROFILE} | \
    jq -r '.Credentials.AccessKeyId, .Credentials.SecretAccessKey, .Credentials.SessionToken, .Credentials.Expiration'))

# set the temporary credentials for the mfa_profile
aws configure set profile.${TMP_AWS_MFA_PROFILE}.aws_access_key_id ${TMP_ACCESS_KEY_ID}
aws configure set profile.${TMP_AWS_MFA_PROFILE}.aws_secret_access_key ${TMP_SECRET_ACCESS_KEY}
aws configure set profile.${TMP_AWS_MFA_PROFILE}.aws_session_token ${TMP_SESSION_TOKEN}
aws configure set profile.${TMP_AWS_MFA_PROFILE}.aws_session_expiration ${TMP_EXPIRATION}
