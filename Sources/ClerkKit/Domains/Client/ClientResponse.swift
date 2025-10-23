//
//  ClientResponse.swift
//  Clerk
//
//  Created by Mike Pitre on 2/23/25.
//

import Foundation

/// The ClerkAPI oftens returns the requested object along with the Client Object (piggy-backed).
///
/// This wrapper object can be used to decode the requested object along with the client object.
/// ### Example
/// ```swift
/// func post(_ params: SignUp.CreateParams) -> Request<ClientResponse<SignUp>>
/// ```
struct ClientResponse<Response: Codable & Sendable>: Codable, Sendable {
    let response: Response
    let client: Client?
}
