//
//  UserProfileUpdateProfileView.swift
//
//
//  Created by Mike Pitre on 11/28/23.
//

#if os(iOS)

import SwiftUI
import NukeUI
import Nuke
import PhotosUI

struct UserProfileUpdateProfileView: View {
    @ObservedObject private var clerk = Clerk.shared
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var errorWrapper: ErrorWrapper?
    
    private var user: User? {
        clerk.client?.lastActiveSession?.user
    }
    
    private var continueButtonDisabled: Bool {
        user?.firstName == firstName &&
        user?.lastName == lastName
    }
    
    private var firstNameIsEnabled: Bool {
        (clerk.environment?.userSettings.enabledAttributes ?? [:]).contains { $0.key == .firstName }
    }
    
    private var lastNameIsEnabled: Bool {
        (clerk.environment?.userSettings.enabledAttributes ?? [:]).contains { $0.key == .lastName }
    }
    
    private func updateUser() async {
        do {
            try await user?.update(.init(
                firstName: firstName,
                lastName: lastName
            ))
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Update profile")
                    .font(.title2.weight(.bold))
                
                HStack(spacing: 16) {
                    if let imageUrl = user?.imageUrl {
                        LazyImage(
                            request: .init(url: URL(string: imageUrl), processors: [ImageProcessors.Circle()]),
                            transaction: .init(animation: .default)
                        ) { imageState in
                            if let image = imageState.image {
                                image.resizable().scaledToFill()
                            } else {
                                Color(.secondarySystemBackground)
                            }
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(.circle)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Profile image")
                            .font(.subheadline)
                        HStack(spacing: 20) {
                            PhotosPicker(
                                "Upload image",
                                selection: $photosPickerItem,
                                matching: .images
                            )
                            .font(.footnote)
                            .tint(clerkTheme.colors.textPrimary)
                            .onChange(of: photosPickerItem) { newValue in
                                if newValue == nil { return }
                                Task {
                                    do {
                                        guard let imageData = try await photosPickerItem?.loadTransferable(type: Data.self) else {
                                            throw ClerkClientError(message: "Unable to upload this item.")
                                        }
                                        try await user?.setProfileImage(imageData)
                                    } catch {
                                        errorWrapper = ErrorWrapper(error: error)
                                        dump(error)
                                    }
                                    
                                    photosPickerItem = nil
                                }
                            }

                            AsyncButton {
                                do {
                                    try await user?.deleteProfileImage()
                                } catch {
                                    errorWrapper = ErrorWrapper(error: error)
                                    dump(error)
                                }
                            } label: {
                                Text("Remove image")
                                    .font(.footnote)
                                    .tint(.red)
                            }
                        }
                    }
                }
                
                if firstNameIsEnabled {
                    VStack(alignment: .leading) {
                        Text("First name")
                            .font(.footnote.weight(.medium))
                        CustomTextField(text: $firstName)
                            .textContentType(.givenName)
                            .autocorrectionDisabled()
                            .task {
                                firstName = user?.firstName ?? ""
                            }
                    }
                }
                
                if lastNameIsEnabled {
                    VStack(alignment: .leading) {
                        Text("Last name")
                            .font(.footnote.weight(.medium))
                        CustomTextField(text: $lastName)
                            .textContentType(.familyName)
                            .autocorrectionDisabled()
                            .task {
                                lastName = user?.lastName ?? ""
                            }
                    }
                }
                
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkSecondaryButtonStyle())
                    
                    AsyncButton {
                        await updateUser()
                        dismiss()
                    } label: {
                        Text("Continue")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkPrimaryButtonStyle())
                    .disabled(continueButtonDisabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.top, 30)
        }
        .dismissButtonOverlay()
        .clerkErrorPresenting($errorWrapper)
    }
}

#Preview {
    UserProfileUpdateProfileView()
}

#endif
