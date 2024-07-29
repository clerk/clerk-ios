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
import SimpleKeychain

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
        
        private static let localAuthAccountKey = "localAuthAccountKey"
        
        @MainActor
        static var displayLocalAuthOption: Bool {
            accountForLocalAuth != nil && !localAuthAccountAlreadySignedIn
        }
        
        static var accountForLocalAuth: String? {
            try? SimpleKeychain().string(forKey: localAuthAccountKey)
        }
        
        static func clearLocalAuthAccount() {
            try? SimpleKeychain().deleteItem(forKey: localAuthAccountKey)
        }
        
        public static func getLocalAuthCredentials() throws -> Credentials {
            guard let identifier = accountForLocalAuth else {
                throw ClerkClientError(message: "Unable to find an account with biometric authentication enabled.")
            }
            
            guard let password = try? SimpleKeychain().string(forKey: identifier) else {
                throw ClerkClientError(message: "Unable to find credentials for the account enrolled in biometric authentication.")
            }
            
            return Credentials(identifier: identifier, password: password)
        }
        
        public static func setLocalAuthCredentials(identifier: String, password: String) throws {
            try SimpleKeychain().set(identifier, forKey: localAuthAccountKey)
            let context = LAContext()
            context.touchIDAuthenticationAllowableReuseDuration = 10
            try SimpleKeychain(accessibility: .whenPasscodeSetThisDeviceOnly, accessControlFlags: .biometryCurrentSet, context: context)
                .set(password, forKey: identifier)
        }
        
        static func accountForLocalAuthBelongsToUser(_ user: User) -> Bool {
            guard let accountForLocalAuth else { return false }
            var identifiers = user.emailAddresses.map(\.emailAddress) + user.phoneNumbers.map(\.phoneNumber)
            if let username = user.username { identifiers.append(username) }
            return identifiers.contains(accountForLocalAuth)
        }
        
        @MainActor
        static var localAuthAccountAlreadySignedIn: Bool {
            guard let client = Clerk.shared.client else { return false }
            let signedInUsers = client.activeSessions.compactMap(\.user)
            if signedInUsers.contains(where: { accountForLocalAuthBelongsToUser($0) }) {
                return true
            }
            
            return false
        }
        
        static func deleteCurrentAccountForLocalAuth() {
            try? SimpleKeychain().deleteItem(forKey: localAuthAccountKey)
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
