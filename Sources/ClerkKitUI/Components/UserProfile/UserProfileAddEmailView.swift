//
//  UserProfileAddEmailView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/16/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct UserProfileAddEmailView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var path = NavigationPath()
    @State private var email = ""
    @State private var error: Error?
    @FocusState private var isFocused: Bool

    enum Destination: Hashable, Identifiable {
        case add  // should never be added to the path
        case verify(EmailAddress)

        var id: Self { self }
    }

    var user: User? {
        clerk.user
    }

    init(desintation: Destination? = nil) {
        if case .verify(let email) = desintation {
            var path = NavigationPath()
            path.append(Destination.verify(email))
            _path = State(initialValue: path)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 24) {
                    Text("You'll need to verify this email address before it can be added to your account.", bundle: .module)
                        .font(theme.fonts.subheadline)
                        .foregroundStyle(theme.colors.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 4) {
                        ClerkTextField("Enter your email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
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

                    AsyncButton {
                        await addEmailAddress()
                    } label: { isRunning in
                        HStack {
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
                }
                .padding(24)
            }
            .presentationBackground(theme.colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .preGlassSolidNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(theme.colors.primary)
                }

                ToolbarItem(placement: .principal) {
                    Text("Add email address", bundle: .module)
                        .font(theme.fonts.headline)
                        .foregroundStyle(theme.colors.foreground)
                }
            }
            .navigationDestination(for: Destination.self) {
                switch $0 {
                case .verify(let email):
                    UserProfileVerifyView(
                        mode: .email(email)
                    ) { _ in
                        dismiss()
                    } customDismiss: {
                        dismiss()
                    }
                case .add:
                    EmptyView()  // should never be hit, .add should never be added to path
                        .task { dismiss() }
                }
            }
        }
    }
}

extension UserProfileAddEmailView {

    func addEmailAddress() async {
        guard let user else { return }

        do {
            let emailAddress = try await user.createEmailAddress(email)
            path.append(Destination.verify(emailAddress))
        } catch {
            self.error = error
            ClerkLogger.error("Failed to add email address", error: error)
        }
    }

}

#Preview {
    UserProfileAddEmailView()
        .environment(\.clerkTheme, .clerk)
}

#endif
