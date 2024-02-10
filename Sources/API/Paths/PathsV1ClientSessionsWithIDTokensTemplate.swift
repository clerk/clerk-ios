//
//  PathsV1ClientSessionsWithIDTokensTemplate.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.ClientEndpoint.SessionsEndpoint.WithIdEndpoint.TokensEndpoint {
    
    func template(_ template: String) -> TemplateEndpoint {
        TemplateEndpoint(path: path + "/\(template)")
    }
    
    struct TemplateEndpoint {
        /// Path: `v1/client/sessions/{id}/tokens/{template}`
        let path: String
        
        func post() -> Request<TokenResource?> {
            .init(path: path, method: .post)
        }
    }
}
