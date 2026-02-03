//
//  SetupMfaPhoneSelectionView.swift
//  Clerk
//
//  Created by Clerk on 1/29/26.
//

#if os(iOS)

import ClerkKit
import PhoneNumberKit
import SwiftUI

struct SetupMfaPhoneSelectionView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  @State private var error: Error?
  @State private var selectedPhoneNumber: ClerkKit.PhoneNumber?

  var session: Session? {
    clerk.client?.sessions.first { $0.status == .pending && $0.currentTask != nil }
  }

  var user: User? {
    session?.user
  }

  var availablePhoneNumbers: [ClerkKit.PhoneNumber] {
    (user?.phoneNumbersAvailableForMfa ?? [])
      .filter { $0.verification?.status == .verified }
      .sorted { $0.createdAt < $1.createdAt }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        HeaderView(style: .title, text: "Add SMS code verification")
          .padding(.bottom, 8)

        HeaderView(style: .subtitle, text: "Select an existing phone number to register for SMS code two-step verification or add a new one")
          .padding(.bottom, 32)

        if !availablePhoneNumbers.isEmpty {
          VStack(spacing: 12) {
            ForEach(availablePhoneNumbers) { phoneNumber in
              Button {
                selectedPhoneNumber = phoneNumber
              } label: {
                PhoneSelectionRow(
                  phoneNumber: phoneNumber,
                  isSelected: selectedPhoneNumber == phoneNumber
                )
              }
              .buttonStyle(.pressedBackground)
            }
          }
          .padding(.bottom, 24)
        }

        AsyncButton {
          guard let selectedPhoneNumber else { return }
          await reserveForSecondFactor(phoneNumber: selectedPhoneNumber)
        } label: { isRunning in
          HStack(spacing: 4) {
            Text("Continue", bundle: .module)
            Image("icon-triangle-right", bundle: .module)
              .foregroundStyle(theme.colors.primaryForeground)
              .opacity(0.6)
          }
          .frame(maxWidth: .infinity)
          .overlayProgressView(isActive: isRunning) {
            SpinnerView(color: theme.colors.primaryForeground)
          }
        }
        .buttonStyle(.primary())
        .disabled(selectedPhoneNumber == nil)
        .padding(.bottom, 12)

        Button {
          navigation.path.append(AuthView.Destination.setupMfaPhoneAdd)
        } label: {
          Text("Add phone number", bundle: .module)
        }
        .buttonStyle(
          .primary(
            config: .init(
              emphasis: .none,
              size: .small
            )
          )
        )
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .clerkErrorPresenting($error)
    .navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          navigation.path.removeLast()
        } label: {
          Image("icon-caret-left", bundle: .module)
            .foregroundStyle(theme.colors.foreground)
        }
      }
    }
    .sensoryFeedback(.selection, trigger: selectedPhoneNumber)
  }

  func reserveForSecondFactor(phoneNumber: ClerkKit.PhoneNumber) async {
    do {
      let phoneNumber = try await phoneNumber.setReservedForSecondFactor()
      if let backupCodes = phoneNumber.backupCodes {
        navigation.path.append(AuthView.Destination.setupMfaPhoneBackupCodes(backupCodes))
      } else {
        navigation.path.append(AuthView.Destination.setupMfaPhoneSuccess)
      }
    } catch {
      self.error = error
    }
  }
}

struct PhoneSelectionRow: View {
  @Environment(\.clerkTheme) private var theme
  let utility = PhoneNumberUtility()

  let phoneNumber: ClerkKit.PhoneNumber
  let isSelected: Bool

  var country: CountryCodePickerViewController.Country? {
    if let phoneNumber = try? utility.parse(phoneNumber.phoneNumber),
       let regionId = phoneNumber.regionID
    {
      return CountryCodePickerViewController.Country(
        for: regionId,
        with: utility
      )
    }

    return CountryCodePickerViewController.Country(
      for: "US",
      with: utility
    )
  }

  @ViewBuilder
  var countryIndicator: some View {
    if let country {
      Text(verbatim: "\(country.flag) \(country.code)")
        .font(theme.fonts.footnote)
        .foregroundStyle(theme.colors.foreground)
        .monospaced()
        .padding(.vertical, 13)
        .padding(.horizontal, 10)
        .background(theme.colors.muted)
        .clipShape(.rect(cornerRadius: theme.design.borderRadius))
        .contentShape(.rect(cornerRadius: theme.design.borderRadius))
    }
  }

  var selectedIndicator: some View {
    Image(systemName: isSelected ? "record.circle.fill" : "record.circle")
      .resizable()
      .scaledToFit()
      .symbolRenderingMode(.palette)
      .foregroundStyle(
        isSelected ? theme.colors.background : .clear,
        isSelected ? theme.colors.primary : theme.colors.inputBorder
      )
      .frame(width: 20, height: 20)
      .contentTransition(.symbolEffect(.replace.offUp))
  }

  var body: some View {
    HStack(spacing: 8) {
      countryIndicator
      Text(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible)
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.foreground)
      Spacer(minLength: 0)
      selectedIndicator
    }
    .padding(.vertical, 8)
    .padding(.leading, 6)
    .padding(.trailing, 16)
    .overlay {
      RoundedRectangle(cornerRadius: theme.design.borderRadius)
        .strokeBorder(
          isSelected ? theme.colors.primary : theme.colors.inputBorder,
          lineWidth: 1
        )
    }
    .contentShape(.rect)
    .animation(.default, value: isSelected)
  }
}

#Preview {
  SetupMfaPhoneSelectionView()
    .environment(\.clerkTheme, .clerk)
}

#endif
