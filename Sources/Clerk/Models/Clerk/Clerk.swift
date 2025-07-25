//
//  Clerk.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import FactoryKit
import Foundation
import Get
import RegexBuilder
import RequestBuilder
import SimpleKeychain

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
  public nonisolated static let shared = Container.shared.clerk()

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
      if let client = client {
        try? saveClientToKeychain(client: client)
      } else {
        try? Container.shared.keychain().deleteItem(forKey: "cachedClient")
      }
    }
  }

  /// The currently active Session, which is guaranteed to be one of the sessions in Client.sessions. If there is no active session, this field will be nil.
  public var session: Session? {
    guard let client else { return nil }
    return client.activeSessions.first(where: { $0.id == client.lastActiveSessionId })
  }

  /// A shortcut to Session.user which holds the currently active User object. If the session is nil, the user field will match.
  public var user: User? {
    session?.user
  }

  /// A dictionary of a user's active sessions on all devices.
  internal(set) public var sessionsByUserId: [String: [Session]] = [:]

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
        let apiUrl = String(match).base64String()
      {
        frontendApiUrl = "https://\(apiUrl.dropLast())"
      }
    }
  }

  /// The event emitter for auth events.
  public let authEventEmitter = EventEmitter<AuthEvent>()

  /// The Clerk environment for the instance.
  var environment = Environment() {
    didSet {
      try? saveEnvironmentToKeychain(environment: environment)
    }
  }

  // MARK: - Private Properties

  nonisolated init() {
    Task { @MainActor in
      loadCachedClient()
      loadCachedEnvironment()
    }
  }

  /// Frontend API URL.
  private(set) var frontendApiUrl: String = "" {
    didSet {
      Container.shared.apiClient.register { [frontendApiUrl] in
        BaseSessionManager(base: URL(string: frontendApiUrl), session: .ephemeral)
          .set(encoder: .clerkEncoder)
          .set(decoder: .clerkDecoder)
          .interceptor(URLRequestInterceptorClerkHeaders())
          .interceptor(URLRequestInterceptorQueryItems())
          .interceptor(URLRequestInterceptorInvalidAuth())
          .interceptor(URLRequestInterceptorDeviceAssertion())
          .interceptor(URLRequestInterceptorDeviceTokenSaving())
          .interceptor(URLRequestInterceptorClientSync())
          .interceptor(URLRequestInterceptorEventEmitter())
          .interceptor(URLRequestInterceptorClerkErrorThrowing())
      }
    }
  }

  /// The configuration settings for this Clerk instance.
  nonisolated var settings: Settings = .init() {
    didSet {
      Container.shared.keychain.register { [keychainConfig = settings.keychainConfig] in
        SimpleKeychain(
          service: keychainConfig.service,
          accessGroup: keychainConfig.accessGroup,
          accessibility: .afterFirstUnlockThisDeviceOnly
        )
      }
    }
  }

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
  public func configure(
    publishableKey: String,
    settings: Settings = .init()
  ) {
    self.publishableKey = publishableKey
    self.settings = settings
  }

  /// Loads all necessary environment configuration and instance settings from the Frontend API.
  /// It is absolutely necessary to call this method before using the Clerk object in your code.
  public func load() async throws {
    if publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      ClerkLogger.error("Clerk loaded without a publishable key. Please call configure() with a valid publishable key first.")
      return
    }

    do {
      startSessionTokenPolling()
      setupNotificationObservers()

      // Both of these are automatically applied to the shared instance:
      async let client = Client.get()  // via middleware
      async let environment = Environment.get()  // via the function itself

      _ = try await client
      attestDeviceIfNeeded(environment: try await environment)

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
    if let sessionId {
      let request = ClerkFAPI.v1.client.sessions.id(sessionId).remove.post
      try await Container.shared.apiClient().send(request)
    } else {
      let request = ClerkFAPI.v1.client.sessions.delete
      try await Container.shared.apiClient().send(request)
    }
  }

  /// A method used to set the active session.
  ///
  /// Useful for multi-session applications.
  ///
  /// - Parameter sessionId: The session ID to be set as active.
  /// - Parameter organizationId: The organization ID to be set as active in the current session. If nil, the currently active organization is removed as active.
  public func setActive(sessionId: String, organizationId: String? = nil) async throws {
    let request = Request<ClientResponse<Session>>(
      path: "v1/client/sessions/\(sessionId)/touch",
      method: .post,
      body: ["active_organization_id": organizationId ?? ""]  // nil key/values get dropped, use an empty string to set no active org
    )
    try await Container.shared.apiClient().send(request)
  }
}

