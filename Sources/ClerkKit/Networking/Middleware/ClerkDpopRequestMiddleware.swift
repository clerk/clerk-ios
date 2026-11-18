//
//  ClerkDpopRequestMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkDpopRequestMiddleware: ClerkRequestMiddleware {
  private let signer: DeviceBindingSigner

  init(
    runtimeScope: ClerkRuntimeScope,
    makeJTI: @escaping @Sendable () -> String = { UUID().uuidString }
  ) {
    signer = DeviceBindingSigner(runtimeScope: runtimeScope, makeJTI: makeJTI)
  }

  func prepare(_ request: inout URLRequest) async throws {
    let proof: String? = if let url = request.url {
      try await signer.proof(
        for: DpopBoundRequest(
          method: request.httpMethod ?? "GET",
          url: url,
          accessToken: DeviceBindingSigner.accessToken(
            fromAuthorization: request.value(forHTTPHeaderField: "Authorization")
          )
        ),
        sentByFrameworkHost: FrameworkHost.sent(request)
      )
    } else {
      nil
    }
    request.setValue(proof, forHTTPHeaderField: DpopProof.headerName)
  }
}
