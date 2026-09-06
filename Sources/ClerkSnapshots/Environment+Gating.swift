extension Environment {
  public var multiSessionModeIsEnabled: Bool {
    authConfig.singleSessionMode == false
  }

  public var passwordIsEnabled: Bool {
    userSettings.attributes.password.enabled
  }

  public var passkeyIsEnabled: Bool {
    userSettings.attributes.passkey.enabled
  }

  public var passkeyFirstFactorIsEnabled: Bool {
    let passkey = userSettings.attributes.passkey
    return passkey.enabled && passkey.usedForFirstFactor
  }

  public var mfaIsEnabled: Bool {
    mfaAuthenticatorAppIsEnabled || mfaPhoneCodeIsEnabled || mfaBackupCodeIsEnabled
  }

  public var mfaAuthenticatorAppIsEnabled: Bool {
    let authenticatorApp = userSettings.attributes.authenticatorApp
    return authenticatorApp.enabled && authenticatorApp.usedForSecondFactor
  }

  public var mfaPhoneCodeIsEnabled: Bool {
    let phoneNumber = userSettings.attributes.phoneNumber
    return phoneNumber.enabled && phoneNumber.usedForSecondFactor
  }

  public var mfaBackupCodeIsEnabled: Bool {
    let backupCode = userSettings.attributes.backupCode
    return backupCode.enabled && backupCode.usedForSecondFactor
  }

  public var deleteSelfIsEnabled: Bool {
    userSettings.actions.deleteSelf
  }

  public var emailIsEnabled: Bool {
    userSettings.attributes.emailAddress.enabled
  }

  public var phoneNumberIsEnabled: Bool {
    userSettings.attributes.phoneNumber.enabled
  }

  public var usernameIsEnabled: Bool {
    userSettings.attributes.username.enabled
  }

  public var firstNameIsEnabled: Bool {
    userSettings.attributes.firstName.enabled
  }

  public var lastNameIsEnabled: Bool {
    userSettings.attributes.lastName.enabled
  }

  public var emailIsImmutable: Bool {
    userSettings.attributes.emailAddress.immutable == true
  }

  public var phoneNumberIsImmutable: Bool {
    userSettings.attributes.phoneNumber.immutable == true
  }

  public var usernameIsImmutable: Bool {
    userSettings.attributes.username.immutable == true
  }

  public var enabledFirstFactorAttributes: [String] {
    userSettings.attributes.namedFields.compactMap { key, attribute in
      guard attribute.enabled, attribute.usedForFirstFactor else {
        return nil
      }
      return key.rawValue
    }
  }

  public var authenticatableSocialProviders: [OAuthProviderSettings] {
    userSettings.social.namedSettings.filter { $0.enabled && $0.authenticatable }
  }

  public var allSocialProviders: [OAuthProviderSettings] {
    userSettings.social.namedSettings.filter(\.enabled)
  }
}

extension Attributes {
  fileprivate var namedFields: [(key: CodingKeys, attribute: AttributeData)] {
    [
      (.emailAddress, emailAddress),
      (.phoneNumber, phoneNumber),
      (.web3Wallet, web3Wallet),
      (.passkey, passkey),
      (.username, username),
      (.password, password),
      (.backupCode, backupCode),
      (.firstName, firstName),
      (.lastName, lastName),
      (.authenticatorApp, authenticatorApp),
    ]
  }
}

extension OAuthProviders {
  fileprivate var namedSettings: [OAuthProviderSettings] {
    [
      oauthFacebook,
      oauthGoogle,
      oauthHubspot,
      oauthGithub,
      oauthTiktok,
      oauthGitlab,
      oauthDiscord,
      oauthTwitter,
      oauthTwitch,
      oauthLinkedin,
      oauthLinkedinOidc,
      oauthDropbox,
      oauthAtlassian,
      oauthBitbucket,
      oauthMicrosoft,
      oauthNotion,
      oauthApple,
      oauthLine,
      oauthInstagram,
      oauthCoinbase,
      oauthSpotify,
      oauthXero,
      oauthBox,
      oauthSlack,
      oauthLinear,
      oauthX,
      oauthEnstall,
      oauthHuggingface,
      oauthVercel,
    ]
  }
}
