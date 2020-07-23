#!/bin/bash

# INPUT PARAMETERS
# TMP_AWS_ORIGIN_PROFILE (prompt iniailly, store in config)
# TMP_AWS_MFA_PROFILE (prompt-only)
# TMP_MFA_SERIAL_ARN (prompt initially, store in config)
# TMP_MFA_TOKEN_CODE (prompt-only)

# Dependencies: awscli, jq
test ! $(command -v jq) && echo "jq is required, please install and ensure the binary is in your \$PATH." && exit 1
test ! $(command -v aws) && echo "awscli is required, please install and ensure the binary is in your \$PATH." && exit 1

while [ -z "${TMP_AWS_MFA_PROFILE}" ]
do
echo "Please specify which aws profile you want to configure, or enter a new one [ this will be the profile that uses the temporary mfa credentials ]:"
aws configure list-profiles
read -p "MFA Profile: " TMP_AWS_MFA_PROFILE
done
# read the TMP_AWS_ORIGIN_PROFILE variable from the aws config
read TMP_AWS_ORIGIN_PROFILE < <(aws configure get profile.${TMP_AWS_MFA_PROFILE}.origin_profile)

# Prompt for Origin Profile if it did not exist in the origin_profile
while [ -z "${TMP_AWS_ORIGIN_PROFILE}" ]
do
echo "Please enter the origin profile [ This is the profile used to make the aws sts get-session-token call ]:"
read -p "Origin Profile: " TMP_AWS_ORIGIN_PROFILE
done
# set the TMP_AWS_ORIGIN_PROFILE as the origin_profile value in aws config
aws configure set profile.${TMP_AWS_MFA_PROFILE}.origin_profile ${TMP_AWS_ORIGIN_PROFILE}

# Take the mfa device from list-mfa-devices and place it into the configuration profile
#aws configure set profile.${TMP_AWS_MFA_PROFILE}.mfa_serial $(aws iam list-mfa-devices --user-name ${AWS_USER} --profile ${TMP_AWS_ORIGIN_PROFILE} | jq -r '.MFADevices[0].SerialNumber')

# Get the mfa_serial from the aws profile
read TMP_MFA_SERIAL_ARN < <(aws configure get profile.${TMP_AWS_MFA_PROFILE}.mfa_serial)

# Prompt for the TMP_MFA_SERIAL_ARN if not found in the mfa_serial
while [ -z "${TMP_MFA_SERIAL_ARN}" ]
do
echo "Please enter your MFA Serial ARN [ example: arn:aws:iam::1234567890:user/my.username ]:"
read -p "MFA Serial ARN: " TMP_MFA_SERIAL_ARN
done

# set the TMP_MFA_SERIAL_ARN as the mfa_serial value in aws config
aws configure set profile.${TMP_AWS_MFA_PROFILE}.mfa_serial ${TMP_MFA_SERIAL_ARN}

# Prompt for MFA Token
while [ -z "${TMP_MFA_TOKEN_CODE}" ]
do
echo "Please enter your MFA Token Code:"
read -p "MFA Token Code: " TMP_MFA_TOKEN_CODE
done

# Get the session token and store in temp variables
read TMP_ACCESS_KEY_ID TMP_SECRET_ACCESS_KEY TMP_SESSION_TOKEN TMP_EXPIRATION < \
    <(echo $(aws sts get-session-token --serial-number ${TMP_MFA_SERIAL_ARN} --token ${TMP_MFA_TOKEN_CODE} --profile ${TMP_AWS_ORIGIN_PROFILE} | \
    jq -r '.Credentials.AccessKeyId, .Credentials.SecretAccessKey, .Credentials.SessionToken, .Credentials.Expiration'))

aws configure set profile.${TMP_AWS_MFA_PROFILE}.aws_access_key_id ${TMP_ACCESS_KEY_ID}
aws configure set profile.${TMP_AWS_MFA_PROFILE}.aws_secret_access_key ${TMP_SECRET_ACCESS_KEY}
aws configure set profile.${TMP_AWS_MFA_PROFILE}.aws_session_token ${TMP_SESSION_TOKEN}
aws configure set profile.${TMP_AWS_MFA_PROFILE}.aws_session_expiration ${TMP_EXPIRATION}
