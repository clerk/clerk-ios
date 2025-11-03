//
//  UserProfileMfaAddSmsView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/4/25.
//

#if os(iOS)

import ClerkKit
import FactoryKit
import PhoneNumberKit
import SwiftUI

struct UserProfileMfaAddSmsView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(UserProfileView.SharedState.self) private var sharedState

  @State private var selectedPhoneNumber: ClerkKit.PhoneNumber?
  @State private var addPhoneNumberIsPresented = false
  @State private var path = NavigationPath()
  @State private var error: Error?

  enum Destination: Hashable {
    case backupCodes([String])

    @MainActor
    @ViewBuilder
    var view: some View {
      switch self {
      case .backupCodes(let backupCodes):
        BackupCodesView(backupCodes: backupCodes, mfaType: .phoneCode)
      }
    }
  }

  private var user: User? {
    clerk.user
  }

  private var availablePhoneNumbers: [ClerkKit.PhoneNumber] {
    (user?.phoneNumbersAvailableForMfa ?? [])
      .filter { $0.verification?.status == .verified }
      .sorted { $0.createdAt < $1.createdAt }
  }

  var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        VStack(spacing: 24) {
          Text("Select an existing phone number to register for SMS code two-step verification or add a new one.", bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)

          VStack(spacing: 12) {
            ForEach(availablePhoneNumbers) { phoneNumber in
              Button {
                selectedPhoneNumber = phoneNumber
              } label: {
                AddMfaSmsRow(
                  phoneNumber: phoneNumber,
                  isSelected: selectedPhoneNumber == phoneNumber
                )
              }
              .buttonStyle(.pressedBackground)
            }
          }

          AsyncButton {
            guard let selectedPhoneNumber else { return }
            await reserveForSecondFactor(phoneNumber: selectedPhoneNumber)
          } label: { isRunning in
            HStack {
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

          Button {
            addPhoneNumberIsPresented = true
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
        }
        .padding(24)
        .clerkErrorPresenting($error)
        .navigationBarTitleDisplayMode(.inline)
        .preGlassSolidNavBar()
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              dismiss()
            }
            .foregroundStyle(theme.colors.primary)
          }

          ToolbarItem(placement: .principal) {
            Text("Add SMS code verification", bundle: .module)
              .font(theme.fonts.headline)
              .foregroundStyle(theme.colors.foreground)
          }
        }
      }
      .navigationDestination(for: Destination.self) {
        $0.view
      }
    }
    .background(theme.colors.background)
    .presentationBackground(theme.colors.background)
    .sensoryFeedback(.selection, trigger: selectedPhoneNumber)
    .sheet(isPresented: $addPhoneNumberIsPresented) {
      UserProfileAddPhoneView()
    }
  }
}

extension UserProfileMfaAddSmsView {

  private func reserveForSecondFactor(phoneNumber: ClerkKit.PhoneNumber) async {
    do {
      let phoneNumber = try await phoneNumber.setReservedForSecondFactor()
      if let backupCodes = phoneNumber.backupCodes {
        path.append(Destination.backupCodes(backupCodes))
      } else {
        sharedState.presentedAddMfaType = nil
      }
    } catch {
      self.error = error
      ClerkLogger.error("Failed to reserve phone number for second factor", error: error)
    }
  }

}

struct AddMfaSmsRow: View {
  @Environment(\.clerkTheme) private var theme
  let utility = Container.shared.phoneNumberUtility()

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

  @ViewBuilder
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
  UserProfileMfaAddSmsView()
    .clerkPreviewMocks()
    .environment(\.clerkTheme, .clerk)
}

#Preview("Row") {
  @Previewable @State var selectedPhoneNumber: ClerkKit.PhoneNumber?
  let phoneNumbers: [ClerkKit.PhoneNumber] = [.mock, .mockMfa]

  VStack {
    ForEach(phoneNumbers) { phoneNumber in
      Button {
        selectedPhoneNumber = phoneNumber
      } label: {
        AddMfaSmsRow(
          phoneNumber: phoneNumber,
          isSelected: selectedPhoneNumber == phoneNumber
        )
      }
      .buttonStyle(.pressedBackground)
    }
  }
  .padding()
  .environment(\.clerkTheme, .clerk)
}

#endif
