import ClerkSnapshots
import Foundation

public typealias RoleResource = ClerkSnapshots.Role

extension RoleResource {
  public init(
    id: String,
    key: String,
    name: String,
    description: String,
    permissions: [PermissionResource],
    createdAt: Date,
    updatedAt: Date
  ) {
    self.init(
      object: "role",
      id: id,
      key: key,
      name: name,
      description: description,
      permissions: permissions,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
