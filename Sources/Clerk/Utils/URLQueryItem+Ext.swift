//
//  File.swift
//
//
//  Created by Mike Pitre on 7/7/24.
//

import Foundation

extension Collection where Element == URLQueryItem {

  var asTuples: [(String, String?)] {
    map { ($0.name, $0.value) }
  }

}
