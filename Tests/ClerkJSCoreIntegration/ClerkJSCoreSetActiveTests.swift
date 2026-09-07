#if !os(watchOS)
@testable import ClerkJSCore
import ClerkWatchCompanion
import Foundation
import Testing

struct ClerkJSCoreSetActiveTests {
  @Test
  func emailCodeSetActiveReturnsSessionToken() async throws {
    guard let publishableKey = publishableKeyFromKeysFile(named: "amusing-barnacle-26") else {
      Issue.record("Missing amusing-barnacle-26 publishable key in .keys.json")
      return
    }
    let signUpRuntime = ClerkJSRuntime()
    try await signUpRuntime.load(publishableKey: publishableKey)
    try await FAPITestGate.shared.run {
      let email = uniqueClerkTestEmail()
      if let code = await ensureSignedUpUser(signUpRuntime, email: email) {
        _ = await deleteCreatedTestUser(signUpRuntime, email: email)
        Issue.record("FAPI \(code)")
        return
      }
      try await deferCleanup(signUpRuntime, email: email) {
        let host = await ClerkJSHost(publishableKey: publishableKey)
        try await host.load()
        try await deferCleanup(host.runtime, email: email) {
          let createdJSON = try await host.invoke(.init(.signIn, SignInJSCall.create(.init(identifier: email))))
          let created = try JSONDecoder().decode(SignIn.self, from: JSONEncoder().encode(createdJSON))
          let factor = try #require(created.supportedFirstFactors.first { $0.strategy == "email_code" })
          _ = try await host.invoke(.init(.signIn, SignInJSCall.prepareFirstFactor(.init(strategy: "email_code", emailAddressId: factor.emailAddressId))))
          let attemptedJSON = try await host.invoke(.init(.signIn, SignInJSCall.attemptFirstFactor(.init(strategy: .emailCode, code: "424242"))))
          let attempted = try JSONDecoder().decode(SignIn.self, from: JSONEncoder().encode(attemptedJSON))
          let sessionID = try #require(attempted.createdSessionId)
          _ = try await host.invoke(.init(receiver: .clerk, method: "setActive", arguments: [.object(["session": .string(sessionID)])]))
          for skipCache in [false, true] {
            let result = try await host.invoke(.init(.session(id: ClerkJSResourceID(sessionID)), SessionJSCall.getToken(.init(skipCache: skipCache))))
            guard case let .string(jwt) = result else {
              Issue.record("The active session did not return a token")
              return
            }
            #expect(jwt.count > 4)
          }
          var replica = WatchCompanion()
          try await replica.apply(host.watchCompanion.encode())
          #expect(replica.client?.id.hasPrefix("client_") == true)
          #expect(replica.client?.lastActiveSessionId == sessionID)
        }
        await host.dispose()
      }
    }
    await signUpRuntime.dispose()
  }
}
#endif
