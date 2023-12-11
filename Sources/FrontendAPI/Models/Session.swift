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
 
 The SessionWithActivities object is a modified Session object. It contains most of the information that the Session object stores, adding extra information about the current session's latest activity.

 The additional data included in the latest activity are useful for analytics purposes. A SessionActivity object will provide information about the user's location, device and browser.

 While the SessionWithActivities object wraps the most important information around a Session object, the two objects have entirely different methods.
 */
public struct Session: Codable, Identifiable {
    public init(
        id: String,
        status: SessionStatus,
        expireAt: Date = .now,
        abandonAt: Date = .now,
        lastActiveAt: Date = .now,
        latestActivity: SessionActivity? = nil,
        lastActiveOrganizationId: String? = nil,
        actor: String? = nil,
        user: User?,
        publicUserData: JSON? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastActiveToken: String? = nil
    ) {
        self.id = id
        self.status = status
        self.expireAt = expireAt
        self.abandonAt = abandonAt
        self.lastActiveAt = lastActiveAt
        self.latestActivity = latestActivity
        self.lastActiveOrganizationId = lastActiveOrganizationId
        self.actor = actor
        self.user = user
        self.publicUserData = publicUserData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
//        self.lastActiveToken = lastActiveToken
    }
    
    /// A unique identifier for the session.
    public let id: String
    
    /// The current state of the session.
    let status: SessionStatus
    
    /// The time the session expires and will cease to be active.
    let expireAt: Date
    
    /// The time when the session was abandoned by the user.
    let abandonAt: Date
    
    /// The time the session was last active on the client.
    public let lastActiveAt: Date
    
    /// The latest activity associated with the session.
    public let latestActivity: SessionActivity?
    
    /// The last active organization identifier.
    let lastActiveOrganizationId: String?
    
    /// The JWT actor for the session.
    let actor: String?
    
    /// The user associated with the session.
    public var user: User?
    
    /// Public information about the user that this session belongs to.
    let publicUserData: JSON?
    
    /// The time the session was created.
    let createdAt: Date
    
    /// The last time the session recorded activity of any kind.
    let updatedAt: Date
    
    /// The last active token for the session.
//    let lastActiveToken: JSON?
}

extension Session {
    
    public var isThisDevice: Bool {
        Clerk.shared.client.lastActiveSessionId == id
    }
    
    public var browserDisplayText: String {
        var string = ""
        if let browserName = latestActivity?.browserName {
            string += browserName
        }
        
        if let browserVersion = latestActivity?.browserVersion {
            string += " \(browserVersion)"
        }
        
        return string
    }
    
    public var ipAddressDisplayText: String {
        var string = ""
        if let ipAddress = latestActivity?.ipAddress {
            string += ipAddress
        }
        
        if latestActivity?.city != nil || latestActivity?.country != nil {
            string += " ("
            if let city = latestActivity?.city {
                string += city
            }
            if let country = latestActivity?.country {
                string += ", \(country)"
            }
            string += ")"
        }
        
        return string
    }
    
    public var identifier: String? {
        publicUserData?["identifier"]?.stringValue
    }
    
}

extension Session: Comparable {
    
    public static func < (lhs: Session, rhs: Session) -> Bool {
        if lhs.isThisDevice != rhs.isThisDevice  {
            return lhs.isThisDevice
        } else {
            return lhs.lastActiveAt > rhs.lastActiveAt
        }
    }
}

public struct SessionActivity: Codable, Equatable {
    /// A unique identifier for the session activity record.
    let id: String
    
    /// The name of the browser from which this session activity occurred.
    public let browserName: String?
    
    /// The version of the browser from which this session activity occurred.
    public let browserVersion: String?
    
    /// The type of the device which was used in this session activity.
    public let deviceType: String?
    
    /// The IP address from which this session activity originated.
    public let ipAddress: String?
    
    /// The city from which this session activity occurred. Resolved by IP address geo-location.
    public let city: String?
    
    /// The country from which this session activity occurred. Resolved by IP address geo-location.
    public let country: String?
    
    /// Will be set to true if the session activity came from a mobile device. Set to false otherwise.
    public let isMobile: Bool?
}

/**
 Represents the status of a session.
 
 - abandoned: The session was abandoned client-side.
 - active: The session is valid, and all activity is allowed.
 - ended: The user signed out of the session, but the Session remains in the Client object.
 - expired: The period of allowed activity for this session has passed.
 - removed: The user signed out of the session, and the Session was removed from the Client object.
 - replaced: The session has been replaced by another one, but the Session remains in the Client object.
 - revoked: The application ended the session, and the Session was removed from the Client object.
 */
public enum SessionStatus: String, Codable {
    /// The session was abandoned client-side.
    case abandoned
    
    /// The session is valid, and all activity is allowed.
    case active
    
    /// The user signed out of the session, but the Session remains in the Client object.
    case ended
    
    /// The period of allowed activity for this session has passed.
    case expired
    
    /// The user signed out of the session, and the Session was removed from the Client object.
    case removed
    
    /// The session has been replaced by another one, but the Session remains in the Client object.
    case replaced
    
    /// The application ended the session, and the Session was removed from the Client object.
    case revoked
}

extension Session {
    
    @MainActor
    @discardableResult
    public func revoke() async throws -> Session {
        let request = APIEndpoint
            .v1
            .me
            .sessions
            .withId(id: id)
            .revoke
            .post
        
        let revokedSession = try await Clerk.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }.value.response
        
        try await Clerk.shared.client.get()
        return revokedSession
    }
    
}
