//
//  UserProfileActiveDevicesSection.swift
//
//
//  Created by Mike Pitre on 11/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import NukeUI

struct UserProfileActiveDevicesSection: View {
    @EnvironmentObject private var clerk: Clerk
    
    private var sessions: [Session] {
        guard let user = clerk.client.lastActiveSession?.user else { return [] }
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
    }
    
    private struct ActiveDeviceView: View {
        @EnvironmentObject private var clerk: Clerk
        @Environment(\.colorScheme) private var colorScheme
        @State private var errorWrapper: ErrorWrapper?

        let session: Session
        
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
                    HStack {
                        Text(session.latestActivity?.deviceType ?? "\(session.latestActivity?.isMobile == true ? "Mobile" : "Desktop") device")
                            .font(.footnote.weight(.medium))
                        if clerk.client.lastActiveSessionId == session.id {
                            CapsuleTag(text: "This device")
                        }
                    }
                    VStack(alignment: .leading) {
                        Text(session.browserDisplayText)
                        Text(session.ipAddressDisplayText)
                        Text(session.lastActiveAt.formatted(Date.RelativeFormatStyle()))
                    }
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                }
                
                Spacer()
                
                if !session.isThisDevice {
                    Menu {
                        AsyncButton(role: .destructive) {
                            await revokeSession()
                        } label: {
                            Text("Sign out of device")
                        }
                    } label: {
                        MoreActionsView()
                    }
                    .tint(.primary)
                }
            }
            .clerkErrorPresenting($errorWrapper)
        }
        
        @ViewBuilder
        private var expandedContent: some View {
            if session.isThisDevice {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current device")
                        .font(.footnote)
                    Text("This is the device you are currently using")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                try await clerk.client.lastActiveSession?.user?.getSessions()
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
        .environmentObject(Clerk.mock)
}

#endif
