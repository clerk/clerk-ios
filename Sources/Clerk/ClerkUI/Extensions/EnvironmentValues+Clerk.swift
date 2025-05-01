//
//  EnvironmentValues+Clerk.swift
//  Clerk
//
//  Created by Mike Pitre on 5/1/25.
//

#if os(iOS)

  import SwiftUI

  struct SupportEmailKey: EnvironmentKey {
    @MainActor
    static var defaultValue = Clerk.shared.environment.displayConfig?.supportEmail ?? ""
  }

  extension EnvironmentValues {
    @MainActor
    var supportEmail: String {
      get { self[SupportEmailKey.self] }
      set { self[SupportEmailKey.self] = newValue }
    }
  }

#endif
