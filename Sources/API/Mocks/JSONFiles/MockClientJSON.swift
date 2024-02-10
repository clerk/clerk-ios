//
//  MockClientJSON.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation

let MockClientJSON = """

{
  "response": {
    "object": "client",
    "id": "client_2cAHwcHy6VsRKn50xsrtVwC6kAW",
    "sessions": [
      {
        "object": "session",
        "id": "sess_2cAHx9rDQUYIxjIMHNIEnorvr7Y",
        "status": "active",
        "expire_at": 1708152506837,
        "abandon_at": 1710139706837,
        "last_active_at": 1707548893364,
        "last_active_organization_id": null,
        "actor": null,
        "user": {
          "id": "user_2XdLRC6pJCyrFQsmlJoAOuYnLx4",
          "object": "user",
          "username": null,
          "first_name": "Mike",
          "last_name": "Pitre",
          "image_url": "https://img.clerk.com/eyJ0eXBlIjoicHJveHkiLCJzcmMiOiJodHRwczovL2ltYWdlcy5jbGVyay5kZXYvdXBsb2FkZWQvaW1nXzJZc05CMGswdmdCUjl2WExCQXVLVVlneXJGayJ9",
          "has_image": true,
          "primary_email_address_id": "idn_2XdLMn0w9V32f6Vg0h4RlAjgltC",
          "primary_phone_number_id": "idn_2bBRe6VNHSregsfJqsRsX5IUkPS",
          "primary_web3_wallet_id": null,
          "password_enabled": true,
          "two_factor_enabled": false,
          "totp_enabled": false,
          "backup_code_enabled": false,
          "email_addresses": [
            {
              "id": "idn_2XdLMn0w9V32f6Vg0h4RlAjgltC",
              "object": "email_address",
              "email_address": "mike@clerk.dev",
              "reserved": false,
              "verification": {
                "status": "verified",
                "strategy": "email_code",
                "attempts": 1,
                "expire_at": 1698954565139
              },
              "linked_to": [
                {
                  "type": "oauth_google",
                  "id": "idn_2XxbZBez2DQk8c4UHd85OBWH9oh"
                }
              ]
            }
          ],
          "phone_numbers": [
            {
              "id": "idn_2cADrifaeMOFAn4IT6qBurGeyUN",
              "object": "phone_number",
              "phone_number": "+12015551234",
              "reserved_for_second_factor": false,
              "default_second_factor": false,
              "reserved": false,
              "verification": {
                "status": "expired",
                "strategy": "phone_code",
                "attempts": 0,
                "expire_at": 1707546290184
              },
              "linked_to": [],
              "backup_codes": null
            },
            {
              "id": "idn_2bBRe6VNHSregsfJqsRsX5IUkPS",
              "object": "phone_number",
              "phone_number": "+19083707882",
              "reserved_for_second_factor": false,
              "default_second_factor": false,
              "reserved": false,
              "verification": {
                "status": "verified",
                "strategy": "phone_code",
                "attempts": 1,
                "expire_at": 1705687178634
              },
              "linked_to": [],
              "backup_codes": null
            }
          ],
          "web3_wallets": [],
          "external_accounts": [
            {
              "object": "external_account",
              "id": "eac_2bRdsuWwMxOjqDd84SaGQrg4Ht7",
              "provider": "oauth_apple",
              "identification_id": "idn_2bRdsqyvgGDbYw7tW2Tc61kclQv",
              "provider_user_id": "",
              "approved_scopes": "",
              "email_address": "",
              "first_name": "",
              "last_name": "",
              "avatar_url": "",
              "username": null,
              "public_metadata": {},
              "label": null,
              "verification": {
                "status": "expired",
                "strategy": "oauth_apple",
                "attempts": null,
                "expire_at": 1706182634229,
                "error": {
                  "code": "oauth_identification_claimed",
                  "message": "Identification claimed by another user",
                  "long_message": "The email address associated with this OAuth account is already claimed by another user."
                }
              }
            },
            {
              "object": "external_account",
              "id": "eac_2XxbZDHKToSmvrurxD7HH7XTzkc",
              "provider": "oauth_google",
              "identification_id": "idn_2XxbZBez2DQk8c4UHd85OBWH9oh",
              "provider_user_id": "110616044525675616994",
              "approved_scopes": "email https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile openid profile",
              "email_address": "mike@clerk.dev",
              "first_name": "Mike",
              "last_name": "Pitre",
              "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocL8uz7WN1OGVaD0dZh2euYVOyF9mzu48SXPbT33PhFT0Q=s1000-c",
              "image_url": "https://img.clerk.com/eyJ0eXBlIjoicHJveHkiLCJzcmMiOiJodHRwczovL2xoMy5nb29nbGV1c2VyY29udGVudC5jb20vYS9BQ2c4b2NMOHV6N1dOMU9HVmFEMGRaaDJldVlWT3lGOW16dTQ4U1hQYlQzM1BoRlQwUT1zMTAwMC1jIiwicyI6IjJYUWZQVlBWVWZBUW92MzlMaU0wcGFPVEVUNytOaVNCOTlRTDJYVTJNOUUifQ",
              "username": null,
              "public_metadata": {},
              "label": null,
              "verification": {
                "status": "verified",
                "strategy": "oauth_google",
                "attempts": null,
                "expire_at": 1699574330054
              }
            }
          ],
          "saml_accounts": [],
          "public_metadata": {},
          "unsafe_metadata": {},
          "external_id": null,
          "last_sign_in_at": 1707552326900,
          "banned": false,
          "locked": false,
          "lockout_expires_in_seconds": null,
          "verification_attempts_remaining": 100,
          "created_at": 1698953999439,
          "updated_at": 1707552376938,
          "delete_self_enabled": true,
          "create_organization_enabled": true,
          "last_active_at": 1707523200000,
          "profile_image_url": "https://images.clerk.dev/uploaded/img_2YsNB0k0vgBR9vXLBAuKUYgyrFk",
          "organization_memberships": []
        },
        "public_user_data": {
          "first_name": "Mike",
          "last_name": "Pitre",
          "image_url": "https://img.clerk.com/eyJ0eXBlIjoicHJveHkiLCJzcmMiOiJodHRwczovL2ltYWdlcy5jbGVyay5kZXYvdXBsb2FkZWQvaW1nXzJZc05CMGswdmdCUjl2WExCQXVLVVlneXJGayJ9",
          "has_image": true,
          "identifier": "mike@clerk.dev",
          "profile_image_url": "https://images.clerk.dev/uploaded/img_2YsNB0k0vgBR9vXLBAuKUYgyrFk"
        },
        "created_at": 1707547706837,
        "updated_at": 1707548893364,
        "last_active_token": {
          "object": "token",
          "jwt": "eyJhbGciOiJSUzI1NiIsImNhdCI6ImNsX0I3ZDRQRDExMUFBQSIsImtpZCI6Imluc18yVnd4T0djcEoySWJISVFyWXloams5Y0p2OUYiLCJ0eXAiOiJKV1QifQ.eyJleHAiOjE3MDc1NTI1MDEsImlhdCI6MTcwNzU1MjQ0MSwiaXNzIjoiaHR0cHM6Ly9hbXVzaW5nLWJhcm5hY2xlLTI2LmNsZXJrLmFjY291bnRzLmRldiIsIm5iZiI6MTcwNzU1MjQzMSwic2lkIjoic2Vzc18yY0FIeDlyRFFVWUl4aklNSE5JRW5vcnZyN1kiLCJzdWIiOiJ1c2VyXzJYZExSQzZwSkN5ckZRc21sSm9BT3VZbkx4NCJ9.vZ-EBgQ2rHFTb92s21OO-oNXohDjNywGFgRI6AEIw94G9Dr0eQnsno3bUxpQpnkGVELc59ImpJnAU-KkRIAneIX_zJ0R-4GtMgC337jeuLd1YFFwSObjwnKhX-oxC5w7_1HMjE3RGJdcneYcUAgf9gvs_mgupYpl2niotm8TZ0Gqyp4AtTaej6Jkjydo_T4vXkDsaoDqke-jdBy5fZkeaTvaTv6As0hI49nzESBrGBucfgSxSsehMJ-NAkTQZL78o1MJ3xB7XUtUM9Jmt4Q5lsLiqXYiZ_uDjjKWOnrNI9zfj5nhOQ3JVXsdC_ssmOO4SCEB1dR5WGxCQEv_dwapjA"
        }
      }
    ],
    "sign_in": null,
    "sign_up": null,
    "last_active_session_id": "sess_2cAHx9rDQUYIxjIMHNIEnorvr7Y",
    "created_at": 1707547702428,
    "updated_at": 1707548905763
  },
  "client": null
}

"""
