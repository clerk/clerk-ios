//
//  UserProfileMfaRow.swift
//  Clerk
//
//  Created by Mike Pitre on 5/12/25.
//

#if os(iOS)

import SwiftUI

struct UserProfileMfaRow: View {
  @Environment(\.clerkTheme) private var theme
  
  enum Style {
    case authenticatorApp
    case sms(phoneNumber: PhoneNumber)
    case backupCodes
  }
  
  @ViewBuilder
  private var icon: Image {
    return switch style {
    case .authenticatorApp:
      Image("icon-key", bundle: .module)
    case .sms:
      Image("icon-phone", bundle: .module)
    case .backupCodes:
      Image("icon-lock", bundle: .module)
    }
  }
  
  @ViewBuilder
  private var text: Text {
    return switch style {
    case .authenticatorApp:
      Text("Authenticator app", bundle: .module)
    case .sms(let phoneNumber):
      Text("SMS code", bundle: .module)
    case .backupCodes:
      Text("Backup codes", bundle: .module)
    }
  }
  
  let style: Style
  var isDefault: Bool = false
  
  var body: some View {
    HStack(spacing: 0) {
      HStack(alignment: .top, spacing: 16) {
        icon
          .resizable()
          .scaledToFit()
          .frame(width: 24, height: 24)
          .foregroundStyle(theme.colors.textSecondary)
        VStack(alignment: .leading, spacing: 4) {
          if isDefault {
            Badge(key: "Default", style: .secondary)
          }
          
          HStack(spacing: 4) {
            text
            if case .sms(let phoneNumber) = style {
              Text(verbatim: phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible)
            }
          }
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.text)
          .frame(minHeight: 22)
        }
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(.rect)
    .overlay(alignment: .bottom) {
      Rectangle()
        .frame(height: 1)
        .foregroundStyle(theme.colors.border)
    }
  }
}

#Preview {
  UserProfileMfaRow(
    style: .authenticatorApp,
    isDefault: true
  )
  
  UserProfileMfaRow(
    style: .sms(phoneNumber: .mock)
  )
  
  UserProfileMfaRow(
    style: .backupCodes
  )
}

#endif
