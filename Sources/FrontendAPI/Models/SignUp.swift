//
//  SignUp.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
/**
 The SignUp object holds the state of the current sign up and provides helper methods to navigate and complete the sign up flow. Once a sign up is complete, a new user is created.
 
 There are two important steps that need to be done in order for a sign up to be completed:
 
 Supply all the required fields. The required fields depend on your instance settings.
 Verify contact information. Some of the supplied fields need extra verification. These are the email address and phone number.
 The above steps can be split into smaller actions (e.g. you don't have to supply all the required fields at once) and can done in any order. This provides great flexibility and supports even the most complicated sign up flows.
 
 Also, the attributes of the SignUp object can basically be grouped into three categories:
 
 Those that contain information regarding the sign-up flow and what is missing in order for the sign-up to complete. For more information on these, check our detailed sign-up flow guide.
 Those that hold the different values that we supply to the sign-up. Examples of these are username, emailAddress, firstName, etc.
 Those that contain references to the created resources once the sign-up is complete, i.e. createdSessionId and createdUserId.
 */
public struct SignUp: Decodable {
    
    public init(
        id: String = "",
        status: String? = nil
    ) {
        self.id = id
        self.status = status
    }
    
    public var id: String = ""
    public var status: String?
}

extension SignUp {
    
    public struct CreateParams: Encodable {
        public init(
            password: String? = nil,
            emailAddress: String? = nil
        ) {
            self.password = password
            self.emailAddress = emailAddress
        }
        
        public var password: String?
        public var emailAddress: String?
    }
    
    public struct PrepareVerificationParams: Encodable {
        public init(strategy: VerificationStrategy) {
            self.strategy = strategy
        }
        
        public let strategy: VerificationStrategy
    }
    
    public struct AttemptVerificationParams: Encodable {
        public init(
            strategy: VerificationStrategy,
            code: String
        ) {
            self.strategy = strategy
            self.code = code
        }
        
        public let strategy: VerificationStrategy
        public let code: String
    }
    
}

extension SignUp {
    
    /**
     This method initiates a new sign-up flow. It creates a new SignUp object and de-activates any existing SignUp that the client might already had in progress.
     
     The form of the given params depends on the configuration of the instance. Choices on the instance settings affect which options are available to use.
     
     The create method will return a promise of the new SignUp object. This sign up might be complete if you supply the required fields in one go.
     However, this is not mandatory. Our sign-up process provides great flexibility and allows users to easily create multi-step sign-up flows.
     */
    @MainActor
    @discardableResult
    public func create(_ params: CreateParams) async throws -> SignUp {
        let request = APIEndpoint
            .v1
            .client
            .signUps
            .post(params)
        
        let signUp = try await Clerk.apiClient.send(request).value.response
        Clerk.shared.client.signUp = signUp
        return signUp
    }
    
    /**
     The prepareVerification is used to initiate the verification process for a field that requires it. As mentioned above, there are two fields that need to be verified:
     
     emailAddress: The email address can be verified via an email code. This is a one-time code that is sent to the email already provided to the SignUp object. The prepareVerification sends this email.
     phoneNumber: The phone number can be verified via a phone code. This is a one-time code that is sent via an SMS to the phone already provided to the SignUp object. The prepareVerification sends this SMS.
     */
    @MainActor
    @discardableResult
    public func prepareVerification(_ params: PrepareVerificationParams) async throws -> SignUp {
        let request = APIEndpoint
            .v1
            .client
            .signUps
            .prepareVerification(id: Clerk.shared.client.signUp.id)
            .post(params)
        
        let signUp = try await Clerk.apiClient.send(request).value.response
        Clerk.shared.client.signUp = signUp
        return signUp
    }
    
    /**
     Attempts to complete the in-flight verification process that corresponds to the given strategy. In order to use this method, you should first initiate a verification process by calling SignUp.prepareVerification.
     
     Depending on the strategy, the method parameters could differ.
     */
    @MainActor
    @discardableResult
    public func attemptVerification(_ params: AttemptVerificationParams) async throws -> SignUp {
        let request = APIEndpoint
            .v1
            .client
            .signUps
            .attemptVerification(id: Clerk.shared.client.signUp.id)
            .post(params)
        
        let signUp = try await Clerk.apiClient.send(request).value.response
        Clerk.shared.client.signUp = signUp
        return signUp
    }
}
