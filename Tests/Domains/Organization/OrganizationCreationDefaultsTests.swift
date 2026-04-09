@testable import ClerkKit
import Foundation
import Testing

struct OrganizationCreationDefaultsTests {
  @Test
  func decodesNilForm() throws {
    let data = Data(
      """
      {
        "advisory": null,
        "form": null
      }
      """.utf8
    )

    let decoded = try JSONDecoder.clerkDecoder.decode(OrganizationCreationDefaults.self, from: data)

    #expect(decoded.advisory == nil)
    #expect(decoded.form == nil)
  }
}
