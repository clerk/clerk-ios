//
//  URL+Ext.swift
//  Clerk
//

import Foundation

extension URL {
  package func queryParam(named name: String) -> String? {
    guard
      let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
      let value = components.queryParam(named: name)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !value.isEmpty
    else {
      return nil
    }

    return value
  }
}

extension URLComponents {
  fileprivate func queryParam(named name: String) -> String? {
    if let queryValue = queryItems?
      .first(where: { $0.name == name })?
      .value
    {
      return queryValue
    }

    guard
      let fragment,
      var fragmentComponents = URLComponents(string: "/")
    else {
      return nil
    }

    fragmentComponents.percentEncodedQuery = fragment
    return fragmentComponents.queryItems?
      .first(where: { $0.name == name })?
      .value
  }
}

extension URLComponents {
  /// Foundation leaves `+` unescaped in query values, and servers decode an unescaped `+` as a space.
  mutating func appendQueryItems(_ items: [URLQueryItem]) {
    let encodedItems = items.map {
      URLQueryItem(
        name: $0.name.addingPercentEncoding(withAllowedCharacters: .afURLQueryAllowed) ?? $0.name,
        value: $0.value?.addingPercentEncoding(withAllowedCharacters: .afURLQueryAllowed)
      )
    }
    percentEncodedQueryItems = (percentEncodedQueryItems ?? []) + encodedItems
  }
}

extension URLRequest {
  mutating func appendQueryItems(_ items: [URLQueryItem]) {
    guard let url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
    components.appendQueryItems(items)
    self.url = components.url ?? url
  }
}
