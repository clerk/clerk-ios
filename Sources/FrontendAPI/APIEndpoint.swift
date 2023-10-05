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
        
        var get: Request<ClerkEnvironment> {
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
    
    func prepareVerification(id: String) -> PrepareVerificationEndpoint {
        PrepareVerificationEndpoint(path: path + "/\(id)/prepare_verification")
    }
    
    struct PrepareVerificationEndpoint {
        /// Path: `v1/client/sign_ups/(id)/prepare_verification`
        let path: String
        
        func post(_ params: SignUp.PrepareVerificationParams) -> Request<ClientResponse<SignUp>> {
            .init(
                path: path,
                method: .post,
                body: [
                    "strategy": params.strategy.stringValue
                ]
            )
        }
    }
}

extension APIEndpoint.V1Endpoint.ClientEndpoint.SignUpsEndpoint {
    
    func attemptVerification(id: String) -> AttemptVerificationEndpoint {
        AttemptVerificationEndpoint(path: path + "/\(id)/attempt_verification")
    }
    
    struct AttemptVerificationEndpoint {
        /// Path: `v1/client/sign_ups/(id)/attempt_verification`
        let path: String
        
        func post(_ params: SignUp.AttemptVerificationParams) -> Request<ClientResponse<SignUp>> {
            .init(
                path: path,
                method: .post,
                body: [
                    "strategy": params.strategy.stringValue,
                    "code": params.code
                ]
            )
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
