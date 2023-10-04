//
//  Client.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/**
 The Client object keeps track of the authenticated sessions in the current device. The device can be a browser, a native application or any other medium that is usually the requesting part in a request/response architecture.
 The Client object also holds information about any sign in or sign up attempts that might be in progress, tracking the sign in or sign up progress.
 */
public final class Client: Decodable, ObservableObject {

    public init(
        signIn: SignIn? = nil,
        signUp: SignUp? = nil
    ) {
        self.signIn = signIn
        self.signUp = signUp
    }
    
    @Published public var signIn: SignIn?
    @Published public var signUp: SignUp?
    
    enum CodingKeys: CodingKey {
        case signIn
        case signUp
    }
    
    public init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<Client.CodingKeys> = try decoder.container(keyedBy: Client.CodingKeys.self)
        
        self.signIn = try container.decodeIfPresent(SignIn.self, forKey: Client.CodingKeys.signIn)
        self.signUp = try container.decodeIfPresent(SignUp.self, forKey: Client.CodingKeys.signUp)
    }
}

extension Client {
    
    /// Retrieves the current client
    @MainActor
    @discardableResult
    public static func get() async throws -> Client {
        let client = try await Clerk.apiClient.send(APIEndpoint.v1.client.get).value.response
        Clerk.shared.client = client
        return client
    }
    
    /// Creates a new client for the current instance along with its cookie.
    @MainActor
    @discardableResult
    public static func create() async throws -> Client {
        let client = try await Clerk.apiClient.send(APIEndpoint.v1.client.put).value.response
        Clerk.shared.client = client
        return client
    }
    
    /// Deletes the client. All sessions will be reset.
    @MainActor
    @discardableResult
    public static func destroy() async throws -> Client {
        let client = try await Clerk.apiClient.send(APIEndpoint.v1.client.delete).value.response
        Clerk.shared.client = Client()
        return client
    }
    
}
