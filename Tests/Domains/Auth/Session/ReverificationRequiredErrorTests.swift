@testable import ClerkKit
import Foundation
import Testing

struct ReverificationRequiredErrorTests {
  @Test(arguments: [
    ("strict_mfa", ReverificationConfig.strictMfa),
    ("strict", .strict),
    ("moderate", .moderate),
    ("lax", .lax),
  ])
  func readsANamedRequirement(name: String, config: ReverificationConfig) throws {
    let error = try #require(ReverificationRequiredError(responseBody: body(reverification: "\"\(name)\"")))

    #expect(error.reverification == config)
  }

  @Test
  func readsACustomRequirement() throws {
    let error = try #require(
      ReverificationRequiredError(responseBody: body(reverification: #"{"level": "first_factor", "afterMinutes": 5}"#))
    )

    #expect(error.reverification == .custom(level: .firstFactor, afterMinutes: 5))
  }

  @Test(arguments: [
    #""forever""#,
    #"{"level": "third_factor", "afterMinutes": 5}"#,
    #"{"level": "first_factor", "afterMinutes": 0}"#,
    "null",
  ])
  func keepsTheErrorButDropsARequirementItCannotRead(reverification: String) throws {
    let error = try #require(ReverificationRequiredError(responseBody: body(reverification: reverification)))

    #expect(error.reverification == nil)
  }

  @Test(arguments: [
    #"{"clerk_error": {"type": "forbidden", "reason": "missing-permission"}}"#,
    #"{"clerk_error": {"type": "unauthorized", "reason": "reverification-error"}}"#,
    #"{"errors": [{"code": "session_reverification_required"}]}"#,
    "not json",
  ])
  func ignoresOtherBodies(body: String) {
    #expect(ReverificationRequiredError(responseBody: Data(body.utf8)) == nil)
  }

  @Test
  func recognizesClerksReverificationError() throws {
    let error = try #require(ReverificationRequiredError(ClerkAPIError(code: "session_reverification_required")))

    #expect(error.reverification == nil)
    #expect(ReverificationRequiredError(ClerkAPIError(code: "form_password_incorrect")) == nil)
    #expect(ReverificationRequiredError(CancellationError()) == nil)
  }

  @Test(arguments: [
    (ReverificationConfig.strictMfa, SessionVerification.Level.multiFactor, 10),
    (.strict, .secondFactor, 10),
    (.moderate, .secondFactor, 60),
    (.lax, .secondFactor, 1440),
    (.custom(level: .firstFactor, afterMinutes: 5), .firstFactor, 5),
  ])
  func requirementsMatchTheAuthorizationCheck(config: ReverificationConfig, level: SessionVerification.Level, afterMinutes: Int) throws {
    let requirement = try #require(config.requirement)

    #expect(requirement.level == level)
    #expect(requirement.afterMinutes == afterMinutes)
  }

  @Test
  func anInvalidCustomConfigHasNoRequirement() {
    #expect(ReverificationConfig.custom(level: .unknown("x"), afterMinutes: 5).requirement == nil)
    #expect(ReverificationConfig.custom(level: .firstFactor, afterMinutes: -1).requirement == nil)
  }

  private func body(reverification: String) -> Data {
    Data(#"{"clerk_error": {"type": "forbidden", "reason": "reverification-error", "metadata": {"reverification": \#(reverification)}}}"#.utf8)
  }
}
