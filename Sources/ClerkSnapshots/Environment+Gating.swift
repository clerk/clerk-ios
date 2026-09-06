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
}
