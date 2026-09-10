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
            if let error = error as? MemoryProbeError { print("CLERK_MEMORY_FAILURE \(error)") }
            if ProcessInfo.processInfo.arguments.contains("--exit-after-ready") { exit(1) }
          }
        }
    }
  }

  @MainActor private func run() async throws {
    if ProcessInfo.processInfo.arguments.contains("--memory") || ProcessInfo.processInfo.arguments.contains("--memory-stress") {
      try await runMemoryMeasurement(stress: ProcessInfo.processInfo.arguments.contains("--memory-stress"))
      return
    }
    #if EMBEDDED_CORE
    let benchmark = ProcessInfo.processInfo.arguments.contains("--benchmark")
    let fixture = try StartupFixtures(authenticated: benchmark)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let configuration = try ClerkConfiguration(publishableKey: key, callbackURL: URL(string: "clerk-footprint://callback")!)
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
    if benchmark, clerk.session?.id != "sess_native" || clerk.user?.id != "user_native" {
      throw CoreError(code: "benchmark_requires_authenticated_projection")
    }
    let session = clerk.session
    let user = clerk.user
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
        guard group.isInvalidated, fixture.requestCount == requestCount,
              clerk.session === session, clerk.user === user
        else {
          throw CoreError(code: "benchmark_reset_contract_failed")
        }
      }
      let report: [String: Any] = [
        "schemaVersion": 2,
        "authenticatedAtReady": clerk.session?.id == "sess_native" && clerk.user?.id == "user_native",
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

  @MainActor private func runMemoryMeasurement(stress: Bool) async throws {
    guard ProcessInfo.processInfo.environment["CLERK_FOOTPRINT_LIVE_KEY"] == nil else {
      throw MemoryProbeError.invalidConfiguration
    }
    let cycleCount = stress ? 12 : 1
    let sampler = ProcessMemorySampler(capacity: stress ? 40000 : 10000)
    var cycleAssertions: [[String: Any]] = []
    sampler.start()
    defer { sampler.stop() }
    let thermalBefore = ProcessInfo.processInfo.thermalState.rawValue
    try await Task.sleep(for: .seconds(1))
    for cycle in 1 ... cycleCount {
      func phase(_ name: String) {
        sampler.phase(stress ? "cycle-\(cycle)-\(name)" : name)
      }
      phase("startup")
      let clock = ContinuousClock()
      let startup = clock.now
      #if EMBEDDED_CORE
      var fixture: StartupFixtures? = try StartupFixtures(authenticated: true)
      let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
      clerk = try await Clerk.connect(
        configuration: .init(publishableKey: key, callbackURL: URL(string: "clerk-footprint://callback")!),
        capabilities: fixture!
      )
      guard clerk?.session?.id == "sess_native", clerk?.user?.id == "user_native" else {
        throw MemoryProbeError.invalidOwner
      }
      #endif
      let startupDuration = startup.duration(to: clock.now)
      if startupDuration < .milliseconds(250) {
        try await Task.sleep(for: .milliseconds(250) - startupDuration)
      }
      phase("warmup")
      let warmup = clock.now
      #if EMBEDDED_CORE
      let requests = fixture!.requestCount
      for _ in 0 ..< 50 {
        let previous = clerk?.signIn.emailCode
        try await clerk?.signIn.reset()
        guard previous?.isInvalidated == true, fixture?.requestCount == requests,
              clerk?.session?.id == "sess_native", clerk?.user?.id == "user_native"
        else {
          throw MemoryProbeError.invalidOwner
        }
      }
      #endif
      if stress, warmup.duration(to: clock.now) < .milliseconds(500) {
        try await Task.sleep(for: .milliseconds(500) - warmup.duration(to: clock.now))
      }
      phase("steadyWait")
      try await Task.sleep(for: stress ? .seconds(1) : .seconds(3))
      phase("steady")
      try await Task.sleep(for: stress ? .milliseconds(500) : .seconds(1))
      phase("close")
      #if EMBEDDED_CORE
      weak var releasedOwner = clerk
      weak var releasedRuntime = try clerk?.context.requireRuntime()
      clerk?.close()
      clerk = nil
      fixture = nil
      #endif
      phase("closedWait")
      try await Task.sleep(for: stress ? .milliseconds(1500) : .seconds(5))
      phase("closed")
      try await Task.sleep(for: stress ? .milliseconds(500) : .seconds(1))
      #if EMBEDDED_CORE
      guard releasedOwner == nil else { throw MemoryProbeError.ownerStillRetained }
      guard releasedRuntime == nil else { throw MemoryProbeError.runtimeStillRetained }
      cycleAssertions.append(["cycle": cycle, "authenticatedAtReady": true,
                              "ownerReleasedAfterClose": true, "runtimeReleasedAfterClose": true,
                              "warmupResets": 50, "httpRequestsAfterWarmup": requests])
      #endif
    }
    let samples = try sampler.finish()
    var report: [String: Any] = [
      "schemaVersion": 1,
      "processID": ProcessInfo.processInfo.processIdentifier,
      "operatingSystem": ProcessInfo.processInfo.operatingSystemVersionString,
      "thermalStateBefore": thermalBefore,
      "thermalStateAfter": ProcessInfo.processInfo.thermalState.rawValue,
      "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
      "requestedSampleIntervalMilliseconds": 5,
      "mode": stress ? "stress" : "single",
      "cycleCount": cycleCount,
      "cycleAssertions": cycleAssertions,
      "forcedCollection": false,
      "samples": samples.map(\.dictionary),
    ]
    #if EMBEDDED_CORE
    report["variant"] = "embedded"
    report["ownerCount"] = 1
    report["authenticatedAtReady"] = true
    report["ownerReleasedAfterClose"] = true
    report["warmupResets"] = 50 * cycleCount
    report["httpRequestsAfterWarmup"] = cycleAssertions.last!["httpRequestsAfterWarmup"]
    report["coreRevision"] = BundledCore.coreRevision
    report["bundleSHA256"] = BundledCore.sha256
    #else
    report["variant"] = "baseline"
    report["ownerCount"] = 0
    report["warmupResets"] = 0
    #endif
    let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
    let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    try data.write(to: directory.appendingPathComponent(stress ? "core-memory-stress.json" : "core-memory.json"), options: .atomic)
    print("\(stress ? "CLERK_CORE_MEMORY_STRESS_WRITTEN" : "CLERK_CORE_MEMORY_WRITTEN") \(samples.count)")
  }
}

