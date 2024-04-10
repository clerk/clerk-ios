//
//  UserProfileMfaBackupCodeListView.swift
//
//
//  Created by Mike Pitre on 1/29/24.
//

#if canImport(SwiftUI)

import SwiftUI

struct UserProfileMfaBackupCodeListView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    let backupCodes: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading) {
                Text("Save these backup codes")
                    .foregroundStyle(clerkTheme.colors.textPrimary)
                    .font(.footnote.weight(.medium))
                Text("Store them somewhere safe. If you lose access to your authentication device, you can use backup codes to sign in.")
                    .foregroundStyle(clerkTheme.colors.textTertiary)
                    .font(.footnote)
            }
            
            VStack(spacing: .zero) {
                LazyVGrid(columns: [.init(spacing: 8), .init(spacing: 8)], spacing: 12, content: {
                    ForEach(backupCodes, id: \.self) { backupCode in
                        Text(backupCode)
                            .frame(minHeight: 16)
                            .font(.caption)
                            .foregroundStyle(clerkTheme.colors.textSecondary)
                    }
                })
                .padding(.vertical, 14)
                
                Divider()
                    .foregroundStyle(clerkTheme.colors.borderPrimary)
                
                HStack(spacing: .zero) {
                    Group {
                        Button {
                            // download action
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider()
                            .foregroundStyle(clerkTheme.colors.borderPrimary)

                        Button {
                            // print action
                        } label: {
                            Image(systemName: "printer")
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider()
                            .foregroundStyle(clerkTheme.colors.borderPrimary)
                        
                        #if !os(tvOS)
                        Button {
                            UIPasteboard.general.string = backupCodes.joined(separator: "\n")
                        } label: {
                            Image(systemName: "clipboard")
                        }
                        .frame(maxWidth: .infinity)
                        #endif
                    }
                    .tint(clerkTheme.colors.textPrimary)
                    .imageScale(.small)
                    .frame(height: 32)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(clerkTheme.colors.borderPrimary, lineWidth: 1)
            }
        }
    }
}

#Preview {
    UserProfileMfaBackupCodeListView(backupCodes: [
        "bfvbhsa0",
        "hb1eds8o",
        "oy3t6xfg",
        "ubatpup3",
        "y9m08ppi",
        "k1sk99it",
        "ny6okyz3",
        "dg8bwbji",
        "g2eh9622",
        "flwmkdcp"
      ])
    .padding()
}

#endif
