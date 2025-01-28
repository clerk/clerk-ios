//
//  LocalAuth.swift
//
//
//  Created by Mike Pitre on 3/25/24.
//

#if !os(tvOS) && !os(watchOS)

import Foundation
import SwiftUI
import LocalAuthentication

        
/// A utility class for handling local authentication mechanisms, including biometrics and device owner authentication.
@MainActor
final public class LocalAuthHelper {
    
    /// A structure representing user credentials with an identifier and password.
    public struct Credentials {
        /// The unique identifier for the credentials, typically a username or email.
        let identifier: String
        
        /// The associated password for the credentials.
        let password: String
    }
    
    /// A shared authentication context used for UI updates during authentication.
    ///
    /// - Note: The context is refreshed before each authentication attempt to avoid unintended reuse of previously successful authentication results.
    public static var context = LAContext()
    
    /// The type of biometry available on the device.
    ///
    /// This property uses a temporary `LAContext` instance to determine the available biometry type.
    /// - Returns: An `LABiometryType` indicating the available biometric capability, such as `.faceID`, `.touchID`, or `.none`.
    static var availableBiometryType: LABiometryType {
        let biometryContext = LAContext()
        biometryContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return biometryContext.biometryType
    }
    
    /// Attempts to authenticate the user using biometric or device owner authentication.
    public static func authenticateWithBiometrics() async throws {
        
        // Get a fresh context for each login. If you use the same context on multiple attempts
        // (by commenting out the next line), then a previously successful authentication
        // causes the next policy evaluation to succeed without testing biometry again.
        // That's usually not what you want.
        context = LAContext()
        
        context.localizedCancelTitle = "Cancel"
        
        // First check if we have the needed hardware support.
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw ClerkClientError(message: "Unable to evaluate policy.")
        }
        
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authenticate")
        } catch {
            throw error
        }
    }
}
    

extension LABiometryType {
    
    var displayName: String {
        switch self {
        case .none:
            "None"
        case .touchID:
            "Touch ID"
        case .faceID:
            "Face ID"
        case .opticID:
            "Optic ID"
        @unknown default:
            "Biometrics"
        }
    }
    
    var systemImageName: String? {
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
