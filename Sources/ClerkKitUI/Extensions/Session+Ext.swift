//
//  Session+Ext.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import Foundation
import SwiftUI

extension Session {
  var requiresForcedMfa: Bool {
    status == .pending && pendingTasks.contains(.setupMfa)
  }

  @MainActor
  var isThisDevice: Bool {
    id == Clerk.shared.session?.id
  }
}

extension SessionActivity {
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

  var browserFormatted: String {
    [browserName, browserVersion].compactMap(\.self).joined(separator: " ")
  }

  var locationFormatted: String {
    [city, country].compactMap(\.self).joined(separator: ", ")
  }

  var ipAndLocationFormatted: String {
    [ipAddress, "(\(locationFormatted))"].compactMap(\.self).joined(separator: " ")
  }
}

#endif
