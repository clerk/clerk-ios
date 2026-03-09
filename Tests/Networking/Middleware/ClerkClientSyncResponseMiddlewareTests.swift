//
//  ClerkClientSyncResponseMiddlewareTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkClientSyncResponseMiddlewareTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func decodesClientFromResponseKey() throws {
    var mockClient = Client.mockSignedOut
    mockClient.id = "client_test123"

    let jsonData = try JSONEncoder.clerkEncoder.encode([
      "response": mockClient
    ])

    let decodedClient = ClerkClientSyncResponseMiddleware.decodeClient(from: jsonData)

    #expect(decodedClient?.id == "client_test123")
  }

  @Test
  func decodesClientFromClientKey() throws {
    var mockClient = Client.mockSignedOut
    mockClient.id = "client_test456"

    let jsonData = try JSONEncoder.clerkEncoder.encode([
      "client": mockClient
    ])

    let decodedClient = ClerkClientSyncResponseMiddleware.decodeClient(from: jsonData)

    #expect(decodedClient?.id == "client_test456")
  }

  @Test
  func decodesClientFromTopLevel() throws {
    var mockClient = Client.mockSignedOut
    mockClient.id = "client_test789"

    let jsonData = try JSONEncoder.clerkEncoder.encode(mockClient)

    let decodedClient = ClerkClientSyncResponseMiddleware.decodeClient(from: jsonData)

    #expect(decodedClient?.id == "client_test789")
  }

  @Test
  func returnsNilWhenNoClientInPayload() throws {
    let jsonData = try JSONEncoder.clerkEncoder.encode([
      "data": "some other data",
      "status": "ok"
    ])

    let decodedClient = ClerkClientSyncResponseMiddleware.decodeClient(from: jsonData)

    #expect(decodedClient == nil)
  }

  @Test
  func returnsNilForInvalidJSON() {
    let invalidData = Data([0x00, 0x01, 0x02])

    let decodedClient = ClerkClientSyncResponseMiddleware.decodeClient(from: invalidData)

    #expect(decodedClient == nil)
  }

  @Test
  func validateAppliesClientToShared() async throws {
    Clerk.shared.client = nil

    var mockClient = Client.mockSignedOut
    mockClient.id = "client_validate_test"
    mockClient.updatedAt = Date()

    let jsonData = try JSONEncoder.clerkEncoder.encode([
      "response": mockClient
    ])

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)

    let middleware = ClerkClientSyncResponseMiddleware()
    try await middleware.validate(response, data: jsonData, for: request)

    #expect(Clerk.shared.client?.id == "client_validate_test")
  }

  @Test
  func validateWithResponseSequence() async throws {
    Clerk.shared.client = nil

    var mockClient = Client.mockSignedOut
    mockClient.id = "client_seq_test"
    mockClient.updatedAt = Date()

    let jsonData = try JSONEncoder.clerkEncoder.encode([
      "response": mockClient
    ])

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    var request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    request.setClerkRequestSequence(42)

    let middleware = ClerkClientSyncResponseMiddleware()
    try await middleware.validate(response, data: jsonData, for: request)

    #expect(Clerk.shared.client?.id == "client_seq_test")
  }

  @Test
  func validateHandlesEmptyResponse() async throws {
    let jsonData = try JSONEncoder.clerkEncoder.encode([
      "status": "ok"
    ])

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)

    let middleware = ClerkClientSyncResponseMiddleware()

    // Should not throw, just skip syncing
    try await middleware.validate(response, data: jsonData, for: request)
  }
}