#if !os(watchOS)
@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct UserServiceTests {
  init() async throws {
    try await configureEmbeddedClerkForTesting()
  }

  @Test
  func testSetProfileImage() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/profile_image")!
    let imageData = Data([0xFF, 0xD8, 0x00, 0x80, 0xFE, 0xFF, 0xD9])

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse<ImageResource>(
            response: ImageResource(id: "1", name: "profile", publicUrl: "https://example.com/image.jpg"),
            client: nil
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
      #expect(request.requestBodyData?.range(of: imageData) != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.userService.setProfileImage(imageData: imageData)
    #expect(requestHandled.value)
  }

  @Test
  func testDeleteProfileImage() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/profile_image")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: nil)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.queryParam(named: "_method") == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.userService.deleteProfileImage()
    #expect(requestHandled.value)
  }
}

#endif
