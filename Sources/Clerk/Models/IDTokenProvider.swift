//
//  IDTokenProvider.swift
//
//
//  Created by Mike Pitre on 9/16/24.
//

import Foundation

public enum IDTokenProvider {
    case apple
}

extension IDTokenProvider {
    
    public var strategy: String {
        switch self {
        case .apple:
            return "oauth_token_apple"
        }
    }
    
}
