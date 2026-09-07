import ClerkSnapshots
import Foundation

public typealias PermissionResource = ClerkSnapshots.Permission

extension PermissionResource {
  public init(
    id: String,
    key: String,
    name: String,
    type: String,
    description: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.init(
      object: "permission",
      id: id,
      key: key,
      name: name,
      description: description,
      type: PermissionType(rawValue: type),
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

extension PermissionType {
  public var rawValue: String {
    switch self {
    case .user:
      "user"
    case .system:
      "system"
    case .unknown(let value):
      value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "user":
      self = .user
    case "system":
      self = .system
    default:
      self = .unknown(rawValue)
    }
  }
}
