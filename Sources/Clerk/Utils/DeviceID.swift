//
//  DeviceID.swift
//
//
//  Created by Mike Pitre on 6/28/24.
//

import Foundation

#if canImport(UIKit)
  import UIKit
#endif

@MainActor
var deviceID: String {
  #if !os(watchOS) && !os(macOS)
    UIDevice.current.identifierForVendor?.uuidString ?? "none"
  #else
    "uidevice-unsupported"
  #endif
}
