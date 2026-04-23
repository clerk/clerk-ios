@testable import ClerkKit
import Foundation
import Testing

@Suite(.tags(.unit))
struct URLEncodedFormEncoderStrategyTests {
  @Test
  func arrayEncodingBrackets() {
    let encoding = URLEncodedFormEncoder.ArrayEncoding.brackets
    #expect(encoding.encode("items", atIndex: 0) == "items[]")
    #expect(encoding.encode("items", atIndex: 5) == "items[]")
  }

  @Test
  func arrayEncodingNoBrackets() {
    let encoding = URLEncodedFormEncoder.ArrayEncoding.noBrackets
    #expect(encoding.encode("items", atIndex: 0) == "items")
    #expect(encoding.encode("items", atIndex: 5) == "items")
  }

  @Test
  func arrayEncodingIndexInBrackets() {
    let encoding = URLEncodedFormEncoder.ArrayEncoding.indexInBrackets
    #expect(encoding.encode("items", atIndex: 0) == "items[0]")
    #expect(encoding.encode("items", atIndex: 5) == "items[5]")
  }

  @Test
  func arrayEncodingCustom() {
    let encoding = URLEncodedFormEncoder.ArrayEncoding.custom { key, index in
      "\(key)_\(index)"
    }
    #expect(encoding.encode("items", atIndex: 0) == "items_0")
    #expect(encoding.encode("items", atIndex: 5) == "items_5")
  }

  @Test
  func boolEncodingNumeric() {
    let encoding = URLEncodedFormEncoder.BoolEncoding.numeric
    #expect(encoding.encode(true) == "1")
    #expect(encoding.encode(false) == "0")
  }

  @Test
  func boolEncodingLiteral() {
    let encoding = URLEncodedFormEncoder.BoolEncoding.literal
    #expect(encoding.encode(true) == "true")
    #expect(encoding.encode(false) == "false")
  }

  @Test
  func dataEncodingBase64() throws {
    let encoding = URLEncodedFormEncoder.DataEncoding.base64
    let data = "Hello World".data(using: .utf8)!
    let result = try encoding.encode(data)
    #expect(result != nil)
    #expect(result == data.base64EncodedString())
  }

  @Test
  func dataEncodingDeferredToData() throws {
    let encoding = URLEncodedFormEncoder.DataEncoding.deferredToData
    let data = "Hello World".data(using: .utf8)!
    let result = try encoding.encode(data)
    #expect(result == nil)
  }

  @Test
  func dataEncodingCustom() throws {
    let encoding = URLEncodedFormEncoder.DataEncoding.custom { data in
      String(data: data, encoding: .utf8) ?? ""
    }
    let data = "Hello World".data(using: .utf8)!
    let result = try encoding.encode(data)
    #expect(result == "Hello World")
  }

  @Test
  func dateEncodingDeferredToDate() throws {
    let encoding = URLEncodedFormEncoder.DateEncoding.deferredToDate
    let date = Date(timeIntervalSince1970: 1_609_459_200)
    let result = try encoding.encode(date)
    #expect(result == nil)
  }

  @Test
  func dateEncodingSecondsSince1970() throws {
    let encoding = URLEncodedFormEncoder.DateEncoding.secondsSince1970
    let date = Date(timeIntervalSince1970: 1_609_459_200)
    let result = try encoding.encode(date)
    #expect(result == "1609459200.0")
  }

  @Test
  func dateEncodingMillisecondsSince1970() throws {
    let encoding = URLEncodedFormEncoder.DateEncoding.millisecondsSince1970
    let date = Date(timeIntervalSince1970: 1_609_459_200)
    let result = try encoding.encode(date)
    #expect(result == "1609459200000.0")
  }

  @Test
  func dateEncodingISO8601() throws {
    let encoding = URLEncodedFormEncoder.DateEncoding.iso8601
    let date = Date(timeIntervalSince1970: 1_609_459_200)
    let result = try encoding.encode(date)
    #expect(result != nil)
    #expect(result?.contains("2021") == true)
  }

  @Test
  func dateEncodingFormatted() throws {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    let encoding = URLEncodedFormEncoder.DateEncoding.formatted(formatter)
    let date = Date(timeIntervalSince1970: 1_609_459_200)
    let result = try encoding.encode(date)
    #expect(result == "2021-01-01")
  }

