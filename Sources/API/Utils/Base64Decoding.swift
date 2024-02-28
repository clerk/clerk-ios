//
//  File.swift
//  
//
//  Created by Mike Pitre on 2/28/24.
//

import Foundation

extension String {
    public func base64Data() -> Data? {
        var string = self
        let remainder = string.count % 4
        if remainder > 0 {
            string = string.padding(toLength: string.count + 4 - remainder, withPad: "=", startingAt: 0)
        }

        return Data(base64Encoded: string)
    }
    
    public func base64String() -> String? {
        if let data = self.base64Data() {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
