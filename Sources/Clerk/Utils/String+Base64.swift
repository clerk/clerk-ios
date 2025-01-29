//
//  File.swift
//  
//
//  Created by Mike Pitre on 2/28/24.
//

import Foundation

extension String {

    func base64String() -> String? {
        if let data = self.dataFromBase64URL() {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func base64URLFromBase64String() -> String {
        var base64url = self
        base64url = base64url.replacingOccurrences(of: "+", with: "-")
        base64url = base64url.replacingOccurrences(of: "/", with: "_")
        base64url = base64url.replacingOccurrences(of: "=", with: "")
        return base64url
    }
    
    func dataFromBase64URL() -> Data? {
        var base64 = self
        
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        
        let paddingLength = 4 - (base64.count % 4)
        if paddingLength < 4 {
            base64 = base64.padding(toLength: base64.count + paddingLength, withPad: "=", startingAt: 0)
        }
        
        return Data(base64Encoded: base64)
    }
    
}
