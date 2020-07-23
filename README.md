# aws-cli-get-session-token
A simple bash script to help with automating aws sts get-session-token and profile creation

This script depends on awscli (v1 or v2) and jq (developed with 1.6)

# Configuration

The script will prompt and store values for fields that should be retained. However, you can have these values set before running the script for the first time by running a few simple commands using the aws cli tool, or modifying the `~./aws/config` file manually.

use the following commands (optional), replacing **MY_MFA_PROFILE**, ***MY_ORIGIN_PROFILE**, and **MY_MFA_SERIAL** with their respective values.

```
aws configure set profile.MY_MFA_PROFILE.origin_profile MY_ORIGIN_PROFILE
aws configure set profile.MY_MFA_PROFILE.mfa_serial MY_MFA_SERIAL
```

- MFA Profile

The script will prompt for the MFA profile name (The script will create a new profile or use an existing profile)
This profile will be stored in your `~/.aws/config` and `~/.aws/credentials` with their respective information

- Origin Profile

The script will prompt for the Origin profile name if it is undefined. This is the profile that will be used to make the `aws sts get-session-token` command.

The script will store this as the `origin_profile` for the **MFA Profile**

- MFA SERIAL

The script will prompt for the MFA Serial if it is undefined. This value will be stored as the `mfa_serial` for the **MFA Profile**

The value can be either a serial number for a hardware device (such as GAHT12345678) or an Amazon Resource Name (ARN) for a virtual MFA device (such as arn:aws:iam::123456789012:mfa/user).

# Running the script (aws_mfa.sh)

The script will prompt for all configuration items as needed and described above. The script will make an attempt at storing the mfa serial and origin profile for the mfa profile.

You will always be prompted to give your MFA Token Code which will be found on your configured MFA device for the origin profile.

The script will then run an `aws sts get-session-token` with the MFA Serial and MFA Token Codes as parameters, using the Origin Profile.

The output of this command is piped into `jq` for extraction of the `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token`, and `aws_session_expiration` values.

These values are then stored within your MFA Profile using `aws configure`

## Debug Data

#### Get Current User

```
# aws sts get-caller-identity
# {
#     "UserId": "AAAAAAAAAAAAAAAAAA",
#     "Account": "1234567890",
#     "Arn": "arn:aws:iam::1234567890:user/my.username"
# }
```

#### Get MFA Device serial

```
# aws iam list-mfa-devices --user-name my.username
# {
#     "MFADevices": [
#         {
#             "UserName": "my.username",
#             "SerialNumber": "arn:aws:iam::1234567890:mfa/my.username",
#             "EnableDate": "2020-01-01T05:05:05+00:00"
#         }
#     ]
# }
```

#### Get Session Token

```
# aws sts get-session-token --serial-number OUTPUT_FROM_GET_MFA_DEVICE_SERIAL --token CURRENT_MFA_TOKEN
# {
#     "Credentials": {
#         "AccessKeyId": "XXXXXXXXXXXXXXXXXXX",
#         "SecretAccessKey": "YYYYYYYYYYYYYYYYYYYYYYY",
#         "SessionToken": "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ",
#         "Expiration": "2020-01-01T05:05:05+00:00"
#     }
# }
```

