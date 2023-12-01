//
//  APIEndpoint.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import Get
import URLQueryEncoder
    
enum APIEndpoint {}

extension APIEndpoint {
    static var v1: V1Endpoint {
        V1Endpoint(path: "/v1")
    }
    
    struct V1Endpoint {
        /// Path: `/v1`
        public let path: String
    }
}

extension APIEndpoint.V1Endpoint {
    
    var client: ClientEndpoint {
        ClientEndpoint(path: path + "/client")
    }
    
    struct ClientEndpoint {
        /// Path: `/v1/client`
        let path: String
        
        var get: Request<ClientResponse<Client?>> {
            .init(path: path)
        }
        
        var put: Request<ClientResponse<Client>> {
            .init(path: path, method: .put)
        }
        
        var delete: Request<ClientResponse<Client>> {
            .init(path: path, method: .delete)
        }
    }
}

extension APIEndpoint.V1Endpoint {
    
    var environment: EnvironmentEndpoint {
        EnvironmentEndpoint(path: path + "/environment")
    }
    
    struct EnvironmentEndpoint {
        /// Path: `v1/environment`
        let path: String
        
        var get: Request<Clerk.Environment> {
            .init(path: path)
        }
    }
    
}

extension APIEndpoint.V1Endpoint.ClientEndpoint {
    
    var signUps: SignUpsEndpoint {
        SignUpsEndpoint(path: path + "/sign_ups")
    }
    
    struct SignUpsEndpoint {
        /// Path: `v1/client/sign_ups`
        let path: String
        
        var get: Request<ClientResponse<SignUp>> {
            .init(path: path)
        }
        
        func post(_ params: SignUp.CreateParams) -> Request<ClientResponse<SignUp>> {
            .init(path: path, method: .post, body: params)
        }
    }
}

extension APIEndpoint.V1Endpoint.ClientEndpoint.SignUpsEndpoint {
    public func id(_ id: String) -> WithID {
        WithID(path: path + "/\(id)")
    }

    public struct WithID {
        /// Path: `/v1/client/sign_ups/{id}`
        public let path: String
        
        func get(params: SignUp.GetParams?) -> Request<ClientResponse<SignUp>> {
            let encoder = URLQueryEncoder()
            encoder.encode(params?.rotatingTokenNonce, forKey: "rotating_token_nonce")
            return .init(path: path, query: encoder.items)
        }
    }
}

extension APIEndpoint.V1Endpoint.ClientEndpoint.SignUpsEndpoint.WithID {
    
    var prepareVerification: PrepareVerificationEndpoint {
        PrepareVerificationEndpoint(path: path + "/prepare_verification")
    }
    
    struct PrepareVerificationEndpoint {
        /// Path: `v1/client/sign_ups/{id}/prepare_verification`
        let path: String
        
        func post(_ params: SignUp.PrepareVerificationParams) -> Request<ClientResponse<SignUp>> {
            .init(path: path, method: .post, body: params)
        }
    }
}

extension APIEndpoint.V1Endpoint.ClientEndpoint.SignUpsEndpoint.WithID {
    
    var attemptVerification: AttemptVerificationEndpoint {
        AttemptVerificationEndpoint(path: path + "/attempt_verification")
    }
    
    struct AttemptVerificationEndpoint {
        /// Path: `v1/client/sign_ups/{id}/attempt_verification`
        let path: String
        
        func post(_ params: SignUp.AttemptVerificationParams) -> Request<ClientResponse<SignUp>> {
            .init(path: path, method: .post, body: params)
        }
    }
}

extension APIEndpoint.V1Endpoint.ClientEndpoint {
    
    var signIns: SignInsEndpoint {
        SignInsEndpoint(path: path + "/sign_ins")
    }
    
    struct SignInsEndpoint {
        /// Path: `v1/client/sign_ins`
        let path: String
        
        func post(_ params: SignIn.CreateParams) -> Request<ClientResponse<SignIn>> {
            .init(path: path, method: .post, body: params)
        }
    }
    
}

