//
//  UserProfileUpdateProfileView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/14/25.
//

#if os(iOS)

import Kingfisher
import PhotosUI
import SwiftUI

struct UserProfileUpdateProfileView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var photosPickerIsPresented = false
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var imageIsLoading = false

    @State private var firstName: String
    @State private var lastName: String
    @State private var username: String
    @State private var error: Error?

    var environment: Clerk.Environment {
        clerk.environment
    }

    var showSaveButton: Bool {
        environment.usernameIsEnabled || environment.firstNameIsEnabled || environment.lastNameIsEnabled
    }

    let user: User

    init(user: User) {
        self.user = user
        _username = State(initialValue: user.username ?? "")
        _firstName = State(initialValue: user.firstName ?? "")
        _lastName = State(initialValue: user.lastName ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    menu

                    VStack(spacing: 24) {
                        if environment.usernameIsEnabled {
                            ClerkTextField("Username", text: $username)
                                .textContentType(.username)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        if environment.firstNameIsEnabled {
                            ClerkTextField("First name", text: $firstName)
                                .textContentType(.givenName)
                        }

                        if environment.lastNameIsEnabled {
                            ClerkTextField("Last name", text: $lastName)
                                .textContentType(.familyName)
                        }

                        AsyncButton {
                            await save()
                        } label: { isRunning in
                            Text("Save")
                                .frame(maxWidth: .infinity)
                                .overlayProgressView(isActive: isRunning) {
                                    SpinnerView(color: theme.colors.textOnPrimaryBackground)
                                }
                        }
                        .buttonStyle(.primary())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 60)
            }
            .clerkErrorPresenting($error)
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
                    Text("Update profile", bundle: .module)
                        .font(theme.fonts.headline)
                        .foregroundStyle(theme.colors.text)
                }
            }
            .photosPicker(
                isPresented: $photosPickerIsPresented,
                selection: $photosPickerItem,
                matching: .images
            )
            .onChange(of: photosPickerItem) { _, item in
                guard let item else { return }

                Task {
                    imageIsLoading = true

                    do {
                        guard
                            let data = try await item.loadTransferable(type: Data.self),
                            let uiImage = UIImage(data: data),
                            let resizedData =
                                uiImage
                                .resizedMaintainingAspectRatio(to: .init(width: 200, height: 200))
                                .jpegData(compressionQuality: 0.8)
                        else {
                            throw ClerkClientError(message: "There was an error loading the image from the photos library.")
                        }

                        try await user.setProfileImage(imageData: resizedData)
                    } catch {
                        self.error = error
                        ClerkLogger.error("Failed to set profile image", error: error)
                        imageIsLoading = false
                    }
                }
            }
        }
        .presentationBackground(theme.colors.background)
        .background(theme.colors.background)
    }

    @ViewBuilder
    private var menu: some View {
        KFImage(URL(string: user.imageUrl))
            .resizable()
            .fade(duration: 0.25)
            .placeholder { progress in
                Image("icon-profile", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(theme.colors.primary.gradient)
                    .opacity(0.5)
            }
            .onSuccess { _ in imageIsLoading = false }
            .onFailure { _ in imageIsLoading = false }
            .overlay {
                if imageIsLoading {
                    theme.colors.inputBorderFocused
                    SpinnerView(color: theme.colors.textOnPrimaryBackground)
                        .frame(width: 24, height: 24)
                }
            }
            .scaledToFill()
            .frame(width: 96, height: 96)
            .clipShape(.circle)
            .overlay(alignment: .bottomTrailing) {
                Menu {
                    menuContent
                } label: {
                    Image("icon-edit", bundle: .module)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .padding(8)
                        .foregroundStyle(theme.colors.textSecondary)
                        .background(theme.colors.background)
                        .clipShape(.rect(cornerRadius: theme.design.borderRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.design.borderRadius)
                                .strokeBorder(theme.colors.buttonBorder, lineWidth: 1)
                        }
                        .shadow(color: theme.colors.buttonBorder, radius: 1, x: 0, y: 1)
                }
            }
    }

    @ViewBuilder
    private var menuContent: some View {
        Button("Choose from photo library") {
            photosPickerIsPresented = true
        }

        if user.hasImage == true {
            AsyncButton(role: .destructive) {
                imageIsLoading = true
                defer { imageIsLoading = false }

                do {
                    try await user.deleteProfileImage()
                } catch {
                    self.error = error
                    ClerkLogger.error("Failed to delete profile image", error: error)
                }
            } label: { _ in
                Text("Remove photo")
            }
        }
    }
}

extension UserProfileUpdateProfileView {

    func save() async {
        do {
            try await user.update(
                .init(
                    username: environment.usernameIsEnabled ? username : nil,
                    firstName: environment.firstNameIsEnabled ? firstName : nil,
                    lastName: environment.lastNameIsEnabled ? lastName : nil
                ))

            dismiss()
        } catch {
            self.error = error
            ClerkLogger.error("Failed to update user profile", error: error)
        }
    }

}

#Preview {
    UserProfileUpdateProfileView(user: .mock)
        .environment(\.clerk, .mock)
        .environment(\.clerkTheme, .clerk)
}

#endif
