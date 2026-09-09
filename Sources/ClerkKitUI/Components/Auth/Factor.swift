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
