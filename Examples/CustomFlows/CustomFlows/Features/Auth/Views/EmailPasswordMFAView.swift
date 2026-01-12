//
//  EmailPasswordMFAView.swift
//  CustomFlows
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

struct EmailPasswordMFAView: View {
  @Environment(Clerk.self) private var clerk
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
      let signIn = try await clerk.auth.signInWithPassword(identifier: emailAddress, password: password)

      switch signIn.status {
      case .complete:
        dump(clerk.session)
      case .needsSecondFactor:
        guard var signIn = clerk.auth.currentSignIn else { return }
        signIn = try await signIn.sendMfaEmailCode()
        needsMFA = true
      default:
        dump(signIn.status)
      }
    } catch {
      dump(error)
    }
  }

  private func verifyMFA(code: String) async {
    do {
      guard var signIn = clerk.auth.currentSignIn else { return }
      signIn = try await signIn.verifyMfaCode(code, type: .emailCode)

      switch signIn.status {
      case .complete:
        dump(clerk.session)
      default:
        dump(signIn.status)
      }
    } catch {
      dump(error)
    }
  }
}

#Preview {
  NavigationStack {
    EmailPasswordMFAView()
      .environment(Clerk.preview { preview in
        preview.isSignedIn = false
      })
  }
}
