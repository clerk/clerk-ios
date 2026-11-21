//
//  DeviceBindingSigner.swift
//  Clerk
//

import Foundation

struct DeviceBindingSigner {
  private let runtimeScope: ClerkRuntimeScope
  private let makeJTI: @Sendable () -> String

  init(
    runtimeScope: ClerkRuntimeScope,
    makeJTI: @escaping @Sendable () -> String = { UUID().uuidString }
  ) {
    self.runtimeScope = runtimeScope
    self.makeJTI = makeJTI
  }

  func proof(for request: DpopBoundRequest, sentByFrameworkHost: Bool) async throws -> String? {
    let state = try await runtimeScope.withCurrentClerk { $0.dependencies.deviceBinding }
    let tokenHasCnf = request.accessToken.map(DeviceTokenClaims.hasCnf) ?? false
    let binding: DeviceBinding = if sentByFrameworkHost, !state.hostSignsRequests {
      .notSigning(.frameworkHost)
    } else {
      await state.current()
    }
    var signFailure: SignFailure?

    while true {
      switch proofDecision(tokenHasCnf: tokenHasCnf, binding: binding, signFailure: signFailure) {
      case .sendUnsigned:
        return nil
      case let .failRequest(reason):
        ClerkLogger.warning("Device binding: failing a device-bound request that has no DPoP proof: \(reason)")
        throw DeviceBindingRequestError.proofUnavailable(reason)
      case .sign:
        guard let holder = state.holder else {
          signFailure = .keyLost
          continue
        }
        let now = try await runtimeScope.withCurrentClerk { $0.identityController.serverClock.proofDate() }
        let jti = makeJTI()
        switch holder.withKey({ try DpopProof.build(key: $0, request: request, now: now, jti: jti) }) {
        case let .success(proof):
          await state.recordSigned()
          ClerkLogger.debug("DPoP proof attached jti=\(jti.prefix(8))")
          return proof
        case let .failure(error):
          let failure: SignFailure = holder.loadedState?.isUnavailable == true ? .keyLost : .notALoss
          ClerkLogger.warning("DPoP proof failed: \(error)")
          await state.recordSignFailure(failure)
          signFailure = failure
        }
      }
    }
  }

  static func accessToken(fromAuthorization authorization: String?) -> String? {
    guard let authorization = authorization.nilIfEmpty else {
      return nil
    }
    if authorization.lowercased().hasPrefix("bearer ") {
      return String(authorization.dropFirst("bearer ".count))
    }
    return authorization
  }
}
