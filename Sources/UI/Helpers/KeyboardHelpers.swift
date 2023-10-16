//
//  KeyboardHelpers.swift
//
//
//  Created by Mike Pitre on 10/12/23.
//

#if canImport(UIKit)

import SwiftUI

enum KeyboardHelpers {
    
    static func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
}

#endif
