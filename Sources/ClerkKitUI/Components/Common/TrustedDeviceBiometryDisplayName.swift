//
//  TrustedDeviceBiometryDisplayName.swift
//  Clerk
//

#if os(iOS)

import LocalAuthentication

struct TrustedDeviceBiometryDisplayName: Equatable {
  let value: String
  let systemImageName: String?
  let isSupported: Bool

  init(
    biometryType: LABiometryType,
    isSupported: Bool? = nil
  ) {
    systemImageName = biometryType.systemImageName
    self.isSupported = isSupported ?? (biometryType != .none)

    switch biometryType {
    case .faceID:
      value = "Face ID"
    case .touchID:
      value = "Touch ID"
    case .opticID:
      value = "Optic ID"
    default:
      value = "biometrics"
    }
  }

  static func current() -> Self {
    let context = LAContext()
    var error: NSError?
    let isSupported = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    return .init(biometryType: context.biometryType, isSupported: isSupported)
  }
}

extension LABiometryType {
  fileprivate var systemImageName: String? {
    switch self {
    case .none:
      nil
    case .touchID:
      "touchid"
    case .faceID:
      "faceid"
    case .opticID:
      "opticid"
    @unknown default:
      nil
    }
  }
}

#endif
