import ClerkSnapshots
import Foundation

extension Passkey {
  /// Updates the name of the associated passkey for the signed-in user.
  @discardableResult @MainActor
  public func update(name: String) async throws -> Passkey {
    try await Clerk.js(
      .userResource(.passkeys, id: ClerkJSResourceID(id)),
      PasskeyJSCall.update(PasskeyUpdateParams(name: name)),
      as: Passkey.self
    )
  }

  /// Deletes the associated passkey for the signed-in user.
  @discardableResult @MainActor
  public func delete() async throws -> DeletedObject {
    try await Clerk.js(
      .userResource(.passkeys, id: ClerkJSResourceID(id)),
      PasskeyJSCall.delete,
      as: DeletedObject.self
    )
  }
}
