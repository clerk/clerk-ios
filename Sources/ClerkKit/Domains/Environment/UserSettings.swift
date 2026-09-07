import ClerkSnapshots
import Foundation

extension Clerk.Environment {
  public typealias UserSettings = ClerkSnapshots.UserSettings
}

extension ClerkSnapshots.Attributes {
  public var keys: [String] {
    [
      "email_address",
      "phone_number",
      "web3_wallet",
      "passkey",
      "username",
      "password",
      "backup_code",
      "first_name",
      "last_name",
      "authenticator_app",
    ]
  }

  public subscript(key: String) -> AttributeData? {
    get {
      switch key {
      case "email_address": emailAddress
      case "phone_number": phoneNumber
      case "web3_wallet": web3Wallet
      case "passkey": passkey
      case "username": username
      case "password": password
      case "backup_code": backupCode
      case "first_name": firstName
      case "last_name": lastName
      case "authenticator_app": authenticatorApp
      default: nil
      }
    }
    set {
      guard let newValue else { return }
      switch key {
      case "email_address": emailAddress = newValue
      case "phone_number": phoneNumber = newValue
      case "web3_wallet": web3Wallet = newValue
      case "passkey": passkey = newValue
      case "username": username = newValue
      case "password": password = newValue
      case "backup_code": backupCode = newValue
      case "first_name": firstName = newValue
      case "last_name": lastName = newValue
      case "authenticator_app": authenticatorApp = newValue
      default: break
      }
    }
  }
}

extension ClerkSnapshots.OAuthProviders {
  public subscript(strategy: String) -> OAuthProviderSettings? {
    get {
      namedSettings.first { $0.strategy == strategy }
    }
    set {
      guard let newValue else { return }
      switch strategy {
      case "oauth_facebook": oauthFacebook = newValue
      case "oauth_google": oauthGoogle = newValue
      case "oauth_hubspot": oauthHubspot = newValue
      case "oauth_github": oauthGithub = newValue
      case "oauth_tiktok": oauthTiktok = newValue
      case "oauth_gitlab": oauthGitlab = newValue
      case "oauth_discord": oauthDiscord = newValue
      case "oauth_twitter": oauthTwitter = newValue
      case "oauth_twitch": oauthTwitch = newValue
      case "oauth_linkedin": oauthLinkedin = newValue
      case "oauth_linkedin_oidc": oauthLinkedinOidc = newValue
      case "oauth_dropbox": oauthDropbox = newValue
      case "oauth_atlassian": oauthAtlassian = newValue
      case "oauth_bitbucket": oauthBitbucket = newValue
      case "oauth_microsoft": oauthMicrosoft = newValue
      case "oauth_notion": oauthNotion = newValue
      case "oauth_apple": oauthApple = newValue
      case "oauth_line": oauthLine = newValue
      case "oauth_instagram": oauthInstagram = newValue
      case "oauth_coinbase": oauthCoinbase = newValue
      case "oauth_spotify": oauthSpotify = newValue
      case "oauth_xero": oauthXero = newValue
      case "oauth_box": oauthBox = newValue
      case "oauth_slack": oauthSlack = newValue
      case "oauth_linear": oauthLinear = newValue
      case "oauth_x": oauthX = newValue
      case "oauth_enstall": oauthEnstall = newValue
      case "oauth_huggingface": oauthHuggingface = newValue
      case "oauth_vercel": oauthVercel = newValue
      default:
        break
      }
    }
  }
}

extension ClerkSnapshots.AttributeData {
  public init(
    enabled: Bool,
    required: Bool,
    immutable: Bool? = nil,
    usedForFirstFactor: Bool,
    firstFactors _: [String]?,
    usedForSecondFactor: Bool,
    secondFactors _: [String]?,
    verifications _: [String]?,
    verifyAtSignUp: Bool
  ) {
    self.init(
      enabled: enabled,
      required: required,
      immutable: immutable,
      verifications: [],
      usedForFirstFactor: usedForFirstFactor,
      firstFactors: [],
      usedForSecondFactor: usedForSecondFactor,
      secondFactors: [],
      verifyAtSignUp: verifyAtSignUp
    )
  }
}
