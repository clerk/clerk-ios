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

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      environmentService: service
    )

    _ = try await Clerk.shared.refreshEnvironment()

    #expect(called.value == true)
    #expect(Clerk.shared.environment == expectedEnvironment)
  }

  @Test
  func environmentDecodesWhenFraudSettingsAreMissing() throws {
    let decoded = try decodeEnvironmentRemovingKeys(["fraud_settings"])

    #expect(decoded.fraudSettings == .init())
  }

  @Test
  func environmentDecodesWhenDeviceAttestationModeIsMissing() throws {
    let decoded = try decodeEnvironmentRemovingKeys(["fraud_settings", "native", "device_attestation_mode"])

    #expect(decoded.fraudSettings == .init())
  }

  private func decodeEnvironmentRemovingKeys(_ keyPath: [String]) throws -> Clerk.Environment {
    let data = try JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock)
    var jsonObject = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    removeValue(at: keyPath, from: &jsonObject)
    let modifiedData = try JSONSerialization.data(withJSONObject: jsonObject)
    return try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: modifiedData)
  }

  private func removeValue(at keyPath: [String], from dictionary: inout [String: Any]) {
    guard let firstKey = keyPath.first else { return }

    if keyPath.count == 1 {
      dictionary.removeValue(forKey: firstKey)
      return
    }

    guard var nestedDictionary = dictionary[firstKey] as? [String: Any] else { return }
    removeValue(at: Array(keyPath.dropFirst()), from: &nestedDictionary)
    dictionary[firstKey] = nestedDictionary
  }
}
