//
//  UUID+V5.swift
//

import CryptoKit
import Foundation

extension UUID {
  /// Creates a deterministic name-based version 5 UUID (RFC 4122, SHA-1).
  ///
  /// The UUID is derived from the SHA-1 digest of the namespace UUID's bytes followed by the
  /// UTF-8 bytes of the name, with the version bits set to `5` and the variant bits set to
  /// RFC 4122. The same namespace and name always produce the same UUID.
  ///
  /// - Parameters:
  ///   - namespace: The namespace UUID that scopes the name.
  ///   - name: The name to derive the UUID from.
  init(v5Namespace namespace: UUID, name: String) {
    var input = Data(capacity: 16 + name.utf8.count)
    withUnsafeBytes(of: namespace.uuid) { input.append(contentsOf: $0) }
    input.append(contentsOf: name.utf8)

    let digest = Insecure.SHA1.hash(data: input)
    var bytes = Array(digest.prefix(16))

    // Set the version to 5 (name-based, SHA-1).
    bytes[6] = (bytes[6] & 0x0F) | 0x50
    // Set the variant to RFC 4122.
    bytes[8] = (bytes[8] & 0x3F) | 0x80

    self.init(uuid: (
      bytes[0], bytes[1], bytes[2], bytes[3],
      bytes[4], bytes[5], bytes[6], bytes[7],
      bytes[8], bytes[9], bytes[10], bytes[11],
      bytes[12], bytes[13], bytes[14], bytes[15]
    ))
  }
}
