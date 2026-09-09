//
//  EmailPasswordMFAView.swift
//  CustomFlows
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct EmailPasswordMFAView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(CustomFlowFeedback.self) private var feedback
  @State private var emailAddress = ""
  @State private var password = ""
  @State private var mfaCode = ""
  @State private var needsMFA = false
  @State private var showDocs = false

  var body: some View {
    Form {
      if needsMFA {
        Section {
          TextField("Enter MFA code", text: $mfaCode)
        }

        Section {
          Button("Verify MFA") {
            Task {
              await verifyMFA(code: mfaCode)
            }
          }
        }
      } else {
        Section {
          TextField("Enter email address", text: $emailAddress)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .autocorrectionDisabled()

          SecureField("Enter password", text: $password)
            .textContentType(.password)
        }

        Section {
          Button("Sign In") {
            Task {
              await handleSignIn()
            }
          }
        }
      }
    }
    .navigationTitle("Email & Password MFA")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showDocs = true
        } label: {
          Image(systemName: "book")
        }
      }
    }
    .sheet(isPresented: $showDocs) {
      if let url = AuthFlow.emailPasswordMFA.documentationURL {
        SafariView(url: url)
      }
    }
  }

  private func handleSignIn() async {
    do {
      let signIn = clerk.signIn
      try await signIn.password(.case1(.init(password: password, identifier: emailAddress)))

      switch signIn.status {
      case .complete:
        try await signIn.finalize()
      case .needsSecondFactor:
        let signIn = clerk.signIn
        try await signIn.mfa.sendEmailCode()
        needsMFA = true
      default:
        feedback.continuation = .signIn
      }
    } catch {
      feedback.error = error.localizedDescription
    }
  }

  private func verifyMFA(code: String) async {
    do {
      let signIn = clerk.signIn
      try await signIn.mfa.verifyEmailCode(.init(code: code))

      switch signIn.status {
      case .complete:
        try await signIn.finalize()
      default:
        feedback.continuation = .signIn
      }
    } catch {
      feedback.error = error.localizedDescription
    }
  }
}

#Preview {
  NavigationStack {
    EmailPasswordMFAView()
      .environment(Clerk.preview(.signedOut))
      .environment(CustomFlowFeedback())
  }
}
