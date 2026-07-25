import Foundation

enum AppLocalKeychainAccessGroup {
  static func isApplicationIdentifier(
    _ accessGroup: String,
    for ownerIdentifier: String
  ) -> Bool {
    guard !accessGroup.hasPrefix("group."),
          let separator = accessGroup.firstIndex(of: "."),
          separator != accessGroup.startIndex
    else {
      return false
    }
    return accessGroup[accessGroup.index(after: separator)...]
      == ownerIdentifier[...]
  }

  static func resolve(
    config: Clerk.Options.KeychainConfig,
    ownerIdentifier: String?,
    requiresIsolation: Bool
  ) throws -> String? {
    let ownerIdentifier = ownerIdentifier?
      .trimmingCharacters(in: .whitespacesAndNewlines)

    if let explicit = config.normalizedAppLocalAccessGroup {
      guard !explicit.hasPrefix("group.") else {
        throw ClerkClientError(
          message: "The app-local Keychain access group must be this app's application identifier."
        )
      }
      if let ownerIdentifier, !ownerIdentifier.isEmpty {
        guard isApplicationIdentifier(
          explicit,
          for: ownerIdentifier
        ) else {
          throw ClerkClientError(
            message: "The app-local Keychain access group must be this app's application identifier."
          )
        }
      }
      guard explicit != config.normalizedAccessGroup else {
        throw ClerkClientError(
          message: "The app-local and shared Keychain access groups must be different."
        )
      }
      return explicit
    }

    guard let sharedAccessGroup = config.normalizedAccessGroup else {
      return nil
    }
    guard let ownerIdentifier, !ownerIdentifier.isEmpty else {
      if requiresIsolation {
        throw ClerkClientError(
          message: "App-local Keychain isolation requires a nonempty application bundle identifier."
        )
      }
      return nil
    }

    // App Groups are valid Keychain access groups, but unlike App ID-prefixed
    // Keychain groups they do not contain the prefix needed to derive this
    // app's private application-identifier group.
    if sharedAccessGroup.hasPrefix("group.") {
      guard !requiresIsolation else {
        throw ClerkClientError(
          message: "Set Clerk.Options.KeychainConfig.appLocalAccessGroup to this app's application identifier when the shared Keychain access group is an App Group."
        )
      }
      return nil
    }

    guard let separator = sharedAccessGroup.firstIndex(of: "."),
          separator != sharedAccessGroup.startIndex
    else {
      guard !requiresIsolation else {
        throw ClerkClientError(
          message: "Set Clerk.Options.KeychainConfig.appLocalAccessGroup because Clerk could not derive the app-specific group from the shared Keychain access group."
        )
      }
      return nil
    }

    let prefix = sharedAccessGroup[..<separator]
    let appLocalAccessGroup = "\(prefix).\(ownerIdentifier)"
    guard appLocalAccessGroup != sharedAccessGroup else {
      throw ClerkClientError(
        message: "The shared Keychain access group must differ from this app's application identifier."
      )
    }
    return appLocalAccessGroup
  }
}
