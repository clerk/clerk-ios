#if !os(watchOS)
@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct OrganizationServiceTests {
  init() async throws {
    try await configureEmbeddedClerkForTesting()
  }

  @Test
  func setOrganizationLogo() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/logo")!
    let imageData = Data([0xFF, 0xD8, 0x00, 0x80, 0xFE, 0xFF, 0xD9])

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: organization, client: nil)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.queryParam(named: "_method") == "PUT")
      #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
      #expect(request.requestBodyData?.range(of: imageData) != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.organizationService.setOrganizationLogo(
      organizationId: organization.id,
      imageData: imageData
    )
    #expect(requestHandled.value)
  }

  @Test
  func deleteOrganizationLogo() async throws {
    let organization = Organization.mock
    let deletedObject = DeletedObject(object: "image", id: "logo_id", deleted: true)
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/logo")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: deletedObject, client: nil)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.queryParam(named: "_method") == "DELETE")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    let response = try await Clerk.shared.dependencies.organizationService.deleteOrganizationLogo(
      organizationId: organization.id
    )
    #expect(requestHandled.value)
    #expect(response.deleted == true)
  }
}

#endif
