//
//  MainTabView.swift
//  ClerkDemo
//
//  Created by Mike Pitre on 3/8/24.
//

import SwiftUI
import ClerkSDK

struct MainTabView: View {
    enum Tab {
        case home
    }
    
    var body: some View {
        TabView {
            HomeView()
                .tag(Tab.home)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(Material.ultraThinMaterial, for: .tabBar, .navigationBar)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(Clerk.shared)
}
