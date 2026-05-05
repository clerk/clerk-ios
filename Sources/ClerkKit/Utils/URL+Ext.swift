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
