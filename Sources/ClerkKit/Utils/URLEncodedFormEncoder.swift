//
//  URLEncodedFormEncoder.swift
//
//  Copyright (c) 2019 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

// swiftlint:disable all

import Foundation

final class URLEncodedFormEncoder {
  enum ArrayEncoding {
    case brackets
    case noBrackets
    case indexInBrackets
    case custom((_ key: String, _ index: Int) -> String)

    func encode(_ key: String, atIndex index: Int) -> String {
      switch self {
      case .brackets: "\(key)[]"
      case .noBrackets: key
      case .indexInBrackets: "\(key)[\(index)]"
      case let .custom(encoding): encoding(key, index)
      }
    }
  }

  enum BoolEncoding {
    case numeric
    case literal

    func encode(_ value: Bool) -> String {
      switch self {
      case .numeric: value ? "1" : "0"
      case .literal: value ? "true" : "false"
      }
    }
  }

  enum DataEncoding {
    case deferredToData
    case base64
    case custom((Data) throws -> String)

    /// Encodes `Data` according to the encoding.
    ///
    /// - Parameter data: The `Data` to encode.
    ///
    /// - Returns:        The encoded `String`, or `nil` if the `Data` should be encoded according to its
    ///                   `Encodable` implementation.
    func encode(_ data: Data) throws -> String? {
      switch self {
      case .deferredToData: nil
      case .base64: data.base64EncodedString()
      case let .custom(encoding): try encoding(data)
      }
    }
  }

  enum DateEncoding {
    private static let iso8601Formatter = Protected<ISO8601DateFormatter>(
      {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = .withInternetDateTime
        return formatter
      }()
    )

    case deferredToDate
    case secondsSince1970
    case millisecondsSince1970
    case iso8601
    case formatted(DateFormatter)
    case custom((Date) throws -> String)

    /// Encodes the date according to the encoding.
    ///
    /// - Parameter date: The `Date` to encode.
    ///
    /// - Returns:        The encoded `String`, or `nil` if the `Date` should be encoded according to its
    ///                   `Encodable` implementation.
    func encode(_ date: Date) throws -> String? {
      switch self {
      case .deferredToDate:
        nil
      case .secondsSince1970:
        String(date.timeIntervalSince1970)
      case .millisecondsSince1970:
        String(date.timeIntervalSince1970 * 1000.0)
      case .iso8601:
        DateEncoding.iso8601Formatter.read { $0.string(from: date) }
      case let .formatted(formatter):
        formatter.string(from: date)
      case let .custom(closure):
        try closure(date)
      }
    }
  }

  enum KeyEncoding {
    case useDefaultKeys
    /// Convert from "camelCaseKeys" to "snake_case_keys" before writing a key.
    ///
    /// Capital characters are determined by testing membership in
    /// `CharacterSet.uppercaseLetters` and `CharacterSet.lowercaseLetters`
    /// (Unicode General Categories Lu and Lt).
    /// The conversion to lower case uses `Locale.system`, also known as
    /// the ICU "root" locale. This means the result is consistent
    /// regardless of the current user's locale and language preferences.
    ///
    /// Converting from camel case to snake case:
    /// 1. Splits words at the boundary of lower-case to upper-case
    /// 2. Inserts `_` between words
    /// 3. Lowercases the entire string
    /// 4. Preserves starting and ending `_`.
    ///
    /// For example, `oneTwoThree` becomes `one_two_three`. `_oneTwoThree_` becomes `_one_two_three_`.
    ///
    /// - Note: Using a key encoding strategy has a nominal performance cost, as each string key has to be converted.
    case convertToSnakeCase
    case convertToKebabCase
    case capitalized
    case uppercased
    case lowercased
    case custom((String) -> String)

    func encode(_ key: String) -> String {
      switch self {
      case .useDefaultKeys: key
      case .convertToSnakeCase: convertToSnakeCase(key)
      case .convertToKebabCase: convertToKebabCase(key)
      case .capitalized: String(key.prefix(1).uppercased() + key.dropFirst())
      case .uppercased: key.uppercased()
      case .lowercased: key.lowercased()
      case let .custom(encoding): encoding(key)
      }
    }

