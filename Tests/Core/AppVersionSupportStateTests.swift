@testable import ClerkKit
import Foundation
import Testing

struct AppVersionSupportStateTests {
  private func makeState() -> AppVersionSupportState {
    var state = AppVersionSupportState()
    state.appBuild = .init(bundleID: "com.example.app", version: "1.0")
    return state
  }

  @Test
  func theServerAnswerOutranksTheEnvironment() {
    var state = makeState()

    state.applySupported(requestSequence: 1)
    state.applyEnvironment(.withIOSPolicy(bundleID: "com.example.app", minimumVersion: "2.0", updateURL: "https://apps.apple.com/app/id123"))

    #expect(state.status.isSupported)
  }

  @Test
  func anAnswerToAnOlderRequestIsIgnored() {
    var state = makeState()

    state.applySupported(requestSequence: 2)
    state.applyUnsupported(meta: nil, requestSequence: 1)

    #expect(state.status.isSupported)
  }

  @Test
  func resetForgetsTheAnswersButKeepsTheBuild() {
    var state = makeState()
    state.applySupported(requestSequence: 5)

    state.reset()
    state.applyUnsupported(meta: nil, requestSequence: 1)

    #expect(!state.status.isSupported)
    #expect(state.status.currentVersion == "1.0")
  }
}
