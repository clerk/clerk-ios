//
//  SetupMfaAddPhoneView.swift
//  Clerk
//
//  Created by Clerk on 1/29/26.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SetupMfaAddPhoneView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  @State private var phoneNumber = ""
  @State private var error: Error?
  @FocusState private var isFocused: Bool

  var session: Session? {
    clerk.client?.sessions.first { $0.status == .pending && $0.currentTask != nil }
  }

  var user: User? {
    session?.user
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        HeaderView(style: .title, text: "Add phone number")
          .padding(.bottom, 8)

        HeaderView(style: .subtitle, text: "A text message containing a verification code will be sent to this phone number")
          .padding(.bottom, 32)

        VStack(spacing: 4) {
          ClerkPhoneNumberField("Enter your phone number", text: $phoneNumber)
            .textContentType(.telephoneNumber)
            .keyboardType(.numberPad)
            .focused($isFocused)
            .onFirstAppear {
              isFocused = true
            }

          if let error {
            ErrorText(error: error, alignment: .leading)
              .font(theme.fonts.subheadline)
              .transition(.blurReplace.animation(.default))
              .id(error.localizedDescription)
          }
        }
        .padding(.bottom, 24)

        AsyncButton {
          await addPhoneNumber()
        } label: { isRunning in
          HStack(spacing: 4) {
            Text("Continue", bundle: .module)
            Image("icon-triangle-right", bundle: .module)
              .foregroundStyle(theme.colors.primaryForeground)
              .opacity(0.6)
          }
          .frame(maxWidth: .infinity)
          .overlayProgressView(isActive: isRunning) {
            SpinnerView(color: theme.colors.primaryForeground)
          }
        }
        .buttonStyle(.primary())
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .clerkErrorPresenting($error)
    .navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          navigation.path.removeLast()
        } label: {
          Image("icon-caret-left", bundle: .module)
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
  }

  func addPhoneNumber() async {
    error = nil
    isFocused = false

    guard let user else { return }

    do {
      let newPhone = try await user.createPhoneNumber(phoneNumber)
      navigation.path.append(AuthView.Destination.setupMfaPhoneVerify(newPhone))
    } catch {
      self.error = error
    }
  }
}

#Preview {
  SetupMfaAddPhoneView()
    .environment(\.clerkTheme, .clerk)
}

#endif
