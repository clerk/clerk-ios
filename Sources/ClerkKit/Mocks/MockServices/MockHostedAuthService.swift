//
//  MockHostedAuthService.swift
//  Clerk
//

import Foundation

final class MockHostedAuthService: HostedAuthServiceProtocol {
  nonisolated(unsafe) var createHandler: ((HostedAuthCreateParams) async throws -> HostedAuthResource)?
  nonisolated(unsafe) var redeemHandler: ((HostedAuthRedeemParams) async throws -> HostedAuthRedeemResponse)?

  init(
    create: ((HostedAuthCreateParams) async throws -> HostedAuthResource)? = nil,
    redeem: ((HostedAuthRedeemParams) async throws -> HostedAuthRedeemResponse)? = nil
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
  func redeem(params: HostedAuthRedeemParams) async throws -> HostedAuthRedeemResponse {
    if let redeemHandler {
      return try await redeemHandler(params)
    }
    let requestIdentity = try await Clerk.shared.identityController.captureRequestIdentity()
    return HostedAuthRedeemResponse(
      client: .mock,
      clientSyncContext: ClientSyncResponseContext(
        update: .client(.mock),
        deviceTokenUpdate: requestIdentity.deviceToken == nil
          ? .set("mock-device-token")
          : .absent,
        requestDeviceToken: requestIdentity.deviceToken,
        baseGeneration: requestIdentity.baseGeneration,
        serverDate: nil,
        isCanonicalClientRequest: true,
        clientResponseGeneration: requestIdentity.clientResponseGeneration,
        responseSequence: nil
      )
    )
  }
}
