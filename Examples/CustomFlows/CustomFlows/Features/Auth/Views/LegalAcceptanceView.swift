//
//  LegalAcceptanceView.swift
//  CustomFlows
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct LegalAcceptanceView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(CustomFlowFeedback.self) private var feedback
  @State private var emailAddress = ""
  @State private var password = ""
  @State private var code = ""
  @State private var legalAccepted = false
  @State private var isVerifying = false
  @State private var showDocs = false

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
      if let url = AuthFlow.legalAcceptance.documentationURL {
        SafariView(url: url)
      }
    }
  }

  private func handleSignUp() async {
    do {
      let signUp = clerk.signUp
      try await signUp.create(.init(
        emailAddress: emailAddress,
        password: password,
        legalAccepted: legalAccepted
      ))
      try await signUp.verifications.sendEmailCode()
      isVerifying = true
    } catch {
      feedback.error = error.localizedDescription
    }
  }

  private func verify(code: String) async {
    do {
      let signUp = clerk.signUp
      try await signUp.verifications.verifyEmailCode(.init(code: code))

      switch signUp.status {
      case .complete:
        try await signUp.finalize()
      default:
        feedback.continuation = .signUp
      }
    } catch {
      feedback.error = error.localizedDescription
    }
  }
}

#Preview {
  NavigationStack {
    LegalAcceptanceView()
      .environment(Clerk.preview(.signedOut))
      .environment(CustomFlowFeedback())
  }
}
