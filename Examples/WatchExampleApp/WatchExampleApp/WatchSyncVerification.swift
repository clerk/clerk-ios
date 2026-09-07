#if os(iOS)
import WatchConnectivity
#endif
@_spi(FrameworkIntegration) import ClerkKit
import Foundation
import os

enum WatchSyncVerification {
  static let argument = "-clerk-verify-watch-sync"
  static let deleteArgument = "-clerk-delete-watch-sync-user"
  static let log = Logger(subsystem: "com.clerk.WatchExampleApp", category: "watch-sync")

  static var isEnabled: Bool {
    ProcessInfo.processInfo.arguments.contains(argument)
  }

  @MainActor
  static func runIfNeeded() async {
    if ProcessInfo.processInfo.arguments.contains(deleteArgument) {
      await deleteSignedInUserIfNeeded()
      return
    }
    guard isEnabled else { return }
    logSession()
    log.notice("clerk-watch-sync phone start")
    do {
      let email = uniqueClerkTestEmail()
      var signUp = try await Clerk.shared.auth.signUp(
        emailAddress: email,
        firstName: "Watch",
        lastName: "Sync",
        phoneNumber: uniqueClerkTestPhone(),
        legalAccepted: true
      )
      log.notice(
        "clerk-watch-sync phone created status=\(signUp.status.rawValue, privacy: .public) missing=\(fieldList(signUp.missingFields), privacy: .public) unverified=\(fieldList(signUp.unverifiedFields), privacy: .public)"
      )
      if signUp.status != .complete {
        signUp = try await signUp.sendEmailCode()
        signUp = try await signUp.verifyEmailCode("424242")
      }
      if signUp.status != .complete, signUp.unverifiedFields.contains(.phoneNumber) || signUp.missingFields.contains(.phoneNumber) {
        signUp = try await signUp.sendPhoneCode()
        signUp = try await signUp.verifyPhoneCode("424242")
      }
      log.notice(
        "clerk-watch-sync phone user=\(Clerk.shared.user?.id ?? "nil", privacy: .public) session=\(Clerk.shared.session?.id ?? "nil", privacy: .public) deviceToken=\(Clerk.shared.deviceToken == nil ? "nil" : "set", privacy: .public) signup=\(signUp.status.rawValue, privacy: .public) missing=\(fieldList(signUp.missingFields), privacy: .public) unverified=\(fieldList(signUp.unverifiedFields), privacy: .public)"
      )
      logSession()
    } catch {
      if Clerk.shared.user != nil || Clerk.shared.session != nil {
        log.notice(
          "clerk-watch-sync phone existing user=\(Clerk.shared.user?.id ?? "nil", privacy: .public) session=\(Clerk.shared.session?.id ?? "nil", privacy: .public) deviceToken=\(Clerk.shared.deviceToken == nil ? "nil" : "set", privacy: .public)"
        )
      } else {
        log.error("clerk-watch-sync phone error=\(String(describing: error), privacy: .public)")
      }
    }
  }

  @MainActor
  private static func deleteSignedInUserIfNeeded() async {
    let user = await waitForSignedInUser()
    guard let user else {
      log.notice("clerk-watch-sync delete user=nil")
      return
    }
    let id = user.id
    do {
      _ = try await user.delete()
      log.notice("clerk-watch-sync deleted user=\(id, privacy: .public) remaining=\(Clerk.shared.user?.id ?? "nil", privacy: .public)")
    } catch {
      log.error("clerk-watch-sync delete error=\(String(describing: error), privacy: .public)")
    }
  }

  @MainActor
  private static func waitForSignedInUser() async -> User? {
    if let user = Clerk.shared.user {
      return user
    }
    for _ in 0 ..< 20 {
      try? await Task.sleep(for: .milliseconds(250))
      if let user = Clerk.shared.user {
        return user
      }
    }
    return Clerk.shared.user
  }

  private static func logSession() {
    #if os(iOS)
    let session = WCSession.default
    log.notice(
      "clerk-watch-sync phone wcsession supported=\(WCSession.isSupported()) paired=\(session.isPaired) installed=\(session.isWatchAppInstalled) reachable=\(session.isReachable) state=\(session.activationState.rawValue)"
    )
    #endif
  }

  private static func fieldList(_ fields: [SignUp.Field]) -> String {
    fields.map(\.rawValue).joined(separator: ",")
  }

  private static func uniqueClerkTestEmail() -> String {
    let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    return "watchex+clerk_test_\(suffix)@example.com"
  }

  private static func uniqueClerkTestPhone() -> String {
    let area = Int.random(in: 200 ... 999)
    let line = Int.random(in: 0 ... 99)
    return String(format: "+1%d55501%02d", area, line)
  }
}
