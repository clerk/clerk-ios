//
//  WatchExampleLocalSecrets.swift
//  WatchExampleApp
//

import Foundation

struct WatchExampleLocalSecrets {
  let publishableKey: String?

  static func load(
    bundle: Bundle = .main,
    processInfo: ProcessInfo = .processInfo
  ) -> WatchExampleLocalSecrets {
    let plistValues = localSecretsPlistValues(bundle: bundle)

    return .init(
      publishableKey: resolveValue(
        for: "CLERK_PUBLISHABLE_KEY",
        processInfo: processInfo,
        plistValues: plistValues
      )
    )
  }

  private static func resolveValue(
    for key: String,
    processInfo: ProcessInfo,
    plistValues: [String: Any]
  ) -> String? {
    if let environmentValue = normalized(processInfo.environment[key]) {
      return environmentValue
    }

    return normalized(plistValues[key] as? String)
  }

  private static func normalized(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    return value
  }

  private static func localSecretsPlistValues(bundle: Bundle) -> [String: Any] {
    guard
      let url = bundle.url(forResource: "LocalSecrets", withExtension: "plist"),
      let data = try? Data(contentsOf: url),
      let propertyList = try? PropertyListSerialization.propertyList(from: data, format: nil),
      let values = propertyList as? [String: Any]
    else {
      return [:]
    }

    return values
  }
}