extension Clerk {

  // MARK: - Private Properties

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
            try? await Client.get()
          }

          Task {
            try? await Environment.get()
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
          try? await session.getToken()
        }
        try await Task.sleep(for: .seconds(5), tolerance: .seconds(0.1))
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
          ClerkLogger.logError(error, message: "Device attestation failed")
        }
      }
    }
  }

  private func loadCachedClient() {
    do {
      if let cachedClient = try loadClientFromKeychain() {
        // Only set cached client if we don't already have one
        // This prevents overwriting fresh data during load()
        if self.client == nil {
          self.client = cachedClient
        }
      }
    } catch {
      // If loading fails, continue without cached client
      ClerkLogger.logError(error, message: "Failed to load cached client")
    }
  }

  private func loadCachedEnvironment() {
    do {
      if let cachedEnvironment = try loadEnvironmentFromKeychain() {
        // Only set cached environment if we don't already have fresh data
        // This prevents overwriting fresh data during load()
        if self.environment.isEmpty {
          self.environment = cachedEnvironment
        }
      }
    } catch {
      // If loading fails, continue without cached environment
      ClerkLogger.logError(error, message: "Failed to load cached environment")
    }
  }

  private func saveClientToKeychain(client: Client) throws {
    let encoder = JSONEncoder.clerkEncoder
    let clientData = try encoder.encode(client)
    try Container.shared.keychain().set(clientData, forKey: "cachedClient")
  }

  private func loadClientFromKeychain() throws -> Client? {
    guard let clientData = try? Container.shared.keychain().data(forKey: "cachedClient") else {
      return nil
    }
    let decoder = JSONDecoder.clerkDecoder
    return try decoder.decode(Client.self, from: clientData)
  }

  private func saveEnvironmentToKeychain(environment: Clerk.Environment) throws {
    let encoder = JSONEncoder.clerkEncoder
    let environmentData = try encoder.encode(environment)
    try Container.shared.keychain().set(environmentData, forKey: "cachedEnvironment")
  }

  private func loadEnvironmentFromKeychain() throws -> Environment? {
    guard let environmentData = try? Container.shared.keychain().data(forKey: "cachedEnvironment") else {
      return nil
    }
    let decoder = JSONDecoder.clerkDecoder
    return try decoder.decode(Clerk.Environment.self, from: environmentData)
  }

}

extension Container {

  var clerk: Factory<Clerk> {
    self { Clerk() }
      .singleton
  }

  var keychain: Factory<SimpleKeychain> {
    self { SimpleKeychain(accessibility: .afterFirstUnlockThisDeviceOnly) }
      .cached
  }

}

extension Clerk {

  @_spi(Internal)
  public static var mock: Clerk {
    let clerk = Clerk()
    clerk.client = .mock
    clerk.environment = .mock
    clerk.sessionsByUserId = [User.mock.id: [.mock, .mock2]]
    return clerk
  }

  @_spi(Internal)
  public static var mockSignedOut: Clerk {
    let clerk = Clerk()
    clerk.client = .mockSignedOut
    clerk.environment = .mock
    clerk.sessionsByUserId = [:]
    return clerk
  }

}

#if canImport(SwiftUI)
  import SwiftUI

  extension EnvironmentValues {
    @Entry public var clerk = Clerk.shared
  }
#endif
