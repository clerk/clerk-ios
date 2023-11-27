//
//  UserProfileExternalAccountSection.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import NukeUI
import Factory

struct UserProfileExternalAccountSection: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    
    @State private var addExternalAccountIsPresented = false
    @State private var confirmDeleteExternalAccount: ExternalAccount?
    
    @State private var deleteSheetHeight: CGFloat = .zero
    @Namespace private var namespace
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    private var externalAccounts: [ExternalAccount] {
        (user?.externalAccounts ?? []).sorted()
    }
    
    private func externalAccountRowString(_ externalAccount: ExternalAccount) -> String {
        var string = ""
        if let provider = externalAccount.externalProvider {
            string += provider.data.name
        }
        
        if !externalAccount.displayName.isEmpty {
            string += " (\(externalAccount.displayName))"
        }
        
        return string
    }
    
    @ViewBuilder
    private func externalInfoCalloutView(_ externalAccount: ExternalAccount) -> some View {
        HStack(spacing: 16) {
            LazyImage(url: URL(string: externalAccount.imageUrl ?? "")) { state in
                if let image = state.image {
                    image.resizable().scaledToFit()
                } else {
                    Color(.secondarySystemBackground)
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(.circle)
            .overlay(alignment: .bottomLeading) {
                LazyImage(url: externalAccount.externalProvider?.iconImageUrl) { state in
                    if let image = state.image {
                        image.resizable().scaledToFit()
                    } else {
                        Color(.secondarySystemBackground)
                    }
                }
                .frame(width: 16, height: 16)
                .clipShape(.circle)
            }
            
            VStack(alignment: .leading) {
                if let fullName = externalAccount.fullName {
                    Text(fullName)
                }
                Text(externalAccount.displayName)
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
            
            Spacer()
        }
        .padding(.leading)
    }
    
    @ViewBuilder
    private func retryConnectionCalloutView(_ externalAccount: ExternalAccount) -> some View {
        VStack(alignment: .leading) {
            Text("Retry failed connection")
                .font(.footnote)
            Text("You did not grant access to your \(externalAccount.externalProvider?.data.name ?? "external") account")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let provider = externalAccount.externalProvider {
                AsyncButton(options: [.disableButton, .showProgressView]) {
                    await retryConnection(provider)
                } label: {
                    Text("Try again")
                }
                .font(.footnote.weight(.medium))
                .padding(.vertical, 4)
                .tint(clerkTheme.colors.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading)
    }
    
    private func retryConnection(_ provider: OAuthProvider) async {
        do {
            let externalAccount = try await user?.addExternalAccount(provider)
            try await externalAccount?.startOAuth()
        } catch {
            dump(error)
        }
    }
    
    @ViewBuilder
    private func removeCalloutView(_ externalAccount: ExternalAccount) -> some View {
        VStack(alignment: .leading) {
            Text("Remove")
                .font(.footnote)
            Text("Remove this connected account from your account")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Remove connected account", role: .destructive) {
                confirmDeleteExternalAccount = externalAccount
            }
            .font(.footnote.weight(.medium))
            .padding(.vertical, 4)
            .popover(item: $confirmDeleteExternalAccount) { externalAccount in
                UserProfileRemoveResourceView(resource: .externalAccount(externalAccount))
                    .padding(.top)
                    .readSize { deleteSheetHeight = $0.height }
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.height(deleteSheetHeight)])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            UserProfileSectionHeader(title: "Connected accounts")
            VStack(alignment: .leading, spacing: 24) {
                ForEach(externalAccounts) { externalAccount in
                    AccordionView {
                        HStack(spacing: 8) {
                            if let provider = externalAccount.externalProvider {
                                LazyImage(url: provider.iconImageUrl)
                                    .frame(width: 16, height: 16)
                            }
                            
                            Text(externalAccountRowString(externalAccount))
                            
                            if externalAccount.verification.status != .verified {
                                CapsuleTag(text: "Requires action", style: .warning)
                            }
                        }
                        .font(.footnote)
                    } expandedContent: {
                        if externalAccount.verification.status == .verified {
                            externalInfoCalloutView(externalAccount)
                        }
                        
                        if externalAccount.verification.status != .verified {
                            retryConnectionCalloutView(externalAccount)
                        }
                        
                        removeCalloutView(externalAccount)
                    }
                }
                
                if let user, !user.unconnectedProviders.isEmpty {
                    Button(action: {
                        addExternalAccountIsPresented = true
                    }, label: {
                        Text("+ Connect account")
                    })
                    .font(.footnote.weight(.medium))
                    .tint(clerkTheme.colors.primary)
                    .padding(.leading, 8)
                }
            }
            .animation(.snappy, value: user)
        }
        .sheet(isPresented: $addExternalAccountIsPresented) {
            UserProfileAddExternalAccountView()
        }
    }
}

#Preview {
    _ = Container.shared.clerk.register { .mock }
    return UserProfileExternalAccountSection()
        .padding()
        .environmentObject(Clerk.mock)
}

#endif