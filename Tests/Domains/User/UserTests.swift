@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct UserTests {
  init() {
    configureClerkForTesting()
  }

  private func configureService(_ service: MockUserService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      userService: service
    )
    try! (Clerk.shared.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: .init())
  }

  @Test
  func setProfileImageUsesUserServiceSetProfileImage() async throws {
    let imageData = Data("fake image data".utf8)
    let captured = LockIsolated<Data?>(nil)
    let service = MockUserService(setProfileImage: { data in
      captured.setValue(data)
      return ImageResource(id: "1", name: "profile", publicUrl: "https://example.com/image.jpg")
    })

    configureService(service)

    _ = try await User.mock.setProfileImage(imageData: imageData)

    #expect(captured.value == imageData)
  }

  @Test
  func deleteProfileImageUsesUserServiceDeleteProfileImage() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(deleteProfileImage: {
      called.setValue(true)
      return .mock
    })

    configureService(service)

    _ = try await User.mock.deleteProfileImage()

    #expect(called.value == true)
  }
}
