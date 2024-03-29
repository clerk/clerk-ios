//
//  LocalAuth.swift
//
//
//  Created by Mike Pitre on 3/25/24.
//

import Foundation
import SwiftUI
import LocalAuthentication

extension Clerk {
    
    public struct LocalAuthConfig {
        @AppStorage("accountIdForLocalAuth") public var enabledAccount: String = ""
        
        public var localAuthCredentialsIsEnabled: Bool {
            !enabledAccount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
}

final public class LocalAuth {
    
    /// An authentication context stored at class scope so it's available for use during UI updates.
    static var context = LAContext()
    
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
            throw ClerkClientError(message: "Can't evaluate policy")
        }
        
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authenticate")
        } catch {
            throw error
        }
    }
    
}
