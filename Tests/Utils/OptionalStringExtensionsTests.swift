import Testing

@testable import ClerkKit

struct OptionalStringExtensionsTests {

  @Test func testNilIfEmptyTrimsWhitespaceAndFiltersEmptyResults() {
    let nilValue: String? = nil
    let emptyValue: String? = ""
    let whitespaceValue: String? = "   \n  "
    let spacedValue: String? = "  Jane  "
    let nonEmptyValue: String? = "John"

    #expect(nilValue.nilIfEmpty == nil)
    #expect(emptyValue.nilIfEmpty == nil)
    #expect(whitespaceValue.nilIfEmpty == nil)
    #expect(spacedValue.nilIfEmpty == "Jane")
    #expect(nonEmptyValue.nilIfEmpty == "John")
  }
}
