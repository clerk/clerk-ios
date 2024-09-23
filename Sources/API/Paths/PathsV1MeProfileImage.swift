//
//  PathsV1MeProfileImage.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint {
    
    var profileImage: ProfileImageEndpoint {
        ProfileImageEndpoint(path: path + "/profile_image")
    }
    
    struct ProfileImageEndpoint {
        /// Path: `v1/me/profile_image`
        let path: String
        
        func post(queryItems: [URLQueryItem] = [], headers: [String: String]? = nil) -> Request<ClientResponse<ClerkImageResource>> {
            .init(path: path, method: .post, query: queryItems.asTuples, headers: headers)
        }
        
        func delete(queryItems: [URLQueryItem] = []) -> Request<ClientResponse<DeletedObject>> {
            .init(path: path, method: .delete, query: queryItems.asTuples)
        }
    }
    
}
