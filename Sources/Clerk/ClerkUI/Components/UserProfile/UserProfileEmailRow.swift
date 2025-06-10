//
//  UserProfileEmailRow.swift
//  Clerk
//
//  Created by Mike Pitre on 6/10/25.
//

import SwiftUI

#if os(iOS)

  struct UserProfileEmailRow: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme

    @State private var addEmailAddressDestination: UserProfileAddEmailView.Destination?
    @State private var removeResource: RemoveResource?
    @State private var isConfirmingRemoval = false
    @State private var error: Error?

    var user: User? {
      clerk.user
    }

    let emailAddress: EmailAddress

    var body: some View {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          WrappingHStack(alignment: .leading) {
            if user?.primaryEmailAddress == emailAddress {
              Badge(key: "Primary", style: .secondary)
            }

            if emailAddress.verification?.status != .verified {
              Badge(key: "Unverified", style: .warning)
            }

            if emailAddress.linkedTo?.isEmpty == false {
              Badge(key: "Linked", style: .secondary)
            }
          }

          Text(emailAddress.emailAddress)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.text)
            .frame(minHeight: 22)
        }

        Spacer(minLength: 0)

        Menu {
          if user?.primaryEmailAddress != emailAddress, emailAddress.verification?.status == .verified {
            AsyncButton {
              await setEmailAsPrimary(emailAddress)
            } label: { isRunning in
              Text("Set as primary", bundle: .module)
            }
          }

          if emailAddress.verification?.status != .verified {
            Button {
              addEmailAddressDestination = .verify(emailAddress)
            } label: {
              Text("Verify", bundle: .module)
            }
          }

          Button(role: .destructive) {
            removeResource = .email(emailAddress)
          } label: {
            Text("Remove email", bundle: .module)
          }

        } label: {
          Image("icon-three-dots-vertical", bundle: .module)
            .resizable()
            .scaledToFit()
            .foregroundColor(theme.colors.textSecondary)
            .frame(width: 20, height: 20)
        }
        .frame(width: 30, height: 30)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
      .overlay(alignment: .bottom) {
        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)
      }
      .clerkErrorPresenting($error)
      .sheet(item: $addEmailAddressDestination) {
        UserProfileAddEmailView(desintation: $0)
      }
      .onChange(of: removeResource) {
        if $0 != nil { isConfirmingRemoval = true }
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

  extension UserProfileEmailRow {

    private func setEmailAsPrimary(_ email: EmailAddress) async {
      do {
        try await user?.update(.init(primaryEmailAddressId: email.id))
      } catch {
        self.error = error
      }
    }

    private func removeResource(_ resource: RemoveResource?) async {
      defer { removeResource = nil }

      do {
        try await resource?.deleteAction()
      } catch {
        self.error = error
      }
    }

  }

  #Preview {
    UserProfileEmailRow(emailAddress: .mock)
  }

#endif
