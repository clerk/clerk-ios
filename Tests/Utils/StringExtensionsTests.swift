//
//  StringExtensionsTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct StringExtensionsTests {
  // MARK: - String+Ext.swift Tests

  @Test
  func testIsEmptyTrimmed() {
    #expect("".isEmptyTrimmed == true)

    #expect("   ".isEmptyTrimmed == true)
    #expect("\n\n".isEmptyTrimmed == true)
    #expect("\t\t".isEmptyTrimmed == true)
    #expect(" \n\t ".isEmptyTrimmed == true)

    #expect("  hello  ".isEmptyTrimmed == false)
    #expect("\nhello\n".isEmptyTrimmed == false)
    #expect("\thello\t".isEmptyTrimmed == false)

    #expect("hello".isEmptyTrimmed == false)
    #expect("hello world".isEmptyTrimmed == false)
  }

  @Test
  func testNonBreaking() {
    let input = "hello-world test"
    let result = input.nonBreaking

    // Should replace spaces with non-breaking space (\u{00A0})
    #expect(result.contains("\u{00A0}"))
    #expect(!result.contains(" "))

    // Should replace hyphens with non-breaking hyphen (\u{2011})
    #expect(result.contains("\u{2011}"))
    #expect(!result.contains("-"))

    let parts = result.components(separatedBy: "\u{00A0}")
    #expect(parts.count == 2)
    #expect(parts[0].contains("\u{2011}"))
  }

  @Test
  func testCapitalizedSentence() {
    #expect("hello".capitalizedSentence == "Hello")
    #expect("HELLO".capitalizedSentence == "Hello")
    #expect("HeLLo".capitalizedSentence == "Hello")
    #expect("hELLO".capitalizedSentence == "Hello")

    #expect("a".capitalizedSentence == "A")
    #expect("A".capitalizedSentence == "A")

    #expect("".capitalizedSentence == "")

    #expect("123hello".capitalizedSentence == "123hello")
    #expect("hello123".capitalizedSentence == "Hello123")
  }

  @Test
  func testIsEmailAddress() {
    // Valid email addresses
    #expect("test@example.com".isEmailAddress == true)
    #expect("user.name@example.com".isEmailAddress == true)
    #expect("user+tag@example.com".isEmailAddress == true)
    #expect("user_name@example.co.uk".isEmailAddress == true)
    #expect("user123@example123.com".isEmailAddress == true)
    #expect("a@b.co".isEmailAddress == true)

    // Invalid email addresses
    #expect("notanemail".isEmailAddress == false)
    #expect("@example.com".isEmailAddress == false)
    #expect("user@".isEmailAddress == false)
    #expect("user@example".isEmailAddress == false)
    #expect("user @example.com".isEmailAddress == false)
    #expect("user@exam ple.com".isEmailAddress == false)
    #expect("".isEmailAddress == false)
    #expect("user@example..com".isEmailAddress == false)
    #expect("user@.example.com".isEmailAddress == false)
    #expect("user@-example.com".isEmailAddress == false)
    #expect("user@example-.com".isEmailAddress == false)
    #expect("user@sub-domain.example.com".isEmailAddress == true)
  }

  // MARK: - String+Base64.swift Tests

  @Test
  func testBase64URLFromBase64String() {
    let base64 = "SGVsbG8+V29ybGQ/"
    let base64URL = base64.base64URLFromBase64String()

    #expect(!base64URL.contains("+"))
    #expect(base64URL.contains("-"))

    #expect(!base64URL.contains("/"))
    #expect(base64URL.contains("_"))

    let base64WithPadding = "SGVsbG8gV29ybGQ="
    let base64URLWithPadding = base64WithPadding.base64URLFromBase64String()
    #expect(!base64URLWithPadding.contains("="))

    #expect(base64URL == "SGVsbG8-V29ybGQ_")
  }

  @Test
  func testDataFromBase64URL() {
    let base64URL = "SGVsbG8gV29ybGQ"
    let data = base64URL.dataFromBase64URL()

    #expect(data != nil)
    if let data {
      let string = String(data: data, encoding: .utf8)
      #expect(string == "Hello World")
    }

    let base64URLWithPadding = "SGVsbG8="
    let dataWithPadding = base64URLWithPadding.dataFromBase64URL()
    #expect(dataWithPadding != nil)

    let invalid = "!!!"
    let invalidData = invalid.dataFromBase64URL()
    #expect(invalidData == nil)
  }

  @Test
  func testBase64String() {
    let base64URL = "SGVsbG8gV29ybGQ"
    let base64String = base64URL.base64String()

    #expect(base64String != nil)
    #expect(base64String == "Hello World")

    let invalid = "!!!"
    let invalidString = invalid.base64String()
    #expect(invalidString == nil)

    // Base64URL that doesn't decode to valid UTF-8
    // This is harder to test, but we can test edge cases
    let empty = ""
    let emptyString = empty.base64String()
    #expect(emptyString == nil || emptyString == "")
  }

  // MARK: - String+JSON.swift Tests

  @Test
  func testToJSON() {
    // Valid JSON strings
    let validJSON = "{\"key\":\"value\"}"
    let json = validJSON.toJSON()
    #expect(json != nil)
    if let json {
      #expect(json["key"]?.stringValue == "value")
    }

    let arrayJSON = "[1,2,3]"
    let arrayResult = arrayJSON.toJSON()
    #expect(arrayResult != nil)
    if let arrayResult {
      #expect(arrayResult.arrayValue?.count == 3)
    }

    #expect("42".toJSON() == .null)

    let objectJSON = "{\"number\":42}"
    let objectResult = objectJSON.toJSON()
    #expect(objectResult != nil)
    if let objectResult {
      #expect(objectResult["number"]?.doubleValue == 42.0)
    }

    // Invalid JSON strings
    let invalidJSON = "{invalid}"
    #expect(invalidJSON.toJSON() == .null)

    let emptyString = ""
    #expect(emptyString.toJSON() == .null)
  }
}
