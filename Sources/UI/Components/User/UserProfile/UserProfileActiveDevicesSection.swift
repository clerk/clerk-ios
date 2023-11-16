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
    
    #if DEBUG
    @State private var sessions: [Session] = [.mockSession1, .mockSession2, .mockSession3]
    #else
    @State private var sessions: [Session] = []
    #endif
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            UserProfileSectionHeader(title: "Active Devices")
            
            ForEach(sessions) { session in
                ActiveDeviceView(session: session)
            }
        }
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
        
        var body: some View {
            AccordionView {
                HStack(spacing: 30) {
                    Image(session.latestActivity?.isMobile == true ? .deviceMobile : .deviceLaptop)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60)
                    VStack(alignment: .leading) {
                        HStack {
                            Text(session.latestActivity?.deviceType ?? "Desktop device")
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
                VStack(alignment: .leading) {
                    Text("Sign Out")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
