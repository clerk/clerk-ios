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
    @State private var selectedTab: Tab = .account
    @Namespace private var namespace
    
    var body: some View {
        VStack(spacing: .zero) {
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
                    }
                    .overlay(alignment: .bottom) {
                        if selectedTab == .account {
                            Rectangle()
                                .frame(height: 2)
                                .offset(y: 16)
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
                    }
                    .overlay(alignment: .bottom) {
                        if selectedTab == .security {
                            Rectangle()
                                .frame(height: 2)
                                .offset(y: 16)
                                .matchedGeometryEffect(id: "underline", in: namespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(30)
                .frame(height: 50)
                
                Divider()
            }
            
            TabView(selection: $selectedTab.animation(.snappy)) {
                UserProfileAccountView()
                    .tag(Tab.account)
                UserProfileSecurityView()
                    .tag(Tab.security)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
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