    private func convertToSnakeCase(_ key: String) -> String {
      convert(key, usingSeparator: "_")
    }

    private func convertToKebabCase(_ key: String) -> String {
      convert(key, usingSeparator: "-")
    }

    private func convert(_ key: String, usingSeparator separator: String) -> String {
      guard !key.isEmpty else { return key }

      var words: [Range<String.Index>] = []
      // The general idea of this algorithm is to split words on
      // transition from lower to upper case, then on transition of >1
      // upper case characters to lowercase
      //
      // myProperty -> my_property
      // myURLProperty -> my_url_property
      //
      // It is assumed, per Swift naming conventions, that the first character of the key is lowercase.
      var wordStart = key.startIndex
      var searchRange = key.index(after: wordStart) ..< key.endIndex

      while let upperCaseRange = key.rangeOfCharacter(from: .uppercaseLetters, options: [], range: searchRange) {
        let untilUpperCase = wordStart ..< upperCaseRange.lowerBound
        words.append(untilUpperCase)

        searchRange = upperCaseRange.lowerBound ..< searchRange.upperBound
        guard let lowerCaseRange = key.rangeOfCharacter(from: .lowercaseLetters, options: [], range: searchRange) else {
          wordStart = searchRange.lowerBound
          break
        }

        // Is the next lowercase letter more than 1 after the uppercase?
        // If so, we encountered a group of uppercase letters that we
        // should treat as its own word
        let nextCharacterAfterCapital = key.index(after: upperCaseRange.lowerBound)
        if lowerCaseRange.lowerBound == nextCharacterAfterCapital {
          // The next character after capital is a lower case character and therefore not a word boundary.
          // Continue searching for the next upper case for the boundary.
          wordStart = upperCaseRange.lowerBound
        } else {
          // There was a range of >1 capital letters. Turn those into a word, stopping at the capital before
          // the lower case character.
          let beforeLowerIndex = key.index(before: lowerCaseRange.lowerBound)
          words.append(upperCaseRange.lowerBound ..< beforeLowerIndex)

          // Next word starts at the capital before the lowercase we just found
          wordStart = beforeLowerIndex
        }
        searchRange = lowerCaseRange.upperBound ..< searchRange.upperBound
      }
      words.append(wordStart ..< searchRange.upperBound)
      return words.map { range in
        key[range].lowercased()
      }.joined(separator: separator)
    }
  }

  struct KeyPathEncoding {
    static let brackets = KeyPathEncoding { "[\($0)]" }
    static let dots = KeyPathEncoding { ".\($0)" }

    private let encoding: @Sendable (_ subkey: String) -> String

    init(encoding: @escaping @Sendable (_ subkey: String) -> String) {
      self.encoding = encoding
    }

    func encodeKeyPath(_ keyPath: String) -> String {
      encoding(keyPath)
    }
  }

  struct NilEncoding {
    static let dropKey = NilEncoding { nil }
    static let dropValue = NilEncoding { "" }
    static let null = NilEncoding { "null" }

    private let encoding: @Sendable () -> String?

    init(encoding: @escaping @Sendable () -> String?) {
      self.encoding = encoding
    }

    func encodeNil() -> String? {
      encoding()
    }
  }

  enum SpaceEncoding {
    case percentEscaped
    case plusReplaced

    func encode(_ string: String) -> String {
      switch self {
      case .percentEscaped: string.replacingOccurrences(of: " ", with: "%20")
      case .plusReplaced: string.replacingOccurrences(of: " ", with: "+")
      }
    }
  }

  enum Error: Swift.Error {
    case invalidRootObject(String)

    var localizedDescription: String {
      switch self {
      case let .invalidRootObject(object):
        "URLEncodedFormEncoder requires keyed root object. Received \(object) instead."
      }
    }
  }

