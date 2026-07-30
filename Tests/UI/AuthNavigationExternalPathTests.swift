@testable import ClerkKitUI
import SwiftUI
import Testing

@MainActor
struct AuthNavigationExternalPathTests {
  private final class PathBox {
    var path = NavigationPath()
  }

  private func makeBinding(_ box: PathBox) -> Binding<NavigationPath> {
    Binding(get: { box.path }, set: { box.path = $0 })
  }

  @Test
  func pushesMirrorOntoExternalPathAboveHostEntries() {
    let box = PathBox()
    box.path.append("host-screen")
    let navigation = AuthNavigation()
    navigation.attachExternalPath(makeBinding(box))

    navigation.path.append(.signInForgotPassword)
    navigation.path.append(.signInSetNewPassword)

    #expect(box.path.count == 3)
  }

  @Test
  func popsMirrorOntoExternalPath() {
    let box = PathBox()
    box.path.append("host-screen")
    let navigation = AuthNavigation()
    navigation.attachExternalPath(makeBinding(box))
    navigation.path.append(.signInForgotPassword)
    navigation.path.append(.signInSetNewPassword)

    navigation.path.removeLast()

    #expect(box.path.count == 2)
  }

  @Test
  func clearingPathRemovesOnlyTheAuthSegment() {
    let box = PathBox()
    box.path.append("host-screen")
    let navigation = AuthNavigation()
    navigation.attachExternalPath(makeBinding(box))
    navigation.path.append(.signInForgotPassword)

    navigation.path = []

    #expect(box.path.count == 1)
  }

  @Test
  func externalPopTrimsTypedPath() {
    let box = PathBox()
    box.path.append("host-screen")
    let navigation = AuthNavigation()
    navigation.attachExternalPath(makeBinding(box))
    navigation.path.append(.signInForgotPassword)
    navigation.path.append(.signInSetNewPassword)

    // Host back button pops the top entry directly.
    box.path.removeLast()
    navigation.externalPathDidChange()

    #expect(navigation.path == [.signInForgotPassword])
    #expect(box.path.count == 2)
  }

  @Test
  func attachingWithExistingStepsMirrorsThem() {
    let box = PathBox()
    box.path.append("host-screen")
    let navigation = AuthNavigation()
    navigation.path.append(.signInForgotPassword)

    navigation.attachExternalPath(makeBinding(box))

    #expect(box.path.count == 2)
  }
}
