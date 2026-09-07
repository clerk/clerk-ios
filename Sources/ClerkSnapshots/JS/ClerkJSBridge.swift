import Foundation

@MainActor
public protocol ClerkJSBridge: AnyObject {
  func load() async throws
  func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue
}
