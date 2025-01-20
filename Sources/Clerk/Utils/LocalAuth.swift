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

extension Clerk {
        
    final public class LocalAuth {
        
        public struct Credentials {
            let identifier: String
            let password: String
        }
        
        /// An authentication context stored at class scope so it's available for use during UI updates.
        nonisolated(unsafe) public static var context = LAContext()
        
        static var availableBiometryType: LABiometryType {
            let biometryContext = LAContext()
            biometryContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            return biometryContext.biometryType
        }
        
        public static func authenticateWithBiometrics() async throws {
            
            // Get a fresh context for each login. If you use the same context on multiple attempts
            //  (by commenting out the next line), then a previously successful authentication
            //  causes the next policy evaluation to succeed without testing biometry again.
            //  That's usually not what you want.
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
