//  MIT License
//
//  Copyright (c) 2017 Tomáš Znamenáček
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

// https://github.com/iwill/generic-json-swift

// swiftlint:disable all

import Foundation

// MARK: - JSON

/// A JSON value representation. This is a bit more useful than the naïve `[String:Any]` type
/// for JSON values, since it makes sure only valid JSON values are present & supports `Equatable`
/// and `Codable`, so that you can compare values for equality and code and decode them into data
/// or strings.
@_documentation(visibility: internal)
@dynamicMemberLookup public enum JSON: Equatable, Sendable {
  case string(String)
  case number(Double)
  case object([String: JSON])
  case array([JSON])
  case bool(Bool)
  case null
}

extension JSON: Codable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case let .array(array):
      try container.encode(array)
    case let .object(object):
      try container.encode(object)
    case let .string(string):
      try container.encode(string)
    case let .number(number):
      try container.encode(number)
    case let .bool(bool):
      try container.encode(bool)
    case .null:
      try container.encodeNil()
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if let object = try? container.decode([String: JSON].self) {
      self = .object(object)
    } else if let array = try? container.decode([JSON].self) {
      self = .array(array)
    } else if let string = try? container.decode(String.self) {
      self = .string(string)
    } else if let bool = try? container.decode(Bool.self) {
      self = .bool(bool)
    } else if let number = try? container.decode(Double.self) {
      self = .number(number)
    } else if container.decodeNil() {
      self = .null
    } else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Invalid JSON value.")
      )
    }
  }
}

extension JSON: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case let .string(str):
      return str.debugDescription
    case let .number(num):
      return num.debugDescription
    case let .bool(bool):
      return bool.description
    case .null:
      return "null"
    default:
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted]
      return try! String(data: encoder.encode(self), encoding: .utf8)!
    }
  }
}

extension JSON: Hashable {}

// MARK: - Initialization

private struct InitializationError: Error {}

public extension JSON {
  /// Create a JSON value from anything.
  ///
  /// Argument has to be a valid JSON structure: A `Double`, `Int`, `String`,
  /// `Bool`, an `Array` of those types or a `Dictionary` of those types.
  ///
  /// You can also pass `nil` or `NSNull`, both will be treated as `.null`.
  init(_ value: Any) throws {
    switch value {
    case _ as NSNull:
      self = .null
    case let opt as Optional<Any> where opt == nil:
      self = .null
    case let num as NSNumber:
      if num.isBool {
        self = .bool(num.boolValue)
      } else {
        self = .number(num.doubleValue)
      }
    case let str as String:
      self = .string(str)
    case let bool as Bool:
      self = .bool(bool)
    case let array as [Any]:
      self = try .array(array.map(JSON.init))
    case let dict as [String: Any]:
      self = try .object(dict.mapValues(JSON.init))
    default:
      throw InitializationError()
    }
  }
}

public extension JSON {
  /// Create a JSON value from an `Encodable`. This will give you access to the “raw”
  /// encoded JSON value the `Encodable` is serialized into.
  init(encodable: some Encodable) throws {
    let encoded = try JSONEncoder().encode(encodable)
    self = try JSONDecoder().decode(JSON.self, from: encoded)
  }
}

extension JSON: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self = .bool(value)
  }
}

extension JSON: ExpressibleByNilLiteral {
  public init(nilLiteral _: ()) {
    self = .null
  }
}

extension JSON: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: JSON...) {
    self = .array(elements)
  }
}

extension JSON: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, JSON)...) {
    var object: [String: JSON] = [:]
    for (k, v) in elements {
      object[k] = v
    }
    self = .object(object)
  }
}

extension JSON: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self = .number(value)
  }
}

extension JSON: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self = .number(Double(value))
  }
}

extension JSON: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self = .string(value)
  }
}

// MARK: - NSNumber

private extension NSNumber {
  /// Boolean value indicating whether this `NSNumber` wraps a boolean.
  ///
  /// For example, when using `NSJSONSerialization` Bool values are converted into `NSNumber` instances.
  ///
  /// - seealso: https://stackoverflow.com/a/49641315/3589408
  var isBool: Bool {
    let objCType = String(cString: objCType)
    if (compare(trueNumber) == .orderedSame && objCType == trueObjCType) || (compare(falseNumber) == .orderedSame && objCType == falseObjCType) {
      return true
    } else {
      return false
    }
  }
}

