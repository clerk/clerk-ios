import ClerkKit

/// Values displayed by the existing factor screens, projected from generated contracts.
struct Factor: Hashable {
  let strategy: FactorStrategy
  var emailAddressId: String?
  var phoneNumberId: String?
  var safeIdentifier: String?

  @MainActor init(_ factor: SignInFirstFactor) {
    strategy = .init(rawValue: factor.strategy)
    switch factor {
    case .case1(let value): emailAddressId = value.emailAddressId; safeIdentifier = value.safeIdentifier
    case .case2(let value): emailAddressId = value.emailAddressId; safeIdentifier = value.safeIdentifier
    case .case3(let value): phoneNumberId = value.phoneNumberId; safeIdentifier = value.safeIdentifier
    case .case9(let value): phoneNumberId = value.phoneNumberId; safeIdentifier = value.safeIdentifier
    case .case10(let value): emailAddressId = value.emailAddressId; safeIdentifier = value.safeIdentifier
    default: break
    }
  }

  @MainActor init(_ factor: SignInSecondFactor) {
    strategy = .init(rawValue: factor.strategy)
    switch factor {
    case .case1(let value): emailAddressId = value.emailAddressId; safeIdentifier = value.safeIdentifier
    case .case2(let value): emailAddressId = value.emailAddressId; safeIdentifier = value.safeIdentifier
    case .case3(let value): phoneNumberId = value.phoneNumberId; safeIdentifier = value.safeIdentifier
    default: break
    }
  }

  init(strategy: FactorStrategy, emailAddressId: String? = nil, phoneNumberId: String? = nil, safeIdentifier: String? = nil) {
    self.strategy = strategy; self.emailAddressId = emailAddressId
    self.phoneNumberId = phoneNumberId; self.safeIdentifier = safeIdentifier
  }
}

extension Factor {
  static var mockEmailLink: Factor {
    Factor(
      strategy: .emailLink,
      emailAddressId: "ema_123",
      safeIdentifier: "test@example.com"
    )
  }

  static var mockEmailCode: Factor {
    Factor(
      strategy: .emailCode,
      emailAddressId: "ema_123",
      safeIdentifier: "test@example.com"
    )
  }

  static var mockPhoneCode: Factor {
    Factor(strategy: .phoneCode)
  }

  static var mockGoogle: Factor {
    Factor(strategy: .oauth(.google))
  }

  static var mockApple: Factor {
    Factor(strategy: .oauth(.apple))
  }

  static var mockPassword: Factor {
    Factor(strategy: .password)
  }

  static var mockPasskey: Factor {
    Factor(strategy: .passkey)
  }

  static var mockResetPasswordEmailCode: Factor {
    Factor(strategy: .resetPasswordEmailCode)
  }

  static var mockResetPasswordPhoneCode: Factor {
    Factor(strategy: .resetPasswordPhoneCode)
  }

  static var mockTotp: Factor {
    Factor(strategy: .totp)
  }

  static var mockBackupCode: Factor {
    Factor(strategy: .backupCode)
  }
}
