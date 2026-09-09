import Foundation
import SwiftUI
#if EMBEDDED_CORE
import ClerkKit
#endif

@main struct CoreFootprintApp: App {
  @State private var message = "Starting"
  #if EMBEDDED_CORE
  @State private var clerk: Clerk?
  #endif

  var body: some Scene {
    WindowGroup {
      Text(message)
        .task {
          do {
            try await run()
            message = "Ready"
            print("CLERK_CORE_FOOTPRINT_READY \(Bundle.main.bundleIdentifier ?? "unknown")")
            if ProcessInfo.processInfo.arguments.contains("--exit-after-ready") {
              try await Task.sleep(for: .milliseconds(250))
              exit(0)
            }
          } catch {
            message = "Failed"
            print("CLERK_CORE_FOOTPRINT_FAILED \(type(of: error))")
          }
        }
    }
  }

  @MainActor private func run() async throws {
    #if EMBEDDED_CORE
    let fixture = try StartupFixtures()
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let configuration = try ClerkConfiguration(publishableKey: key, callbackURL: URL(string: "clerk-footprint://callback")!)
    let benchmark = ProcessInfo.processInfo.arguments.contains("--benchmark")
    let liveKey = ProcessInfo.processInfo.environment["CLERK_FOOTPRINT_LIVE_KEY"]
    guard !benchmark || liveKey == nil else { throw CoreError(code: "benchmark_requires_fixture") }
    let thermalBefore = ProcessInfo.processInfo.thermalState.rawValue
    let clock = ContinuousClock()
    let start = clock.now
    // Explicit manual live mode keeps the normal secure-storage/platform factory linked.
    if let liveKey {
      clerk = try await Clerk.connect(configuration: .init(publishableKey: liveKey, callbackURL: configuration.callbackURL))
    } else {
      clerk = try await Clerk.connect(configuration: configuration, capabilities: fixture)
    }
    let startup = milliseconds(start.duration(to: clock.now))
    guard let clerk, clerk.loaded else { throw CoreError(code: "footprint_not_loaded") }
    let previous = clerk.signIn.emailCode
    try await clerk.signIn.reset()
    guard previous.isInvalidated else { throw CoreError(code: "footprint_reset_did_not_invalidate") }
    if benchmark {
      let requestCount = fixture.requestCount
      var resets: [Double] = []
      for _ in 0 ..< 10 {
        let group = clerk.signIn.emailCode
        let before = clock.now
        try await clerk.signIn.reset()
        resets.append(milliseconds(before.duration(to: clock.now)))
        guard group.isInvalidated, fixture.requestCount == requestCount else {
          throw CoreError(code: "benchmark_reset_contract_failed")
        }
      }
      let report: [String: Any] = [
        "schemaVersion": 1,
        "processID": ProcessInfo.processInfo.processIdentifier,
        "operatingSystem": ProcessInfo.processInfo.operatingSystemVersionString,
        "thermalStateBefore": thermalBefore,
        "thermalStateAfter": ProcessInfo.processInfo.thermalState.rawValue,
        "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
        "coreRevision": BundledCore.coreRevision,
        "bundleSHA256": BundledCore.sha256,
        "startupMilliseconds": startup,
        "localResetMilliseconds": resets,
        "httpRequestsAtReady": requestCount,
        "httpRequestsAfterResets": fixture.requestCount,
      ]
      let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
      print("CLERK_CORE_BENCHMARK " + String(decoding: data, as: UTF8.self))
    }
    #endif
  }

  private func milliseconds(_ duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
  }
}

#if EMBEDDED_CORE
@MainActor private final class StartupFixtures: NativeCapabilities {
  let supported = ["http", "storage", "timer", "random"]
  private let fixtures: [String: JSONValue]
  private var credential = JSONValue.null
  private(set) var requestCount = 0

  init() throws {
    guard let url = Bundle.main.url(forResource: "fapi", withExtension: "json") else { throw CoreError(code: "missing_fixture") }
    fixtures = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url)).object()
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    let args = try arguments.object()
    switch capability {
    case "storage.read": return credential
    case "storage.write": credential = args["value"] ?? .null; return .null
    case "storage.remove": credential = .null; return .null
    case "timer": try await Task.sleep(for: .milliseconds((args["milliseconds"] ?? .number(0)).number())); return .null
    case "http":
      requestCount += 1
      guard args["method"] == .string("GET"), let url = try args["url"]?.url() else { throw CoreError(code: "unexpected_fixture_request") }
      let name: String
      if url.path.hasSuffix("/environment") { name = "environment" }
      else if url.path.hasSuffix("/client") { name = "client" }
      else { throw CoreError(code: "unexpected_fixture_path") }
      let body = try JSONEncoder().encode(JSONValue.object(["response": fixtures[name] ?? .null]))
      return .object(["status": .number(200), "headers": .object(name == "client" ? ["authorization": .string("fixture-client-credential")] : [:]), "body": .string(String(decoding: body, as: UTF8.self))])
    default: throw CoreError(code: "unexpected_fixture_capability")
    }
  }
}
#endif
