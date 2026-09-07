import Foundation

protocol UserServiceProtocol: Sendable {
  @MainActor func setProfileImage(imageData: Data) async throws -> ImageResource
  @MainActor func deleteProfileImage() async throws -> DeletedObject
}

final class UserService: UserServiceProtocol {
  init() {}

  @MainActor
  func setProfileImage(imageData: Data) async throws -> ImageResource {
    try await Clerk.js(.clerk, JSRawCall("setNativeProfileImage", .string(imageData.base64EncodedString())), as: ImageResource.self)
  }

  @MainActor
  func deleteProfileImage() async throws -> DeletedObject {
    try await Clerk.js(.clerk, JSRawCall("deleteNativeProfileImage"), as: DeletedObject.self)
  }
}
