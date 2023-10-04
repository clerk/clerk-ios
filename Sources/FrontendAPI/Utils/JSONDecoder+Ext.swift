//
//  JSONDecoder+Ext.swift
//
//
//  Created by Mike Pitre on 10/4/23.
//

import Foundation

extension JSONDecoder {
    
    static var snakeCaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
    
}
