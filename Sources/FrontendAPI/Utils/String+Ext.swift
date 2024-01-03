//
//  String+Ext.swift
//
//
//  Created by Mike Pitre on 10/23/23.
//

import Foundation

extension String {
    func base64Encoded() -> String? {
        data(using: .utf8)?.base64EncodedString()
    }

    func base64Decoded() -> String? {
        let stringWithPadding = self.padding(
            toLength: ((self.count+3)/4)*4,
            withPad: "=",
            startingAt: 0
        )
        
        guard let data = Data(base64Encoded: stringWithPadding) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    public var capitalizedSentence: String {
        let firstLetter = self.prefix(1).capitalized
        let remainingLetters = self.dropFirst().lowercased()
        return firstLetter + remainingLetters
    }
}
