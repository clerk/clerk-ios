//
//  PhoneNumber+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/19/25.
//

import Foundation
import Clerk
import PhoneNumberKit
import Factory

extension ClerkPhoneNumber {
    
    func isPrimary(for user: User) -> Bool {
        user.primaryPhoneNumberId == id
    }
    
    var regionId: String? {
        let phoneNumberKit = Container.shared.phoneNumberKit()
        guard let phoneNumber = try? phoneNumberKit.parse(phoneNumber) else { return nil }
        return phoneNumber.regionID
    }
    
    var flag: String? {
        let phoneNumberKit = Container.shared.phoneNumberKit()
        guard let phoneNumber = try? phoneNumberKit.parse(phoneNumber) else { return phoneNumber }

        #if os(iOS)
        
        if
            let region = phoneNumber.regionID,
            let country = CountryCodePickerViewController.Country(for: region, with: phoneNumberKit)
        {
            return country.flag
        }
        #endif
        
        return nil
    }
    
    func formatted(_ format: PhoneNumberFormat) -> String {
        let phoneNumberKit = Container.shared.phoneNumberKit()
        guard let phoneNumber = try? phoneNumberKit.parse(phoneNumber) else { return phoneNumber }
        return phoneNumberKit.format(phoneNumber, toType: format)
    }
    
}

extension Container {
    
    var phoneNumberKit: Factory<PhoneNumberKit> {
        self { PhoneNumberKit() }
            .cached
    }
    
}