private enum MemoryProbeError: Error {
  case invalidConfiguration, invalidOwner, ownerStillRetained, runtimeStillRetained, samplingFailed
}

/// The timer and all mutable sample storage are confined to this private queue.
private final class ProcessMemorySampler: @unchecked Sendable {
  struct Sample {
    let elapsedNanoseconds: UInt64
    let phase: String
    let footprint: UInt64
    let resident: UInt64
    let footprintLifetimePeak: Int64
    let internalBytes: UInt64
    let externalBytes: UInt64
    let compressedBytes: UInt64
    var dictionary: [String: Any] {
      ["elapsedNanoseconds": elapsedNanoseconds, "phase": phase,
       "physicalFootprintBytes": footprint, "residentBytes": resident,
       "processLifetimeFootprintPeakBytes": footprintLifetimePeak,
       "internalBytes": internalBytes, "externalBytes": externalBytes,
       "compressedBytes": compressedBytes]
    }
  }

  private let queue = DispatchQueue(label: "com.clerk.nativecore.memory-sampler", qos: .userInitiated)
  private var timer: DispatchSourceTimer?
  private var samples: [Sample] = []
  private var currentPhase = "before"
  private var failed = false
  private var origin: UInt64 = 0
  private let capacity: Int
  init(capacity: Int) {
    self.capacity = capacity
  }

  func start() {
    queue.sync {
      samples.reserveCapacity(capacity)
      origin = DispatchTime.now().uptimeNanoseconds
      sample()
      let timer = DispatchSource.makeTimerSource(queue: queue)
      timer.schedule(deadline: .now(), repeating: .milliseconds(5), leeway: .milliseconds(1))
      timer.setEventHandler { [weak self] in self?.sample() }
      self.timer = timer
      timer.resume()
    }
  }

  func phase(_ phase: String) {
    queue.sync {
      sample()
      currentPhase = phase
      sample()
    }
  }

  func stop() {
    queue.sync { timer?.cancel(); timer = nil }
  }

  func finish() throws -> [Sample] {
    try queue.sync {
      timer?.cancel()
      timer = nil
      guard !failed, !samples.isEmpty else { throw MemoryProbeError.samplingFailed }
      return samples
    }
  }

  private func sample() {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    guard result == KERN_SUCCESS else { failed = true; return }
    samples.append(Sample(
      elapsedNanoseconds: DispatchTime.now().uptimeNanoseconds - origin,
      phase: currentPhase, footprint: info.phys_footprint, resident: info.resident_size,
      footprintLifetimePeak: info.ledger_phys_footprint_peak, internalBytes: info.internal,
      externalBytes: info.external, compressedBytes: info.compressed
    ))
  }
}

#if EMBEDDED_CORE
@MainActor private final class StartupFixtures: NativeCapabilities {
  let supported = ["http", "storage", "timer", "random"]
  private var fixtures: [String: JSONValue]
  private var credential = JSONValue.null
  private(set) var requestCount = 0

  init(authenticated: Bool) throws {
    guard let url = Bundle.main.url(forResource: "fapi", withExtension: "json") else { throw CoreError(code: "missing_fixture") }
    fixtures = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url)).object()
    if authenticated {
      func encoded(_ value: [String: JSONValue]) throws -> String {
        try JSONEncoder().encode(JSONValue.object(value)).base64EncodedString()
          .replacingOccurrences(of: "=", with: "")
          .replacingOccurrences(of: "+", with: "-")
          .replacingOccurrences(of: "/", with: "_")
      }
      let now = Date().timeIntervalSince1970.rounded(.down)
      let header = try encoded(["alg": .string("RS256"), "typ": .string("JWT")])
      let payload = try encoded(["sub": .string("user_native"), "sid": .string("sess_native"),
                                 "iat": .number(now), "exp": .number(now + 3600),
                                 "iss": .string("https://native-core.clerk.accounts.dev")])
      let token = JSONValue.object(["object": .string("token"), "jwt": .string("\(header).\(payload).fixture_signature")])
      var client = try fixtures["authenticatedClient"]!.object()
      guard case .array(var sessions) = client["sessions"], !sessions.isEmpty else {
        throw CoreError(code: "missing_authenticated_fixture")
      }
      var session = try sessions[0].object()
      session["last_active_token"] = token
      sessions[0] = .object(session)
      client["sessions"] = .array(sessions)
      fixtures["client"] = .object(client)
    }
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