  /// Whether or not to sort the encoded key value pairs.
  ///
  /// - Note: This setting ensures a consistent ordering for all encodings of the same parameters. When set to `false`,
  ///         encoded `Dictionary` values may have a different encoded order each time they're encoded due to
  ///       ` Dictionary`'s random storage order, but `Encodable` types will maintain their encoded order.
  let alphabetizeKeyValuePairs: Bool
  let arrayEncoding: ArrayEncoding
  let boolEncoding: BoolEncoding
  let dataEncoding: DataEncoding
  let dateEncoding: DateEncoding
  let keyEncoding: KeyEncoding
  let keyPathEncoding: KeyPathEncoding
  let nilEncoding: NilEncoding
  let spaceEncoding: SpaceEncoding
  var allowedCharacters: CharacterSet

  init(
    alphabetizeKeyValuePairs: Bool = true,
    arrayEncoding: ArrayEncoding = .brackets,
    boolEncoding: BoolEncoding = .numeric,
    dataEncoding: DataEncoding = .base64,
    dateEncoding: DateEncoding = .deferredToDate,
    keyEncoding: KeyEncoding = .useDefaultKeys,
    keyPathEncoding: KeyPathEncoding = .brackets,
    nilEncoding: NilEncoding = .dropKey,
    spaceEncoding: SpaceEncoding = .percentEscaped,
    allowedCharacters: CharacterSet = .afURLQueryAllowed
  ) {
    self.alphabetizeKeyValuePairs = alphabetizeKeyValuePairs
    self.arrayEncoding = arrayEncoding
    self.boolEncoding = boolEncoding
    self.dataEncoding = dataEncoding
    self.dateEncoding = dateEncoding
    self.keyEncoding = keyEncoding
    self.keyPathEncoding = keyPathEncoding
    self.nilEncoding = nilEncoding
    self.spaceEncoding = spaceEncoding
    self.allowedCharacters = allowedCharacters
  }

  func encode(_ value: any Encodable) throws -> URLEncodedFormComponent {
    let context = URLEncodedFormContext(.object([]))
    let encoder = _URLEncodedFormEncoder(
      context: context,
      boolEncoding: boolEncoding,
      dataEncoding: dataEncoding,
      dateEncoding: dateEncoding,
      nilEncoding: nilEncoding
    )
    try value.encode(to: encoder)

    return context.component
  }

  func encode(_ value: any Encodable) throws -> String {
    let component: URLEncodedFormComponent = try encode(value)

    guard case let .object(object) = component else {
      throw Error.invalidRootObject("\(component)")
    }

    let serializer = URLEncodedFormSerializer(
      alphabetizeKeyValuePairs: alphabetizeKeyValuePairs,
      arrayEncoding: arrayEncoding,
      keyEncoding: keyEncoding,
      keyPathEncoding: keyPathEncoding,
      spaceEncoding: spaceEncoding,
      allowedCharacters: allowedCharacters
    )
    return serializer.serialize(object)
  }

  func encode(_ value: any Encodable) throws -> Data {
    let string: String = try encode(value)

    return Data(string.utf8)
  }
}

final class _URLEncodedFormEncoder {
  var codingPath: [any CodingKey]
  var userInfo: [CodingUserInfoKey: Any] {
    [:]
  }

  let context: URLEncodedFormContext

  private let boolEncoding: URLEncodedFormEncoder.BoolEncoding
  private let dataEncoding: URLEncodedFormEncoder.DataEncoding
  private let dateEncoding: URLEncodedFormEncoder.DateEncoding
  private let nilEncoding: URLEncodedFormEncoder.NilEncoding

  init(
    context: URLEncodedFormContext,
    codingPath: [any CodingKey] = [],
    boolEncoding: URLEncodedFormEncoder.BoolEncoding,
    dataEncoding: URLEncodedFormEncoder.DataEncoding,
    dateEncoding: URLEncodedFormEncoder.DateEncoding,
    nilEncoding: URLEncodedFormEncoder.NilEncoding
  ) {
    self.context = context
    self.codingPath = codingPath
    self.boolEncoding = boolEncoding
    self.dataEncoding = dataEncoding
    self.dateEncoding = dateEncoding
    self.nilEncoding = nilEncoding
  }
}

