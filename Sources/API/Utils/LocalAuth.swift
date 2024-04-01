//
//  LocalAuth.swift
//
//
//  Created by Mike Pitre on 3/25/24.
//

import Foundation
import SwiftUI
import LocalAuthentication
import KeychainAccess

extension Clerk {
    
    public struct LocalAuthConfig {
        
        public struct Credentials {
            let identifier: String
            let password: String
        }
        
        private let localAuthAccountKey = "localAuthAccountKey"
        
        public var accountForLocalAuth: String? {
            try? Keychain().get(localAuthAccountKey)
        }
        
        public func getLocalAuthCredentials() throws -> Credentials {
            guard let identifier = accountForLocalAuth else {
                throw ClerkClientError(message: "Unable to find biometry enrolled account.")
            }
            
            guard let password = try Keychain(server: Clerk.shared.environment.displayConfig.homeUrl, protocolType: .https).get(identifier) else {
                throw ClerkClientError(message: "Unable to find password for biometry enrolled account.")
            }
            
            return Credentials(identifier: identifier, password: password)
        }
        
        public func setLocalAuthCredentials(identifier: String, password: String) throws {
            try Keychain().set(identifier, key: localAuthAccountKey)
            try Keychain(server: Clerk.shared.environment.displayConfig.homeUrl, protocolType: .https)
                .accessibility(.whenPasscodeSetThisDeviceOnly, authenticationPolicy: .userPresence)
                .set(password, key: identifier)
        }
        
        private func accountForLocalAuthBelongsToUser(_ user: User) -> Bool {
            guard let accountForLocalAuth else { return false }
            let identifiers = user.emailAddresses.map(\.emailAddress) + user.phoneNumbers.map(\.phoneNumber)
            return identifiers.contains(accountForLocalAuth)
        }
        
        var localAuthAccountAlreadySignedIn: Bool {
            let signedInUsers = Clerk.shared.client.sessions.compactMap(\.user)
            if signedInUsers.contains(where: { accountForLocalAuthBelongsToUser($0) }) {
                return true
            }
            
            return false
        }
    }
    
}

final public class LocalAuth {
    
    /// An authentication context stored at class scope so it's available for use during UI updates.
    static var context = LAContext()
    
    public static var availableBiometryType: LABiometryType {
        let biometryContext = LAContext()
        biometryContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return biometryContext.biometryType
    }
    
    public static func authenticateWithFaceID() async throws {
        
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
            ""
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
