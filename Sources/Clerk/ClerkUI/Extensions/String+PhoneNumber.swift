//
//  String+PhoneNumber.swift.swift
//  Clerk
//
//  Created by Mike Pitre on 4/29/25.
//

#if canImport(SwiftUI)

import Factory
import Foundation

extension String {
  public var formattedAsPhoneNumberIfPossible: String {
    let utility = Container.shared.phoneNumberUtility()
    do {
      let number = try utility.parse(self)
      return utility.format(number, toType: .national)
    } catch {
      return self
    }
  }
}

#endif
