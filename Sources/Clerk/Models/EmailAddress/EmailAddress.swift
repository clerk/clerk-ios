//
//  EmailAddress.swift
//
//
//  Created by Mike Pitre on 10/20/23.
//

import Foundation

/// The `EmailAddress` object is a model around an email address.
///
/// Email addresses are used to provide identification for users.
///
/// Email addresses must be verified to ensure that they can be assigned to their rightful owners.
/// The `EmailAddress` object holds all necessary state around the verification process.
///
/// The verification process always starts with the ``EmailAddress/prepareVerification(strategy:)`` method,
/// which will send a one-time verification code via an email message.
///
/// The second and final step involves an attempt to complete the verification by calling the ``EmailAddress/attemptVerification(strategy:)`` method,
/// passing the one-time code as a parameter.
public struct EmailAddress: Codable, Equatable, Hashable, Identifiable, Sendable {
    
    /// The unique identifier for this email address.
    public let id: String
    
    /// The value of this email address.
    public let emailAddress: String
    
    /// An object holding information on the verification of this email address.
    public let verification: Verification?
    
    /// An array of objects containing information about any identifications
    /// that might be linked to this email address.
    public let linkedTo: [JSON]?
    
}

extension EmailAddress {
    
    /// Prepares the verification process for this email address.
    ///
    /// An email message with a one-time code or an email link will be sent to the email address box.
    ///
    /// - Parameters:
    ///   - strategy: The verification strategy to use. See ``EmailAddress/PrepareStrategy`` for available strategies.
    /// - Returns: ``EmailAddress``
    /// - Throws: An error if the verification preparation fails.
    ///
    /// Example usage:
    /// ```swift
    /// let emailAddress = try await emailAddress.prepareVerification(strategy: .emailCode)
    /// ```
    @discardableResult @MainActor
    public func prepareVerification(strategy: PrepareStrategy) async throws -> EmailAddress {
        let request = ClerkFAPI.v1.me.emailAddresses.id(id).prepareVerification.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: strategy.requestBody
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Attempts to verify this email address, passing the one-time code that was sent as an email message.
    /// The code will be sent when calling the ``EmailAddress/prepareVerification(strategy:)`` method.
    ///
    /// - Parameters:
    ///   - strategy: The verification strategy to use. See ``EmailAddress/AttemptStrategy`` for available strategies.
    /// - Returns: ``EmailAddress``
    /// - Throws: An error if the verification attempt fails.
    ///
    /// Example usage:
    /// ```swift
    /// let emailAddress = try await emailAddress.attemptVerification(strategy: .emailCode(code: "123456"))
    /// ```
    @discardableResult @MainActor
    public func attemptVerification(strategy: AttemptStrategy) async throws -> EmailAddress {
        let request = ClerkFAPI.v1.me.emailAddresses.id(id).attemptVerification.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: strategy.requestBody
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    
    /// Deletes this email address.
    @discardableResult @MainActor
    public func destroy() async throws -> DeletedObject {
        let request = ClerkFAPI.v1.me.emailAddresses.id(id).delete(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
}
