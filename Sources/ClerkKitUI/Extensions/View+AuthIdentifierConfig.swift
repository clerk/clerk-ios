//
//  View+AuthIdentifierConfig.swift
//  Clerk
//

#if os(iOS)

import SwiftUI

extension EnvironmentValues {
  @Entry var clerkInitialIdentifier: String?
  @Entry var clerkInitialPhoneNumber: String?
  @Entry var clerkPersistsIdentifiers: Bool = true
}

extension AuthView {
  /// Sets the initial value for the email or username field on the auth screen.
  ///
  /// Use this to pre-fill the identifier field when presenting `AuthView`.
  ///
  /// - Parameter identifier: The email address or username to pre-fill.
  /// - Returns: A view with the initial identifier configured.
  public func clerkInitialIdentifier(_ identifier: String) -> some View {
    environment(\.clerkInitialIdentifier, identifier)
  }

  /// Sets the initial value for the phone number field on the auth screen.
  ///
  /// Use this to pre-fill the phone number field when presenting `AuthView`.
  ///
  /// - Parameter phoneNumber: The phone number to pre-fill (e.g. `"15555550100"`).
  /// - Returns: A view with the initial phone number configured.
  public func clerkInitialPhoneNumber(_ phoneNumber: String) -> some View {
    environment(\.clerkInitialPhoneNumber, phoneNumber)
  }

  /// Controls whether auth identifier values are persisted between sessions.
  ///
  /// When set to `false`, any previously stored identifiers are cleared and
  /// future changes will not be saved. This is useful on shared devices where
  /// the previous user's information should not appear after sign-out.
  ///
  /// The default value is `true`, which preserves the existing persistence behavior.
  ///
  /// - Parameter persists: Whether to persist identifier values to storage.
  /// - Returns: A view with the identifier persistence behavior configured.
  public func clerkPersistsIdentifiers(_ persists: Bool) -> some View {
    environment(\.clerkPersistsIdentifiers, persists)
  }
}

#endif
