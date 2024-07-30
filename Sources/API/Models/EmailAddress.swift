//
//  EmailAddress.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

import Foundation

/**
 The EmailAddress object is a model around an email address. Email addresses are used to provide identification for users.

 Email addresses must be verified to ensure that they can be assigned to their rightful owners. The EmailAddress object holds all necessary state around the verification process.

 The verification process always starts with the EmailAddress.prepareVerification() method, which will send a one-time verification code via an email message. The second and final step involves an attempt to complete the verification by calling the EmailAddress.attemptVerification() method, passing the one-time code as a parameter.

 Finally, email addresses can be linked to other identifications.
 */
public struct EmailAddress: Codable, Equatable, Hashable, Identifiable, Sendable {

    /// A unique identifier for this email address.
    public let id: String
    
    /// The value of this email address.
    public let emailAddress: String
    
    ///
    let reserved: Bool
    
    /// An object holding information on the verification of this email address.
    public let verification: Verification?
    
    /// An array of objects containing information about any identifications that might be linked to this email address.
    let linkedTo: [JSON]?
}

extension EmailAddress {
    
    func isPrimary(for user: User) -> Bool {
        user.primaryEmailAddressId == id
    }
    
}

extension EmailAddress {
    
    /// Kick off the verification process for this email address. An email message with a one-time code or a magic-link will be sent to the email address box.
    @discardableResult @MainActor
    public func prepareVerification(strategy: PrepareStrategy) async throws -> EmailAddress {
        let request = ClerkAPI.v1.me.emailAddresses.id(id).prepareVerification.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: strategy.requestBody
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    public enum PrepareStrategy {
        
        /// User will receive a one-time authentication code via email.
        case emailCode
        
        internal var requestBody: RequestBody {
            switch self {
            case .emailCode:
                return .init(strategy: .emailCode)
            }
        }
        
        internal struct RequestBody: Encodable {
            public init(strategy: Strategy) {
                self.strategy = strategy.stringValue
            }
            
            public let strategy: String
        }
    }
    
    /// Attempts to verify this email address, passing the one-time code that was sent as an email message. The code will be sent when calling the EmailAddress.prepareVerification() method.
    @discardableResult @MainActor
    public func attemptVerification(strategy: AttemptStrategy) async throws -> EmailAddress {
        let request = ClerkAPI.v1.me.emailAddresses.id(id).attemptVerification.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: strategy.requestBody
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    public enum AttemptStrategy {
        /// The one-time code that was sent to the user's email address when EmailAddress.prepareVerification() was called with `strategy` set to `email_code`.
        case emailCode(code: String)
        
        internal var requestBody: RequestBody {
            switch self {
            case .emailCode(let code):
                return .init(code: code)
            }
        }
        
        struct RequestBody: Encodable {
            public let code: String
        }
        
    }
    
    /// Deletes this email address.
    @discardableResult @MainActor
    public func destroy() async throws -> Deletion {
        let request = ClerkAPI.v1.me.emailAddresses.id(id).delete(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    @discardableResult @MainActor
    func setAsPrimary() async throws -> User {
        let request = ClerkAPI.v1.me.update(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["primary_email_address_id": id]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
}
