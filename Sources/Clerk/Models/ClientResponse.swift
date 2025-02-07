//
//  ClientResponse.swift
//  Clerk
//
//  Created by Mike Pitre on 2/7/25.
//


/// The ClerkAPI oftens returns the requested object along with the Client Object (piggy-backed).
///
/// This wrapper object can be used to decode the requested object along with the client object.
/// ### Example
/// ```swift
/// func post(_ params: SignUp.CreateParams) -> Request<ClientResponse<SignUp>>
/// ```
struct ClientResponse<Response: Decodable & Sendable>: Decodable, Sendable {
    let response: Response
    let client: Client?
}
