//
//  UserProfileUpdateProfileView.swift
//
//
//  Created by Mike Pitre on 11/28/23.
//

#if canImport(UIKit)

import SwiftUI
import NukeUI
import Clerk
import PhotosUI

struct UserProfileUpdateProfileView: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var photosPickerItem: PhotosPickerItem?
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    private var continueButtonDisabled: Bool {
        user?.firstName == firstName &&
        user?.lastName == lastName
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Update profile")
                    .font(.title2.weight(.bold))
                
                HStack(spacing: 16) {
                    if let imageUrl = user?.imageUrl {
                        LazyImage(
                            url: URL(string: imageUrl),
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
                            .tint(clerkTheme.colors.primary)
                            .onChange(of: photosPickerItem) { newValue in
                                if newValue == nil { return }
                                Task {
                                    do {
                                        guard let imageData = try await photosPickerItem?.loadTransferable(type: Data.self) else {
                                            throw ClerkClientError(message: "Unable to upload this item.")
                                        }
                                        try await user?.setProfileImage(imageData)
                                    } catch {
                                        dump(error)
                                    }
                                    
                                    photosPickerItem = nil
                                }
                            }

                            AsyncButton {
                                do {
                                    try await user?.deleteProfileImage()
                                } catch {
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
                
                VStack(alignment: .leading) {
                    Text("First name")
                        .font(.footnote.weight(.medium))
                    CustomTextField(text: $firstName)
                        .frame(height: 44)
                        .textContentType(.givenName)
                        .autocorrectionDisabled()
                        .task {
                            firstName = user?.firstName ?? ""
                        }
                }
                
                VStack(alignment: .leading) {
                    Text("Last name")
                        .font(.footnote.weight(.medium))
                    CustomTextField(text: $lastName)
                        .frame(height: 44)
                        .textContentType(.familyName)
                        .autocorrectionDisabled()
                        .task {
                            lastName = user?.lastName ?? ""
                        }
                }
                
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("CANCEL")
                            .foregroundStyle(clerkTheme.colors.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .font(.caption.weight(.bold))
                    }
                    
                    AsyncButton {
                        //
                    } label: {
                        Text("CONTINUE")
                            .foregroundStyle(clerkTheme.colors.primaryButtonTextColor)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                clerkTheme.colors.primary,
                                in: .rect(cornerRadius: 6, style: .continuous)
                            )
                    }
                    .disabled(continueButtonDisabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(30)
            .dismissButtonOverlay()
        }
    }
}

#Preview {
    UserProfileUpdateProfileView()
        .environmentObject(Clerk.mock)
        .environment(\.clerkTheme.colors.primary, Color(.clerkPurple))
}

#endif
