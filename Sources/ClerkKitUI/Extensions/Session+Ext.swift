//
//  Session+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 5/13/25.
//

#if os(iOS)

import ClerkKit
import Foundation
import SwiftUI

extension Session {

  @MainActor
  var isThisDevice: Bool {
    id == Clerk.shared.session?.id
  }

}

extension SessionActivity {

  var deviceText: Text {
    if let deviceType {
      return Text(verbatim: deviceType)
    } else if let isMobile {
      return Text(isMobile ? "Mobile device" : "Desktop device", bundle: .module)
    } else {
      return Text("Unknown device", bundle: .module)
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