extension _URLEncodedFormEncoder: Encoder {
  func container<Key: CodingKey>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> {
    let container = _URLEncodedFormEncoder.KeyedContainer<Key>(
      context: context,
      codingPath: codingPath,
      boolEncoding: boolEncoding,
      dataEncoding: dataEncoding,
      dateEncoding: dateEncoding,
      nilEncoding: nilEncoding
    )
    return KeyedEncodingContainer(container)
  }

  func unkeyedContainer() -> any UnkeyedEncodingContainer {
    _URLEncodedFormEncoder.UnkeyedContainer(
      context: context,
      codingPath: codingPath,
      boolEncoding: boolEncoding,
      dataEncoding: dataEncoding,
      dateEncoding: dateEncoding,
      nilEncoding: nilEncoding
    )
  }

  func singleValueContainer() -> any SingleValueEncodingContainer {
    _URLEncodedFormEncoder.SingleValueContainer(
      context: context,
      codingPath: codingPath,
      boolEncoding: boolEncoding,
      dataEncoding: dataEncoding,
      dateEncoding: dateEncoding,
      nilEncoding: nilEncoding
    )
  }
}

final class URLEncodedFormContext {
  var component: URLEncodedFormComponent

  init(_ component: URLEncodedFormComponent) {
    self.component = component
  }
}

enum URLEncodedFormComponent {
  typealias Object = [(key: String, value: URLEncodedFormComponent)]

  case string(String)
  case array([URLEncodedFormComponent])
  case object(Object)

  var array: [URLEncodedFormComponent]? {
    switch self {
    case let .array(array): array
    default: nil
    }
  }

  var object: Object? {
    switch self {
    case let .object(object): object
    default: nil
    }
  }

  mutating func set(to value: URLEncodedFormComponent, at path: [any CodingKey]) {
    set(&self, to: value, at: path)
  }

  private func set(_ context: inout URLEncodedFormComponent, to value: URLEncodedFormComponent, at path: [any CodingKey]) {
    guard !path.isEmpty else {
      context = value
      return
    }

    let end = path[0]
    var child: URLEncodedFormComponent
    switch path.count {
    case 1:
      child = value
    case 2...:
      if let index = end.intValue {
        let array = context.array ?? []
        if array.count > index {
          child = array[index]
        } else {
          child = .array([])
        }
        set(&child, to: value, at: Array(path[1...]))
      } else {
        child = context.object?.first { $0.key == end.stringValue }?.value ?? .object(.init())
        set(&child, to: value, at: Array(path[1...]))
      }
    default: fatalError("Unreachable")
    }

    if let index = end.intValue {
      if var array = context.array {
        if array.count > index {
          array[index] = child
        } else {
          array.append(child)
        }
        context = .array(array)
      } else {
        context = .array([child])
      }
    } else {
      if var object = context.object {
        if let index = object.firstIndex(where: { $0.key == end.stringValue }) {
          object[index] = (key: end.stringValue, value: child)
        } else {
          object.append((key: end.stringValue, value: child))
        }
        context = .object(object)
      } else {
        context = .object([(key: end.stringValue, value: child)])
      }
    }
  }
}

struct AnyCodingKey: CodingKey, Hashable {
  let stringValue: String
  let intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  init?(intValue: Int) {
    stringValue = "\(intValue)"
    self.intValue = intValue
  }

  init(_ base: some CodingKey) {
    if let intValue = base.intValue {
      self.init(intValue: intValue)!
    } else {
      self.init(stringValue: base.stringValue)!
    }
  }
}

extension _URLEncodedFormEncoder {
  final class KeyedContainer<Key: CodingKey> {
    var codingPath: [any CodingKey]

    private let context: URLEncodedFormContext
    private let boolEncoding: URLEncodedFormEncoder.BoolEncoding
    private let dataEncoding: URLEncodedFormEncoder.DataEncoding
    private let dateEncoding: URLEncodedFormEncoder.DateEncoding
    private let nilEncoding: URLEncodedFormEncoder.NilEncoding

