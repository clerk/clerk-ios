//
//  Session+Ext.swift
//  Clerk
//

import ClerkKit
import Foundation
import SwiftUI

extension Session {
  var pendingTasks: [Task] {
    tasks ?? []
  }

  var requiresForcedMfa: Bool {
    status == .pending && pendingTasks.contains(.setupMfa)
  }

  @MainActor
  var isThisDevice: Bool {
    id == Clerk.shared.session?.id
  }
}

extension SessionActivity {
  var browserFormatted: String {
    [browserName, browserVersion].compactMap(\.self).joined(separator: " ")
  }

  var locationFormatted: String {
    [city, country].compactMap(\.self).joined(separator: ", ")
  }

  var ipAndLocationFormatted: String {
    [ipAddress, "(\(locationFormatted))"].compactMap(\.self).joined(separator: " ")
  }

  var deviceDescription: String {
    if let deviceType, !deviceType.isEmpty {
      return deviceType
    }

    if let isMobile {
      return isMobile ? "Mobile device" : "Desktop device"
    }

    return "Unknown device"
  }

  var deviceText: Text {
    if let deviceType {
      Text(verbatim: deviceType)
    } else if let isMobile {
      Text(isMobile ? "Mobile device" : "Desktop device", bundle: .module)
    } else {
      Text("Unknown device", bundle: .module)
    }
  }

  var deviceImage: Image {
    Image(isMobile == true ? "device-mobile" : "device-desktop", bundle: .module)
  }
}
