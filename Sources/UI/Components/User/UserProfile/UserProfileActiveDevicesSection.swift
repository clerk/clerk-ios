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
    @State private var didFetchSessions = false
    
    // TODO: MIKE - This is ugly, find a way to get rid of this
    @State private var sessions: [Session] = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" ? [.mockSession1, .mockSession2, .mockSession3] : []
        
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            UserProfileSectionHeader(title: "Active Devices")
            
            VStack(alignment: .leading, spacing: 24) {
                ForEach(sessions) { session in
                    ActiveDeviceView(session: session)
                        .onRevoke { revokedSession in
                            sessions.removeAll(where: { $0.id == revokedSession.id })
                        }
                }
            }
        }
        .animation(.snappy, value: sessions.count)
        .task {
            if !didFetchSessions {
                do {
                    guard let user else { return }
                    self.sessions = try await user.getSessions().sorted()
                    didFetchSessions = true
                } catch {
                    dump(error)
                }
            }
        }
    }
    
    private struct ActiveDeviceView: View {
        @EnvironmentObject private var clerk: Clerk

        let session: Session
        var onRevoke: ((Session) async -> ())?
        
        var body: some View {
            AccordionView {
                HStack(spacing: 30) {
                    Image(session.latestActivity?.isMobile == true ? .deviceMobile : .deviceLaptop)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60)
                    VStack(alignment: .leading) {
                        HStack {
                            Text(session.latestActivity?.deviceType ?? "\(session.latestActivity?.isMobile == true ? "Mobile" : "Desktop") device")
                                .fontWeight(.medium)
                            if clerk.client.lastActiveSessionId == session.id {
                                CapsuleTag(text: "This device", style: .primary)
                            }
                        }
                        VStack(alignment: .leading) {
                            Text(session.browserDisplayText)
                            Text(session.ipAddressDisplayText)
                            Text(session.lastActiveAt.formatted(Date.RelativeFormatStyle()))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .font(.footnote)
            } expandedContent: {
                expandedContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading)
            }
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
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sign out")
                        .font(.footnote)
                    Text("Sign out from your account on this device")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    AsyncButton(options: [.disableButton, .showProgressView], action: {
                        await revokeSession(session)
                    }, label: {
                        Text("Sign out of device")
                            .font(.footnote.weight(.medium))
                    })
                    .tint(.red)
                }
            }
        }
        
        private func revokeSession(_ session: Session) async {
            do {
                let revokedSession = try await session.revoke()
                await onRevoke?(revokedSession)
            } catch {
                dump(error)
            }
        }
        
        func onRevoke(perform action: @escaping (Session) -> Void) -> Self {
            var copy = self
            copy.onRevoke = action
            return copy
        }
    }
}

#Preview {
    UserProfileActiveDevicesSection()
        .padding()
        .environmentObject(Clerk.mock)
}

#endif
