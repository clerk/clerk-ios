//
//  DeviceKey.swift
//  Clerk
//

import Foundation

enum DeviceKeySecurityLevel: Equatable {
  case secureEnclave
  case software

  /// The `clerk_sl` value FAPI records. FAPI accepts only `strongbox`, `tee`, and `software`, and records
  /// any other value as `software`, so a Secure Enclave key reports `tee`, the hardware level it accepts.
  var wireName: String {
    switch self {
    case .secureEnclave:
      "tee"
    case .software:
      "software"
    }
  }
}

protocol DeviceKey: Sendable {
  var publicJwk: Es256PublicJwk { get }
  var securityLevel: DeviceKeySecurityLevel { get }

  /// Returns the ES256 signature of `data` as JWS encodes it: `r` then `s`, 32 bytes each (RFC 7518 §3.4).
  func sign(_ data: Data) throws -> Data
}

extension DeviceKey {
  var thumbprint: String {
    publicJwk.thumbprint
  }
}

protocol DeviceKeyStore: Sendable {
  func loadOrCreate() throws -> any DeviceKey

  func hasStoredKey() throws -> Bool

  func delete() throws
}

enum DeviceKeyState {
  case ready(any DeviceKey)
  case unavailable(any Error)

  var isUnavailable: Bool {
    if case .unavailable = self { true } else { false }
  }
}

enum DeviceKeyError: Error, Equatable {
  case keychain(OSStatus)
  case security(String)
}
