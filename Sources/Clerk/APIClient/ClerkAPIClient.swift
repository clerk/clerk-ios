//
//  APIClient.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/// Context shared across middleware stages while processing a network request.
struct RequestPipelineContext: Sendable {
    /// The final request submitted to the underlying URLSession.
    let request: URLRequest
    /// The current retry attempt (starting at 1).
    let attempt: Int
}

protocol RequestPreprocessor: Sendable {
    static func process(request: inout URLRequest) async throws
}

protocol RequestPostprocessor: Sendable {
    static func process(response: HTTPURLResponse, data: Data, context: RequestPipelineContext) throws
}

protocol RequestRetrier: Sendable {
    static func retryDecision(context: RequestPipelineContext, error: any Error, attempts: Int) async throws -> RetryDecision
}
