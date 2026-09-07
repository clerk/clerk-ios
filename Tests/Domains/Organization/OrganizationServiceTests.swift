@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct OrganizationServiceTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func setOrganizationLogo() async throws {
    let organization = Organization.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/organizations/\(organization.id)/logo")!
    let imageData = Data("fake image data".utf8)

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .put: JSONEncoder.clerkEncoder.encode(ClientResponse<Organization>(response: organization, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "PUT")
      #expect(request.allHTTPHeaderFields?["Content-Type"]?.contains("multipart/form-data") == true)
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
        .delete: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: deletedObject, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "DELETE")
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
