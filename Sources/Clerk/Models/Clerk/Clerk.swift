//
//  Clerk.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Dependencies
import Get
import Foundation
import RegexBuilder

#if canImport(UIKit)
import UIKit
#endif

/**
 This is the main entrypoint class for the clerk package. It contains a number of methods and properties for interacting with the Clerk API.
 */
@MainActor
@Observable
final public class Clerk {
  
  /// The shared Clerk instance.
  public static let shared = Clerk()
  
  /// A getter to see if the Clerk object is ready for use or not.
  private(set) public var isLoaded: Bool = false
  
  /// A getter to see if a Clerk instance is running in production or development mode.
  public var instanceType: InstanceEnvironmentType {
    if publishableKey.starts(with: "pk_live_") {
      return .production
    }
    return .development
  }
  
  /// The Client object for the current device.
  internal(set) public var client: Client? {
    didSet {
      if let clientId = client?.id {
        try? clerkClient.saveClientIdToKeychain(clientId: clientId)
      }
    }
  }
  
  /// The currently active Session, which is guaranteed to be one of the sessions in Client.sessions. If there is no active session, this field will be nil.
  public var session: Session? {
    guard let client else { return nil }
    return client.sessions.first(where: { $0.id == client.lastActiveSessionId })
  }
  
  /// A shortcut to Session.user which holds the currently active User object. If the session is nil, the user field will match.
  public var user: User? {
    session?.user
  }
  
  /// The publishable key from your Clerk Dashboard, used to connect to Clerk.
  private(set) public var publishableKey: String = "" {
    didSet {
      let liveRegex = Regex {
        "pk_live_"
        Capture {
          OneOrMore(.any)
        }
      }
      
      let testRegex = Regex {
        "pk_test_"
        Capture {
          OneOrMore(.any)
        }
      }
      
      if let match = publishableKey.firstMatch(of: liveRegex)?.output.1 ?? publishableKey.firstMatch(of: testRegex)?.output.1,
         let apiUrl = String(match).base64String() {
        frontendApiUrl = "https://\(apiUrl.dropLast())"
      }
    }
  }
  
  /// Frontend API URL.
  private(set) var frontendApiUrl: String = "" {
    didSet {
      _ = apiClientProvider.createClient(baseUrl: frontendApiUrl)
    }
  }
  
  /// The retrieved active sessions for this user.
  ///
  /// Is set by the `getSessions` function on a user.
  var sessionsByUserId: [String: [Session]] = .init()
  
  /// The configurable redirect settings. For example: `redirectUrl`, `callbackUrlScheme`
  public var redirectConfig = RedirectConfig()
  
  /// The event emitter for auth events.
  public let authEventEmitter = EventEmitter<AuthEvent>()
  
  /// Enable for additional debugging signals.
  private(set) public var debugMode: Bool = false
  
  /// The Clerk environment for the instance.
  var environment = Environment()
  
  // MARK: - Private Properties
  
  nonisolated init() {}
    
  @ObservationIgnored
  @Dependency(\.apiClientProvider) private var apiClientProvider
  
  @ObservationIgnored
  @Dependency(\.clerkClient) private var clerkClient
  
  /// Holds a reference to the task performed when the app will enter the foreground.
  private var willEnterForegroundTask: Task<Void, Error>?
  
  /// Holds a reference to the task performed when the app entered the background.
  private var didEnterBackgroundTask: Task<Void, Error>?
  
  /// Holds a reference to the session polling task.
  private var sessionPollingTask: Task<Void, Error>?
}

extension Clerk {
  
  /// Configures the shared clerk instance.
  /// - Parameters:
  ///     - publishableKey: The publishable key from your Clerk Dashboard, used to connect to Clerk.
  ///     - debugMode: Enable for additional debugging signals.
  public func configure(publishableKey: String, debugMode: Bool = false) {
    if publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      dump("""
        Clerk configured without a publishable key. 
        Please include a valid publishable key.
        """)
      return
    }
    
    self.publishableKey = publishableKey
    self.debugMode = debugMode
  }
  
  /// Loads all necessary environment configuration and instance settings from the Frontend API.
  /// It is absolutely necessary to call this method before using the Clerk object in your code.
  public func load() async throws {
    if publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw ClerkClientError(
        message: """
          Clerk loaded without a publishable key. 
          Please call configure() with a valid publishable key first.
        """
      )
    }
    
    do {
      startSessionTokenPolling()
      setupNotificationObservers()
      
      async let client = Client.get()
      async let environment = Environment.get()
      self.environment = try await environment
      
      try? await attestDeviceIfNeeded(environment: environment)
      
      isLoaded = true
    } catch {
      throw error
    }
  }
  
  /// Signs out the active user.
  ///
  /// - In a **multi-session** application: Signs out the active user from all sessions.
  /// - In a **single-session** context: Signs out the active user from the current session.
  /// - You can specify a specific session to sign out by passing the `sessionId` parameter.
  ///
  /// - Parameter sessionId: An optional session ID to specify a particular session to sign out.
  ///   Useful for multi-session applications.
  ///
  /// - Throws: An error if the sign-out process fails.
  ///
  /// - Example:
  /// ```swift
  /// try await clerk.signOut()
  /// ```
  public func signOut(sessionId: String? = nil) async throws {
    try await clerkClient.signOut(sessionId: sessionId)
  }
  
  /// A method used to set the active session.
  ///
  /// Useful for multi-session applications.
  ///
  /// - Parameter sessionId: The session ID to be set as active.
  public func setActive(sessionId: String) async throws {
    try await clerkClient.setActive(sessionId: sessionId)
  }
}

extension Clerk {
  
  // MARK: - Private Properties
  
  var apiClient: APIClient {
    get async throws {
      try apiClientProvider.current()
    }
  }
  
  private func setupNotificationObservers() {
  #if !os(watchOS) && !os(macOS)
    
    // cancel existing tasks if they exist (switching instances)
    willEnterForegroundTask?.cancel()
    didEnterBackgroundTask?.cancel()
    
    willEnterForegroundTask = Task {
      for await _ in NotificationCenter.default.notifications(
        named: UIApplication.willEnterForegroundNotification
      ).map({ _ in () }) {
        self.startSessionTokenPolling()
        
        // Start both functions concurrently without waiting for them
        Task {
          _ = try? await Client.get()
        }
        
        Task {
          self.environment = try await Environment.get()
        }
      }
    }
    
    didEnterBackgroundTask = Task {
      for await _ in NotificationCenter.default.notifications(
        named: UIApplication.didEnterBackgroundNotification
      ).map({ _ in () }) {
        stopSessionTokenPolling()
      }
    }
    
    #endif
  }
  
  private func startSessionTokenPolling() {
    guard sessionPollingTask == nil || sessionPollingTask?.isCancelled == true else {
      return
    }
    
    sessionPollingTask = Task(priority: .background) {
      repeat {
        if let session = session {
          _ = try? await session.getToken(.init(skipCache: true))
        }
        try await Task.sleep(for: .seconds(50), tolerance: .seconds(0.1))
      } while !Task.isCancelled
    }
  }
  
  private func stopSessionTokenPolling() {
    sessionPollingTask?.cancel()
    sessionPollingTask = nil
  }
  
  private func attestDeviceIfNeeded(environment: Environment) {
    if !AppAttestHelper.hasKeyId, [.onboarding, .enforced].contains(environment.fraudSettings?.native.deviceAttestationMode) {
      Task.detached {
        do {
          try await AppAttestHelper.performDeviceAttestation()
        } catch {
          dump(error)
        }
      }
    }
  }
  
}
