import Foundation

package final class MockUserService: UserServiceProtocol {
  package nonisolated(unsafe) var setProfileImageHandler: ((Data) async throws -> ImageResource)?
  package nonisolated(unsafe) var deleteProfileImageHandler: (() async throws -> DeletedObject)?

  package init(
    setProfileImage: ((Data) async throws -> ImageResource)? = nil,
    deleteProfileImage: (() async throws -> DeletedObject)? = nil
  ) {
    setProfileImageHandler = setProfileImage
    deleteProfileImageHandler = deleteProfileImage
  }

  @MainActor
  package func setProfileImage(imageData: Data) async throws -> ImageResource {
    if let handler = setProfileImageHandler {
      return try await handler(imageData)
    }
    return ImageResource(id: "mock-image-id", name: "mock-image", publicUrl: nil)
  }

  @MainActor
  package func deleteProfileImage() async throws -> DeletedObject {
    if let handler = deleteProfileImageHandler {
      return try await handler()
    }
    return .mock
  }
}
