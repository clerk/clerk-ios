//
//  LegalAcceptanceView.swift
//  CustomFlows
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

struct LegalAcceptanceView: View {
  @Environment(Clerk.self) private var clerk
  @State private var emailAddress = ""
  @State private var password = ""
  @State private var code = ""
  @State private var legalAccepted = false
  @State private var isVerifying = false

  var body: some View {
    Form {
      if isVerifying {
        Section {
          TextField("Enter your verification code", text: $code)
        }

        Section {
          Button("Verify") {
            Task {
              await verify(code: code)
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
            .textContentType(.newPassword)
        }

        Section {
          Toggle("I agree to the Terms of Service and Privacy Policy", isOn: $legalAccepted)
        }

        Section {
          Button("Sign Up") {
            Task {
              await handleSignUp()
            }
          }
        }
      }
    }
    .navigationTitle("Legal Acceptance")
  }

  private func handleSignUp() async {
    do {
      let signUp = try await clerk.auth.signUp(
        emailAddress: emailAddress,
        password: password,
        legalAccepted: legalAccepted
      )
      try await signUp.sendEmailCode()
      isVerifying = true
    } catch {
      dump(error)
    }
  }

  private func verify(code: String) async {
    do {
      guard let inProgressSignUp = clerk.client?.signUp else { return }
      let signUp = try await inProgressSignUp.verifyCode(code, type: .email)

      switch signUp.status {
      case .complete:
        dump(clerk.session)
      default:
        dump(signUp.status)
      }
    } catch {
      dump(error)
    }
  }
}

#Preview {
  NavigationStack {
    LegalAcceptanceView()
      .environment(Clerk.preview { preview in
        preview.isSignedIn = false
      })
  }
}
