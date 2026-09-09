import ClerkKit
import Foundation

@MainActor enum BenchmarkProof {
  static func run(output: String) async throws {
    guard let fixtureURL = Bundle.module.url(forResource: "fapi", withExtension: "json", subdirectory: "Fixtures") else {
      throw CoreError(code: "missing_benchmark_fixture")
    }
    let data = try Data(contentsOf: fixtureURL)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let configuration = try ClerkConfiguration(publishableKey: key, callbackURL: URL(string: "clerk-test://sso-callback")!)
    let clock = ContinuousClock()
    var startup: [Double] = []
    var calls: [Double] = []
    for _ in 0 ..< 12 {
      let capabilities = try FixtureCapabilities(data: data)
      let before = clock.now
      let clerk = try await Clerk.connect(configuration: configuration, capabilities: capabilities)
      startup.append(milliseconds(before.duration(to: clock.now)))
      do {
        guard clerk.loaded else { throw CoreError(code: "benchmark_owner_not_loaded") }
        try await clerk.signIn.reset()
        let requestCount = capabilities.requests.count
        for _ in 0 ..< 25 {
          let prior = clerk.signIn.emailCode
          let start = clock.now
          try await clerk.signIn.reset()
          calls.append(milliseconds(start.duration(to: clock.now)))
          guard prior.isInvalidated, capabilities.requests.count == requestCount else {
            throw CoreError(code: "benchmark_reset_contract_failed")
          }
        }
        clerk.close()
      } catch { clerk.close(); throw error }
    }
    #if DEBUG
    let buildType = "debug"
    #else
    let buildType = "release"
    #endif
    let report: [String: Any] = [
      "schemaVersion": 1,
      "buildType": buildType,
      "platform": ProcessInfo.processInfo.operatingSystemVersionString,
      "engine": "JavaScriptCore (system)",
      "coreRevision": BundledCore.coreRevision,
      "bundleSHA256": BundledCore.sha256,
      "fixture": "packaged FAPI JSON; in-memory HTTP and storage; no service or platform prompts",
      "startupDefinition": "connect: bundled resource read, hash verification, fresh engine, core load, fixture HTTP and initial native projection",
      "operationDefinition": "generated signIn.reset: local core mutation, handle invalidation and full state projection; no HTTP",
      "startupMilliseconds": startup,
      "localResetMilliseconds": calls,
      "startupSummary": summary(startup),
      "localResetSummary": summary(calls),
      "limitations": ["repeated fresh engines in one warm process", "first startup sample is reported separately", "not a cold application launch", "fixture timing excludes real HTTP and secure storage", "no agreed performance budgets"],
    ]
    let outputURL = URL(fileURLWithPath: output)
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: outputURL)
    print("BENCHMARK: wrote \(startup.count) fresh-engine starts and \(calls.count) generated local resets to \(output)")
  }

  private static func milliseconds(_ duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
  }

  private static func summary(_ values: [Double]) -> [String: Double] {
    let sorted = values.sorted()
    return ["first": values[0], "minimum": sorted[0], "median": sorted[sorted.count / 2], "p95": sorted[Int(ceil(Double(sorted.count) * 0.95)) - 1], "maximum": sorted.last!]
  }
}
