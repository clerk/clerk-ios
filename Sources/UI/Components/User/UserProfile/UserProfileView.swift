//
//  UserProfileView.swift
//  
//
//  Created by Mike Pitre on 11/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct UserProfileView: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Tab = .account
    @State private var errorWrapper: ErrorWrapper?
    @Namespace private var namespace
    
    var body: some View {
        VStack(spacing: .zero) {
            HStack(spacing: 20) {
                Button {
                    withAnimation(.snappy) { selectedTab = .account }
                } label: {
                    HStack {
                        Image(systemName: "person.fill")
                            .frame(width: 16, height: 16)
                        
                        Text("Account")
                            .animation(.none, value: selectedTab)
                    }
                    .foregroundStyle(selectedTab == .account ? .primary : .secondary)
                    .frame(maxHeight: .infinity)
                }
                .overlay(alignment: .bottom) {
                    if selectedTab == .account {
                        Rectangle()
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "underline", in: namespace)
                    }
                }
                
                Button {
                    withAnimation(.snappy) { selectedTab = .security }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .frame(width: 16, height: 16)
                        
                        Text("Security")
                            .animation(.none, value: selectedTab)
                    }
                    .foregroundStyle(selectedTab == .security ? .primary : .secondary)
                    .frame(maxHeight: .infinity)
                }
                .overlay(alignment: .bottom) {
                    if selectedTab == .security {
                        Rectangle()
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "underline", in: namespace)
                    }
                }
            }
            .frame(height: 50)
            .buttonStyle(.plain)
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
            .background(alignment: .bottom) {
                Divider()
            }
            .padding(.top)
            
            TabView(selection: $selectedTab.animation(.snappy)) {
                UserProfileAccountView()
                    .tag(Tab.account)
                UserProfileSecurityView()
                    .tag(Tab.security)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .dismissButtonOverlay()
        .clerkErrorPresenting($errorWrapper)
        .task {
            do {
                try await clerk.client.get()
            } catch {
                errorWrapper = ErrorWrapper(error: error)
                dump(error)
            }
        }
        .task {
            do {
                try await clerk.client.lastActiveSession?.user?.getSessions()
            } catch {
                errorWrapper = ErrorWrapper(error: error)
                dump(error)
            }
        }
    }
    
    enum Tab {
        case account, security
    }
}

#Preview {
    UserProfileView()
        .environmentObject(Clerk.mock)
}

#endif
