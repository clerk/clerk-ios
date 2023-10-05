//
//  SignIn.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/**
 The SignIn object holds all the state of the current sign in and provides helper methods to navigate and complete the sign in process.

 There are two important steps in the sign in flow.

 Users must complete a first factor verification. This can be something like providing a password, an email magic link, a one-time code (OTP), a web3 wallet public address or providing proof of their identity through an external social account (SSO/OAuth).
 After that, users might need to go through a second verification process. This is the second factor (2FA).
 The SignIn object's properties can be split into logical groups, with each group providing information on different aspects of the sign in flow. These groups can be:

 Information about the current sign in status in general and which authentication identifiers, authentication methods and verifications are supported.
 Information about the user and the provided authentication identifier value (email address, phone number or username). Information about each verification, either the first factor (logging in) or the second factor (2FA).
 */
public struct SignIn: Decodable {
    
    init(status: String = "") {
        self.status = status
    }
    
    private(set) public var status: String = ""
}

extension SignIn {
    
    public struct CreateParams: Encodable {
        public init(
            identifier: String,
            password: String? = nil
        ) {
            self.identifier = identifier
            self.password = password
        }
        
        public let identifier: String
        public let password: String?
    }
    
}

extension SignIn {
    
    /**
     Use this method to kick-off the sign in flow. It creates a SignIn object and stores the sign in lifecycle state.

     Depending on the use-case and the params you pass to the create method, it can either complete the sign in process in one go, or simply collect part of the necessary data for completing authentication at a later stage.
     */
    @MainActor
    public func create(_ params: CreateParams) async throws {
        let request = APIEndpoint
            .v1
            .client
            .signIns
            .post(params)
        
        let signIn = try await Clerk.apiClient.send(request).value.response
        Clerk.shared.client.signIn = signIn
    }
    
}