  @Test
  func dateEncodingCustom() throws {
    let encoding = URLEncodedFormEncoder.DateEncoding.custom { date in
      "custom_\(date.timeIntervalSince1970)"
    }
    let date = Date(timeIntervalSince1970: 1_609_459_200)
    let result = try encoding.encode(date)
    #expect(result == "custom_1609459200.0")
  }

  @Test
  func keyEncodingUseDefaultKeys() {
    let encoding = URLEncodedFormEncoder.KeyEncoding.useDefaultKeys
    #expect(encoding.encode("testKey") == "testKey")
  }

  @Test
  func keyEncodingConvertToSnakeCase() {
    let encoding = URLEncodedFormEncoder.KeyEncoding.convertToSnakeCase
    #expect(encoding.encode("testKey") == "test_key")
    #expect(encoding.encode("oneTwoThree") == "one_two_three")
    #expect(encoding.encode("myURLProperty") == "my_url_property")
    #expect(encoding.encode("_oneTwoThree_") == "_one_two_three_")
  }

  @Test
  func keyEncodingConvertToKebabCase() {
    let encoding = URLEncodedFormEncoder.KeyEncoding.convertToKebabCase
    #expect(encoding.encode("testKey") == "test-key")
    #expect(encoding.encode("oneTwoThree") == "one-two-three")
  }

  @Test
  func keyEncodingCapitalized() {
    let encoding = URLEncodedFormEncoder.KeyEncoding.capitalized
    #expect(encoding.encode("testKey") == "TestKey")
    #expect(encoding.encode("hello") == "Hello")
  }

  @Test
  func keyEncodingUppercased() {
    let encoding = URLEncodedFormEncoder.KeyEncoding.uppercased
    #expect(encoding.encode("testKey") == "TESTKEY")
    #expect(encoding.encode("hello") == "HELLO")
  }

  @Test
  func keyEncodingLowercased() {
    let encoding = URLEncodedFormEncoder.KeyEncoding.lowercased
    #expect(encoding.encode("TestKey") == "testkey")
    #expect(encoding.encode("HELLO") == "hello")
  }

  @Test
  func keyEncodingCustom() {
    let encoding = URLEncodedFormEncoder.KeyEncoding.custom { key in
      "prefix_\(key)_suffix"
    }
    #expect(encoding.encode("test") == "prefix_test_suffix")
  }

  @Test
  func keyPathEncodingBrackets() {
    let encoding = URLEncodedFormEncoder.KeyPathEncoding.brackets
    #expect(encoding.encodeKeyPath("child") == "[child]")
    #expect(encoding.encodeKeyPath("grandchild") == "[grandchild]")
  }

  @Test
  func keyPathEncodingDots() {
    let encoding = URLEncodedFormEncoder.KeyPathEncoding.dots
    #expect(encoding.encodeKeyPath("child") == ".child")
    #expect(encoding.encodeKeyPath("grandchild") == ".grandchild")
  }

  @Test
  func keyPathEncodingCustom() {
    let encoding = URLEncodedFormEncoder.KeyPathEncoding { subkey in
      "->\(subkey)"
    }
    #expect(encoding.encodeKeyPath("child") == "->child")
  }

  @Test
  func nilEncodingDropKey() {
    let encoding = URLEncodedFormEncoder.NilEncoding.dropKey
    #expect(encoding.encodeNil() == nil)
  }

  @Test
  func nilEncodingDropValue() {
    let encoding = URLEncodedFormEncoder.NilEncoding.dropValue
    #expect(encoding.encodeNil() == "")
  }

  @Test
  func nilEncodingNull() {
    let encoding = URLEncodedFormEncoder.NilEncoding.null
    #expect(encoding.encodeNil() == "null")
  }

  @Test
  func nilEncodingCustom() {
    let encoding = URLEncodedFormEncoder.NilEncoding { "custom_null" }
    #expect(encoding.encodeNil() == "custom_null")
  }

  @Test
  func spaceEncodingPercentEscaped() {
    let encoding = URLEncodedFormEncoder.SpaceEncoding.percentEscaped
    #expect(encoding.encode("hello world") == "hello%20world")
    #expect(encoding.encode("test  spaces") == "test%20%20spaces")
  }

  @Test
  func spaceEncodingPlusReplaced() {
    let encoding = URLEncodedFormEncoder.SpaceEncoding.plusReplaced
    #expect(encoding.encode("hello world") == "hello+world")
    #expect(encoding.encode("test  spaces") == "test++spaces")
  }
}
