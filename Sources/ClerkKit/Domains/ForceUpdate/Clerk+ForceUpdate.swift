//
//  Clerk+ForceUpdate.swift
//

import Foundation

extension Clerk {
  public var isForceUpdateRequired: Bool {
    environment?.forceUpdate.required == true
  }
}
