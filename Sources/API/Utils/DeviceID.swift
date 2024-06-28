//
//  DeviceID.swift
//
//
//  Created by Mike Pitre on 6/28/24.
//

import Foundation
import UIKit

var deviceID: String {
    #if !os(watchOS)
    UIDevice.current.identifierForVendor?.uuidString ?? "none"
    #else
    "watch-none"
    #endif
}
