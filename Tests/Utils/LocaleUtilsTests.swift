//
//  LocaleUtilsTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct LocaleUtilsTests {
  @Test
  func testUserLocale() throws {
    let preferredLanguage = try #require(Locale.preferredLanguages.first)

    #expect(LocaleUtils.userLocale() == preferredLanguage)
  }
}
