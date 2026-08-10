//
//  ClerkClientError.swift
//

import Foundation

/// An object that represents an error created by Clerk on the client.
public struct ClerkClientError: Error, LocalizedError, ClerkError {
  private enum MessageStorage {
    case localizationValue(String.LocalizationValue)
    case localizedResource(LocalizedStringResource)
  }

  private var messageStorage: MessageStorage?

  /// A message that describes the error.
  public var messageLocalizationValue: String.LocalizationValue? {
    get {
      switch messageStorage {
      case .localizationValue(let value):
        value
      case .localizedResource(let resource):
        resource.defaultValue
      case nil:
        nil
      }
    }
    set {
      messageStorage = newValue.map(MessageStorage.localizationValue)
    }
  }

  /// Additional context about the error.
  public var context: [String: String]? {
    nil
  }

  /// A human-readable error message.
  public var message: String? {
    switch messageStorage {
    case .localizationValue(let value):
      String(localized: value)
    case .localizedResource(let resource):
      String(localized: resource)
    case nil:
      nil
    }
  }

  public init(message: String.LocalizationValue? = nil) {
    messageStorage = message.map(MessageStorage.localizationValue)
  }

  /// Creates an error whose message carries its localization bundle and locale.
  public init(localizedMessage: LocalizedStringResource) {
    messageStorage = .localizedResource(localizedMessage)
  }

  /// Creates an error whose message is localized using the provided bundle.
  public init(
    message: String.LocalizationValue,
    localizationBundle: Bundle,
    locale: Locale = .current
  ) {
    self.init(
      localizedMessage: LocalizedStringResource(
        message,
        locale: locale,
        bundle: localizationBundle
      )
    )
  }
}

extension ClerkClientError {
  public var errorDescription: String? {
    message
  }
}
