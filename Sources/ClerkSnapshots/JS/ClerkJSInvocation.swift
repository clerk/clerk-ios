import Foundation

public protocol ClerkJSCallable: Sendable {
  var jsMethod: String { get }
  func jsArguments() throws -> [JSONValue]
}

public struct ClerkJSInvocation: Hashable, Sendable, Encodable {
  public var receiver: ClerkJSReceiver
  public var method: String
  public var arguments: [JSONValue]

  public init(_ receiver: ClerkJSReceiver, _ call: some ClerkJSCallable) throws {
    self.receiver = receiver
    method = call.jsMethod
    arguments = try call.jsArguments()
  }

  public init(receiver: ClerkJSReceiver, method: String, arguments: [JSONValue]) {
    self.receiver = receiver
    self.method = method
    self.arguments = arguments
  }
}

public struct JSRawCall: ClerkJSCallable {
  public var jsMethod: String
  public var rawArguments: [JSONValue]

  public init(_ method: String, _ arguments: JSONValue...) {
    jsMethod = method
    rawArguments = arguments
  }

  public func jsArguments() throws -> [JSONValue] {
    rawArguments
  }
}

extension JSONValue {
  public init(encoding value: some Encodable) throws {
    let data = try JSONEncoder().encode(value)
    self = try JSONDecoder().decode(JSONValue.self, from: data)
  }

  public func data() throws -> Data {
    try JSONEncoder().encode(self)
  }
}
