//
//  APIEndpoint.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import Get
    
public enum APIEndpoint {}

extension APIEndpoint {
    public static var v1: V1Endpoint {
        V1Endpoint(path: "/v1")
    }
    
    public struct V1Endpoint {
        /// Path: `/v1`
        public let path: String
    }
}

extension APIEndpoint.V1Endpoint {
    
    public var client: ClientEndpoint {
        ClientEndpoint(path: path + "/client")
    }
    
    public struct ClientEndpoint {
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

extension APIEndpoint.V1Endpoint.ClientEndpoint {
    
    public var signUps: SignUpsEndpoint {
        SignUpsEndpoint(path: path + "/sign_ups")
    }
    
    public struct SignUpsEndpoint {
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
    
    public func prepareVerification(id: String) -> PrepareVerificationEndpoint {
        PrepareVerificationEndpoint(path: path + "/\(id)/prepare_verification")
    }
    
    public struct PrepareVerificationEndpoint {
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
    
    public func attemptVerification(id: String) -> AttemptVerificationEndpoint {
        AttemptVerificationEndpoint(path: path + "/\(id)/prepare_verification")
    }
    
    public struct AttemptVerificationEndpoint {
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