    init(
      context: URLEncodedFormContext,
      codingPath: [any CodingKey],
      boolEncoding: URLEncodedFormEncoder.BoolEncoding,
      dataEncoding: URLEncodedFormEncoder.DataEncoding,
      dateEncoding: URLEncodedFormEncoder.DateEncoding,
      nilEncoding: URLEncodedFormEncoder.NilEncoding
    ) {
      self.context = context
      self.codingPath = codingPath
      self.boolEncoding = boolEncoding
      self.dataEncoding = dataEncoding
      self.dateEncoding = dateEncoding
      self.nilEncoding = nilEncoding
    }

    private func nestedCodingPath(for key: any CodingKey) -> [any CodingKey] {
      codingPath + [key]
    }
  }
}

extension _URLEncodedFormEncoder.KeyedContainer: KeyedEncodingContainerProtocol {
  func encodeNil(forKey key: Key) throws {
    guard let nilValue = nilEncoding.encodeNil() else { return }

    try encode(nilValue, forKey: key)
  }

  func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func encodeIfPresent(_ value: String?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func encodeIfPresent(_ value: (some Encodable)?, forKey key: Key) throws {
    try _encodeIfPresent(value, forKey: key)
  }

  func _encodeIfPresent(_ value: (some Encodable)?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      try encodeNil(forKey: key)
    }
  }

  func encode(_ value: some Encodable, forKey key: Key) throws {
    var container = nestedSingleValueEncoder(for: key)
    try container.encode(value)
  }

  func nestedSingleValueEncoder(for key: Key) -> any SingleValueEncodingContainer {
    _URLEncodedFormEncoder.SingleValueContainer(
      context: context,
      codingPath: nestedCodingPath(for: key),
      boolEncoding: boolEncoding,
      dataEncoding: dataEncoding,
      dateEncoding: dateEncoding,
      nilEncoding: nilEncoding
    )
  }

  func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
    _URLEncodedFormEncoder.UnkeyedContainer(
      context: context,
      codingPath: nestedCodingPath(for: key),
      boolEncoding: boolEncoding,
      dataEncoding: dataEncoding,
      dateEncoding: dateEncoding,
      nilEncoding: nilEncoding
    )
  }

  func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
    let container = _URLEncodedFormEncoder.KeyedContainer<NestedKey>(
      context: context,
      codingPath: nestedCodingPath(for: key),
      boolEncoding: boolEncoding,
      dataEncoding: dataEncoding,
      dateEncoding: dateEncoding,
      nilEncoding: nilEncoding
    )

    return KeyedEncodingContainer(container)
  }

  func superEncoder() -> any Encoder {
    _URLEncodedFormEncoder(
      context: context,
      codingPath: codingPath,
      boolEncoding: boolEncoding,
      dataEncoding: dataEncoding,
      dateEncoding: dateEncoding,
      nilEncoding: nilEncoding
    )
  }

  func superEncoder(forKey key: Key) -> any Encoder {
    _URLEncodedFormEncoder(
      context: context,
      codingPath: nestedCodingPath(for: key),
      boolEncoding: boolEncoding,
      dataEncoding: dataEncoding,
      dateEncoding: dateEncoding,
      nilEncoding: nilEncoding
    )
  }
}

extension _URLEncodedFormEncoder {
  final class SingleValueContainer {
    var codingPath: [any CodingKey]

    private var canEncodeNewValue = true

    private let context: URLEncodedFormContext
    private let boolEncoding: URLEncodedFormEncoder.BoolEncoding
    private let dataEncoding: URLEncodedFormEncoder.DataEncoding
    private let dateEncoding: URLEncodedFormEncoder.DateEncoding
    private let nilEncoding: URLEncodedFormEncoder.NilEncoding

    init(
      context: URLEncodedFormContext,
      codingPath: [any CodingKey],
      boolEncoding: URLEncodedFormEncoder.BoolEncoding,
      dataEncoding: URLEncodedFormEncoder.DataEncoding,
      dateEncoding: URLEncodedFormEncoder.DateEncoding,
      nilEncoding: URLEncodedFormEncoder.NilEncoding
    ) {
      self.context = context
      self.codingPath = codingPath
      self.boolEncoding = boolEncoding
      self.dataEncoding = dataEncoding
      self.dateEncoding = dateEncoding
      self.nilEncoding = nilEncoding
    }

