//
//  MockUserJSON.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation

let MockUserJSON = """

{
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
  "two_factor_enabled": true,
  "totp_enabled": false,
  "backup_code_enabled": true,
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
      "id": "idn_2bSxhtMnzNTXcx3t5rGnBafAhCD",
      "object": "phone_number",
      "phone_number": "+12015551234",
      "reserved_for_second_factor": false,
      "default_second_factor": false,
      "reserved": false,
      "verification": {
        "status": "expired",
        "strategy": "phone_code",
        "attempts": 0,
        "expire_at": 1706556415377
      },
      "linked_to": [],
      "backup_codes": null
    },
    {
      "id": "idn_2bBRe6VNHSregsfJqsRsX5IUkPS",
      "object": "phone_number",
      "phone_number": "+19083707882",
      "reserved_for_second_factor": true,
      "default_second_factor": true,
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
  "last_sign_in_at": 1706582129615,
  "banned": false,
  "locked": false,
  "lockout_expires_in_seconds": null,
  "verification_attempts_remaining": 100,
  "created_at": 1698953999439,
  "updated_at": 1706630287167,
  "delete_self_enabled": true,
  "create_organization_enabled": true,
  "last_active_at": 1706659200000,
  "profile_image_url": "https://images.clerk.dev/uploaded/img_2YsNB0k0vgBR9vXLBAuKUYgyrFk",
  "organization_memberships": []
}

"""
