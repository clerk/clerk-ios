import ClerkKit
import Foundation

@MainActor enum LiveStartupProof {
  private actor MemoryStorage: CredentialStorage {
    private var value: String?
    func read() async throws -> String? {
      value
    }

    func write(_ value: String) async throws {
      self.value = value
    }

    func remove() async throws {
      value = nil
    }
  }

  private final class ReadOnlyCapabilities: NativeCapabilities {
    let delegate: AppleCapabilities
    var supported: [String] {
      delegate.supported
    }

    private(set) var reads = 0

    init(configuration: ClerkConfiguration) throws {
      delegate = try AppleCapabilities(
        publishableKey: configuration.publishableKey,
        frontendAPI: configuration.frontendAPI,
        storage: MemoryStorage(),
        authStorage: MemoryStorage()
      )
    }

    func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
      if capability == "http" {
        let args = try arguments.object()
        let method = try (args["method"] ?? .undefined).string()
        let url = try (args["url"] ?? .undefined).url()
        guard method == "GET", ["/v1/environment", "/v1/client"].contains(url.path) else {
          throw CoreError(code: "live_proof_write_forbidden")
        }
        reads += 1
      }
      return try await delegate.perform(capability, arguments: arguments)
    }
  }

  static func run() async throws {
    guard let key = ProcessInfo.processInfo.environment["CLERK_PROOF_PUBLISHABLE_KEY"], key.hasPrefix("pk_test_") else {
      throw CoreError(code: "development_publishable_key_required")
    }
    let configuration = try ClerkConfiguration(
      publishableKey: key,
      callbackURL: URL(string: "clerk-live-proof://oauth/callback")!
    )
    let capabilities = try ReadOnlyCapabilities(configuration: configuration)
    let clerk = try await Clerk.connect(configuration: configuration, capabilities: capabilities)
    defer { clerk.close() }
    precondition(clerk.loaded && !clerk.isInvalidated)
    precondition(clerk.user == nil && clerk.session == nil)
    precondition(capabilities.reads >= 2)
    print("PASS: live GET-only core startup; signed out; memory-only storage; \(capabilities.reads) permitted reads")
  }
}
