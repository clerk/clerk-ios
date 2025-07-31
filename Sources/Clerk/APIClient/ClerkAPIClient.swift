//
//  APIClient.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import FactoryKit
import Foundation
import Get

extension Container {
    var apiClient: Factory<APIClient> {
        self { APIClient(baseURL: nil) }.cached
    }
}

protocol RequestPreprocessor {
    static func process(request: inout URLRequest) async throws
}

protocol RequestPostprocessor {
    static func process(response: HTTPURLResponse, data: Data, task: URLSessionTask) throws
}

protocol RequestRetrier {
    static func shouldRetry(task: URLSessionTask, error: any Error, attempts: Int) async throws -> Bool
}

final class ClerkAPIClientDelegate: APIClientDelegate, Sendable {
    
    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
        try await ClerkHeaderRequestProcessor.process(request: &request)
        try await ClerkQueryItemsRequestProcessor.process(request: &request)
        try await ClerkURLEncodedFormEncoderRequestProcessor.process(request: &request)
    }
    
    func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        try ClerkDeviceTokenRequestProcessor.process(response: response, data: data, task: task)
        try ClerkClientSyncRequestProcessor.process(response: response, data: data, task: task)
        try ClerkEventEmitterRequestProcessor.process(response: response, data: data, task: task)
        try ClerkErrorThrowingRequestProcessor.process(response: response, data: data, task: task)
        try ClerkInvalidAuthRequestProcessor.process(response: response, data: data, task: task)
    }
    
    func client(_ client: APIClient, shouldRetry task: URLSessionTask, error: any Error, attempts: Int) async throws -> Bool {
        guard attempts == 1 else {
            return false
        }
        
        if try await ClerkDeviceAssertionRetrier.shouldRetry(task: task, error: error, attempts: attempts) {
            return true
        }
        
        return false
    }
    
}
