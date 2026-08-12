//
//  Clerk+ForceUpdate.swift
//

import Foundation

extension Clerk {
  public var isForceUpdateRequired: Bool {
    !appVersionSupportStatus.isSupported
  }
}