extension APIEndpoint.V1Endpoint.ClientEndpoint.SignInsEndpoint {
    
    public func id(_ id: String) -> WithIDEndpoint {
        WithIDEndpoint(path: path + "/\(id)")
    }

    public struct WithIDEndpoint {
        /// Path: `/v1/client/sign_ins/{id}`
        public let path: String
        
        func get(params: SignIn.GetParams?) -> Request<ClientResponse<SignIn>> {
            let encoder = URLQueryEncoder()
            encoder.encode(params?.rotatingTokenNonce, forKey: "rotating_token_nonce")
            return .init(path: path, query: encoder.items)
        }
    }
    
}

extension APIEndpoint.V1Endpoint.ClientEndpoint.SignInsEndpoint.WithIDEndpoint {
    
    var prepareFirstFactor: PrepareFirstFactorEndpoint {
        PrepareFirstFactorEndpoint(path: path + "/prepare_first_factor")
    }
    
    struct PrepareFirstFactorEndpoint {
        /// Path: `v1/client/sign_ins/{id}/prepare_first_factor`
        let path: String
        
        func post(_ params: SignIn.PrepareFirstFactorParams) -> Request<ClientResponse<SignIn>> {
            .init(path: path, method: .post, body: params)
        }
    }
    
}

extension APIEndpoint.V1Endpoint.ClientEndpoint.SignInsEndpoint.WithIDEndpoint {
    
    var attemptFirstFactor: AttemptFirstFactorEndpoint {
        AttemptFirstFactorEndpoint(path: path + "/attempt_first_factor")
    }
    
    struct AttemptFirstFactorEndpoint {
        /// Path: `v1/client/sign_ins/{id}/attempt_first_factor`
        let path: String
        
        func post(_ params: SignIn.AttemptFirstFactorParams) -> Request<ClientResponse<SignIn>> {
            .init(path: path, method: .post, body: params)
        }
    }
    
}

extension APIEndpoint.V1Endpoint.ClientEndpoint {
    
    var sessions: SessionsEndpoint {
        SessionsEndpoint(path: path + "/sessions")
    }
    
    struct SessionsEndpoint {
        /// Path: `v1/client/sessions`
        let path: String
    }
    
}

extension APIEndpoint.V1Endpoint.ClientEndpoint.SessionsEndpoint {
    
    func id(_ id: String) -> WithIdEndpoint {
        WithIdEndpoint(path: path + "/\(id)")
    }
    
    struct WithIdEndpoint {
        /// Path: `v1/client/sessions/{id}`
        let path: String
    }
    
}

extension APIEndpoint.V1Endpoint.ClientEndpoint.SessionsEndpoint.WithIdEndpoint {
    
    var touch: TouchEndpoint {
        TouchEndpoint(path: path + "/touch")
    }
    
    struct TouchEndpoint {
        /// Path: `v1/client/sessions/{id}/touch`
        let path: String
        
        func post(_ params: Clerk.SetActiveParams) -> Request<ClientResponse<Session>> {
            .init(path: path, method: .post, body: params.organizationId)
        }
    }
    
}

extension APIEndpoint.V1Endpoint.ClientEndpoint.SessionsEndpoint.WithIdEndpoint {
    
    var remove: RemoveEndpoint {
        RemoveEndpoint(path: path + "/remove")
    }
    
    struct RemoveEndpoint {
        /// Path: `v1/client/sessions/{id}/remove`
        let path: String
        
        var post: Request<ClientResponse<Session>> {
            .init(path: path, method: .post)
        }
    }
    
}


extension APIEndpoint.V1Endpoint {
    
    var me: MeEndpoint {
        MeEndpoint(path: path + "/me")
    }
    
    struct MeEndpoint {
        /// Path: `v1/me`
        let path: String
        
        func get() -> Request<ClientResponse<User>> {
            .init(path: path)
        }
        
        func update(_ params: User.UpdateParams) -> Request<ClientResponse<User>> {
            .init(path: path, method: .patch, body: params)
        }
    }
    
}

