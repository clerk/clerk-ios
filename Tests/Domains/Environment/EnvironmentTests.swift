@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct EnvironmentTests {
  init() {
    configureClerkForTesting()
    Clerk.engineClient = nil
    Clerk.makeEngineClient = nil
  }

  @Test
  func refreshEnvironmentReturnsCachedEnvironmentWithoutEngine() async throws {
    let clerk = makeClerk()
    clerk.environment = .mock

    let environment = try await clerk.refreshEnvironment()

    #expect(environment.displayConfig.applicationName == Clerk.Environment.mock.displayConfig.applicationName)
    #expect(clerk.environment?.displayConfig.applicationName == Clerk.Environment.mock.displayConfig.applicationName)
    #expect(Clerk.engineClient == nil)
  }

  @Test
  func refreshEnvironmentThrowsWhenCachedEnvironmentIsMissing() async {
    let clerk = makeClerk()
    clerk.environment = nil

    do {
      _ = try await clerk.refreshEnvironment()
      Issue.record("Expected refreshEnvironment to throw when environment is not loaded.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Environment is not loaded.")
    } catch {
      Issue.record("Expected ClerkClientError, got \(error)")
    }
  }

  @Test
  func refreshEnvironmentCoalescesConcurrentRequests() async throws {
    let clerk = makeClerk()
    clerk.environment = .mock

    let firstRefresh = Task { @MainActor in
      try await clerk.refreshEnvironment()
    }
    let secondRefresh = Task { @MainActor in
      try await clerk.refreshEnvironment()
    }

    let first = try await firstRefresh.value
    let second = try await secondRefresh.value

    #expect(first.displayConfig.applicationName == Clerk.Environment.mock.displayConfig.applicationName)
    #expect(second.displayConfig.applicationName == Clerk.Environment.mock.displayConfig.applicationName)
    #expect(clerk.environment?.displayConfig.applicationName == Clerk.Environment.mock.displayConfig.applicationName)
  }

  @Test
  func ensureEnvironmentRefreshedAfterSatisfiedCheckpointReturnsCachedEnvironment() async throws {
    let clerk = makeClerk()
    clerk.environment = .mock
    let checkpoint = clerk.environmentRefreshCheckpoint
    _ = try await clerk.refreshEnvironment()
    let afterRefresh = clerk.environmentRefreshCheckpoint
    let environment = try await clerk.ensureEnvironmentRefreshed(after: checkpoint)

    #expect(environment.displayConfig.applicationName == Clerk.Environment.mock.displayConfig.applicationName)
    #expect(clerk.environment?.displayConfig.applicationName == Clerk.Environment.mock.displayConfig.applicationName)
    #expect(clerk.environmentRefreshCheckpoint == afterRefresh)
  }

  @Test
  func ensureEnvironmentRefreshedAfterUnsatisfiedCheckpointRequestsEnvironment() async throws {
    let clerk = makeClerk()
    clerk.environment = .mock
    let checkpoint = clerk.environmentRefreshCheckpoint
    let environment = try await clerk.ensureEnvironmentRefreshed(after: checkpoint)

    #expect(environment.displayConfig.applicationName == Clerk.Environment.mock.displayConfig.applicationName)
    #expect(clerk.environment?.displayConfig.applicationName == Clerk.Environment.mock.displayConfig.applicationName)
    #expect(clerk.environmentRefreshCheckpoint != checkpoint)
  }

  private func makeClerk() -> Clerk {
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
    )
    return clerk
  }
}

struct LiveEnvironmentDecodingTests {
  @Test
  func signUpDataDefaultsAllowlistOnlyWhenOmitted() throws {
    let data = Data("""
    {
      "captcha_enabled": true,
      "legal_consent_enabled": false,
      "mode": "public",
      "progressive": true
    }
    """.utf8)
    let signUp = try JSONDecoder.clerkDecoder.decode(SignUpData.self, from: data)
    #expect(signUp.allowlistOnly == false)
    #expect(signUp.progressive == true)
  }

  @Test
  func signUpDataDefaultsCaptchaEnabledWhenOmitted() throws {
    let data = Data("""
    {
      "legal_consent_enabled": false,
      "mode": "public",
      "progressive": true
    }
    """.utf8)
    let signUp = try JSONDecoder.clerkDecoder.decode(SignUpData.self, from: data)
    #expect(signUp.captchaEnabled == false)
    #expect(signUp.mode == .public)
  }

  @Test
  func amusingBarnacleEnvironmentJSONPublishesFirstFactorAttributes() throws {
    let url = try #require(Bundle.module.url(forResource: "amusing-barnacle-environment", withExtension: "json"))
    let environment = try JSONDecoder.clerkDecoder.decode(
      Clerk.Environment.self,
      from: Data(contentsOf: url)
    )
    #expect(!environment.displayConfig.applicationName.isEmpty)
    #expect(!environment.enabledFirstFactorAttributes.isEmpty)
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
