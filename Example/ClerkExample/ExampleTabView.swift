//
//  ExampleTabView.swift
//  ClerkExample
//
//  Created by Mike Pitre on 12/11/23.
//

import SwiftUI
import ClerkUI
import Clerk

struct ExampleTabView: View {
    @State private var selectedTab: Tab = .home
    
    enum Tab {
        case home
        case profile
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ExamplesListView()
                .tag(Tab.home)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(Material.ultraThinMaterial, for: .tabBar)
            
            NavigationStack {
                UserProfileView()
                    .removeDismissButton()
                    .navigationTitle("Account")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            UserButton()
                        }
                    }
            }
            .tag(Tab.profile)
            .tabItem { Label("Account", systemImage: "person.fill") }
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(Material.ultraThinMaterial, for: .tabBar)
        }
    }
}

#Preview {
    ExampleTabView()
        .environmentObject(Clerk.mock)
}
