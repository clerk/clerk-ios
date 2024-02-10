//
//  MockEnvironmentJSON.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation

let MockEnvironmentJSON = """

{
  "auth_config": {
    "object": "auth_config",
    "id": "aac_2VwxODsgEK6GqcXUqLY5ut1aLWb",
    "first_name": "on",
    "last_name": "on",
    "email_address": "on",
    "phone_number": "on",
    "username": "off",
    "password": "required",
    "identification_requirements": [
      [
        "email_address",
        "oauth_apple",
        "oauth_google",
        "phone_number"
      ],
      []
    ],
    "identification_strategies": [
      "email_address",
      "oauth_apple",
      "oauth_google",
      "phone_number"
    ],
    "first_factors": [
      "email_code",
      "oauth_apple",
      "oauth_google",
      "password",
      "phone_code",
      "reset_password_email_code",
      "reset_password_phone_code",
      "ticket"
    ],
    "second_factors": [
      "backup_code",
      "phone_code",
      "totp"
    ],
    "email_address_verification_strategies": [
      "email_code"
    ],
    "single_session_mode": false,
    "enhanced_email_deliverability": false,
    "test_mode": true,
    "cookieless_dev": true,
    "url_based_session_syncing": true,
    "demo": false
  },
  "display_config": {
    "object": "display_config",
    "id": "display_config_2VwxOFgcJA9i8JNoimHhPOE1iKD",
    "instance_environment_type": "development",
    "application_name": "Mike's Test App",
    "theme": {
      "buttons": {
        "font_color": "#ffffff",
        "font_family": "\"Source Sans Pro\", sans-serif",
        "font_weight": "600"
      },
      "general": {
        "color": "#6c47ff",
        "padding": "1em",
        "box_shadow": "0 2px 8px rgba(0, 0, 0, 0.2)",
        "font_color": "#151515",
        "font_family": "\"Source Sans Pro\", sans-serif",
        "border_radius": "0.5em",
        "background_color": "#ffffff",
        "label_font_weight": "600"
      },
      "accounts": {
        "background_color": "#ffffff"
      }
    },
    "preferred_sign_in_strategy": "password",
    "logo_image_url": "",
    "favicon_image_url": "",
    "home_url": "https://amusing-barnacle-26.accounts.dev/default-redirect",
    "sign_in_url": "https://amusing-barnacle-26.accounts.dev/sign-in",
    "sign_up_url": "https://amusing-barnacle-26.accounts.dev/sign-up",
    "user_profile_url": "https://amusing-barnacle-26.accounts.dev/user",
    "after_sign_in_url": "https://amusing-barnacle-26.accounts.dev/default-redirect",
    "after_sign_up_url": "https://amusing-barnacle-26.accounts.dev/default-redirect",
    "after_sign_out_one_url": "https://amusing-barnacle-26.accounts.dev/sign-in/choose",
    "after_sign_out_all_url": "https://amusing-barnacle-26.accounts.dev/sign-in",
    "after_switch_session_url": "https://amusing-barnacle-26.accounts.dev/default-redirect",
    "organization_profile_url": "https://amusing-barnacle-26.accounts.dev/organization",
    "create_organization_url": "https://amusing-barnacle-26.accounts.dev/create-organization",
    "after_leave_organization_url": "https://amusing-barnacle-26.accounts.dev/default-redirect",
    "after_create_organization_url": "https://amusing-barnacle-26.accounts.dev/default-redirect",
    "logo_link_url": "https://amusing-barnacle-26.accounts.dev/default-redirect",
    "support_email": null,
    "branded": true,
    "experimental_force_oauth_first": false,
    "clerk_js_version": "4",
    "captcha_public_key": null,
    "logo_url": null,
    "favicon_url": null,
    "logo_image": null,
    "favicon_image": null
  },
  "user_settings": {
    "attributes": {
      "email_address": {
        "enabled": true,
        "required": false,
        "used_for_first_factor": true,
        "first_factors": [
          "email_code"
        ],
        "used_for_second_factor": false,
        "second_factors": [],
        "verifications": [
          "email_code"
        ],
        "verify_at_sign_up": true
      },
      "phone_number": {
        "enabled": true,
        "required": false,
        "used_for_first_factor": true,
        "first_factors": [
          "phone_code"
        ],
        "used_for_second_factor": true,
        "second_factors": [
          "phone_code"
        ],
        "verifications": [
          "phone_code"
        ],
        "verify_at_sign_up": true
      },
      "username": {
        "enabled": false,
        "required": false,
        "used_for_first_factor": false,
        "first_factors": [],
        "used_for_second_factor": false,
        "second_factors": [],
        "verifications": [],
        "verify_at_sign_up": false
      },
      "web3_wallet": {
        "enabled": false,
        "required": false,
        "used_for_first_factor": false,
        "first_factors": [],
        "used_for_second_factor": false,
        "second_factors": [],
        "verifications": [],
        "verify_at_sign_up": false
      },
      "first_name": {
        "enabled": true,
        "required": false,
        "used_for_first_factor": false,
        "first_factors": [],
        "used_for_second_factor": false,
        "second_factors": [],
        "verifications": [],
        "verify_at_sign_up": false
      },
      "last_name": {
        "enabled": true,
        "required": false,
        "used_for_first_factor": false,
        "first_factors": [],
        "used_for_second_factor": false,
        "second_factors": [],
        "verifications": [],
        "verify_at_sign_up": false
      },
      "password": {
        "enabled": true,
        "required": true,
        "used_for_first_factor": false,
        "first_factors": [],
        "used_for_second_factor": false,
        "second_factors": [],
        "verifications": [],
        "verify_at_sign_up": false
      },
      "authenticator_app": {
        "enabled": true,
        "required": false,
        "used_for_first_factor": false,
        "first_factors": [],
        "used_for_second_factor": true,
        "second_factors": [
          "totp"
        ],
        "verifications": [
          "totp"
        ],
        "verify_at_sign_up": false
      },
      "ticket": {
        "enabled": true,
        "required": false,
        "used_for_first_factor": false,
        "first_factors": [],
        "used_for_second_factor": false,
        "second_factors": [],
        "verifications": [],
        "verify_at_sign_up": false
      },
      "backup_code": {
        "enabled": true,
        "required": false,
        "used_for_first_factor": false,
        "first_factors": [],
        "used_for_second_factor": true,
        "second_factors": [
          "backup_code"
        ],
        "verifications": [],
        "verify_at_sign_up": false
      }
    },
    "social": {
      "oauth_apple": {
        "enabled": true,
        "required": false,
        "authenticatable": true,
        "block_email_subaddresses": false,
        "strategy": "oauth_apple",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_atlassian": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_atlassian",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_bitbucket": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_bitbucket",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_box": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_box",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_coinbase": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_coinbase",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_discord": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_discord",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_dropbox": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_dropbox",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_facebook": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_facebook",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_github": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_github",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_gitlab": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_gitlab",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_google": {
        "enabled": true,
        "required": false,
        "authenticatable": true,
        "block_email_subaddresses": false,
        "strategy": "oauth_google",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_hubspot": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_hubspot",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_line": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_line",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_linear": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_linear",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_linkedin_oidc": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_linkedin_oidc",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_microsoft": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_microsoft",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_notion": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_notion",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_slack": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_slack",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_tiktok": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_tiktok",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_twitch": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_twitch",
        "not_selectable": false,
        "deprecated": false
      },
      "oauth_xero": {
        "enabled": false,
        "required": false,
        "authenticatable": false,
        "block_email_subaddresses": false,
        "strategy": "oauth_xero",
        "not_selectable": false,
        "deprecated": false
      }
    },
    "saml": {
      "enabled": false
    },
    "sign_in": {
      "second_factor": {
        "required": false
      }
    },
    "sign_up": {
      "captcha_enabled": false,
      "custom_action_required": false,
      "progressive": true
    },
    "restrictions": {
      "allowlist": {
        "enabled": false
      },
      "blocklist": {
        "enabled": false
      },
      "block_email_subaddresses": {
        "enabled": false
      },
      "block_disposable_email_domains": {
        "enabled": false
      }
    },
    "actions": {
      "delete_self": true,
      "create_organization": true
    },
    "attack_protection": {
      "user_lockout": {
        "enabled": true,
        "max_attempts": 100,
        "duration_in_minutes": 60
      },
      "pii": {
        "enabled": false
      }
    },
    "password_settings": {
      "disable_hibp": false,
      "min_length": 0,
      "max_length": 0,
      "require_special_char": false,
      "require_numbers": false,
      "require_uppercase": false,
      "require_lowercase": false,
      "show_zxcvbn": false,
      "min_zxcvbn_strength": 0,
      "allowed_special_characters": "!\"#$%&'()*+,-./:;<=>?@[]^_`{|}~"
    }
  },
  "organization_settings": {
    "enabled": true,
    "max_allowed_memberships": 3,
    "actions": {
      "admin_delete": true
    },
    "domains": {
      "enabled": false,
      "enrollment_modes": [],
      "default_role": ""
    },
    "creator_role": "org:admin"
  }
}

"""
