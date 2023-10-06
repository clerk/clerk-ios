//
//  Session.swift
//
//
//  Created by Mike Pitre on 10/5/23.
//

import Foundation

/**
 The Session object is an abstraction over an HTTP session. It models the period of information exchange between a user and the server.

 The Session object includes methods for recording session activity and ending the session client-side. For security reasons, sessions can also expire server-side.

 As soon as a User signs in, Clerk creates a Session for the current Client. Clients can have more than one sessions at any point in time, but only one of those sessions will be active.

 In certain scenarios, a session might be replaced by another one. This is often the case with mutli-session applications.

 All sessions that are expired, removed, replaced, ended or abandoned are not considered valid.
 */
public struct Session: Decodable {
    
    init(
        id: String,
        status: String
    ) {
        self.id = id
        self.status = status
    }
    
    public let id: String
    public let status: String
}
