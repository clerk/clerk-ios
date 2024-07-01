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

var deviceID: String {
    #if canImport(UIKit)
    UIDevice.current.identifierForVendor?.uuidString ?? "none"
    #else
    "uikit-unsupported"
    #endif
}
