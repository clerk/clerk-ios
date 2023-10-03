//
//  SessionStatus.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public enum SessionStatus: String, Codable {
    case abandoned
    case active
    case ended
    case expired
    case removed
    case replaced
    case revoked
}
