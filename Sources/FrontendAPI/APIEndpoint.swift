//
//  APIEndpoint.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import Get
    
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
        
        var get: Request<ClientResponse<Client>> {
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
    
    public func id(_ id: String) -> WithID {
        WithID(path: path + "/\(id)")
    }

    public struct WithID {
        /// Path: `/v1/client/sign_ins/{id}`
        public let path: String
    }
    
}

extension APIEndpoint.V1Endpoint.ClientEndpoint.SignInsEndpoint.WithID {
    
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

extension APIEndpoint.V1Endpoint.ClientEndpoint.SignInsEndpoint.WithID {
    
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
