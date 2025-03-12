//
//  String+Ext.swift
//
//
//  Created by Mike Pitre on 10/23/23.
//

import Foundation

extension String {
  
  var capitalizedSentence: String {
    let firstLetter = self.prefix(1).capitalized
    let remainingLetters = self.dropFirst().lowercased()
    return firstLetter + remainingLetters
  }
  
  func toJSON() -> JSON? {
    guard let data = self.data(using: .utf8, allowLossyConversion: false) else { return nil }
    let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    return try? JSON(jsonObject as Any)
  }
  
}
