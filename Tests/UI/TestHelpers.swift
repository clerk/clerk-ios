#if os(iOS) || os(macOS)

import ClerkKit
@testable import ClerkKitUI

/// Changes test inputs through the same generated state decoder used by the core transport.
@MainActor
func setTestResourceState(
  _ resource: any CoreResource,
  encoded: JSONValue,
  path: [String],
  value: JSONValue
) {
  func replacing(_ original: JSONValue, at path: ArraySlice<String>) -> JSONValue {
    guard let key = path.first else { return value }
    var object = try! original.object()
    object[key] = replacing(object[key] ?? .object([:]), at: path.dropFirst())
    return .object(object)
  }
  let runtime = try! resource.context.requireRuntime()
  runtime.receive(.object([
    "kind": .string("state"),
    "state": .object([
      "revision": .number(Double(runtime.revision + 1)),
      "epoch": .number(Double(runtime.epoch)),
      "roots": .object(runtime.roots.mapValues(\.json)),
      "resources": .array([.object([
        "handle": resource.handle.json,
        "state": replacing(encoded, at: path[...]),
      ])]),
      "invalidated": .array([]),
    ]),
  ]))
  precondition(runtime.isAvailable, "Test state must satisfy the generated contract")
}

@MainActor
func setTestEnvironment(_ clerk: Clerk, _ path: [String], _ value: JSONValue) {
  setTestResourceState(clerk.environment, encoded: try! clerk.environment.state.encode(), path: path, value: value)
}

#endif
