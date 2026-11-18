//
//  ClerkDpopRequestMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkDpopRequestMiddleware: ClerkRequestMiddleware {
  private let runtimeScope: ClerkRuntimeScope
  private let makeJTI: @Sendable () -> String

  init(
    runtimeScope: ClerkRuntimeScope,
    makeJTI: @escaping @Sendable () -> String = { UUID().uuidString }
  ) {
    self.runtimeScope = runtimeScope
    self.makeJTI = makeJTI
  }

  func prepare(_ request: inout URLRequest) async throws {
    let state = try await runtimeScope.withCurrentClerk { $0.dependencies.deviceBinding }
    let accessToken = Self.accessToken(of: request)
    let tokenHasCnf = accessToken.map(DeviceTokenClaims.hasCnf) ?? false
    let binding = await state.current()
    var signFailure: SignFailure?

    while true {
      switch proofDecision(tokenHasCnf: tokenHasCnf, binding: binding, signFailure: signFailure) {
      case .sendUnsigned:
        request.setValue(nil, forHTTPHeaderField: DpopProof.headerName)
        return
      case let .failRequest(reason):
        ClerkLogger.warning("Device binding: failing a device-bound request that has no DPoP proof: \(reason)")
        throw DeviceBindingRequestError.proofUnavailable(reason)
      case .sign:
        guard let holder = state.holder, let url = request.url else {
          signFailure = .keyLost
          continue
        }
        let boundRequest = DpopBoundRequest(method: request.httpMethod ?? "GET", url: url, accessToken: accessToken)
        let now = try await runtimeScope.withCurrentClerk { $0.identityController.serverClock.proofDate() }
        let jti = makeJTI()
        switch holder.withKey({ try DpopProof.build(key: $0, request: boundRequest, now: now, jti: jti) }) {
        case let .success(proof):
          await state.recordSigned()
          request.setValue(proof, forHTTPHeaderField: DpopProof.headerName)
          ClerkLogger.debug("DPoP proof attached jti=\(jti.prefix(8))")
          return
        case let .failure(error):
          let failure: SignFailure = holder.loadedState?.isUnavailable == true ? .keyLost : .notALoss
          ClerkLogger.warning("DPoP proof failed: \(error)")
          await state.recordSignFailure(failure)
          signFailure = failure
        }
      }
    }
  }

  private static func accessToken(of request: URLRequest) -> String? {
    guard let authorization = request.value(forHTTPHeaderField: "Authorization").nilIfEmpty else {
      return nil
    }
    if authorization.lowercased().hasPrefix("bearer ") {
      return String(authorization.dropFirst("bearer ".count))
    }
    return authorization
  }
}
