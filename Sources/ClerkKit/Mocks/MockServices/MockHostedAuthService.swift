//
//  MockHostedAuthService.swift
//  Clerk
//

import Foundation

final class MockHostedAuthService: HostedAuthServiceProtocol {
  nonisolated(unsafe) var createHandler: ((HostedAuthCreateParams) async throws -> HostedAuthResource)?
  nonisolated(unsafe) var redeemHandler: ((HostedAuthRedeemParams) async throws -> ClientServiceResponse)?

  init(
    create: ((HostedAuthCreateParams) async throws -> HostedAuthResource)? = nil,
    redeem: ((HostedAuthRedeemParams) async throws -> ClientServiceResponse)? = nil
  ) {
    createHandler = create
    redeemHandler = redeem
  }

  @MainActor
  func create(params: HostedAuthCreateParams) async throws -> HostedAuthResource {
    if let createHandler {
      return try await createHandler(params)
    }
    return HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in")
  }

  @MainActor
  func redeem(params: HostedAuthRedeemParams) async throws -> ClientServiceResponse {
    if let redeemHandler {
      return try await redeemHandler(params)
    }
    return ClientServiceResponse(client: .mock, requestSequence: nil, serverDate: nil)
  }
}
