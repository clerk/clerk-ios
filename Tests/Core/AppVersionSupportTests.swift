@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct AppVersionSupportTests {
  private static let blockingEnvironment = Clerk.Environment.withIOSPolicy(
    bundleID: "com.example.app",
    minimumVersion: "2.0",
    updateURL: "https://apps.apple.com/app/id123"
  )

  private func makeClerk() -> Clerk {
    let clerk = Clerk()
    clerk.appBuild = .init(bundleID: "com.example.app", version: "1.0")
    return clerk
  }

  @Test
  func appVersionIsSupportedByDefault() {
    #expect(makeClerk().appVersionSupportStatus.isSupported)
  }

  @Test
  func freshlyFetchedEnvironmentBlocksAnOutdatedApp() {
    let clerk = makeClerk()

    clerk.applyRefreshedEnvironment(Self.blockingEnvironment)

    #expect(!clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0")
  }

  @Test
  func cachedEnvironmentBlocksAnOutdatedAppAtLaunch() {
    let clerk = makeClerk()

    clerk.setEnvironmentIfNeeded(Self.blockingEnvironment)

    #expect(!clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0")
  }

  @Test
  func cachedEnvironmentAllowsAnUpdatedApp() {
    let clerk = makeClerk()
    clerk.appBuild = .init(bundleID: "com.example.app", version: "2.0")

    clerk.setEnvironmentIfNeeded(Self.blockingEnvironment)

    #expect(clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func freshEnvironmentReplacesACachedBlock() {
    let clerk = makeClerk()
    clerk.setEnvironmentIfNeeded(Self.blockingEnvironment)

    clerk.applyRefreshedEnvironment(.mock)

    #expect(clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func supportedResponseKeepsTheMinimumTheEnvironmentSet() {
    let clerk = makeClerk()
    clerk.appBuild = .init(bundleID: "com.example.app", version: "2.1")
    clerk.applyRefreshedEnvironment(Self.blockingEnvironment)

    clerk.applySupportedAppVersion()

    #expect(clerk.appVersionSupportStatus == .init(
      isSupported: true,
      currentVersion: "2.1",
      minimumVersion: "2.0",
      updateURL: URL(string: "https://apps.apple.com/app/id123")
    ))
  }

  @Test
  func supportedResponseDropsAMinimumTheServerNoLongerEnforces() {
    let clerk = makeClerk()
    clerk.applyRefreshedEnvironment(Self.blockingEnvironment)

    clerk.applySupportedAppVersion()

    #expect(clerk.appVersionSupportStatus == .supported(currentVersion: "1.0"))
  }

  @Test
  func laterSupportedResponseLiftsAnEnvironmentBlock() {
    let clerk = makeClerk()
    clerk.applyRefreshedEnvironment(Self.blockingEnvironment)

    clerk.applySupportedAppVersion()

    #expect(clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func laterServerRejectionBlocksDespiteTheEnvironment() {
    let clerk = makeClerk()
    clerk.applyRefreshedEnvironment(.mock)

    clerk.applyUnsupportedAppVersion(meta: ["minimum_version": "2.0"])

    #expect(!clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0")
  }

  @Test
  func fetchedEnvironmentDoesNotLiftAServerRejection() {
    let clerk = makeClerk()
    clerk.applyUnsupportedAppVersion(meta: ["minimum_version": "2.0"])

    clerk.applyRefreshedEnvironment(.mock)

    #expect(!clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0")
  }

  @Test
  func supportedResponseLiftsAServerRejection() {
    let clerk = makeClerk()
    clerk.applyUnsupportedAppVersion(meta: ["minimum_version": "2.0"])

    clerk.applySupportedAppVersion()

    #expect(clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func fetchedEnvironmentDoesNotOverrideASupportedResponse() {
    let clerk = makeClerk()
    clerk.applySupportedAppVersion()

    clerk.applyRefreshedEnvironment(Self.blockingEnvironment)

    #expect(clerk.appVersionSupportStatus == .supported(currentVersion: "1.0"))
  }

  @Test
  func supportedResponseShowsTheMinimumALaterEnvironmentSets() {
    let clerk = makeClerk()
    clerk.appBuild = .init(bundleID: "com.example.app", version: "2.1")
    clerk.applySupportedAppVersion()

    clerk.applyRefreshedEnvironment(Self.blockingEnvironment)

    #expect(clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0")
  }

  @Test
  func rejectionFallsBackToTheEnvironmentForWhatItsMetaLeavesOut() {
    let clerk = makeClerk()
    clerk.applyRefreshedEnvironment(Self.blockingEnvironment)

    clerk.applyUnsupportedAppVersion(meta: ["update_url": ""])

    #expect(clerk.appVersionSupportStatus == .init(
      isSupported: false,
      currentVersion: "1.0",
      minimumVersion: "2.0",
      updateURL: URL(string: "https://apps.apple.com/app/id123")
    ))
  }

  @Test
  func rejectionAfterASupportedResponseBlocks() {
    let clerk = makeClerk()
    clerk.applySupportedAppVersion()
    clerk.applyRefreshedEnvironment(Self.blockingEnvironment)

    clerk.applyUnsupportedAppVersion(meta: nil)

    #expect(!clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0")
  }

  @Test
  func savedEnvironmentKeepsAServerRejection() {
    let clerk = makeClerk()
    clerk.applyUnsupportedAppVersion(meta: ["minimum_version": "2.0"])

    clerk.setEnvironmentIfNeeded(.mock)

    #expect(!clerk.appVersionSupportStatus.isSupported)
  }

  @Test
  func supportedStatusReportsTheInjectedBuild() {
    let clerk = makeClerk()
    clerk.applySupportedAppVersion()

    #expect(clerk.appVersionSupportStatus.currentVersion == "1.0")
  }

  @Test
  func reconfigurationClearsTheBlock() {
    let clerk = makeClerk()
    clerk.applyUnsupportedAppVersion(meta: nil)

    clerk.cleanupManagers()

    #expect(clerk.appVersionSupportStatus.isSupported)
  }
}
