//
//  UserProfileDetailView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/9/25.
//

#if os(iOS)

import FactoryKit
import Kingfisher
import SwiftUI

struct UserProfileDetailView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.userProfileSharedState) private var sharedState

    @State private var addEmailAddressDestination: UserProfileAddEmailView.Destination?
    @State private var addPhoneNumberDestination: UserProfileAddPhoneView.Destination?
    @State private var addConnectedAccountIsPresented = false
    @State private var connectAccountSheetHeight: CGFloat = 200

    private var user: User? {
        clerk.user
    }

    var sortedEmails: [EmailAddress] {
        (user?.emailAddresses ?? [])
            .sorted { lhs, rhs in
                if lhs == user?.primaryEmailAddress {
                    return true
                } else if rhs == user?.primaryEmailAddress {
                    return false
                } else {
                    return lhs.createdAt < rhs.createdAt
                }
            }
    }

    var sortedPhoneNumbers: [PhoneNumber] {
        (user?.phoneNumbers ?? [])
            .sorted { lhs, rhs in
                if lhs == user?.primaryPhoneNumber {
                    return true
                } else if rhs == user?.primaryPhoneNumber {
                    return false
                } else {
                    return lhs.createdAt < rhs.createdAt
                }
            }
    }

    var sortedExternalAccounts: [ExternalAccount] {
        (user?.externalAccounts.filter({
            $0.verification?.status == .verified || $0.verification?.error != nil
        }) ?? [])
        .sorted { lhs, rhs in
            lhs.createdAt < rhs.createdAt
        }
    }

    var body: some View {
        ZStack {
            if let user {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {

                            if clerk.environment.emailIsEnabled {
                                Section {
                                    Group {
                                        ForEach(sortedEmails) { emailAddress in
                                            UserProfileEmailRow(emailAddress: emailAddress)
                                        }

                                        UserProfileButtonRow(text: "Add email address") {
                                            addEmailAddressDestination = .add
                                        }
                                    }
                                    .background(theme.colors.background)

                                } header: {
                                    UserProfileSectionHeader(text: "EMAIL ADDRESSES")
                                }
                            }

                            if clerk.environment.phoneNumberIsEnabled {
                                Section {
                                    Group {
                                        ForEach(sortedPhoneNumbers) { phoneNumber in
                                            UserProfilePhoneRow(phoneNumber: phoneNumber)
                                        }

                                        UserProfileButtonRow(text: "Add phone number") {
                                            addPhoneNumberDestination = .add
                                        }
                                    }
                                    .background(theme.colors.background)
                                } header: {
                                    UserProfileSectionHeader(text: "PHONE NUMBERS")
                                }
                            }

                            if !clerk.environment.allSocialProviders.isEmpty {
                                Section {
                                    Group {
                                        ForEach(sortedExternalAccounts) { externalAccount in
                                            UserProfileExternalAccountRow(externalAccount: externalAccount)
                                        }

                                        if !user.unconnectedProviders.isEmpty {
                                            UserProfileButtonRow(text: "Connect account") {
                                                addConnectedAccountIsPresented = true
                                            }
                                        }
                                    }
                                    .background(theme.colors.background)
                                } header: {
                                    UserProfileSectionHeader(text: "CONNECTED ACCOUNTS")
                                }
                            }
                        }
                        .animation(.default, value: sortedEmails)
                        .animation(.default, value: sortedPhoneNumbers)
                        .animation(.default, value: sortedExternalAccounts)
                    }
                    .background(theme.colors.muted)

                    SecuredByClerkFooter()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Profile", bundle: .module)
                    .font(theme.fonts.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.foreground)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .presentationBackground(theme.colors.background)
        .background(theme.colors.background)
        .sheet(item: $addEmailAddressDestination) {
            UserProfileAddEmailView(desintation: $0)
        }
        .sheet(item: $addPhoneNumberDestination) {
            UserProfileAddPhoneView(desintation: $0)
        }
        .sheet(isPresented: $addConnectedAccountIsPresented) {
            UserProfileAddConnectedAccountView(contentHeight: $connectAccountSheetHeight)
                .presentationDetents([.height(connectAccountSheetHeight)])
        }
        .task {
            _ = try? await Client.get()
        }
    }
}

#Preview {
    Container.shared.clerk.preview { @MainActor in
        .mock
    }

    NavigationStack {
        UserProfileDetailView()
            .environment(\.clerk, .mock)
            .environment(\.clerkTheme, .clerk)
    }
}

#endif
