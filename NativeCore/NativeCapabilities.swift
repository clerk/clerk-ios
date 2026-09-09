import Foundation

@MainActor public protocol NativeCapabilities: AnyObject {
  var supported: [String] { get }
  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue
}
