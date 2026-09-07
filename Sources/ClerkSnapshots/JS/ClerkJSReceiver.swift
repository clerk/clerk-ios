import Foundation

public struct ClerkJSResourceID: Hashable, Sendable, Codable, RawRepresentable {
  public var rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    rawValue = try container.decode(String.self)
  }
}

public enum ClerkJSReceiver: Hashable, Sendable, Encodable {
  case clerk
  case signIn
  case signUp
  case billing
  case user
  case session(id: ClerkJSResourceID)
  case userResource(UserCollection, id: ClerkJSResourceID)
  case organization(id: ClerkJSResourceID)
  case listed(ListedKind, id: ClerkJSResourceID)

  public enum UserCollection: String, Sendable, Encodable {
    case emailAddresses
    case phoneNumbers
    case passkeys
    case externalAccounts
    case web3Wallets
    case enterpriseAccounts
  }

  public enum ListedKind: String, Sendable, Encodable {
    case userOrganizationInvitation
    case organizationSuggestion
    case organizationInvitation
    case organizationMembership
    case organizationMembershipRequest
    case organizationDomain
    case organizationEnterpriseConnection
    case billingPaymentMethod
    case sessionWithActivities
  }

  public enum CodingKeys: String, CodingKey {
    case kind
    case id
    case collection
    case listedKind
    case scope
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .clerk:
      try container.encode("clerk", forKey: .kind)
    case .signIn:
      try container.encode("signIn", forKey: .kind)
    case .signUp:
      try container.encode("signUp", forKey: .kind)
    case .billing:
      try container.encode("billing", forKey: .kind)
    case .user:
      try container.encode("user", forKey: .kind)
    case .session(let id):
      try container.encode("session", forKey: .kind)
      try container.encode(id, forKey: .id)
      try container.encode("client", forKey: .scope)
    case .userResource(let collection, let id):
      try container.encode("userResource", forKey: .kind)
      try container.encode(collection, forKey: .collection)
      try container.encode(id, forKey: .id)
      try container.encode("user", forKey: .scope)
    case .organization(let id):
      try container.encode("organization", forKey: .kind)
      try container.encode(id, forKey: .id)
      try container.encode("organization", forKey: .scope)
    case .listed(let listedKind, let id):
      try container.encode("listed", forKey: .kind)
      try container.encode(listedKind, forKey: .listedKind)
      try container.encode(id, forKey: .id)
      try container.encode(listedKind.rawValue, forKey: .scope)
    }
  }
}