    private func checkCanEncode(value: Any?) throws {
      guard canEncodeNewValue else {
        let context = EncodingError.Context(
          codingPath: codingPath,
          debugDescription: "Attempt to encode value through single value container when previously value already encoded."
        )
        throw EncodingError.invalidValue(value as Any, context)
      }
    }
  }
}

extension _URLEncodedFormEncoder.SingleValueContainer: SingleValueEncodingContainer {
  func encodeNil() throws {
    guard let nilValue = nilEncoding.encodeNil() else { return }

    try encode(nilValue)
  }

  func encode(_ value: Bool) throws {
    try encode(value, as: String(boolEncoding.encode(value)))
  }

  func encode(_ value: String) throws {
    try encode(value, as: value)
  }

  func encode(_ value: Double) throws {
    try encode(value, as: String(value))
  }

  func encode(_ value: Float) throws {
    try encode(value, as: String(value))
  }

  func encode(_ value: Int) throws {
    try encode(value, as: String(value))
  }

  func encode(_ value: Int8) throws {
    try encode(value, as: String(value))
  }

  func encode(_ value: Int16) throws {
    try encode(value, as: String(value))
  }

  func encode(_ value: Int32) throws {
    try encode(value, as: String(value))
  }

  func encode(_ value: Int64) throws {
    try encode(value, as: String(value))
  }

  func encode(_ value: UInt) throws {
    try encode(value, as: String(value))
  }

  func encode(_ value: UInt8) throws {
    try encode(value, as: String(value))
  }

  func encode(_ value: UInt16) throws {
    try encode(value, as: String(value))
  }

  func encode(_ value: UInt32) throws {
    try encode(value, as: String(value))
  }

  func encode(_ value: UInt64) throws {
    try encode(value, as: String(value))
  }

  private func encode(_ value: some Encodable, as string: String) throws {
    try checkCanEncode(value: value)
    defer { canEncodeNewValue = false }

    context.component.set(to: .string(string), at: codingPath)
  }

  func encode(_ value: some Encodable) throws {
    switch value {
    case let date as Date:
      guard let string = try dateEncoding.encode(date) else {
        try attemptToEncode(value)
        return
      }

      try encode(value, as: string)
    case let data as Data:
      guard let string = try dataEncoding.encode(data) else {
        try attemptToEncode(value)
        return
      }

      try encode(value, as: string)
    case let decimal as Decimal:
      // Decimal's `Encodable` implementation returns an object, not a single value, so override it.
      try encode(value, as: String(describing: decimal))
    default:
      try attemptToEncode(value)
    }
  }

  private func attemptToEncode(_ value: some Encodable) throws {
    try checkCanEncode(value: value)
    defer { canEncodeNewValue = false }

    let encoder = _URLEncodedFormEncoder(
      context: context,
      codingPath: codingPath,
      boolEncoding: boolEncoding,
      dataEncoding: dataEncoding,
      dateEncoding: dateEncoding,
      nilEncoding: nilEncoding
    )
    try value.encode(to: encoder)
  }
}

extension _URLEncodedFormEncoder {
  final class UnkeyedContainer {
    var codingPath: [any CodingKey]

    var count = 0
    var nestedCodingPath: [any CodingKey] {
      codingPath + [AnyCodingKey(intValue: count)!]
    }

    private let context: URLEncodedFormContext
    private let boolEncoding: URLEncodedFormEncoder.BoolEncoding
    private let dataEncoding: URLEncodedFormEncoder.DataEncoding
    private let dateEncoding: URLEncodedFormEncoder.DateEncoding
    private let nilEncoding: URLEncodedFormEncoder.NilEncoding

    init(
      context: URLEncodedFormContext,
      codingPath: [any CodingKey],
      boolEncoding: URLEncodedFormEncoder.BoolEncoding,
      dataEncoding: URLEncodedFormEncoder.DataEncoding,
      dateEncoding: URLEncodedFormEncoder.DateEncoding,
      nilEncoding: URLEncodedFormEncoder.NilEncoding
    ) {
      self.context = context
      self.codingPath = codingPath
      self.boolEncoding = boolEncoding
      self.dataEncoding = dataEncoding
      self.dateEncoding = dateEncoding
      self.nilEncoding = nilEncoding
    }
  }
}

