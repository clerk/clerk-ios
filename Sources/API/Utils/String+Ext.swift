//
//  String+Ext.swift
//
//
//  Created by Mike Pitre on 10/23/23.
//

import Foundation

extension String {
    
    var capitalizedSentence: String {
        let firstLetter = self.prefix(1).capitalized
        let remainingLetters = self.dropFirst().lowercased()
        return firstLetter + remainingLetters
    }
    
}
