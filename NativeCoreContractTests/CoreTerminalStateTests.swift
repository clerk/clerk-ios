import ClerkKit
import Testing

@MainActor struct CoreTerminalStateTests {
  @Test func delayedCallbacksCannotPublishAfterClose() throws {
    let transport = DelayedCallbackTransport()
    let runtime = CoreRuntime(transport: transport)
    let deliver = try #require(transport.receive)
    runtime.close()
    let revision = runtime.revision

    deliver(Self.snapshot)
    deliver(Self.lifecycleError)

    #expect(!runtime.isAvailable)
    #expect(runtime.revision == revision)
    #expect(runtime.epoch == 0)
    #expect(runtime.roots.isEmpty)
    #expect(runtime.lastLifecycleError == nil)
  }

  @Test func delayedCallbacksCannotPublishAfterFatalFailure() throws {
    let transport = DelayedCallbackTransport()
    let runtime = CoreRuntime(transport: transport)
    defer { runtime.close() }
    let deliver = try #require(transport.receive)
    deliver(.object(["kind": .string("unavailable")]))
    let revision = runtime.revision

    deliver(Self.snapshot)
    deliver(Self.lifecycleError)

    #expect(!runtime.isAvailable)
    #expect(runtime.revision == revision)
    #expect(runtime.epoch == 0)
    #expect(runtime.lastLifecycleError == nil)
  }

  private static let snapshot: JSONValue = .object([
    "kind": .string("state"),
    "state": .object([
      "revision": .number(42), "epoch": .number(7), "roots": .object([:]),
      "resources": .array([]), "invalidated": .array([]),
    ]),
  ])
  private static let lifecycleError: JSONValue = .object([
    "kind": .string("lifecycleError"),
    "failure": .object(["code": .string("delayed_refresh_failure")]),
  ])
}

@MainActor private final class DelayedCallbackTransport: CoreTransport {
  var receive: (@MainActor (JSONValue) -> Void)?
  func send(_: JSONValue) throws {}
  func close() {
    receive = nil
  }
}