extension _URLEncodedFormEncoder.UnkeyedContainer: UnkeyedEncodingContainer {
  func encodeNil() throws {
    guard let nilValue = nilEncoding.encodeNil() else { return }

    try encode(nilValue)
  }

  func encode(_ value: some Encodable) throws {
    var container = nestedSingleValueContainer()
    try container.encode(value)
  }

  func nestedSingleValueContainer() -> any SingleValueEncodingContainer {
    defer { count += 1 }

    return _URLEncodedFormEncoder.SingleValueContainer(
      context: context,
      codingPath: nestedCodingPath,
      boolEncoding: boolEncoding,
      dataEncoding: dataEncoding,
      dateEncoding: dateEncoding,
      nilEncoding: nilEncoding
    )
  }

  func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
    defer { count += 1 }
    let container = _URLEncodedFormEncoder.KeyedContainer<NestedKey>(
      context: context,
      codingPath: nestedCodingPath,
      boolEncoding: boolEncoding,
      dataEncoding: dataEncoding,
      dateEncoding: dateEncoding,
      nilEncoding: nilEncoding
    )

    return KeyedEncodingContainer(container)
  }

  func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
    defer { count += 1 }

    return _URLEncodedFormEncoder.UnkeyedContainer(
      context: context,
      codingPath: nestedCodingPath,
      boolEncoding: boolEncoding,
      dataEncoding: dataEncoding,
      dateEncoding: dateEncoding,
      nilEncoding: nilEncoding
    )
  }

  func superEncoder() -> any Encoder {
    defer { count += 1 }

    return _URLEncodedFormEncoder(
      context: context,
      codingPath: codingPath,
      boolEncoding: boolEncoding,
      dataEncoding: dataEncoding,
      dateEncoding: dateEncoding,
      nilEncoding: nilEncoding
    )
  }
}

final class URLEncodedFormSerializer {
  private let alphabetizeKeyValuePairs: Bool
  private let arrayEncoding: URLEncodedFormEncoder.ArrayEncoding
  private let keyEncoding: URLEncodedFormEncoder.KeyEncoding
  private let keyPathEncoding: URLEncodedFormEncoder.KeyPathEncoding
  private let spaceEncoding: URLEncodedFormEncoder.SpaceEncoding
  private let allowedCharacters: CharacterSet

  init(
    alphabetizeKeyValuePairs: Bool,
    arrayEncoding: URLEncodedFormEncoder.ArrayEncoding,
    keyEncoding: URLEncodedFormEncoder.KeyEncoding,
    keyPathEncoding: URLEncodedFormEncoder.KeyPathEncoding,
    spaceEncoding: URLEncodedFormEncoder.SpaceEncoding,
    allowedCharacters: CharacterSet
  ) {
    self.alphabetizeKeyValuePairs = alphabetizeKeyValuePairs
    self.arrayEncoding = arrayEncoding
    self.keyEncoding = keyEncoding
    self.keyPathEncoding = keyPathEncoding
    self.spaceEncoding = spaceEncoding
    self.allowedCharacters = allowedCharacters
  }

  func serialize(_ object: URLEncodedFormComponent.Object) -> String {
    var output: [String] = []
    for (key, component) in object {
      let value = serialize(component, forKey: key)
      output.append(value)
    }
    output = alphabetizeKeyValuePairs ? output.sorted() : output

    return output.joinedWithAmpersands()
  }

  func serialize(_ component: URLEncodedFormComponent, forKey key: String) -> String {
    switch component {
    case let .string(string): "\(escape(keyEncoding.encode(key)))=\(escape(string))"
    case let .array(array): serialize(array, forKey: key)
    case let .object(object): serialize(object, forKey: key)
    }
  }

  func serialize(_ object: URLEncodedFormComponent.Object, forKey key: String) -> String {
    var segments: [String] = object.map { subKey, value in
      let keyPath = keyPathEncoding.encodeKeyPath(subKey)
      return serialize(value, forKey: key + keyPath)
    }
    segments = alphabetizeKeyValuePairs ? segments.sorted() : segments

    return segments.joinedWithAmpersands()
  }

