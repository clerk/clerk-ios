//
//  SessionPollingManager.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Protocol defining an interface for providing the current session.
///
/// Implementations of this protocol can provide the current active session
/// for token refresh operations.
protocol SessionProviding: Sendable {
    /// Returns the current active session, if available.
    @MainActor var session: Session? { get }
}

/// Manages periodic polling of session tokens to keep them refreshed.
///
/// This class handles the background task that periodically refreshes session tokens
/// to ensure they remain valid. The polling interval is configurable and defaults to 5 seconds.
@MainActor
final class SessionPollingManager {
    
    /// The interval between token refresh attempts.
    static let defaultPollInterval: TimeInterval = 5.0
    
    /// The tolerance for the polling interval to allow for system scheduling flexibility.
    static let defaultPollTolerance: TimeInterval = 0.1
    
    /// Task that performs the periodic token polling.
    nonisolated(unsafe) private var pollingTask: Task<Void, Error>?
    
    /// The provider that supplies the current session for token retrieval.
    @MainActor private let sessionProvider: any SessionProviding
    
    /// The interval between polling attempts.
    private let pollInterval: TimeInterval
    
    /// The tolerance for the polling interval.
    private let pollTolerance: TimeInterval
    
    /// Creates a new session polling manager.
    ///
    /// - Parameters:
    ///   - sessionProvider: The object that provides the current active session.
    ///   - pollInterval: The interval between polling attempts. Defaults to 5 seconds.
    ///   - pollTolerance: The tolerance for the polling interval. Defaults to 0.1 seconds.
    init(
        sessionProvider: any SessionProviding,
        pollInterval: TimeInterval = defaultPollInterval,
        pollTolerance: TimeInterval = defaultPollTolerance
    ) {
        self.sessionProvider = sessionProvider
        self.pollInterval = pollInterval
        self.pollTolerance = pollTolerance
    }
    
    /// Starts polling for session tokens.
    ///
    /// If polling is already active, this method does nothing. The polling will continue
    /// until explicitly stopped or the manager is deallocated.
    func startPolling() {
        guard pollingTask == nil || pollingTask?.isCancelled == true else {
            return
        }
        
        let interval = self.pollInterval
        let tolerance = self.pollTolerance
        
        pollingTask = Task(priority: .background) { [weak self] in
            repeat {
                await self?.refreshTokenIfNeeded()
                try await Task.sleep(for: .seconds(interval), tolerance: .seconds(tolerance))
            } while !Task.isCancelled
        }
    }
    
    /// Stops polling for session tokens.
    ///
    /// This method cancels the polling task and cleans up resources. It can be called
    /// multiple times safely.
    nonisolated func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    /// Refreshes the token for the current session if one exists.
    @MainActor
    private func refreshTokenIfNeeded() async {
        guard let session = sessionProvider.session else {
            return
        }
        
        // Silently ignore errors - token refresh failures are non-critical
        _ = try? await session.getToken()
    }
    
    /// Cancels polling and cleans up resources.
    ///
    /// This is called automatically when the manager is deallocated.
    deinit {
        stopPolling()
    }
}

