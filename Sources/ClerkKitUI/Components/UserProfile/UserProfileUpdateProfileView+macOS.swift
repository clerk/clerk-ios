//
//  UserProfileUpdateProfileView+macOS.swift
//  Clerk
//

#if os(macOS)

import ClerkKit
import SwiftUI

struct UserProfileUpdateProfileView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.dismiss) private var dismiss
  @Environment(\.clerkTheme) private var theme

  @State private var firstName: String
  @State private var lastName: String
  @State private var username: String
  @State private var isSaving = false
  @State private var errorMessage: String?

  let user: User

  init(user: User) {
    self.user = user
    _username = State(initialValue: user.username ?? "")
    _firstName = State(initialValue: user.firstName ?? "")
    _lastName = State(initialValue: user.lastName ?? "")
  }

  private var canEditUsername: Bool {
    attributeIsEnabled("username")
  }

  private var canEditFirstName: Bool {
    attributeIsEnabled("first_name")
  }

  private var canEditLastName: Bool {
    attributeIsEnabled("last_name")
  }

  private var hasEditableFields: Bool {
    canEditUsername || canEditFirstName || canEditLastName
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Edit profile")
        .font(theme.fonts.title3.weight(.semibold))
        .foregroundStyle(theme.colors.foreground)

      Text("Update the profile details currently enabled for this Clerk instance.")
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.mutedForeground)
        .fixedSize(horizontal: false, vertical: true)

      if hasEditableFields {
        VStack(alignment: .leading, spacing: 16) {
          if canEditUsername {
            VStack(alignment: .leading, spacing: 6) {
              Text("Username")
                .font(theme.fonts.subheadline.weight(.medium))
                .foregroundStyle(theme.colors.foreground)

              TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
            }
          }

          if canEditFirstName {
            VStack(alignment: .leading, spacing: 6) {
              Text("First name")
                .font(theme.fonts.subheadline.weight(.medium))
                .foregroundStyle(theme.colors.foreground)

              TextField("First name", text: $firstName)
                .textFieldStyle(.roundedBorder)
            }
          }

          if canEditLastName {
            VStack(alignment: .leading, spacing: 6) {
              Text("Last name")
                .font(theme.fonts.subheadline.weight(.medium))
                .foregroundStyle(theme.colors.foreground)

              TextField("Last name", text: $lastName)
                .textFieldStyle(.roundedBorder)
            }
          }
        }
      } else {
        Text("No editable profile fields are enabled for this instance.")
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.mutedForeground)
      }

      if let errorMessage {
        Text(errorMessage)
          .font(theme.fonts.footnote)
          .foregroundStyle(theme.colors.danger)
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack {
        Button("Cancel") {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Spacer()

        Button("Save") {
          Task {
            await save()
          }
        }
        .buttonStyle(.primary())
        .disabled(isSaving || !hasEditableFields)
      }
    }
    .padding(24)
    .frame(minWidth: 420, maxWidth: 520, alignment: .leading)
    .background(theme.colors.background)
  }
}

extension UserProfileUpdateProfileView {
  private func attributeIsEnabled(_ key: String) -> Bool {
    clerk.environment?.userSettings.attributes[key]?.enabled == true
  }

  @MainActor
  private func save() async {
    isSaving = true
    errorMessage = nil
    defer { isSaving = false }

    do {
      try await user.update(
        .init(
          username: canEditUsername ? username.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
          firstName: canEditFirstName ? firstName.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
          lastName: canEditLastName ? lastName.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )
      )

      _ = try? await clerk.refreshClient()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
      ClerkLogger.error("Failed to update user profile", error: error)
    }
  }
}

#Preview {
  UserProfileUpdateProfileView(user: .mock)
    .environment(Clerk.preview())
}

#endif
