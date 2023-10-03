//
//  Client.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

public struct Client: Codable {
    public let signIn: SignIn?
    public let signUp: SignUp?
    public let sessions: [Session]
    public let activeSessions: [Session]
    public let lastActiveSessionId: String
    public let updatedAt: Date
}
