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
public struct Session: Codable, Identifiable, Sendable {
    
    /// A unique identifier for the session.
    public let id: String
    
    /// The current state of the session.
    public let status: SessionStatus
    
    /// The time the session expires and will cease to be active.
    public let expireAt: Date
    
    /// The time when the session was abandoned by the user.
    public let abandonAt: Date
    
    /// The time the session was last active on the client.
    public let lastActiveAt: Date
    
    /// The latest activity associated with the session.
    public let latestActivity: SessionActivity?
    
    /// The last active organization identifier.
    public let lastActiveOrganizationId: String?
    
    /// The JWT actor for the session.
    public let actor: String?
    
    /// The user associated with the session.
    public var user: User?
    
    /// Public information about the user that this session belongs to.
    public let publicUserData: PublicUserData?
    
    /// The time the session was created.
    public let createdAt: Date
    
    /// The last time the session recorded activity of any kind.
    public let updatedAt: Date
    
    /// The last active token for the session.
    public let lastActiveToken: TokenResource?
    
    /// Information about the user that's publicly available.
    public struct PublicUserData: Codable, Equatable, Sendable {
        /// The user's first name. This attribute will only be populated if name is enabled in instance settings.
        public let firstName: String?
        
        /// The user's last name. This attribute will only be populated if name is enabled in instance settings.
        public let lastName: String?
        
        /// A getter boolean to check if the user has uploaded an image or one was copied from OAuth. Returns false if Clerk is displaying an avatar for the user.
        public let imageUrl: String
        
        /// Whether the user has a profile image.
        public let hasImage: Bool
        
        /// The user's identifier (email address, phone number, username, etc) that was used for authentication when this session was created.
        public let identifier: String
    }
}

extension Session {
    
    @MainActor
    var isThisDevice: Bool {
        Clerk.shared.client?.lastActiveSessionId == id
    }
    
    var browserDisplayText: String {
        var string = ""
        if let browserName = latestActivity?.browserName {
            string += browserName
        }
        
        if let browserVersion = latestActivity?.browserVersion {
            string += " \(browserVersion)"
        }
        
        return string
    }
    
    var ipAddressDisplayText: String {
        var string = ""
        if let ipAddress = latestActivity?.ipAddress {
            string += ipAddress
        }
        
        if latestActivity?.city != nil || latestActivity?.country != nil {
            var cityCountry: [String] = []
            
            if let city = latestActivity?.city {
                cityCountry.append(city)
            }
            if let country = latestActivity?.country {
                cityCountry.append(country)
            }
            
            var locationString = " (" + cityCountry.joined(separator: ", ")
            locationString.append(")")
            
            string += locationString
        }
        
        return string
    }
    
    var identifier: String? {
        publicUserData?.identifier
    }
    
}

extension Session: Comparable {
    
    @MainActor
    public static func < (lhs: Session, rhs: Session) -> Bool {
        if lhs.isThisDevice != rhs.isThisDevice  {
            return lhs.isThisDevice
        } else {
            return lhs.lastActiveAt > rhs.lastActiveAt
        }
    }
}

/// A `SessionActivity` object will provide information about the user's location, device and browser.
public struct SessionActivity: Codable, Equatable, Sendable {
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

/// Represents the status of a session.
public enum SessionStatus: String, Codable, Sendable {
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
    /// Format for the session token cache key
    ///
    /// For example:
    /// - If the template is null, the key will be 'sess_abc12345'
    /// - If the template is 'supabase', the key will be 'sess_abc12345-supabase'
    func tokenCacheKey(template: String?) -> String {
        var tokenCacheKey = id
        if let template = template {
            tokenCacheKey += "-\(template)"
        }
        return tokenCacheKey
    }
}

extension Session {
    
    /// Marks this session as revoked. If this is the active session, the attempt to revoke it will fail. Users can revoke only their own sessions.
    @discardableResult @MainActor
    public func revoke() async throws -> Session {
        let request = ClerkAPI.v1.me.sessions.withId(id: id).revoke.post
        let response = try await Clerk.shared.apiClient.send(request) {
            $0.url?.append(queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)])
        }
        
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /**
     Retrieves the user's session token for the given template or the default clerk token.
     This method uses a cache so a network request will only be made if the token in memory is expired.
     The TTL for clerk token is one minute.
     */
    @discardableResult
    public func getToken(_ options: GetTokenOptions = .init()) async throws -> TokenResource? {
        return try await SessionTokenFetcher.shared.getToken(self, options: options)
    }
    
    /// Options that can be passed as parameters to the `getToken()` function.
    public struct GetTokenOptions: Hashable, Sendable {
        
        public init(
            template: String? = nil,
            expirationBuffer: Double = 10,
            skipCache: Bool = false
        ) {
            self.template = template
            self.expirationBuffer = min(expirationBuffer, 60)
            self.skipCache = skipCache
        }

        /// The name of the JWT template from the Clerk Dashboard to generate a new token from. E.g. 'firebase', 'grafbase', or your custom template's name.
        public let template: String?
        
        /// If the cached token will expire within X seconds (the buffer), fetch a new token instead. Max is 60 seconds.
        public let expirationBuffer: Double
        
        /// Whether to skip the cache lookup and force a call to the server instead, even within the TTL. Useful if the token claims are time-sensitive or depend on data that can be updated (e.g. user fields). Defaults to false.
        public let skipCache: Bool
    }
    
}

// The purpose of this actor is to NOT trigger refreshes of tokens if a refresh is already in progress.
// This is not a token cache. It is only responsible to returning in progress tasks to refresh a token.
actor SessionTokenFetcher {
    static let shared = SessionTokenFetcher()
    
    // Key is `tokenCacheKey` property of a `session`
    private var tokenTasks: [String: Task<TokenResource?, Error>] = [:]
    
    func getToken(_ session: Session, options: Session.GetTokenOptions = .init()) async throws -> TokenResource? {
        
        let cacheKey = session.tokenCacheKey(template: options.template)
        
        if let inProgressTask = tokenTasks[cacheKey] {
            return try await inProgressTask.value
        }
        
        let task: Task<TokenResource?, Error> = Task {
            return try await fetchToken(session, options: options)
        }

        tokenTasks[cacheKey] = task
        
        let result = await task.result

        // clear the inProgressTask on success AND failure
        tokenTasks[cacheKey] = nil
        
        return try result.get()
    }
    
    /**
     Internal function to get the session token. Checks the cache first.
     */
    @discardableResult @MainActor
    func fetchToken(_ session: Session, options: Session.GetTokenOptions = .init()) async throws -> TokenResource? {
        
        let cacheKey = session.tokenCacheKey(template: options.template)
        
        if options.skipCache == false,
           let token = Clerk.shared.sessionTokensByCacheKey[cacheKey],
           let expiresAt = token.decodedJWT?.expiresAt,
           Date.now.distance(to: expiresAt) > options.expirationBuffer
        {
            return token
        }
                    
        var token: TokenResource?
        
        let tokensRequest = ClerkAPI.v1.client.sessions.id(session.id).tokens
        
        if let template = options.template {
            let templateTokenRequest = tokensRequest
                .template(template)
                .post()
            
            token = try await Clerk.shared.apiClient.send(templateTokenRequest).value
        } else {
            let defaultTokenRequest = tokensRequest.post()
            
            token = try await Clerk.shared.apiClient.send(defaultTokenRequest).value
        }
        
        if let token {
            Clerk.shared.sessionTokensByCacheKey[cacheKey] = token
        }
        
        return token
    }
    
}
