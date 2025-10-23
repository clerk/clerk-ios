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
  var networkingPipeline: Factory<NetworkingPipeline> {
    self { .clerkDefault }.cached
  }

  var apiClient: Factory<APIClient> {
    self {
      let pipeline = self.networkingPipeline()
      return APIClient(baseURL: nil) { configuration in
        configuration.delegate = ClerkAPIClientDelegate(pipeline: pipeline)
      }
    }.cached
  }
}

final class ClerkAPIClientDelegate: APIClientDelegate, Sendable {
  private let pipeline: NetworkingPipeline

  init(pipeline: NetworkingPipeline) {
    self.pipeline = pipeline
  }

  func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
    try await pipeline.prepare(&request)
  }

  func client(
    _ client: APIClient,
    validateResponse response: HTTPURLResponse,
    data: Data,
    task: URLSessionTask
  ) throws {
    try pipeline.validate(response, data: data, task: task)
  }

  func client(
    _ client: APIClient,
    shouldRetry task: URLSessionTask,
    error: any Error,
    attempts: Int
  ) async throws -> Bool {
    try await pipeline.shouldRetry(task, error: error, attempts: attempts)
  }
}
