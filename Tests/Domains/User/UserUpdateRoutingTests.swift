@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct UserUpdateRoutingTests {
  init() {
    configureClerkForTesting()
  }

  // MARK: - Routing

  @Test
  func noMetadataIssuesSingleUpdateCall() async throws {
    let order = LockIsolated<[String]>([])
    let updateCalls = LockIsolated(0)
    let metadataCalls = LockIsolated(0)

    let service = MockUserService(
      update: { _ in
        order.withValue { $0.append("update") }
        updateCalls.withValue { $0 += 1 }
        return .mock
      },
      updateMetadata: { _ in
        metadataCalls.withValue { $0 += 1 }
        return .mock
      }
    )
    configureService(service)

    _ = try await User.mock.update(.init(firstName: "Jane"))

    #expect(updateCalls.value == 1)
    #expect(metadataCalls.value == 0)
    #expect(order.value == ["update"])
  }

  @Test
  @available(*, deprecated)
  func onlyMetadataIssuesSingleUpdateMetadataCallWithComputedPatch() async throws {
    let updateCalls = LockIsolated(0)
    let captured = LockIsolated<JSON?>(nil)

    let service = MockUserService(
      update: { _ in
        updateCalls.withValue { $0 += 1 }
        return .mock
      },
      updateMetadata: { params in
        captured.setValue(params.unsafeMetadata)
        return .mock
      }
    )
    configureService(service)

    var user = User.mock
    user.unsafeMetadata = ["theme": "dark", "layout": "compact"]

    _ = try await user.update(
      .init(unsafeMetadata: ["theme": "light"])
    )

    #expect(updateCalls.value == 0)
    // The patch null-deletes `layout` (absent from desired) and overwrites `theme`.
    #expect(captured.value == ["theme": "light", "layout": .null])
  }

  @Test
  @available(*, deprecated)
  func mixedFieldsAndMetadataIssueUpdateThenUpdateMetadataInOrder() async throws {
    let order = LockIsolated<[String]>([])
    let updateParams = LockIsolated<User.UpdateParams?>(nil)
    let metadataPatch = LockIsolated<JSON?>(nil)

    let service = MockUserService(
      update: { params in
        order.withValue { $0.append("update") }
        updateParams.setValue(params)
        return .mock
      },
      updateMetadata: { params in
        order.withValue { $0.append("updateMetadata") }
        metadataPatch.setValue(params.unsafeMetadata)
        return .mock
      }
    )
    configureService(service)

    var user = User.mock
    user.unsafeMetadata = ["foo": "old"]

    _ = try await user.update(
      .init(firstName: "Jane", unsafeMetadata: ["foo": "new", "bar": "added"])
    )

    #expect(order.value == ["update", "updateMetadata"])
    #expect(updateParams.value?.firstName == "Jane")
    // unsafeMetadata must NOT be on the rest params sent to /me.
    #expect(updateParams.value?._unsafeMetadata == nil)
    #expect(metadataPatch.value == ["foo": "new", "bar": "added"])
  }

  @Test
  @available(*, deprecated)
  func identicalMetadataShortCircuitsWithoutMetadataCall() async throws {
    let updateCalls = LockIsolated(0)
    let metadataCalls = LockIsolated(0)

    let service = MockUserService(
      update: { _ in
        updateCalls.withValue { $0 += 1 }
        return .mock
      },
      updateMetadata: { _ in
        metadataCalls.withValue { $0 += 1 }
        return .mock
      }
    )
    configureService(service)

    var user = User.mock
    user.unsafeMetadata = ["theme": "dark"]

    _ = try await user.update(.init(unsafeMetadata: ["theme": "dark"]))

    #expect(updateCalls.value == 0)
    #expect(metadataCalls.value == 0)
  }

  @Test
  @available(*, deprecated)
  func identicalMetadataWithOtherFieldsReturnsTheUpdateMeResponse() async throws {
    // Receiver has stale firstName; the /me response (User.mock2) has the fresh one.
    // The bug to guard against: empty-patch short-circuit returning stale `self`
    // instead of the fresh `afterPatch`.
    let metadataCalls = LockIsolated(0)
    let service = MockUserService(
      update: { _ in
        var fresh = User.mock
        fresh.firstName = "Fresh"
        fresh.unsafeMetadata = ["theme": "dark"]
        return fresh
      },
      updateMetadata: { _ in
        metadataCalls.withValue { $0 += 1 }
        return .mock
      }
    )
    configureService(service)

    var user = User.mock
    user.firstName = "Stale"
    user.unsafeMetadata = ["theme": "dark"]

    let returned = try await user.update(
      .init(firstName: "Fresh", unsafeMetadata: ["theme": "dark"])
    )

    #expect(metadataCalls.value == 0, "Identical metadata must not trigger a /me/metadata call")
    #expect(returned.firstName == "Fresh", "Must return the fresh /me response, not stale self")
  }

  // MARK: - Helpers

  private func configureService(_ service: MockUserService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      userService: service
    )
    try! (Clerk.shared.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: .init())
  }
}
