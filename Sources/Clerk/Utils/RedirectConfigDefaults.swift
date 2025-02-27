//
//  RedirectConfigDefaults.swift
//
//
//  Created by Mike Pitre on 3/19/24.
//

import Foundation

enum RedirectConfigDefaults {
  static let redirectUrl: String = "\(Bundle.main.bundleIdentifier ?? "")://callback"
  static let callbackUrlScheme: String = Bundle.main.bundleIdentifier ?? ""
}
