import Foundation

public indirect enum JSONValue: Sendable, Hashable, Codable {
  case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])
  public static var undefined: JSONValue {
    .object(["$undefined": .bool(true)])
  }

  public var isUndefined: Bool {
    self == .undefined
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() { self = .null }
    else if let v = try? c.decode(Bool.self) { self = .bool(v) }
    else if let v = try? c.decode(Double.self) { self = .number(v) }
    else if let v = try? c.decode(String.self) { self = .string(v) }
    else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
    else { self = try .object(c.decode([String: JSONValue].self)) }
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .null: try c.encodeNil()
    case .bool(let v): try c.encode(v)
    case .number(let v): try c.encode(v)
    case .string(let v): try c.encode(v)
    case .array(let v): try c.encode(v)
    case .object(let v): try c.encode(v)
    }
  }

  public func string() throws -> String {
    guard case .string(let v) = self else { throw CoreError.invalidValue }; return v
  }

  public func number() throws -> Double {
    guard case .number(let v) = self, v.isFinite else { throw CoreError.invalidValue }; return v
  }

  public func bool() throws -> Bool {
    guard case .bool(let v) = self else { throw CoreError.invalidValue }; return v
  }

  public func array() throws -> [JSONValue] {
    guard case .array(let v) = self else { throw CoreError.invalidValue }; return v
  }

  public func object() throws -> [String: JSONValue] {
    guard case .object(let v) = self else { throw CoreError.invalidValue }; return v
  }

  public func optional<T>(_ decode: (JSONValue) throws -> T) rethrows -> T? {
    if self == .null || isUndefined { return nil }; return try decode(self)
  }

  public func date() throws -> Date {
    let text = try string()
    guard let date = (try? Date(text, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true))) ?? (try? Date(text, strategy: .iso8601)) else { throw CoreError.invalidValue }; return date
  }

  public func url() throws -> URL {
    guard let value = try URL(string: string()) else { throw CoreError.invalidValue }; return value
  }

  public func data() throws -> Data {
    guard let data = try Data(base64Encoded: (object()["base64"] ?? .undefined).string()) else { throw CoreError.invalidValue }; return data
  }

  public func literal(_ expected: JSONValue) throws -> JSONValue {
    guard self == expected else { throw CoreError.invalidValue }; return self
  }
}

public enum Field<Value: Sendable>: Sendable {
  case omitted, null, value(Value)
  public func encode(_ encode: (Value) throws -> JSONValue) rethrows -> JSONValue {
    switch self { case .omitted: return .undefined; case .null: return .null; case .value(let v): return try encode(v) }
  }

  public static func decode(_ value: JSONValue, _ decode: (JSONValue) throws -> Value) rethrows -> Field {
    if value.isUndefined { return .omitted }; if value == .null { return .null }; return try .value(decode(value))
  }
}

extension Field: Equatable where Value: Equatable {}
extension Field: Hashable where Value: Hashable {}

public struct UploadFile: Sendable, Hashable {
  public let name: String
  public let contentType: String
  public let data: Data
  public init(name: String, contentType: String, data: Data) {
    self.name = name; self.contentType = contentType; self.data = data
  }

  public func encode() throws -> JSONValue {
    .object(["name": .string(name), "contentType": .string(contentType), "base64": .string(data.base64EncodedString())])
  }

  public static func decode(_ value: JSONValue) throws -> UploadFile {
    let v = try value.object()
    return try .init(name: (v["name"] ?? .undefined).string(), contentType: (v["contentType"] ?? .undefined).string(), data: value.data())
  }
}
