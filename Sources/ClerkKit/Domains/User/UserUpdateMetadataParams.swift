//
//  UserUpdateMetadataParams.swift
//  Clerk
//

extension User {
  /// Parameters for ``User/updateMetadata(_:)``.
  ///
  /// The submitted value is deep-merged into the existing `unsafeMetadata`:
  /// keys in the patch overwrite or extend the current value, and any key
  /// whose value is ``JSON/null`` is removed at any nesting level. Omit
  /// (`nil`) to make no change.
  public struct UpdateMetadataParams: Encodable, Sendable {
    public init(unsafeMetadata: JSON? = nil) {
      self.unsafeMetadata = unsafeMetadata
    }

    /// A JSON object containing the unsafe metadata patch.
    public var unsafeMetadata: JSON?
  }
}
