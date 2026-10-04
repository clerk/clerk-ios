@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkPreviewTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func emailCreationUsesPreviewTransport() async throws {
    var fixture = EmailAddress.mock
    fixture.id = "email_preview"
    fixture.emailAddress = "preview@example.com"
    let transport = FakeTransport.mockDefaults()
    transport.stub(EmailAddressAPI.create(email: fixture.emailAddress), returning: ClientResponse(response: fixture, client: nil))

    let clerk = makePreview { preview in
      preview.transport = transport
    }
    let user = try #require(clerk.user)
    let created = try await user.createEmailAddress(fixture.emailAddress)

    #expect(created == fixture)
    #expect(transport.calls.count == 1)
    let call = try #require(transport.calls.first)
    #expect(call.method == .post)
    #expect(call.path == "/v1/me/email_addresses")
    #expect(call.body?["email_address"]?.stringValue == fixture.emailAddress)
  }

  @Test
  func emailCreationPropagatesPreviewTransportErrors() async throws {
    let transport = FakeTransport.mockDefaults()
    transport.stub(EmailAddressAPI.create(email: "preview@example.com")) { _ in
      throw PreviewError.rejected
    }

    let clerk = makePreview { preview in
      preview.transport = transport
    }
    let user = try #require(clerk.user)

    await #expect(throws: PreviewError.rejected) {
      try await user.createEmailAddress("preview@example.com")
    }
    #expect(transport.calls.count == 1)
  }

  private func makePreview(_ configure: @escaping (PreviewBuilder) -> Void) -> Clerk {
    let environmentKey = "XCODE_RUNNING_FOR_PREVIEWS"
    let previousValue = ProcessInfo.processInfo.environment[environmentKey]
    setenv(environmentKey, "1", 1)
    defer {
      if let previousValue {
        setenv(environmentKey, previousValue, 1)
      } else {
        unsetenv(environmentKey)
      }
    }

    let clerk = Clerk.preview(preview: configure)
    clerk.cleanupManagers()
    return clerk
  }

  private enum PreviewError: Error {
    case rejected
  }
}
