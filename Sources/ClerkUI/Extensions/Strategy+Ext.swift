//
//  Strategy+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/23/25.
//

extension Strategy {
    
    var icon: String? {
        switch self {
        case .password:
            return "lock.fill"
        case .phoneCode:
            return "text.bubble.fill"
        case .emailCode:
            return "envelope.fill"
        case .passkey:
            return "person.badge.key.fill"
        default:
            return nil
        }
    }
    
}
