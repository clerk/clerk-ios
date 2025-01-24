//
//  APIClient.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import Get
import SimpleKeychain
import Factory

final class ClerkAPIClientDelegate: APIClientDelegate, Sendable {
    
    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
        await HeaderMiddleware.process(&request)
        QueryItemMiddleware.process(&request)
        try URLEncodedFormMiddleware.process(&request)
    }
     
    func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        DeviceTokenSavingMiddleware.process(response)
        EventEmitterMiddleware.process(data)
        try ErrorThrowingMiddleware.process(response, data: data)
    }
    
    func client(_ client: APIClient, shouldRetry task: URLSessionTask, error: any Error, attempts: Int) async throws -> Bool {
        
        if attempts == 1 {
            if let lastPathComponent = task.originalRequest?.url?.pathComponents.last, lastPathComponent != "client" {
                // if the original request wasn't a get client, try to get the client in sync with the server
                _ = try? await Client.get()
            }
            return true
        }
        
        return false
    }
    
}

extension Container {
    
    private var additionalHeaders: [String: any Encodable] {
        var headers = [
            "Content-Type": "application/x-www-form-urlencoded",
            "clerk-api-version": "2024-10-01",
            "x-ios-sdk-version": Clerk.version
        ]
        
        #if os(iOS)
        headers["x-mobile"] = "1"
        #endif
        
        return headers
    }
    
    var apiClient: ParameterFactory<String, APIClient> {
        self {
            APIClient(baseURL: URL(string: $0)) { client in
                client.delegate = ClerkAPIClientDelegate()
                client.decoder = JSONDecoder.clerkDecoder
                client.encoder = JSONEncoder.clerkEncoder
                client.sessionConfiguration.httpAdditionalHeaders = self.additionalHeaders
            }
        }
        .cached
    }
    
}
