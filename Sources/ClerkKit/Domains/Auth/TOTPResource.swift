import ClerkSnapshots
import Foundation

public typealias TOTPResource = ClerkSnapshots.TOTP

extension TOTPResource: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

extension TOTPResource {
  public init(
    id: String,
    secret: String? = nil,
    uri: String? = nil,
    verified: Bool,
    backupCodes: [String]? = nil,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.init(
      object: "totp",
      id: id,
      secret: secret,
      uri: uri,
      verified: verified,
      backupCodes: backupCodes,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
