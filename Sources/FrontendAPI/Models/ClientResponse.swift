//
//  ClientResponse.swift
//
//
//  Created by Mike Pitre on 10/3/23.
//

import Foundation

/// Some of the endpoints return the requested object along with the Client Object (piggy-backed).
/// This wrapper object can be used to decode the requested obejct along with the client object.
public struct ClientResponse<Object: Codable>: Codable {
    let object: Object
    let client: Client?
}
