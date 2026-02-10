//
//  String+JSON.swift
//

import Foundation

extension String {
  func toJSON() -> JSON? {
    guard let data = data(using: .utf8, allowLossyConversion: false) else { return nil }
    let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    return try? JSON(jsonObject as Any)
  }
}
