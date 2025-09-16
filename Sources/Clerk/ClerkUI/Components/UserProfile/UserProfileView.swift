//
//  UserProfileView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/8/25.
//

#if os(iOS)

import Kingfisher
import SwiftUI

/// A comprehensive user profile view that displays user information and account management options.
///
/// ``UserProfileView`` provides an interface for users to view and manage their profile,
/// including personal information, security settings, account switching, and sign-out functionality.
///
/// ## Usage
///
/// As a full-screen profile view:
///
/// ```swift
/// struct ProfileView: View {
///   @Environment(\.clerk) private var clerk
///
///   var body: some View {
///     Group {
///       if clerk.user != nil {
///         UserProfileView(isDismissable: false)
///       } else {
///         AuthView(isDismissable: false)
///       }
///     }
///   }
/// }
/// ```
///
/// As a dismissable sheet:
///
/// ```swift
/// struct MainView: View {
///   @State private var profileIsPresented = false
///
///   var body: some View {
///     Button("Show Profile") {
///       profileIsPresented = true
///     }
///     .sheet(isPresented: $profileIsPresented) {
///       UserProfileView()
///     }
///   }
/// }
/// ```
public struct UserProfileView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var updateProfileIsPresented = false
    @State private var accountSwitcherHeight: CGFloat = 400
    @State private var sharedState = SharedState()
    @State private var error: Error?

    let isDismissable: Bool

    /// Creates a new user profile view.
    ///
    /// - Parameter isDismissable: Whether the view can be dismissed by the user.
    ///   When `true`, a dismiss button appears in the navigation bar and the view
    ///   can be used in sheets or other dismissable contexts. When `false`, no
    ///   dismiss button is shown, making it suitable for full-screen usage.
    ///   Defaults to `true`.
    public init(isDismissable: Bool = true) {
        self.isDismissable = isDismissable
    }

    var user: User? {
        clerk.user
    }

    @ViewBuilder
    private func userProfileHeader(_ user: User) -> some View {
        VStack(spacing: 12) {
            KFImage(URL(string: user.imageUrl))
                .resizable()
                .placeholder {
                    Image("icon-profile", bundle: .module)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(theme.colors.primary.gradient)
                        .opacity(0.5)
                }
                .fade(duration: 0.25)
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(.circle)

            if let fullName = user.fullName {
                Text(fullName)
                    .font(theme.fonts.title2)
                    .fontWeight(.bold)
                    .frame(minHeight: 28)
                    .foregroundStyle(theme.colors.foreground)
            }

            Button {
                updateProfileIsPresented = true
            } label: {
                Text("Update profile", bundle: .module)
            }
            .buttonStyle(.secondary(config: .init(size: .small)))
            .simultaneousGesture(TapGesture())
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func row(
        icon: String,
        text: LocalizedStringKey,
        action: @escaping () async -> Void
    ) -> some View {
        AsyncButton {
            await action()
        } label: { isRunning in
            UserProfileRowView(icon: icon, text: text)
                .overlayProgressView(isActive: isRunning)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(theme.colors.border)
        }
        .buttonStyle(.pressedBackground)
        .simultaneousGesture(TapGesture())
    }

    public var body: some View {
        if let user {
            NavigationStack(path: $sharedState.path) {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            userProfileHeader(user)

                            VStack(spacing: 48) {
                                VStack(spacing: 0) {
                                    row(icon: "icon-profile", text: "Profile") {
                                        sharedState.path.append(Destination.profileDetail)
                                    }

                                    row(icon: "icon-security", text: "Security") {
                                        sharedState.path.append(Destination.security)
                                    }
                                }
                                .background(theme.colors.background)
                                .overlay(alignment: .top) {
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundStyle(theme.colors.border)
                                }

                                VStack(spacing: 0) {
                                    if clerk.environment.mutliSessionModeIsEnabled {
                                        if let activeSessions = clerk.client?.activeSessions, activeSessions.count > 1 {
                                            row(icon: "icon-switch", text: "Switch account") {
                                                sharedState.accountSwitcherIsPresented = true
                                            }
                                        }

                                        row(icon: "icon-plus", text: "Add account") {
                                            sharedState.authViewIsPresented = true
                                        }
                                    }

                                    row(icon: "icon-sign-out", text: "Sign out") {
                                        guard let sessionId = clerk.session?.id else { return }
                                        await signOut(sessionId: sessionId)
                                    }
                                }
                                .background(theme.colors.background)
                                .overlay(alignment: .top) {
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundStyle(theme.colors.border)
                                }
                            }
                        }
                    }
                    .background(theme.colors.muted)

                    SecuredByClerkFooter()
                }
                .animation(.default, value: user)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Account", bundle: .module)
                            .font(theme.fonts.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(theme.colors.foreground)
                    }

                    if isDismissable {
                        ToolbarItem(placement: .topBarTrailing) {
                            DismissButton()
                        }
                    }
                }
                .navigationDestination(for: Destination.self) {
                    $0.view
                }
            }
            .tint(theme.colors.primary)
            .presentationBackground(theme.colors.background)
            .background(theme.colors.background)
            .clerkErrorPresenting($error)
            .sheet(isPresented: $sharedState.accountSwitcherIsPresented) {
                UserButtonAccountSwitcher(contentHeight: $accountSwitcherHeight)
                    .presentationDetents([.height(accountSwitcherHeight)])
            }
            .sheet(isPresented: $updateProfileIsPresented) {
                UserProfileUpdateProfileView(user: user)
            }
            .sheet(isPresented: $sharedState.authViewIsPresented) {
                AuthView()
                    .interactiveDismissDisabled()
            }
            .task {
                for await event in clerk.authEventEmitter.events {
                    switch event {
                    case .signInCompleted, .signUpCompleted, .signedOut:
                        sharedState.authViewIsPresented = false
                    }
                }
            }
            .task(id: user) {
                await getSessionsOnAllDevices()
            }
            .task {
                _ = try? await Clerk.Environment.get()
            }
            .task {
                _ = try? await Client.get()
            }
            .taskOnce {
                await clerk.telemetry.record(
                    TelemetryEvents.viewDidAppear(
                        "UserProfileView",
                        payload: ["isDismissable": .bool(isDismissable)]
                    )
                )
            }
            .environment(\.userProfileSharedState, sharedState)
        }
    }
}

