//
//  UserProfileEmailRow.swift
//  Clerk
//

import ClerkKit
import SwiftUI

#if os(iOS)

struct UserProfileEmailRow: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  @State private var addEmailAddressDestination: UserProfileAddEmailView.Destination?
  @State private var isLoading = false
  @State private var removeResource: RemoveResource?
  @State private var isConfirmingRemoval = false
  @State private var error: Error?

  var user: User? {
    clerk.user
  }

  let emailAddress: EmailAddress

  private var isPrimary: Bool {
    user?.primaryEmailAddress == emailAddress
  }

  private var isVerified: Bool {
    emailAddress.verification?.status == .verified
  }

  private var canRemove: Bool {
    clerk.environment?.emailIsImmutable != true
  }

  private var shouldShowMenu: Bool {
    canRemove || !isPrimary || !isVerified
  }

  var body: some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        WrappingHStack(alignment: .leading) {
          if isPrimary {
            Badge(key: "Primary", style: .secondary)
          }

          if !isVerified {
            Badge(key: "Unverified", style: .warning)
          }

          if emailAddress.linkedTo?.isEmpty == false {
            Badge(key: "Linked", style: .secondary)
          }
        }

        Text(emailAddress.emailAddress)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.foreground)
          .frame(minHeight: 22)
      }

      Spacer(minLength: 0)

      if shouldShowMenu {
        Menu {
          if !isPrimary, isVerified {
            AsyncButton {
              await setEmailAsPrimary(emailAddress)
            } label: { _ in
              Text("Set as primary", bundle: .module)
            }
            .onIsRunningChanged { isLoading = $0 }
            .onDisappear { isLoading = false }
          }

          if !isVerified {
            Button {
              addEmailAddressDestination = .verify(emailAddress)
            } label: {
              Text("Verify", bundle: .module)
            }
          }

          if canRemove {
            Button(role: .destructive) {
              removeResource = .email(emailAddress)
            } label: {
              Text("Remove email", bundle: .module)
            }
          }
        } label: {
          ThreeDotsMenuLabel()
        }
        .frame(width: 30, height: 30)
      }
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
    .sheet(item: $addEmailAddressDestination) {
      UserProfileAddEmailView(desintation: $0)
    }
    .onChange(of: removeResource) {
      if $1 != nil { isConfirmingRemoval = true }
    }
    .confirmationDialog(
      removeResource?.messageLine1 ?? "",
      isPresented: $isConfirmingRemoval,
      titleVisibility: .visible,
      actions: {
        AsyncButton(role: .destructive) {
          await removeResource(removeResource)
        } label: { _ in
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

extension UserProfileEmailRow {
  private func setEmailAsPrimary(_ email: EmailAddress) async {
    do {
      try await user?.update(.init(primaryEmailAddressId: email.id))
    } catch {
      self.error = error
      ClerkLogger.error("Failed to set email as primary", error: error)
    }
  }

  private func removeResource(_ resource: RemoveResource?) async {
    defer { removeResource = nil }

    do {
      try await resource?.deleteAction()
    } catch {
      self.error = error
      ClerkLogger.error("Failed to remove email resource", error: error)
    }
  }
}

#Preview {
  UserProfileEmailRow(emailAddress: .mock)
}

#endif
