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
public struct EmailAddress: Decodable, Identifiable {
    
    public init(
        id: String,
        emailAddress: String,
        reserved: Bool = false,
        verification: Verification? = nil,
        linkedTo: [JSON]? = nil
    ) {
        self.id = id
        self.emailAddress = emailAddress
        self.reserved = reserved
        self.verification = verification
        self.linkedTo = linkedTo
    }
    
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

extension EmailAddress: Equatable, Hashable {}

extension EmailAddress {
    
    public var isPrimary: Bool {
        Clerk.shared.client.lastActiveSession?.user.primaryEmailAddressId == id
    }
    
}

extension EmailAddress {
    
    public struct CreateParams: Encodable {
        public init(emailAddress: String) {
            self.emailAddress = emailAddress
        }
        
        public let emailAddress: String
    }
    
    public struct PrepareParams: Encodable {
        public init(strategy: Strategy) {
            self.strategy = strategy.stringValue
        }
        
        public let strategy: String
    }
    
    public struct AttemptParams: Encodable {
        public init(code: String) {
            self.code = code
        }
        
        public let code: String
    }
    
}

extension EmailAddress {
    
    public enum PrepareStrategy {
        case emailCode
        case emailLink
    }
    
    private func prepareParams(for strategy: PrepareStrategy) -> PrepareParams {
        switch strategy {
        case .emailCode:
            return .init(strategy: .emailCode)
        case .emailLink:
            return .init(strategy: .emailLink)
        }
    }
    
    public enum AttemptStrategy {
        case emailCode(code: String)
    }
    
    private func attemptParams(for strategy: AttemptStrategy) -> AttemptParams {
        switch strategy {
        case .emailCode(let code):
            return .init(code: code)
        }
    }
    
}

extension EmailAddress {
    
    @MainActor
    public func prepareVerification(strategy: PrepareStrategy) async throws {
        let params = prepareParams(for: strategy)
        let request = APIEndpoint
            .v1
            .me
            .emailAddresses
            .id(id)
            .prepareVerification
            .post(params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
    @MainActor
    public func attemptVerification(strategy: AttemptStrategy) async throws {
        let params = attemptParams(for: strategy)
        let request = APIEndpoint
            .v1
            .me
            .emailAddresses
            .id(id)
            .attemptVerification
            .post(params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
    @MainActor
    public func delete() async throws {
        let request = APIEndpoint
            .v1
            .me
            .emailAddresses
            .id(id)
            .delete
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
    @MainActor
    public func setAsPrimary() async throws {
        let request = APIEndpoint
            .v1
            .me
            .update(.init(primaryEmailAddressId: id))
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
}
