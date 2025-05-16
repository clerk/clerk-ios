//
//  String+Ext.swift
//
//
//  Created by Mike Pitre on 10/23/23.
//

import Foundation

extension String {

  func toJSON() -> JSON? {
    guard let data = self.data(using: .utf8, allowLossyConversion: false) else { return nil }
    let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    return try? JSON(jsonObject as Any)
  }

}
