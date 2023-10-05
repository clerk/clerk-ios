//
//  ClientResponse.swift
//
//
//  Created by Mike Pitre on 10/3/23.
//

import Foundation

/**
 Some of the endpoints return the requested object along with the Client Object (piggy-backed).
 This wrapper object can be used to decode the requested obejct along with the client object.
 
 Example Usage:
 ```swift
 func post(_ params: SignUp.CreateParams) -> Request<ClientResponse<SignUp>>
 */
struct ClientResponse<Response: Decodable>: Decodable {
    let response: Response
    let client: Client?
}
