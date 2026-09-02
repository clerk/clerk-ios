@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct EnvironmentTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func refreshEnvironmentUsesEnvironmentServiceGet() async throws {
    let called = LockIsolated(false)
    let expectedEnvironment = Clerk.Environment.mock
    let service = MockEnvironmentService(get: {
      called.setValue(true)
      return expectedEnvironment
    })
    let clerk = makeClerk(environmentService: service)

    _ = try await clerk.refreshEnvironment()

    #expect(called.value == true)
    #expect(clerk.environment == expectedEnvironment)
  }

  @Test
  func refreshEnvironmentCoalescesConcurrentRequests() async throws {
    let callCount = LockIsolated(0)
    let service = MockEnvironmentService(get: {
      callCount.withValue { $0 += 1 }
      try await Task.sleep(for: .milliseconds(100))
      return .mock
    })
    let clerk = makeClerk(environmentService: service)

    let firstRefresh = Task { @MainActor in
      try await clerk.refreshEnvironment()
    }
    try await waitUntil { callCount.value == 1 }

    let secondRefresh = Task { @MainActor in
      try await clerk.refreshEnvironment()
    }

    _ = try await firstRefresh.value
    _ = try await secondRefresh.value

    #expect(callCount.value == 1)
  }

  @Test
  func ensureEnvironmentRefreshedAfterSatisfiedCheckpointDoesNotRequestAgain() async throws {
    let callCount = LockIsolated(0)
    let service = MockEnvironmentService(get: {
      callCount.withValue { $0 += 1 }
      return .mock
    })
    let clerk = makeClerk(environmentService: service)

    let checkpoint = clerk.environmentRefreshCheckpoint
    _ = try await clerk.refreshEnvironment()
    _ = try await clerk.ensureEnvironmentRefreshed(after: checkpoint)

    #expect(callCount.value == 1)
  }

  @Test
  func ensureEnvironmentRefreshedAfterUnsatisfiedCheckpointRequestsEnvironment() async throws {
    let callCount = LockIsolated(0)
    let service = MockEnvironmentService(get: {
      callCount.withValue { $0 += 1 }
      return .mock
    })
    let clerk = makeClerk(environmentService: service)

    let checkpoint = clerk.environmentRefreshCheckpoint
    _ = try await clerk.ensureEnvironmentRefreshed(after: checkpoint)

    #expect(callCount.value == 1)
  }

  private func makeClerk(environmentService: MockEnvironmentService) -> Clerk {
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      environmentService: environmentService
    )
    return clerk
  }

  private func waitUntil(
    timeout: Duration = .milliseconds(500),
    _ condition: () -> Bool
  ) async throws {
    enum TimeoutError: Error {
      case timedOut
    }

    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if condition() {
        return
      }
      try await Task.sleep(for: .milliseconds(10))
    }

    if !condition() {
      throw TimeoutError.timedOut
    }
  }
}

struct EnvironmentCommerceSettingsDecodingTests {
  private let decoder = JSONDecoder.clerkDecoder
  private let encoder = JSONEncoder.clerkEncoder

  private enum TestError: Error {
    case invalidUTF8
  }

  private func environmentJSON(commerceSettings: String? = nil) throws -> Data {
    let authConfig = try encoder.encode(Clerk.Environment.AuthConfig.mock)
    let userSettings = try encoder.encode(Clerk.Environment.UserSettings.mock)
    let displayConfig = try encoder.encode(Clerk.Environment.DisplayConfig.mock)
    guard
      let authConfigString = String(data: authConfig, encoding: .utf8),
      let userSettingsString = String(data: userSettings, encoding: .utf8),
      let displayConfigString = String(data: displayConfig, encoding: .utf8)
    else {
      throw TestError.invalidUTF8
    }

    var parts = [
      "\"auth_config\": \(authConfigString)",
      "\"user_settings\": \(userSettingsString)",
      "\"display_config\": \(displayConfigString)",
    ]
    if let commerceSettings {
      parts.append("\"commerce_settings\": \(commerceSettings)")
    }

    return Data("{ \(parts.joined(separator: ", ")) }".utf8)
  }

  @Test
  func environmentDecodesWhenCommerceSettingsKeyIsMissing() throws {
    let data = try environmentJSON(commerceSettings: nil)
    let env = try decoder.decode(Clerk.Environment.self, from: data)
    #expect(env.commerceSettings == .default)
  }

  @Test
  func environmentDecodesEnabledUserBilling() throws {
    let json = """
    {
      "billing": {
        "stripe_publishable_key": "pk_test_123",
        "user": { "enabled": true, "has_paid_plans": true },
        "organization": { "enabled": false, "has_paid_plans": false }
      }
    }
    """
    let env = try decoder.decode(Clerk.Environment.self, from: environmentJSON(commerceSettings: json))

    #expect(env.commerceSettings.billing.user.enabled == true)
    #expect(env.commerceSettings.billing.user.hasPaidPlans == true)
    #expect(env.commerceSettings.billing.organization.enabled == false)
    #expect(env.commerceSettings.billing.stripePublishableKey == "pk_test_123")
  }

  @Test
  func environmentDecodesEnabledOrganizationBilling() throws {
    let json = """
    {
      "billing": {
        "stripe_publishable_key": "pk_live_abc",
        "user": { "enabled": false, "has_paid_plans": false },
        "organization": { "enabled": true, "has_paid_plans": true }
      }
    }
    """
    let env = try decoder.decode(Clerk.Environment.self, from: environmentJSON(commerceSettings: json))

    #expect(env.commerceSettings.billing.organization.enabled == true)
    #expect(env.commerceSettings.billing.organization.hasPaidPlans == true)
    #expect(env.commerceSettings.billing.user.enabled == false)
    #expect(env.commerceSettings.billing.stripePublishableKey == "pk_live_abc")
  }

  @Test
  func environmentDecodesNullStripePublishableKey() throws {
    let json = """
    {
      "billing": {
        "stripe_publishable_key": null,
        "user": { "enabled": true, "has_paid_plans": false },
        "organization": { "enabled": false, "has_paid_plans": false }
      }
    }
    """
    let env = try decoder.decode(Clerk.Environment.self, from: environmentJSON(commerceSettings: json))

    #expect(env.commerceSettings.billing.stripePublishableKey == nil)
    #expect(env.commerceSettings.billing.user.enabled == true)
  }

  @Test
  func environmentDecodesUnknownCommerceSettingsKeys() throws {
    let json = """
    {
      "id": "commerce_settings_1",
      "object": "commerce_settings",
      "billing": {
        "stripe_publishable_key": "pk_test_leftover",
        "user": { "enabled": true, "has_paid_plans": false },
        "organization": { "enabled": true, "has_paid_plans": false },
        "future_flag": true
      }
    }
    """
    let env = try decoder.decode(Clerk.Environment.self, from: environmentJSON(commerceSettings: json))

    #expect(env.commerceSettings.billing.user.enabled == true)
    #expect(env.commerceSettings.billing.organization.enabled == true)
    #expect(env.commerceSettings.billing.stripePublishableKey == "pk_test_leftover")
  }
}
