//
//  URLEncodedFormEncoderTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct URLEncodedFormEncoderTests {

  // MARK: - ArrayEncoding Tests

  @Test
  func testArrayEncodingBrackets() {
    let encoding = URLEncodedFormEncoder.ArrayEncoding.brackets
    #expect(encoding.encode("items", atIndex: 0) == "items[]")
    #expect(encoding.encode("items", atIndex: 5) == "items[]")
  }

  @Test
  func testArrayEncodingNoBrackets() {
    let encoding = URLEncodedFormEncoder.ArrayEncoding.noBrackets
    #expect(encoding.encode("items", atIndex: 0) == "items")
    #expect(encoding.encode("items", atIndex: 5) == "items")
  }

  @Test
  func testArrayEncodingIndexInBrackets() {
    let encoding = URLEncodedFormEncoder.ArrayEncoding.indexInBrackets
    #expect(encoding.encode("items", atIndex: 0) == "items[0]")
    #expect(encoding.encode("items", atIndex: 5) == "items[5]")
  }

  @Test
  func testArrayEncodingCustom() {
    let encoding = URLEncodedFormEncoder.ArrayEncoding.custom { key, index in
      "\(key)_\(index)"
    }
    #expect(encoding.encode("items", atIndex: 0) == "items_0")
    #expect(encoding.encode("items", atIndex: 5) == "items_5")
  }

  // MARK: - BoolEncoding Tests

  @Test
  func testBoolEncodingNumeric() {
    let encoding = URLEncodedFormEncoder.BoolEncoding.numeric
    #expect(encoding.encode(true) == "1")
    #expect(encoding.encode(false) == "0")
  }

  @Test
  func testBoolEncodingLiteral() {
    let encoding = URLEncodedFormEncoder.BoolEncoding.literal
    #expect(encoding.encode(true) == "true")
    #expect(encoding.encode(false) == "false")
  }

  // MARK: - DataEncoding Tests

  @Test
  func testDataEncodingBase64() throws {
    let encoding = URLEncodedFormEncoder.DataEncoding.base64
    let data = "Hello World".data(using: .utf8)!
    let result = try encoding.encode(data)
    #expect(result != nil)
    #expect(result == data.base64EncodedString())
  }

  @Test
  func testDataEncodingDeferredToData() throws {
    let encoding = URLEncodedFormEncoder.DataEncoding.deferredToData
    let data = "Hello World".data(using: .utf8)!
    let result = try encoding.encode(data)
    #expect(result == nil)
  }

  @Test
  func testDataEncodingCustom() throws {
    let encoding = URLEncodedFormEncoder.DataEncoding.custom { data in
      String(data: data, encoding: .utf8) ?? ""
    }
    let data = "Hello World".data(using: .utf8)!
    let result = try encoding.encode(data)
    #expect(result == "Hello World")
  }

  // MARK: - DateEncoding Tests

  @Test
  func testDateEncodingDeferredToDate() throws {
    let encoding = URLEncodedFormEncoder.DateEncoding.deferredToDate
    let date = Date(timeIntervalSince1970: 1609459200)
    let result = try encoding.encode(date)
    #expect(result == nil)
  }

  @Test
  func testDateEncodingSecondsSince1970() throws {
    let encoding = URLEncodedFormEncoder.DateEncoding.secondsSince1970
    let date = Date(timeIntervalSince1970: 1609459200)
    let result = try encoding.encode(date)
    #expect(result == "1609459200.0")
  }

  @Test
  func testDateEncodingMillisecondsSince1970() throws {
    let encoding = URLEncodedFormEncoder.DateEncoding.millisecondsSince1970
    let date = Date(timeIntervalSince1970: 1609459200)
    let result = try encoding.encode(date)
    #expect(result == "1609459200000.0")
  }

  @Test
  func testDateEncodingISO8601() throws {
    let encoding = URLEncodedFormEncoder.DateEncoding.iso8601
    let date = Date(timeIntervalSince1970: 1609459200) // 2021-01-01 00:00:00 UTC
    let result = try encoding.encode(date)
    #expect(result != nil)
    #expect(result?.contains("2021") == true)
  }

  @Test
  func testDateEncodingFormatted() throws {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    let encoding = URLEncodedFormEncoder.DateEncoding.formatted(formatter)
    let date = Date(timeIntervalSince1970: 1609459200)
    let result = try encoding.encode(date)
    #expect(result == "2021-01-01")
  }

  @Test
  func testDateEncodingCustom() throws {
    let encoding = URLEncodedFormEncoder.DateEncoding.custom { date in
      "custom_\(date.timeIntervalSince1970)"
    }
    let date = Date(timeIntervalSince1970: 1609459200)
    let result = try encoding.encode(date)
    #expect(result == "custom_1609459200.0")
  }

  // MARK: - KeyEncoding Tests

  @Test
  func testKeyEncodingUseDefaultKeys() {
    let encoding = URLEncodedFormEncoder.KeyEncoding.useDefaultKeys
    #expect(encoding.encode("testKey") == "testKey")
  }

  @Test
  func testKeyEncodingConvertToSnakeCase() {
    let encoding = URLEncodedFormEncoder.KeyEncoding.convertToSnakeCase
    #expect(encoding.encode("testKey") == "test_key")
    #expect(encoding.encode("oneTwoThree") == "one_two_three")
    #expect(encoding.encode("myURLProperty") == "my_url_property")
    #expect(encoding.encode("_oneTwoThree_") == "_one_two_three_")
  }

  @Test
  func testKeyEncodingConvertToKebabCase() {
    let encoding = URLEncodedFormEncoder.KeyEncoding.convertToKebabCase
    #expect(encoding.encode("testKey") == "test-key")
    #expect(encoding.encode("oneTwoThree") == "one-two-three")
  }

  @Test
  func testKeyEncodingCapitalized() {
    let encoding = URLEncodedFormEncoder.KeyEncoding.capitalized
    #expect(encoding.encode("testKey") == "TestKey")
    #expect(encoding.encode("hello") == "Hello")
  }

  @Test
  func testKeyEncodingUppercased() {
    let encoding = URLEncodedFormEncoder.KeyEncoding.uppercased
    #expect(encoding.encode("testKey") == "TESTKEY")
    #expect(encoding.encode("hello") == "HELLO")
  }

  @Test
  func testKeyEncodingLowercased() {
    let encoding = URLEncodedFormEncoder.KeyEncoding.lowercased
    #expect(encoding.encode("TestKey") == "testkey")
    #expect(encoding.encode("HELLO") == "hello")
  }

  @Test
  func testKeyEncodingCustom() {
    let encoding = URLEncodedFormEncoder.KeyEncoding.custom { key in
      "prefix_\(key)_suffix"
    }
    #expect(encoding.encode("test") == "prefix_test_suffix")
  }

  // MARK: - KeyPathEncoding Tests

  @Test
  func testKeyPathEncodingBrackets() {
    let encoding = URLEncodedFormEncoder.KeyPathEncoding.brackets
    #expect(encoding.encodeKeyPath("child") == "[child]")
    #expect(encoding.encodeKeyPath("grandchild") == "[grandchild]")
  }

  @Test
  func testKeyPathEncodingDots() {
    let encoding = URLEncodedFormEncoder.KeyPathEncoding.dots
    #expect(encoding.encodeKeyPath("child") == ".child")
    #expect(encoding.encodeKeyPath("grandchild") == ".grandchild")
  }

  @Test
  func testKeyPathEncodingCustom() {
    let encoding = URLEncodedFormEncoder.KeyPathEncoding { subkey in
      "->\(subkey)"
    }
    #expect(encoding.encodeKeyPath("child") == "->child")
  }

  // MARK: - NilEncoding Tests

  @Test
  func testNilEncodingDropKey() {
    let encoding = URLEncodedFormEncoder.NilEncoding.dropKey
    #expect(encoding.encodeNil() == nil)
  }

  @Test
  func testNilEncodingDropValue() {
    let encoding = URLEncodedFormEncoder.NilEncoding.dropValue
    #expect(encoding.encodeNil() == "")
  }

  @Test
  func testNilEncodingNull() {
    let encoding = URLEncodedFormEncoder.NilEncoding.null
    #expect(encoding.encodeNil() == "null")
  }

  @Test
  func testNilEncodingCustom() {
    let encoding = URLEncodedFormEncoder.NilEncoding { "custom_null" }
    #expect(encoding.encodeNil() == "custom_null")
  }

  // MARK: - SpaceEncoding Tests

  @Test
  func testSpaceEncodingPercentEscaped() {
    let encoding = URLEncodedFormEncoder.SpaceEncoding.percentEscaped
    #expect(encoding.encode("hello world") == "hello%20world")
    #expect(encoding.encode("test  spaces") == "test%20%20spaces")
  }

  @Test
  func testSpaceEncodingPlusReplaced() {
    let encoding = URLEncodedFormEncoder.SpaceEncoding.plusReplaced
    #expect(encoding.encode("hello world") == "hello+world")
    #expect(encoding.encode("test  spaces") == "test++spaces")
  }

  // MARK: - Full Encoding Tests

  @Test
  func testEncodeSimpleStruct() throws {
    struct TestStruct: Encodable {
      let name: String
      let age: Int
    }

    let encoder = URLEncodedFormEncoder()
    let value = TestStruct(name: "John", age: 30)
    let result: String = try encoder.encode(value)

    #expect(result.contains("name=John"))
    #expect(result.contains("age=30"))
  }

  @Test
  func testEncodeWithArrays() throws {
    struct TestStruct: Encodable {
      let items: [String]
    }

    let encoder = URLEncodedFormEncoder()
    let value = TestStruct(items: ["a", "b", "c"])
    let result: String = try encoder.encode(value)

    // URL encoding converts [ to %5B and ] to %5D
    #expect(result.contains("items%5B%5D=a") || result.contains("items[]=a"))
    #expect(result.contains("items%5B%5D=b") || result.contains("items[]=b"))
    #expect(result.contains("items%5B%5D=c") || result.contains("items[]=c"))
  }

  @Test
  func testEncodeWithNestedObjects() throws {
    struct Nested: Encodable {
      let value: String
    }
    struct TestStruct: Encodable {
      let parent: Nested
    }

    let encoder = URLEncodedFormEncoder()
    let value = TestStruct(parent: Nested(value: "test"))
    let result: String = try encoder.encode(value)

    // URL encoding converts [ to %5B and ] to %5D
    #expect(result.contains("parent%5Bvalue%5D=test") || result.contains("parent[value]=test"))
  }

  @Test
  func testEncodeWithBoolNumeric() throws {
    struct TestStruct: Encodable {
      let flag: Bool
    }

    let encoder = URLEncodedFormEncoder(boolEncoding: .numeric)
    let value = TestStruct(flag: true)
    let result: String = try encoder.encode(value)

    #expect(result.contains("flag=1"))

    let valueFalse = TestStruct(flag: false)
    let resultFalse: String = try encoder.encode(valueFalse)
    #expect(resultFalse.contains("flag=0"))
  }

  @Test
  func testEncodeWithBoolLiteral() throws {
    struct TestStruct: Encodable {
      let flag: Bool
    }

    let encoder = URLEncodedFormEncoder(boolEncoding: .literal)
    let value = TestStruct(flag: true)
    let result: String = try encoder.encode(value)

    #expect(result.contains("flag=true"))
  }

  @Test
  func testEncodeWithOptionalNilDropKey() throws {
    struct TestStruct: Encodable {
      let name: String?
    }

    let encoder = URLEncodedFormEncoder(nilEncoding: .dropKey)
    let value = TestStruct(name: nil)
    let result: String = try encoder.encode(value)

    #expect(!result.contains("name"))
  }

  @Test
  func testEncodeWithOptionalNilDropValue() throws {
    struct TestStruct: Encodable {
      let name: String?
    }

    let encoder = URLEncodedFormEncoder(nilEncoding: .dropValue)
    let value = TestStruct(name: nil)
    let result: String = try encoder.encode(value)

    #expect(result.contains("name="))
  }

  @Test
  func testEncodeWithDateSeconds() throws {
    struct TestStruct: Encodable {
      let date: Date
    }

    let encoder = URLEncodedFormEncoder(dateEncoding: .secondsSince1970)
    let date = Date(timeIntervalSince1970: 1609459200)
    let value = TestStruct(date: date)
    let result: String = try encoder.encode(value)

    #expect(result.contains("date=1609459200.0"))
  }

  @Test
  func testEncodeWithKeyEncodingSnakeCase() throws {
    struct TestStruct: Encodable {
      let firstName: String
      let lastName: String
    }

    let encoder = URLEncodedFormEncoder(keyEncoding: .convertToSnakeCase)
    let value = TestStruct(firstName: "John", lastName: "Doe")
    let result: String = try encoder.encode(value)

    #expect(result.contains("first_name=John"))
    #expect(result.contains("last_name=Doe"))
  }

  @Test
  func testEncodeErrorInvalidRootObject() throws {
    // Encoding a single value (not a keyed object) should throw an error
    let encoder = URLEncodedFormEncoder()

    do {
      let _: String = try encoder.encode("just a string")
      Issue.record("Expected invalidRootObject error")
    } catch let error as URLEncodedFormEncoder.Error {
      if case .invalidRootObject = error {
        // Expected error
      } else {
        Issue.record("Wrong error type")
      }
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  @Test
  func testAlphabetizeKeyValuePairs() throws {
    struct TestStruct: Encodable {
      let z: String
      let a: String
      let m: String
    }

    let encoder = URLEncodedFormEncoder(alphabetizeKeyValuePairs: true)
    let value = TestStruct(z: "z", a: "a", m: "m")
    let result: String = try encoder.encode(value)

    // Keys should be alphabetized
    let parts = result.split(separator: "&")
    #expect(parts.count == 3)
    // First should be a=
    #expect(parts[0].hasPrefix("a="))
  }

  @Test
  func testEncodeAsData() throws {
    struct TestStruct: Encodable {
      let name: String
      let age: Int
    }

    let encoder = URLEncodedFormEncoder()
    let value = TestStruct(name: "John", age: 30)
    let result = try encoder.encode(value) as Data

    #expect(result.count > 0)
    let string = String(data: result, encoding: .utf8)
    #expect(string?.contains("name=John") == true)
  }
}