  func serialize(_ array: [URLEncodedFormComponent], forKey key: String) -> String {
    var segments: [String] = array.enumerated().map { index, component in
      let keyPath = arrayEncoding.encode(key, atIndex: index)
      return serialize(component, forKey: keyPath)
    }
    segments = alphabetizeKeyValuePairs ? segments.sorted() : segments

    return segments.joinedWithAmpersands()
  }

  func escape(_ query: String) -> String {
    var allowedCharactersWithSpace = allowedCharacters
    allowedCharactersWithSpace.insert(charactersIn: " ")
    let escapedQuery = query.addingPercentEncoding(withAllowedCharacters: allowedCharactersWithSpace) ?? query
    return spaceEncoding.encode(escapedQuery)
  }
}

extension [String] {
  func joinedWithAmpersands() -> String {
    joined(separator: "&")
  }
}

extension CharacterSet {
  /// Creates a CharacterSet from RFC 3986 allowed characters.
  ///
  /// RFC 3986 states that the following characters are "reserved" characters.
  ///
  /// - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
  /// - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
  ///
  /// In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
  /// query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
  /// should be percent-escaped in the query string.
  static let afURLQueryAllowed: CharacterSet = {
    let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
    let subDelimitersToEncode = "!$&'()*+,;="
    let encodableDelimiters = CharacterSet(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")

    return CharacterSet.urlQueryAllowed.subtracting(encodableDelimiters)
  }()
}

// MARK: - Protected (Thread-Safe Wrapper)

private protocol Lock: Sendable {
  func lock()
  func unlock()
}

extension Lock {
  func around<T>(_ closure: () throws -> T) rethrows -> T {
    lock(); defer { unlock() }
    return try closure()
  }

  func around(_ closure: () throws -> Void) rethrows {
    lock(); defer { unlock() }
    try closure()
  }
}

#if canImport(Darwin)
final class UnfairLock: Lock, @unchecked Sendable {
  private let unfairLock: os_unfair_lock_t

  init() {
    unfairLock = .allocate(capacity: 1)
    unfairLock.initialize(to: os_unfair_lock())
  }

  deinit {
    unfairLock.deinitialize(count: 1)
    unfairLock.deallocate()
  }

  fileprivate func lock() {
    os_unfair_lock_lock(unfairLock)
  }

  fileprivate func unlock() {
    os_unfair_lock_unlock(unfairLock)
  }
}

#elseif canImport(Foundation)
extension NSLock: Lock {}
#else
#error("This platform needs a Lock-conforming type without Foundation.")
#endif

@dynamicMemberLookup
final class Protected<Value> {
  #if canImport(Darwin)
  private let lock = UnfairLock()
  #elseif canImport(Foundation)
  private let lock = NSLock()
  #else
  #error("This platform needs a Lock-conforming type without Foundation.")
  #endif
  #if compiler(>=6)
  private nonisolated(unsafe) var value: Value
  #else
  private var value: Value
  #endif

  init(_ value: Value) {
    self.value = value
  }

  func read<U>(_ closure: (Value) throws -> U) rethrows -> U {
    try lock.around { try closure(self.value) }
  }

  @discardableResult
  func write<U>(_ closure: (inout Value) throws -> U) rethrows -> U {
    try lock.around { try closure(&self.value) }
  }

  func write(_ value: Value) {
    write { $0 = value }
  }

  subscript<Property>(dynamicMember keyPath: WritableKeyPath<Value, Property>) -> Property {
    get { lock.around { value[keyPath: keyPath] } }
    set { lock.around { value[keyPath: keyPath] = newValue } }
  }

  subscript<Property>(dynamicMember keyPath: KeyPath<Value, Property>) -> Property {
    lock.around { value[keyPath: keyPath] }
  }
}

#if compiler(>=6)
extension Protected: Sendable {}
#else
extension Protected: @unchecked Sendable {}
#endif

// swiftlint:enable all
