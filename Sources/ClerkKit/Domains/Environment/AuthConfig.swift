import ClerkSnapshots
import Foundation

extension Clerk.Environment {
  public typealias AuthConfig = ClerkSnapshots.AuthConfig
}

extension Clerk.Environment.AuthConfig {
  public typealias NativeSettings = ClerkSnapshots.NativeSettings

  public init(
    singleSessionMode: Bool,
    sessionMinter: Bool = false,
    nativeSettings: NativeSettings = .default
  ) {
    self.init(
      singleSessionMode: singleSessionMode,
      claimedAt: nil,
      reverification: false,
      preferredChannels: nil,
      sessionMinter: sessionMinter,
      nativeSettings: nativeSettings,
      id: "",
      object: "auth_config"
    )
  }
}
