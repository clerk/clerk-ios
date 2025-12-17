//
//  AuthFlowListView.swift
//  CustomFlows
//
//  Created by Mike Pitre on 12/15/25.
//

import SwiftUI

struct AuthFlowListView: View {
  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(AuthFlow.allCases) { flow in
            NavigationLink(value: flow) {
              AuthFlowRow(flow: flow)
            }
          }
        } header: {
          Text("Authentication Flows")
        } footer: {
          Text("Select an authentication flow to see how it's implemented with Clerk.")
        }
      }
      .navigationTitle("Custom Flows")
      .navigationDestination(for: AuthFlow.self) { flow in
        flowView(for: flow)
      }
    }
  }

  @ViewBuilder
  private func flowView(for flow: AuthFlow) -> some View {
    switch flow {
    case .emailPassword:
      EmailPasswordView()
    case .emailCode:
      EmailCodeView()
    case .phoneSMSOTP:
      PhoneSMSOTPView()
    case .oauthConnections:
      OAuthConnectionsView()
    case .emailPasswordMFA:
      EmailPasswordMFAView()
    case .enterpriseConnections:
      EnterpriseConnectionsView()
    case .signInWithApple:
      SignInWithAppleView()
    case .legalAcceptance:
      LegalAcceptanceView()
    }
  }
}

// MARK: - AuthFlowRow

private struct AuthFlowRow: View {
  let flow: AuthFlow

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(flow.displayName)
        .font(.headline)
        .foregroundStyle(.primary)

      Text(flow.description)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
  }
}

#Preview {
  NavigationStack {
    AuthFlowListView()
  }
}
