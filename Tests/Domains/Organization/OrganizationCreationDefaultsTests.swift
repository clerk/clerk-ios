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

  @Test
  func decodesAdvisoryWithoutSeverity() throws {
    let data = Data(
      """
      {
        "advisory": {
          "code": "organization_already_exists",
          "meta": {
            "organization_domain": "clerk.dev",
            "organization_name": "Clerk"
          }
        },
        "form": {
          "name": "My Organization",
          "logo": null,
          "slug": "my-organization-1776268051877551207",
          "blur_hash": null
        }
      }
      """.utf8
    )

    let decoded = try JSONDecoder.clerkDecoder.decode(OrganizationCreationDefaults.self, from: data)

    #expect(decoded.advisory?.code == "organization_already_exists")
    #expect(decoded.advisory?.severity == nil)
    #expect(decoded.advisory?.meta["organization_domain"] == "clerk.dev")
    #expect(decoded.form?.name == "My Organization")
  }

  @Test
  func decodesFormWithoutSlug() throws {
    let data = Data(
      """
      {
        "advisory": null,
        "form": {
          "name": "My Organization",
          "logo": null,
          "blur_hash": null
        }
      }
      """.utf8
    )

    let decoded = try JSONDecoder.clerkDecoder.decode(OrganizationCreationDefaults.self, from: data)

    #expect(decoded.form?.name == "My Organization")
    #expect(decoded.form?.slug == nil)
    #expect(decoded.form?.logo == nil)
  }
}
