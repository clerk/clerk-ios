//
//  ContentView.swift
//  Quickstart
//

import ClerkKit
import ClerkKitUI
import SwiftUI

struct ContentView: View {
  @Environment(Clerk.self) private var clerk
  @State private var authViewIsPresented = false
  @State private var externalProfileIsPresented = false
  @State private var navigationPath = NavigationPath()

  var body: some View {
    NavigationStack(path: $navigationPath) {
      VStack(spacing: 24) {
        UserButton(signedOutContent: {
          Button("Sign in") {
            authViewIsPresented = true
          }
        })

        OrganizationSwitcher()

        if clerk.user != nil {
          VStack(spacing: 12) {
            Button("Open UserProfile with host header") {
              externalProfileIsPresented = true
            }
            .buttonStyle(.borderedProminent)

            Button("Push embedded UserProfile") {
              navigationPath.append(QuickstartRoute.embeddedUserProfile)
            }
            .buttonStyle(.bordered)
          }
        }
      }
      .navigationTitle("Quickstart")
      .navigationDestination(for: QuickstartRoute.self) { route in
        switch route {
        case .embeddedUserProfile:
          UserProfileView(isDismissible: false, navigationPath: $navigationPath)
        }
      }
    }
    .onOpenURL { url in
      Task {
        do {
          try await clerk.handle(url)
        } catch {
          print("Failed to handle Clerk URL: \(error.localizedDescription)")
        }
      }
    }
    .task {
      for await event in clerk.auth.events {
        switch event {
        case .signInNeedsContinuation, .signUpNeedsContinuation:
          authViewIsPresented = true
        default:
          break
        }
      }
    }
    .onChange(of: clerk.session?.tasks, initial: true) { _, newValue in
      if newValue?.isEmpty == false {
        authViewIsPresented = true
      }
    }
    .sheet(isPresented: $authViewIsPresented) {
      AuthView()
    }
    .sheet(isPresented: $externalProfileIsPresented) {
      HostHeaderUserProfileView()
    }
  }
}

private enum QuickstartRoute: Hashable {
  case embeddedUserProfile
}

private enum QuickstartProfileRoute: Hashable {
  case billing
  case invoiceDetails
  case preferences
}

private struct HostHeaderUserProfileView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var navigationController = UserProfileNavigationController()

  var body: some View {
    VStack(spacing: 0) {
      navigationHeader
      Divider()
      UserProfileView(
        isDismissible: false,
        navigationController: navigationController
      )
      .userProfileRows(profileRows)
      .userProfileDestination { route in
        QuickstartProfileDestinationView(route: route)
      }
    }
    .onChange(of: navigationController.shouldDismiss) { _, shouldDismiss in
      guard shouldDismiss else { return }
      navigationController.resetDismissRequest()
      dismiss()
    }
    #if os(iOS)
    .presentationDragIndicator(.visible)
    #endif
  }

  private var navigationHeader: some View {
    ZStack {
      Text(navigationController.title)
        .font(.headline)
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 120)

      HStack {
        Button {
          navigationController.pop()
        } label: {
          Image(systemName: "chevron.left")
            .font(.headline)
        }
        .accessibilityLabel("Back")
        .disabled(!navigationController.canGoBack)
        .opacity(navigationController.canGoBack ? 1 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 16) {
          Button("Root") {
            navigationController.popToRoot()
          }
          .disabled(!navigationController.canGoBack)
          .opacity(navigationController.canGoBack ? 1 : 0)

          Button {
            navigationController.dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.headline)
          }
          .accessibilityLabel("Close")
          .disabled(!navigationController.canDismiss)
        }
      }
      .padding(.horizontal, 16)
    }
    .frame(height: 56)
  }

  private var profileRows: [UserProfileCustomRow<QuickstartProfileRoute>] {
    [
      .init(
        route: .billing,
        title: "Billing",
        navigationTitle: "Billing",
        icon: .system(name: "creditcard"),
        placement: .after(.security)
      ),
      .init(
        route: .preferences,
        title: "Preferences",
        icon: .system(name: "gearshape"),
        placement: .before(.signOut)
      ),
    ]
  }
}

private struct QuickstartProfileDestinationView: View {
  @Environment(UserProfileNavigator<QuickstartProfileRoute>.self) private var navigator

  let route: QuickstartProfileRoute

  var body: some View {
    VStack(spacing: 20) {
      switch route {
      case .billing:
        Text("Billing")
          .font(.title2)
        Button("Push invoice details") {
          navigator.push(.invoiceDetails, title: "Invoice details")
        }
      case .invoiceDetails:
        Text("Invoice details")
          .font(.title2)
      case .preferences:
        Text("Preferences")
          .font(.title2)
      }

      Button("Pop to profile root") {
        navigator.popToRoot()
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview("Signed Out") {
  ContentView()
    .environment(Clerk.preview { preview in
      preview.isSignedIn = false
    })
}

#Preview("Signed In") {
  ContentView()
    .environment(Clerk.preview())
}
