//
//  UserProfileActiveDevicesSection.swift
//
//
//  Created by Mike Pitre on 11/16/23.
//

#if os(iOS)

import SwiftUI
import NukeUI

struct UserProfileActiveDevicesSection: View {
    @ObservedObject private var clerk = Clerk.shared
    @Environment(\.clerkTheme) private var clerkTheme
    
    private var user: User? {
        clerk.user
    }
    
    private var sessions: [Session] {
        guard let user = clerk.client?.lastActiveSession?.user else { return [] }
        return clerk.sessionsByUserId[user.id, default: []].sorted()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Devices")
                .font(.footnote.weight(.medium))
                .frame(minHeight: 32)
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(sessions) { session in
                    ActiveDeviceView(session: session)
                }
            }
            .padding(.leading, 12)
            
            Divider()
        }
        .animation(.snappy, value: sessions.count)
        .animation(.snappy, value: user)
    }
    
    private struct ActiveDeviceView: View {
        @ObservedObject private var clerk = Clerk.shared
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.clerkTheme) private var clerkTheme
        @State private var errorWrapper: ErrorWrapper?
        @State private var isSigningOutOfDevice: Bool = false

        let session: Session
        
        private var user: User? {
            clerk.user
        }
        
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(session.latestActivity?.isMobile == true ? .deviceMobile : .deviceLaptop)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .background {
                        if colorScheme == .dark {
                            Color(.secondarySystemBackground)
                                .clipShape(.rect(cornerRadius: 8, style: .continuous))
                        }
                    }
                
                VStack(alignment: .leading) {
                    HStack(spacing: 8) {
                        Text(session.latestActivity?.deviceType ?? "\(session.latestActivity?.isMobile == true ? "Mobile" : "Desktop") device")
                            .font(.footnote.weight(.medium))
                        if clerk.client?.lastActiveSessionId == session.id {
                            CapsuleTag(text: "This device")
                        }
                    }
                    VStack(alignment: .leading) {
                        if !session.browserDisplayText.isEmpty {
                            Text(session.browserDisplayText)
                        }
                        
                        if !session.ipAddressDisplayText.isEmpty {
                            Text(session.ipAddressDisplayText)
                        }
                        
                        Text(session.lastActiveAt.formatted(Date.RelativeFormatStyle()))
                    }
                    .foregroundStyle(clerkTheme.colors.textSecondary)
                    .font(.footnote)
                }
                
                Spacer()
                
                if !session.isThisDevice {
                    Menu {
                        AsyncButton(role: .destructive) {
                            isSigningOutOfDevice = true
                            await revokeSession()
                            isSigningOutOfDevice = false
                        } label: {
                            Text("Sign out of device")
                        }
                    } label: {
                        MoreActionsView()
                    }
                    .tint(clerkTheme.colors.textPrimary)
                }
            }
            .opacity(isSigningOutOfDevice ? 0 : 1)
            .overlay {
                if isSigningOutOfDevice {
                    ProgressView()
                }
            }
            .clerkErrorPresenting($errorWrapper)
            .animation(.default, value: isSigningOutOfDevice)
        }
        
        @ViewBuilder
        private var expandedContent: some View {
            if session.isThisDevice {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current device")
                        .font(.footnote)
                    Text("This is the device you are currently using")
                        .font(.footnote)
                        .foregroundStyle(clerkTheme.colors.textSecondary)
                }
            } else {
                    AsyncButton {
                        await revokeSession()
                    } label: {
                        Text("Sign out of device")
                            .font(.footnote.weight(.medium))
                            .tint(.red)
                    }
            }
        }
        
        private func revokeSession() async {
            do {
                try await session.revoke()
                try await clerk.client?.lastActiveSession?.user?.getSessions()
            } catch {
                errorWrapper = ErrorWrapper(error: error)
                dump(error)
            }
        }
    }
}

#Preview {
    UserProfileActiveDevicesSection()
        .padding()
}

#endif
