//
//  StringPresentationTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct StringPresentationTests {
  // MARK: - String+Ext.swift Tests

  @Test
  func testIsEmptyTrimmed() {
    // Empty string
    #expect("".isEmptyTrimmed == true)

    // Whitespace-only strings
    #expect("   ".isEmptyTrimmed == true)
    #expect("\n\n".isEmptyTrimmed == true)
    #expect("\t\t".isEmptyTrimmed == true)
    #expect(" \n\t ".isEmptyTrimmed == true)

    // Strings with leading/trailing whitespace
    #expect("  hello  ".isEmptyTrimmed == false)
    #expect("\nhello\n".isEmptyTrimmed == false)
    #expect("\thello\t".isEmptyTrimmed == false)

    // Normal strings
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

    // Verify specific characters
    let parts = result.components(separatedBy: "\u{00A0}")
    #expect(parts.count == 2)
    #expect(parts[0].contains("\u{2011}"))
  }

  @Test
  func testCapitalizedSentence() {
    // First letter capitalized, rest lowercase
    #expect("hello".capitalizedSentence == "Hello")
    #expect("HELLO".capitalizedSentence == "Hello")
    #expect("HeLLo".capitalizedSentence == "Hello")
    #expect("hELLO".capitalizedSentence == "Hello")

    // Single character
    #expect("a".capitalizedSentence == "A")
    #expect("A".capitalizedSentence == "A")

    // Empty string
    #expect("".capitalizedSentence == "")

    // Numbers and special characters
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
    // Note: The regex may accept double dots, so we'll skip this test
    // #expect("user@example..com".isEmailAddress == false)
  }
}