private let trueNumber = NSNumber(value: true)
private let falseNumber = NSNumber(value: false)
private let trueObjCType = String(cString: trueNumber.objCType)
private let falseObjCType = String(cString: falseNumber.objCType)

// MARK: - Merging

public extension JSON {
  /// Return a new JSON value by merging two other ones
  ///
  /// If we call the current JSON value `old` and the incoming JSON value
  /// `new`, the precise merging rules are:
  ///
  /// 1. If `old` or `new` are anything but an object, return `new`.
  /// 2. If both `old` and `new` are objects, create a merged object like this:
  ///     1. Add keys from `old` not present in `new` (“no change” case).
  ///     2. Add keys from `new` not present in `old` (“create” case).
  ///     3. For keys present in both `old` and `new`, apply merge recursively to their values (“update” case).
  func merging(with new: JSON) -> JSON {
    // If old or new are anything but an object, return new.
    guard case let .object(lhs) = self, case let .object(rhs) = new else {
      return new
    }

    var merged: [String: JSON] = [:]

    // Add keys from old not present in new (“no change” case).
    for (key, val) in lhs where rhs[key] == nil {
      merged[key] = val
    }

    // Add keys from new not present in old (“create” case).
    for (key, val) in rhs where lhs[key] == nil {
      merged[key] = val
    }

    // For keys present in both old and new, apply merge recursively to their values.
    for key in lhs.keys where rhs[key] != nil {
      merged[key] = lhs[key]?.merging(with: rhs[key]!)
    }

    return JSON.object(merged)
  }
}

// MARK: - Querying

public extension JSON {
  /// Return the string value if this is a `.string`, otherwise `nil`
  var stringValue: String? {
    if case let .string(value) = self {
      return value
    }
    return nil
  }

  /// Return the double value if this is a `.number`, otherwise `nil`
  var doubleValue: Double? {
    if case let .number(value) = self {
      return value
    }
    return nil
  }

  /// Return the bool value if this is a `.bool`, otherwise `nil`
  var boolValue: Bool? {
    if case let .bool(value) = self {
      return value
    }
    return nil
  }

  /// Return the object value if this is an `.object`, otherwise `nil`
  var objectValue: [String: JSON]? {
    if case let .object(value) = self {
      return value
    }
    return nil
  }

  /// Return the array value if this is an `.array`, otherwise `nil`
  var arrayValue: [JSON]? {
    if case let .array(value) = self {
      return value
    }
    return nil
  }

  /// Return `true` iff this is `.null`
  var isNull: Bool {
    if case .null = self {
      return true
    }
    return false
  }

  /// If this is an `.array`, return item at index
  ///
  /// If this is not an `.array` or the index is out of bounds, returns `nil`.
  subscript(index: Int) -> JSON? {
    if case let .array(arr) = self, arr.indices.contains(index) {
      return arr[index]
    }
    return nil
  }

  /// If this is an `.object`, return item at key
  subscript(key: String) -> JSON? {
    if case let .object(dict) = self {
      return dict[key]
    }
    return nil
  }

  /// Dynamic member lookup sugar for string subscripts
  ///
  /// This lets you write `json.foo` instead of `json["foo"]`.
  subscript(dynamicMember member: String) -> JSON? {
    self[member]
  }

  /// Return the JSON type at the keypath if this is an `.object`, otherwise `nil`
  ///
  /// This lets you write `json[keyPath: "foo.bar.jar"]`.
  subscript(keyPath keyPath: String) -> JSON? {
    queryKeyPath(keyPath.components(separatedBy: "."))
  }

  func queryKeyPath(_ path: some Collection<String>) -> JSON? {
    // Only object values may be subscripted
    guard case let .object(object) = self else {
      return nil
    }

    // Is the path non-empty?
    guard let head = path.first else {
      return nil
    }

    // Do we have a value at the required key?
    guard let value = object[head] else {
      return nil
    }

    let tail = path.dropFirst()

    return tail.isEmpty ? value : value.queryKeyPath(tail)
  }
}

// swiftlint:enable all
