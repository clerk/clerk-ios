//
//  APIClient.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import Get
import SimpleKeychain

final class ClerkAPIClientDelegate: APIClientDelegate, Sendable {
    
    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
        try await HeaderMiddleware.process(&request)
        QueryItemMiddleware.process(&request)
        try URLEncodedFormMiddleware.process(&request)
    }
    
    func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        Task {
            try DeviceTokenSavingMiddleware.process(response)
            await EventEmitterMiddleware.process(data)
            try ErrorThrowingMiddleware.process(response, data: data)
        }
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
