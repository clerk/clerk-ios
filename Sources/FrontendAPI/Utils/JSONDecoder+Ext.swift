//
//  JSONDecoder+Ext.swift
//
//
//  Created by Mike Pitre on 10/4/23.
//

import Foundation

extension JSONDecoder {
    
    static var clerkDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
    
}
