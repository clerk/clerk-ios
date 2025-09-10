//
//  Array+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 6/25/25.
//

#if os(iOS)

import Foundation

extension [String] {
  func sortedByPriority(_ priorityOrder: [String]) -> [String] {
    sorted { first, second in
      let firstPriority = priorityOrder.firstIndex(of: first) ?? Int.max
      let secondPriority = priorityOrder.firstIndex(of: second) ?? Int.max
      return firstPriority < secondPriority
    }
  }
}

#endif
