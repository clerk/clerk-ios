//
//  ClerkInitializationState.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Represents the initialization state of a Clerk instance.
enum ClerkInitializationState {
    /// Initial state before any initialization has occurred.
    case uninitialized
    
    /// Cached data is being loaded from keychain.
    case loadingCachedData
    
    /// Cached data has been loaded (or skipped if none exists).
    case cachedDataLoaded
    
    /// Configuration has been applied (publishable key, options, API client).
    case configured
    
    /// Fresh data is being loaded from the API.
    case loadingFreshData
    
    /// Fully initialized and ready to use.
    case loaded
}