extension UserProfileView {

    func signOut(sessionId: String) async {
        do {
            try await clerk.signOut(sessionId: sessionId)
            if clerk.session == nil {
                dismiss()
            }
        } catch {
            self.error = error
            ClerkLogger.error("Failed to sign out", error: error)
        }
    }

    func getSessionsOnAllDevices() async {
        guard let user else { return }
        do {
            try await user.getSessions()
        } catch {
            if error.isCancellationError {
                ClerkLogger.error("Get sessions on all devices cancelled.", error: error)
            } else {
                self.error = error
                ClerkLogger.error("Failed to get sessions on all devices", error: error)
            }
        }
    }

}

extension UserProfileView {
    enum Destination: Hashable {
        case profileDetail
        case security

        @MainActor
        @ViewBuilder
        var view: some View {
            switch self {
            case .profileDetail:
                UserProfileDetailView()
            case .security:
                UserProfileSecurityView()
            }
        }
    }
}

extension UserProfileView {
    @Observable
    class SharedState {
        var path = NavigationPath()
        var lastCodeSentAt: [String: Date] = [:]
        var accountSwitcherIsPresented = false
        var authViewIsPresented = false
        var chooseMfaTypeIsPresented = false
        var presentedAddMfaType: UserProfileAddMfaView.PresentedView?
    }
}

extension EnvironmentValues {
    @Entry var userProfileSharedState = UserProfileView.SharedState()
}

#Preview("Dismissable") {
    UserProfileView()
        .environment(\.clerk, .mock)
        .environment(\.clerkTheme, .clerk)
}

#Preview("Not dismissable") {
    UserProfileView(isDismissable: false)
        .environment(\.clerk, .mock)
        .environment(\.clerkTheme, .clerk)
}

#endif
