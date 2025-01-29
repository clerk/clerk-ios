//
//  EmailAddress+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/19/25.
//

import Foundation

extension EmailAddress {
    
    func isPrimary(for user: User) -> Bool {
        user.primaryEmailAddressId == id
    }
    
}
