//
//  UserProfilePhoneRow.swift
//  Clerk
//
//  Created by Mike Pitre on 6/10/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct UserProfilePhoneRow: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var addPhoneNumberDestination: UserProfileAddPhoneView.Destination?
  @State private var isLoading = false
  @State private var removeResource: RemoveResource?
  @State private var isConfirmingRemoval = false
  @State private var error: Error?

  var user: User? {
    clerk.user
  }

  let phoneNumber: PhoneNumber

  var body: some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        WrappingHStack(alignment: .leading) {
          if user?.primaryPhoneNumber == phoneNumber {
            Badge(key: "Primary", style: .secondary)
          }

          if phoneNumber.verification?.status != .verified {
            Badge(key: "Unverified", style: .warning)
          }

          if phoneNumber.reservedForSecondFactor {
            Badge(key: "MFA reserved", style: .secondary)
          }
        }

        Text(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.foreground)
          .frame(minHeight: 22)
      }

      Spacer()

      Menu {
        if user?.primaryPhoneNumber != phoneNumber, phoneNumber.verification?.status == .verified {
          AsyncButton {
            await setPhoneAsPrimary(phoneNumber)
          } label: { isRunning in
            Text("Set as primary", bundle: .module)
          }
          .onIsRunningChanged { isLoading = $0 }
          .onDisappear { isLoading = false }
        }

        if phoneNumber.verification?.status != .verified {
          Button {
            addPhoneNumberDestination = .verify(phoneNumber)
          } label: {
            Text("Verify", bundle: .module)
          }
        }

        Button(role: .destructive) {
          removeResource = .phoneNumber(phoneNumber)
        } label: {
          Text("Remove phone", bundle: .module)
        }

      } label: {
        Image("icon-three-dots-vertical", bundle: .module)
          .resizable()
          .scaledToFit()
          .foregroundColor(theme.colors.mutedForeground)
          .frame(width: 20, height: 20)
      }
      .frame(width: 30, height: 30)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .overlayProgressView(isActive: isLoading)
    .overlay(alignment: .bottom) {
      Rectangle()
        .frame(height: 1)
        .foregroundStyle(theme.colors.border)
    }
    .clerkErrorPresenting($error)
    .onChange(of: removeResource) {
      if $1 != nil { isConfirmingRemoval = true }
    }
    .sheet(item: $addPhoneNumberDestination) {
      UserProfileAddPhoneView(desintation: $0)
    }
    .confirmationDialog(
      removeResource?.messageLine1 ?? "",
      isPresented: $isConfirmingRemoval,
      titleVisibility: .visible,
      actions: {
        AsyncButton(role: .destructive) {
          await removeResource(removeResource)
        } label: { isRunning in
          Text(removeResource?.title ?? "", bundle: .module)
        }
        .onIsRunningChanged { isLoading = $0 }

        Button(role: .cancel) {
          isConfirmingRemoval = false
          removeResource = nil
        } label: {
          Text("Cancel", bundle: .module)
        }
      }
    )
  }
}

extension UserProfilePhoneRow {

  private func setPhoneAsPrimary(_ phone: PhoneNumber) async {
    do {
      try await user?.update(.init(primaryPhoneNumberId: phone.id))
    } catch {
      self.error = error
      ClerkLogger.error("Failed to set phone as primary", error: error)
    }
  }

  private func removeResource(_ resource: RemoveResource?) async {
    defer { removeResource = nil }

    do {
      try await resource?.deleteAction()
    } catch {
      self.error = error
      ClerkLogger.error("Failed to remove phone resource", error: error)
    }
  }

}

#Preview {
  UserProfilePhoneRow(phoneNumber: .mock)
}

#endif
