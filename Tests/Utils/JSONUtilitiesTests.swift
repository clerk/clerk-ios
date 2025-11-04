//
//  JSONUtilitiesTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct JSONUtilitiesTests {

  // MARK: - JSON Enum Cases

  @Test
  func testJSONCases() {
    let stringJSON: JSON = .string("hello")
    let numberJSON: JSON = .number(42.0)
    let boolJSON: JSON = .bool(true)
    let nullJSON: JSON = .null
    let arrayJSON: JSON = .array([.string("a"), .number(1)])
    let objectJSON: JSON = .object(["key": .string("value")])

    #expect(stringJSON.stringValue == "hello")
    #expect(numberJSON.doubleValue == 42.0)
    #expect(boolJSON.boolValue == true)
    #expect(nullJSON.isNull == true)
    #expect(arrayJSON.arrayValue?.count == 2)
    #expect(objectJSON.objectValue?["key"]?.stringValue == "value")
  }

  // MARK: - ExpressibleBy Protocols

  @Test
  func testExpressibleByStringLiteral() {
    let json: JSON = "hello"
    #expect(json.stringValue == "hello")
  }

  @Test
  func testExpressibleByIntegerLiteral() {
    let json: JSON = 42
    #expect(json.doubleValue == 42.0)
  }

  @Test
  func testExpressibleByFloatLiteral() {
    let json: JSON = 3.14
    #expect(json.doubleValue == 3.14)
  }

  @Test
  func testExpressibleByBooleanLiteral() {
    let json: JSON = true
    #expect(json.boolValue == true)
  }

  @Test
  func testExpressibleByNilLiteral() {
    let json: JSON = nil
    #expect(json.isNull == true)
  }

  @Test
  func testExpressibleByArrayLiteral() {
    let json: JSON = ["a", "b", "c"]
    #expect(json.arrayValue?.count == 3)
    #expect(json[0]?.stringValue == "a")
    #expect(json[1]?.stringValue == "b")
    #expect(json[2]?.stringValue == "c")
  }

  @Test
  func testExpressibleByDictionaryLiteral() {
    let json: JSON = ["key1": "value1", "key2": "value2"]
    #expect(json.objectValue?["key1"]?.stringValue == "value1")
    #expect(json.objectValue?["key2"]?.stringValue == "value2")
  }

  // MARK: - Value Extraction

  @Test
  func testStringValue() {
    #expect(JSON.string("hello").stringValue == "hello")
    #expect(JSON.number(42.0).stringValue == nil)
    #expect(JSON.bool(true).stringValue == nil)
    #expect(JSON.null.stringValue == nil)
  }

  @Test
  func testDoubleValue() {
    #expect(JSON.number(42.5).doubleValue == 42.5)
    #expect(JSON.string("42").doubleValue == nil)
    #expect(JSON.bool(true).doubleValue == nil)
  }

  @Test
  func testBoolValue() {
    #expect(JSON.bool(true).boolValue == true)
    #expect(JSON.bool(false).boolValue == false)
    #expect(JSON.string("true").boolValue == nil)
    #expect(JSON.number(1).boolValue == nil)
  }

  @Test
  func testObjectValue() {
    let object: JSON = .object(["key": .string("value")])
    #expect(object.objectValue?["key"]?.stringValue == "value")
    #expect(JSON.string("not an object").objectValue == nil)
  }

  @Test
  func testArrayValue() {
    let array: JSON = .array([.string("a"), .string("b")])
    #expect(array.arrayValue?.count == 2)
    #expect(JSON.string("not an array").arrayValue == nil)
  }

  @Test
  func testIsNull() {
    #expect(JSON.null.isNull == true)
    #expect(JSON.string("").isNull == false)
    #expect(JSON.number(0).isNull == false)
  }

  // MARK: - Subscript Access

  @Test
  func testArraySubscript() {
    let json: JSON = ["a", "b", "c"]
    #expect(json[0]?.stringValue == "a")
    #expect(json[1]?.stringValue == "b")
    #expect(json[2]?.stringValue == "c")
    #expect(json[3] == nil)  // Out of bounds
    #expect(json[-1] == nil)  // Invalid index
  }

  @Test
  func testObjectSubscript() {
    let json: JSON = ["key1": "value1", "key2": "value2"]
    #expect(json["key1"]?.stringValue == "value1")
    #expect(json["key2"]?.stringValue == "value2")
    #expect(json["nonexistent"] == nil)
  }

  @Test
  func testDynamicMemberLookup() {
    let json: JSON = ["key1": "value1"]
    #expect(json.key1?.stringValue == "value1")
    #expect(json.nonexistent == nil)
  }

  @Test
  func testKeyPathSubscript() {
    let json: JSON = ["parent": ["child": ["grandchild": "value"]]]
    #expect(json[keyPath: "parent.child.grandchild"]?.stringValue == "value")
    #expect(json[keyPath: "parent.child"]?.objectValue?["grandchild"]?.stringValue == "value")
    #expect(json[keyPath: "nonexistent.path"] == nil)
  }

  @Test
  func testQueryKeyPath() {
    let json: JSON = ["a": ["b": ["c": "value"]]]
    let path = ["a", "b", "c"]
    #expect(json.queryKeyPath(path)?.stringValue == "value")

    let partialPath = ["a", "b"]
    #expect(json.queryKeyPath(partialPath)?.objectValue?["c"]?.stringValue == "value")

    let invalidPath = ["nonexistent"]
    #expect(json.queryKeyPath(invalidPath) == nil)
  }

  // MARK: - Merging

  @Test
  func testMergingObjects() {
    let old: JSON = ["a": "old", "b": "unchanged"]
    let new: JSON = ["a": "new", "c": "added"]

    let merged = old.merging(with: new)

    #expect(merged["a"]?.stringValue == "new")  // Updated
    #expect(merged["b"]?.stringValue == "unchanged")  // Preserved
    #expect(merged["c"]?.stringValue == "added")  // Added
  }

  @Test
  func testMergingNestedObjects() {
    let old: JSON = ["parent": ["child": "old"]]
    let new: JSON = ["parent": ["child": "new", "sibling": "added"]]

    let merged = old.merging(with: new)

    #expect(merged["parent"]?["child"]?.stringValue == "new")
    #expect(merged["parent"]?["sibling"]?.stringValue == "added")
  }

  @Test
  func testMergingNonObjects() {
    let old: JSON = "old"
    let new: JSON = "new"

    let merged = old.merging(with: new)
    #expect(merged.stringValue == "new")  // Returns new when not objects
  }

  // MARK: - Codable

  @Test
  func testJSONEncoding() throws {
    let json: JSON = ["key": "value", "number": 42, "bool": true, "null": nil]
    let encoder = JSONEncoder()
    let data = try encoder.encode(json)

    #expect(data.count > 0)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(JSON.self, from: data)

    #expect(decoded["key"]?.stringValue == "value")
    #expect(decoded["number"]?.doubleValue == 42.0)
    #expect(decoded["bool"]?.boolValue == true)
    #expect(decoded["null"]?.isNull == true)
  }

  @Test
  func testJSONDecoding() throws {
    let jsonString = """
      {"key":"value","number":42,"bool":true,"null":null}
      """
    let data = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    let json = try decoder.decode(JSON.self, from: data)

    #expect(json["key"]?.stringValue == "value")
    #expect(json["number"]?.doubleValue == 42.0)
    #expect(json["bool"]?.boolValue == true)
    #expect(json["null"]?.isNull == true)
  }

  @Test
  func testJSONEquatable() {
    #expect(JSON.string("hello") == JSON.string("hello"))
    #expect(JSON.string("hello") != JSON.string("world"))
    #expect(JSON.number(42.0) == JSON.number(42.0))
    #expect(JSON.bool(true) == JSON.bool(true))
    #expect(JSON.null == JSON.null)
  }

  // MARK: - JSONDecoder Extension

  @Test
  func testClerkDecoder() {
    let decoder = JSONDecoder.clerkDecoder

    // Verify snake_case conversion strategy
    if case .convertFromSnakeCase = decoder.keyDecodingStrategy {
      // Correct strategy
    } else {
      Issue.record("Expected convertFromSnakeCase strategy")
    }

    // Verify date decoding strategy
    if case .millisecondsSince1970 = decoder.dateDecodingStrategy {
      // Correct strategy
    } else {
      Issue.record("Expected millisecondsSince1970 strategy")
    }
  }

  @Test
  func testClerkDecoderSnakeCase() throws {
    struct TestStruct: Codable {
      let firstName: String
      let lastName: String
    }

    let jsonString = """
      {"first_name":"John","last_name":"Doe"}
      """
    let data = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder.clerkDecoder
    let result = try decoder.decode(TestStruct.self, from: data)

    #expect(result.firstName == "John")
    #expect(result.lastName == "Doe")
  }

  @Test
  func testClerkDecoderDate() throws {
    struct TestStruct: Codable {
      let timestamp: Date
    }

    // Milliseconds since 1970
    let jsonString = """
      {"timestamp":1609459200000}
      """
    let data = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder.clerkDecoder
    let result = try decoder.decode(TestStruct.self, from: data)

    // 1609459200000 ms = 2021-01-01 00:00:00 UTC
    let expectedDate = Date(timeIntervalSince1970: 1609459200)
    let timeDiff = abs(result.timestamp.timeIntervalSince1970 - expectedDate.timeIntervalSince1970)
    #expect(timeDiff < 1.0)
  }

  // MARK: - JSONEncoder Extension

  @Test
  func testClerkEncoder() {
    let encoder = JSONEncoder.clerkEncoder

    // Verify snake_case conversion strategy
    if case .convertToSnakeCase = encoder.keyEncodingStrategy {
      // Correct strategy
    } else {
      Issue.record("Expected convertToSnakeCase strategy")
    }

    // Verify date encoding strategy
    if case .millisecondsSince1970 = encoder.dateEncodingStrategy {
      // Correct strategy
    } else {
      Issue.record("Expected millisecondsSince1970 strategy")
    }
  }

  @Test
  func testClerkEncoderSnakeCase() throws {
    struct TestStruct: Codable {
      let firstName: String
      let lastName: String
    }

    let value = TestStruct(firstName: "John", lastName: "Doe")
    let encoder = JSONEncoder.clerkEncoder
    let data = try encoder.encode(value)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    #expect(json["first_name"] as? String == "John")
    #expect(json["last_name"] as? String == "Doe")
  }

  @Test
  func testClerkEncoderDate() throws {
    struct TestStruct: Codable {
      let timestamp: Date
    }

    let date = Date(timeIntervalSince1970: 1609459200)  // 2021-01-01 00:00:00 UTC
    let value = TestStruct(timestamp: date)
    let encoder = JSONEncoder.clerkEncoder
    let data = try encoder.encode(value)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    // Should be encoded as milliseconds
    let timestamp = json["timestamp"] as! Double
    #expect(timestamp == 1609459200000.0)
  }
}