extension APIEndpoint.V1Endpoint.MeEndpoint {
    
    var emailAddresses: EmailAddressesEndpoint {
        EmailAddressesEndpoint(path: path + "/email_addresses")
    }
    
    struct EmailAddressesEndpoint {
        /// Path: `v1/me/email_addresses`
        let path: String
        
        func post(_ params: EmailAddress.CreateParams) -> Request<ClientResponse<EmailAddress>> {
            .init(path: path, method: .post, body: params)
        }
    }
    
}

extension APIEndpoint.V1Endpoint.MeEndpoint.EmailAddressesEndpoint {
    
    public func id(_ id: String) -> WithID {
        WithID(path: path + "/\(id)")
    }

    public struct WithID {
        /// Path: `/v1/client/email_addresses/{id}`
        public let path: String
        
        var get: Request<ClientResponse<EmailAddress>> {
            .init(path: path)
        }
        
        var delete: Request<Void> {
            .init(path: path, method: .delete)
        }
    }
    
}

extension APIEndpoint.V1Endpoint.MeEndpoint.EmailAddressesEndpoint.WithID {
    
    var prepareVerification: PrepareVerificationEndpoint {
        PrepareVerificationEndpoint(path: path + "/prepare_verification")
    }
    
    struct PrepareVerificationEndpoint {
        /// Path: `v1/me/email_addresses/{id}/prepare_verification`
        let path: String
        
        func post(_ params: EmailAddress.PrepareParams) -> Request<ClientResponse<EmailAddress>> {
            .init(path: path, method: .post, body: params)
        }
    }
}

extension APIEndpoint.V1Endpoint.MeEndpoint.EmailAddressesEndpoint.WithID {
    
    var attemptVerification: AttemptVerificationEndpoint {
        AttemptVerificationEndpoint(path: path + "/attempt_verification")
    }
    
    struct AttemptVerificationEndpoint {
        /// Path: `v1/me/email_addresses/{id}/attempt_verification`
        let path: String
        
        func post(_ params: EmailAddress.AttemptParams) -> Request<ClientResponse<EmailAddress>> {
            .init(path: path, method: .post, body: params)
        }
    }
}

extension APIEndpoint.V1Endpoint.MeEndpoint {
    
    var phoneNumbers: PhoneNumbersEndpoint {
        PhoneNumbersEndpoint(path: path + "/phone_numbers")
    }
    
    struct PhoneNumbersEndpoint {
        /// Path: `v1/me/phone_numbers`
        let path: String
        
        func post(_ params: PhoneNumber.CreateParams) -> Request<ClientResponse<PhoneNumber>> {
            .init(path: path, method: .post, body: params)
        }
    }
    
}

extension APIEndpoint.V1Endpoint.MeEndpoint.PhoneNumbersEndpoint {
    
    public func id(_ id: String) -> WithID {
        WithID(path: path + "/\(id)")
    }

    public struct WithID {
        /// Path: `/v1/me/phone_numbers/{id}`
        public let path: String
        
        var get: Request<ClientResponse<PhoneNumber>> {
            return .init(path: path)
        }
        
        var delete: Request<Void> {
            .init(path: path, method: .delete)
        }
    }
    
}

extension APIEndpoint.V1Endpoint.MeEndpoint.PhoneNumbersEndpoint.WithID {
    
    var prepareVerification: PrepareVerificationEndpoint {
        PrepareVerificationEndpoint(path: path + "/prepare_verification")
    }
    
    struct PrepareVerificationEndpoint {
        /// Path: `v1/me/phone_numbers/{id}/prepare_verification`
        let path: String
        
        func post(_ params: PhoneNumber.PrepareParams) -> Request<ClientResponse<PhoneNumber>> {
            .init(path: path, method: .post, body: params)
        }
    }
}

extension APIEndpoint.V1Endpoint.MeEndpoint.PhoneNumbersEndpoint.WithID {
    
