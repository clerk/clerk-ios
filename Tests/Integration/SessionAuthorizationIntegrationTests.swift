//
//  SessionAuthorizationIntegrationTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
import Testing

/// Live `has()` coverage against the with-billing instance.
///
/// Lane 4 (`o:<slug>`) asserts true only when `free_org` has a feature. Until that
/// plan carries a feature, the test still signs in, creates an org, and prints
/// `LIVE_HAS orgFeature` so the restamp can see the miss.
@MainActor
@Suite(.serialized)
struct SessionAuthorizationIntegrationTests {
  private static let testPassword = "Clerk_iOS_Test_2025_XyZ9#mK2$pL7"
  private static let testVerificationCode = "424242"

  @Test
  func signedInHasMatchesSubscriptionAndPlans() async throws {
    let keyName = "with-billing"
    guard try configureClerkForIntegrationTesting(keyName: keyName) else {
      return
    }

    let testEmail = Self.makeUniqueTestEmail()
    var capturedError: Error?
    var didCreateSignUp = false
    var createdOrg: Organization?

    do {
      let signUp = try await Clerk.shared.auth.signUp(emailAddress: testEmail, password: Self.testPassword)
      didCreateSignUp = true
      let prepared = try await signUp.sendEmailCode()
      try await prepared.verifyEmailCode(Self.testVerificationCode)

      guard let session = Clerk.shared.session else {
        throw IntegrationSessionAuthorizationError.missingSession("after sign up")
      }

      let plans = try await Clerk.shared.billing.getPlans(params: .init(for: .user))
      let subscription = try await Clerk.shared.billing.getSubscription(params: .init())
      let subscribedSlugs = Set(subscription.subscriptionItems.map(\.plan.slug))

      print("LIVE_HAS session=\(session.id)")
      print("LIVE_HAS subscriptionStatus=\(subscription.status)")
      print("LIVE_HAS subscribedSlugs=\(subscribedSlugs.sorted())")
      print("LIVE_HAS planSlugs=\(plans.data.map(\.slug))")

      #expect(session.has(.init()) == false)
      #expect(session.has(.init(plan: "plus")) == session.checkAuthorization(.init(plan: "plus")))

      for plan in plans.data {
        let hasPlan = session.has(.init(plan: plan.slug))
        let subscribed = subscribedSlugs.contains(plan.slug)
        print("LIVE_HAS plan=\(plan.slug) has=\(hasPlan) subscribed=\(subscribed)")
        if subscribed {
          #expect(hasPlan)
        }
        for feature in plan.features {
          let hasFeature = session.has(.init(feature: feature.slug))
          print("LIVE_HAS feature=\(feature.slug) has=\(hasFeature) plan=\(plan.slug)")
        }
      }

      #expect(session.has(.init(plan: "missing-plan-slug-for-live")) == false)
      #expect(session.has(.init(feature: "lol:dashboard")) == false)

      let noOrgFeature = session.has(.init(feature: "o:feature_one"))
      print("LIVE_HAS noActiveOrg o:feature_one=\(noOrgFeature)")
      #expect(noOrgFeature == false)

      _ = try await Clerk.shared.auth.getToken(.init(skipCache: true))
      guard let refreshed = Clerk.shared.session else {
        throw IntegrationSessionAuthorizationError.missingSession("after getToken")
      }
      let hasFreeAfterRefresh = refreshed.has(.init(plan: "free_user"))
      print("LIVE_HAS afterGetToken plan=free_user has=\(hasFreeAfterRefresh)")
      #expect(hasFreeAfterRefresh)

      let orgPlans = try await Clerk.shared.billing.getPlans(params: .init(for: .organization))
      let freeOrgFeatures = orgPlans.data.first { $0.slug == "free_org" }?.features.map(\.slug) ?? []
      print("LIVE_HAS orgPlanSlugs=\(orgPlans.data.map(\.slug))")
      print("LIVE_HAS freeOrgFeatures=\(freeOrgFeatures)")

      let org = try await Clerk.shared.organizations.create(
        name: "Has Org \(UUID().uuidString.prefix(8))"
      )
      createdOrg = org
      try await Clerk.shared.auth.setActive(sessionId: session.id, organizationId: org.id)
      _ = try await Clerk.shared.auth.getToken(.init(skipCache: true))
      guard let orgSession = Clerk.shared.session else {
        throw IntegrationSessionAuthorizationError.missingSession("after setActive")
      }

      let hasAdmin = orgSession.has(.init(role: "org:admin"))
      let hasMembershipRead = orgSession.has(.init(permission: "org:sys_memberships:read"))
      let orgFeatureSlug = freeOrgFeatures.first ?? "feature_one"
      let hasOrgFeature = orgSession.has(.init(feature: "o:\(orgFeatureSlug)"))
      print("LIVE_HAS orgRole admin=\(hasAdmin)")
      print("LIVE_HAS orgPermission membershipsRead=\(hasMembershipRead)")
      print("LIVE_HAS orgFeature o:\(orgFeatureSlug)=\(hasOrgFeature)")
      if !freeOrgFeatures.isEmpty {
        #expect(hasOrgFeature)
      }

      try await org.destroy()
      createdOrg = nil
    } catch {
      capturedError = error
    }

    if let createdOrg {
      _ = try? await createdOrg.destroy()
    }
    await deleteTestAccountIfExists(email: testEmail, allowPasswordCleanup: didCreateSignUp)

    if let capturedError {
      if try shouldSkipIntegrationTest(capturedError, keyName: keyName) {
        return
      }
      throw capturedError
    }
  }

  private static func makeUniqueTestEmail() -> String {
    let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    return "test+clerk_test_\(suffix)@example.com"
  }

  private func deleteTestAccountIfExists(email: String, allowPasswordCleanup: Bool) async {
    do {
      if let currentUser = Clerk.shared.user {
        try await currentUser.delete()
        return
      }
      guard allowPasswordCleanup else {
        return
      }
      _ = try await Clerk.shared.auth.signInWithPassword(identifier: email, password: Self.testPassword)
      try await Clerk.shared.user?.delete()
    } catch {
      // Best-effort cleanup. Some failure paths may not produce a deletable account.
    }
  }
}

private enum IntegrationSessionAuthorizationError: LocalizedError {
  case missingSession(String)

  var errorDescription: String? {
    switch self {
    case .missingSession(let when):
      "session missing \(when)"
    }
  }
}
