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
  func aRejectionUsesTheLatestEnvironmentForWhatItsMetaLeavesOut() {
    var state = makeState()
    state.applyEnvironment(.withIOSPolicy(bundleID: "com.example.app", minimumVersion: "2.0", updateURL: "https://apps.apple.com/app/id1"))
    state.applyUnsupported(meta: ["current_version": "1.0"], requestSequence: 1)

    state.applyEnvironment(.withIOSPolicy(bundleID: "com.example.app", minimumVersion: "3.0", updateURL: "https://apps.apple.com/app/id2"))

    #expect(!state.status.isSupported)
    #expect(state.status.minimumVersion == "3.0")
    #expect(state.status.updateURL == URL(string: "https://apps.apple.com/app/id2"))
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

  @Test(arguments: [
    (updateRequiredViewEnabled: true, updateScreenIsAvailable: false, expected: true),
    (updateRequiredViewEnabled: false, updateScreenIsAvailable: false, expected: false),
    (updateRequiredViewEnabled: true, updateScreenIsAvailable: true, expected: false),
  ])
  func aBlockedAppWarnsOnlyWhenItsUpdateScreenCanNotShow(
    updateRequiredViewEnabled: Bool,
    updateScreenIsAvailable: Bool,
    expected: Bool
  ) {
    var state = makeState()
    state.updateScreenIsAvailable = updateScreenIsAvailable
    state.applyEnvironment(.withIOSPolicy(bundleID: "com.example.app", minimumVersion: "2.0", updateURL: "https://apps.apple.com/app/id123"))

    let warned = state.claimMissingUpdateScreenWarning(updateRequiredViewEnabled: updateRequiredViewEnabled)

    #expect(warned == expected)
  }

  @Test
  func theMissingUpdateScreenWarningIsClaimedOnce() {
    var state = makeState()
    state.updateScreenIsAvailable = false
    state.applyEnvironment(.withIOSPolicy(bundleID: "com.example.app", minimumVersion: "2.0", updateURL: "https://apps.apple.com/app/id123"))

    let first = state.claimMissingUpdateScreenWarning(updateRequiredViewEnabled: true)
    let second = state.claimMissingUpdateScreenWarning(updateRequiredViewEnabled: true)

    #expect(first)
    #expect(!second)
  }

  @Test
  func aBuildAtItsMinimumStillWarnsAboutAMissingUpdateScreen() {
    var state = makeState()
    state.updateScreenIsAvailable = false
    state.applyEnvironment(.withIOSPolicy(bundleID: "com.example.app", minimumVersion: "1.0", updateURL: "https://apps.apple.com/app/id123"))

    let warned = state.claimMissingUpdateScreenWarning(updateRequiredViewEnabled: true)

    #expect(state.status.isSupported)
    #expect(warned)
  }

  @Test
  func anAppWithoutAMinimumDoesNotWarnAboutAMissingUpdateScreen() {
    var state = makeState()
    state.updateScreenIsAvailable = false

    let warned = state.claimMissingUpdateScreenWarning(updateRequiredViewEnabled: true)

    #expect(!warned)
  }

  @Test
  func resetLetsTheNextConfigurationWarnAgain() {
    var state = makeState()
    state.updateScreenIsAvailable = false
    let environment = Clerk.Environment.withIOSPolicy(bundleID: "com.example.app", minimumVersion: "2.0", updateURL: "https://apps.apple.com/app/id123")
    state.applyEnvironment(environment)
    let beforeReset = state.claimMissingUpdateScreenWarning(updateRequiredViewEnabled: true)

    state.reset()
    let afterResetWithoutAMinimum = state.claimMissingUpdateScreenWarning(updateRequiredViewEnabled: true)

    state.applyEnvironment(environment)
    let afterResetWithAMinimum = state.claimMissingUpdateScreenWarning(updateRequiredViewEnabled: true)

    #expect(beforeReset)
    #expect(!afterResetWithoutAMinimum)
    #expect(afterResetWithAMinimum)
  }
}
