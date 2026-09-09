@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

@MainActor struct AppleBiometricInstallationTests {
  private let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
  private let app = "com.example.app"

  private func capabilities(_ defaults: UserDefaults, key: String? = nil, app: String? = nil, legacy: LegacyKeychainConfiguration = .init()) -> AppleBiometricCapabilities {
    AppleBiometricCapabilities(publishableKey: key ?? self.key, appIdentifier: app ?? self.app, credentials: InstallationTestStorage(), cleanup: InstallationTestStorage(), legacyKeychain: legacy, defaults: defaults)
  }

  private func current(_ capabilities: AppleBiometricCapabilities, key: String? = nil) async throws -> Bool {
    try await capabilities.perform("biometrics.installation.isCurrent", arguments: .object(["scope": .string(key ?? self.key)])).bool()
  }

  @Test func legacyMarkersRequireTheMatchingInstanceAndExactConfiguration() async throws {
    let suite = "clerk-installation-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    // Literal keys from the previous major's length-prefixed UTF-8 encoding.
    for (service, group, marker) in [
      ("a.b", "c", "s3:a.b.s1:c"),
      ("a", "b.c", "s1:a.s3:b.c"),
      ("é", " group ", "s2:é.s7: group "),
    ] {
      defaults.removePersistentDomain(forName: suite)
      defaults.set(true, forKey: "com.clerk.trusted-device-installation-marker.\(marker).s15:com.example.app")
      #expect(try await current(capabilities(defaults, legacy: .init(service: service, accessGroup: group, publishableKey: key))))
      #expect(try await !current(capabilities(defaults, legacy: .init(service: service, accessGroup: group))))
      #expect(try await !current(capabilities(defaults, legacy: .init(service: service, accessGroup: group, publishableKey: "other"))))
      #expect(try await !current(capabilities(defaults, legacy: .init(service: service, accessGroup: "wrong", publishableKey: key))))
    }
    defaults.removePersistentDomain(forName: suite)
    defaults.set(true, forKey: "com.clerk.trusted-device-installation-marker.s15:com.example.app.n.s15:com.example.app")
    #expect(try await current(capabilities(defaults, legacy: .init(publishableKey: key))))
    #expect(try await !current(capabilities(defaults, legacy: .init(accessGroup: "default", publishableKey: key))))
  }

  @Test func currentMarkersSurviveReconstructionAndRespectApplicationAndInstance() async throws {
    let suite = "clerk-installation-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let first = capabilities(defaults)
    #expect(try await !current(first))
    _ = try await first.perform("biometrics.installation.markCurrent", arguments: .object(["scope": .string(key)]))
    #expect(try await current(capabilities(defaults)))
    #expect(try await !current(capabilities(defaults, app: "com.example.other")))
    #expect(try await !current(capabilities(defaults, key: "other"), key: "other"))
    defaults.removePersistentDomain(forName: suite)
    #expect(try await !current(capabilities(defaults)))
  }

  @Test func aMismatchedScopeCannotReadOrWriteAnInstallationMarker() async throws {
    let suite = "clerk-installation-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let host = capabilities(defaults)
    for operation in ["isCurrent", "markCurrent"] {
      do {
        _ = try await host.perform("biometrics.installation.\(operation)", arguments: .object(["scope": .string("other")]))
        Issue.record("Expected scope rejection")
      } catch let error as CoreError { #expect(error.code == "invalid_storage_scope") }
    }
    #expect(try await !current(host))
  }

  @Test func packagedCoreCleansAReinstallButPreservesAnExistingInstallation() async throws {
    for existing in [false, true] {
      let suite = "clerk-installation-\(UUID())"
      let defaults = try #require(UserDefaults(suiteName: suite))
      defer { defaults.removePersistentDomain(forName: suite) }
      if existing {
        defaults.set(true, forKey: "com.clerk.trusted-device-installation-marker.s15:com.example.app.n.s15:com.example.app")
      }
      let marker = capabilities(defaults, legacy: .init(publishableKey: key))
      let fixture = try InstallationCapabilities(marker: marker, app: app)
      let callback = try #require(URL(string: "clerk-test://sso-callback"))
      let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: callback), capabilities: fixture)
      defer { clerk.close() }
      #expect(try await current(marker))
      #expect(fixture.deleted == (existing ? [] : ["key_old"]))
      #expect(try await clerk.biometricCredentials.localAvailability().isAvailable == existing)
      let records = try #require(fixture.base.biometricRecords).data(using: .utf8)
      let decoded = try JSONDecoder().decode(JSONValue.self, from: #require(records)).array()
      #expect(decoded.count == (existing ? 2 : 1))
      #expect(try decoded.last?.object()["appIdentifier"]?.string() == "com.example.other")
      // The new marker no longer depends on retaining the legacy configuration.
      #expect(try await current(capabilities(defaults)))
    }
  }
}

private actor InstallationTestStorage: CredentialStorage {
  func read() -> String? {
    nil
  }

  func write(_: String) {}
  func remove() {}
}

@MainActor private final class InstallationCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  let marker: AppleBiometricCapabilities
  let app: String
  let nativeHost: AppleCapabilities
  var deleted: [String] = []
  var supported: [String] {
    base.supported + nativeHost.supported.filter { !base.supported.contains($0) }
  }

  init(marker: AppleBiometricCapabilities, app: String) throws {
    self.marker = marker; self.app = app
    nativeHost = try AppleCapabilities(publishableKey: "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString(), frontendAPI: #require(URL(string: "https://native-core.clerk.accounts.dev")), storage: InstallationTestStorage(), biometrics: marker)
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    base.biometricRecords = #"[{"id":"td_old","localKeyId":"key_old","userId":"user_native","appIdentifier":"com.example.app","policy":"biometry_current_set","createdAt":1700000000000,"updatedAt":1700000000001},{"id":"td_other","localKeyId":"key_other","userId":"user_other","appIdentifier":"com.example.other","policy":"biometry_current_set","createdAt":1700000000000,"updatedAt":1700000000001}]"#
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    if capability.hasPrefix("biometrics.installation.") { return try await nativeHost.perform(capability, arguments: arguments) }
    if capability == "biometrics.appIdentifier" { return .string(app) }
    if capability == "biometrics.deleteKey" { try deleted.append(#require(arguments.object()["localKeyId"]).string()) }
    return try await base.perform(capability, arguments: arguments)
  }
}
