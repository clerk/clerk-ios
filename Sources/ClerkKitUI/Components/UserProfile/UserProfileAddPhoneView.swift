//
//  UserProfileAddPhoneView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/27/25.
//

#if os(iOS)

import SwiftUI

struct UserProfileAddPhoneView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var path = NavigationPath()
    @State private var phoneNumber = ""
    @State private var error: Error?
    @FocusState private var isFocused: Bool

    enum Destination: Hashable, Identifiable {
        case add  // should never be added to the path
        case verify(PhoneNumber)

        var id: Self { self }
    }

    var user: User? {
        clerk.user
    }

    init(desintation: Destination? = nil) {
        if case .verify(let phoneNumber) = desintation {
            var path = NavigationPath()
            path.append(Destination.verify(phoneNumber))
            _path = State(initialValue: path)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 24) {
                    Text("A text message containing a verification code will be sent to this phone number. Message and data rates may apply.", bundle: .module)
                        .font(theme.fonts.subheadline)
                        .foregroundStyle(theme.colors.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)

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

                    AsyncButton {
                        await addPhoneNumber()
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
                    Text("Add phone number", bundle: .module)
                        .font(theme.fonts.headline)
                        .foregroundStyle(theme.colors.foreground)
                }
            }
            .navigationDestination(for: Destination.self) {
                switch $0 {
                case .verify(let phoneNumber):
                    UserProfileVerifyView(
                        mode: .phone(phoneNumber)
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

extension UserProfileAddPhoneView {

    func addPhoneNumber() async {
        guard let user else { return }

        do {
            let phoneNumber = try await user.createPhoneNumber(phoneNumber)
            path.append(Destination.verify(phoneNumber))
        } catch {
            self.error = error
            ClerkLogger.error("Failed to add phone number", error: error)
        }
    }

}

#Preview {
    UserProfileAddPhoneView()
        .environment(\.clerkTheme, .clerk)
}

#endif