    var attemptVerification: AttemptVerificationEndpoint {
        AttemptVerificationEndpoint(path: path + "/attempt_verification")
    }
    
    struct AttemptVerificationEndpoint {
        /// Path: `v1/me/phone_numbers/{id}/attempt_verification`
        let path: String
        
        func post(_ params: PhoneNumber.AttemptParams) -> Request<ClientResponse<PhoneNumber>> {
            .init(path: path, method: .post, body: params)
        }
    }
}

extension APIEndpoint.V1Endpoint.MeEndpoint {
    
    var externalAccounts: ExternalAccountsEndpoint {
        ExternalAccountsEndpoint(path: path + "/external_accounts")
    }
    
    struct ExternalAccountsEndpoint {
        /// Path: `v1/me/external_accounts`
        let path: String
        
        func create(_ params: ExternalAccount.CreateParams) -> Request<ClientResponse<ExternalAccount>> {
            .init(path: path, method: .post, body: params)
        }
    }
    
}

extension APIEndpoint.V1Endpoint.MeEndpoint.ExternalAccountsEndpoint {
    
    public func id(_ id: String) -> WithID {
        WithID(path: path + "/\(id)")
    }

    struct WithID {
        /// Path: `/v1/me/external_accounts/{id}`
        public let path: String
        
        var get: Request<ClientResponse<ExternalAccount>> {
            return .init(path: path)
        }
        
        var delete: Request<Void> {
            .init(path: path, method: .delete)
        }
    }
    
}

extension APIEndpoint.V1Endpoint.MeEndpoint {
    
    var sessions: SessionsEndpoint {
        SessionsEndpoint(path: path + "/sessions")
    }
    
    struct SessionsEndpoint {
        /// Path: `/v1/me/sessions`
        let path: String
    }
    
}

extension APIEndpoint.V1Endpoint.MeEndpoint.SessionsEndpoint {
    
    var active: ActiveEndpoint {
        ActiveEndpoint(path: path + "/active")
    }
    
    struct ActiveEndpoint {
        /// Path: `/v1/me/sessions/active`
        let path: String
        
        var get: Request<[Session]> {
            .init(path: path)
        }
    }
    
}

extension APIEndpoint.V1Endpoint.MeEndpoint.SessionsEndpoint {
    
    func withId(id: String) -> WithIdEndpoint {
        WithIdEndpoint(path: path + "/\(id)")
    }
    
    struct WithIdEndpoint {
        /// Path: `v1/me/sessions/{id}`
        let path: String
    }
    
}

extension APIEndpoint.V1Endpoint.MeEndpoint.SessionsEndpoint.WithIdEndpoint {
    
    var revoke: RevokeEndpoint {
        RevokeEndpoint(path: path + "/revoke")
    }
    
    struct RevokeEndpoint {
        /// Path: `v1/me/sessions/{id}/revoke`
        let path: String
        
        var post: Request<ClientResponse<Session>> {
            .init(path: path, method: .post)
        }
        
    }
    
}

extension APIEndpoint.V1Endpoint.MeEndpoint {
    
    var changePassword: ChangePasswordEndpoint {
        ChangePasswordEndpoint(path: path + "/change_password")
    }
    
    struct ChangePasswordEndpoint {
        /// Path: `v1/me/change_password`
        let path: String
        
        func post(_ params: User.UpdateUserPasswordParams) -> Request<ClientResponse<User>> {
            .init(path: path, method: .post, body: params)
        }
        
    }
}

extension APIEndpoint.V1Endpoint.MeEndpoint {
    
    var profileImage: ProfileImageEndpoint {
        ProfileImageEndpoint(path: path + "/profile_image")
    }
    
    struct ProfileImageEndpoint {
        /// Path: `v1/me/profile_image`
        let path: String
        
        var post: Request<ClientResponse<ImageResource>> {
            .init(path: path, method: .post)
        }
        
        var delete: Request<ClientResponse<ImageResource>> {
            .init(path: path, method: .delete)
        }
    }
    
}
