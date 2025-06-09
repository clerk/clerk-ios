//
//  UserProfileMfaAddSmsView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/4/25.
//

#if os(iOS)

  import Factory
  import PhoneNumberKit
  import SwiftUI

  struct UserProfileMfaAddSmsView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.userProfileSharedState) private var sharedState

    @State private var selectedPhoneNumber: PhoneNumber?
    @State private var addPhoneNumberIsPresented = false
    @State private var path = NavigationPath()
    @State private var error: Error?
    
    enum Destination: Hashable {
      case backupCodes([String])
      
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

    private var availablePhoneNumbers: [PhoneNumber] {
      (user?.phoneNumbersAvailableForMfa ?? [])
        .sorted { lhs, rhs in
          lhs.createdAt < rhs.createdAt
        }
    }

    var body: some View {
      NavigationStack(path: $path) {
        ScrollView {
          VStack(spacing: 24) {
            Text("Select an existing phone number to register for SMS code two-step verification or add a new one.", bundle: .module)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.textSecondary)
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
                  .foregroundStyle(theme.colors.textOnPrimaryBackground)
                  .opacity(0.6)
              }
              .frame(maxWidth: .infinity)
              .overlayProgressView(isActive: isRunning) {
                SpinnerView(color: theme.colors.textOnPrimaryBackground)
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
          .background(theme.colors.background)
          .clerkErrorPresenting($error)
          .navigationBarTitleDisplayMode(.inline)
          .toolbarBackground(.visible, for: .navigationBar)
          .toolbarBackground(theme.colors.background, for: .navigationBar)
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
                .foregroundStyle(theme.colors.text)
            }
          }
        }
        .navigationDestination(for: Destination.self) {
          $0.view
        }
      }
      .presentationBackground(theme.colors.background)
      .sensoryFeedback(.selection, trigger: selectedPhoneNumber)
      .sheet(isPresented: $addPhoneNumberIsPresented) {
        UserProfileAddPhoneView()
      }
    }
  }

  extension UserProfileMfaAddSmsView {

    private func reserveForSecondFactor(phoneNumber: PhoneNumber) async {
      do {
        let phoneNumber = try await phoneNumber.setReservedForSecondFactor()
        if let backupCodes = phoneNumber.backupCodes {
          path.append(Destination.backupCodes(backupCodes))
        } else {
          sharedState.addMfaIsPresented = false
        }
      } catch {
        self.error = error
      }
    }

  }

  struct AddMfaSmsRow: View {
    @Environment(\.clerkTheme) private var theme
    let utility = Container.shared.phoneNumberUtility()

    let phoneNumber: PhoneNumber
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
        Text("\(country.flag) \(country.code)")
          .font(theme.fonts.footnote)
          .foregroundStyle(theme.colors.text)
          .monospaced()
          .padding(.vertical, 13)
          .padding(.horizontal, 10)
          .background(theme.colors.backgroundSecondary)
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
          .foregroundStyle(theme.colors.text)
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
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

  #Preview("Row") {
    @Previewable @State var selectedPhoneNumber: PhoneNumber?
    let phoneNumbers: [PhoneNumber] = [.mock, .mockMfa]

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
