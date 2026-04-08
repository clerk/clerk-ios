//
//  SessionTaskCreateOrganizationView.swift
//

#if os(iOS)

import ClerkKit
import NukeUI
import PhotosUI
import SwiftUI

struct SessionTaskCreateOrganizationView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  let creationDefaults: OrganizationCreationDefaults?
  var showBackButton: Bool = false

  @State private var organizationName: String
  @State private var slug: String

  init(creationDefaults: OrganizationCreationDefaults?, showBackButton: Bool = false) {
    self.creationDefaults = creationDefaults
    self.showBackButton = showBackButton
    _organizationName = State(initialValue: creationDefaults?.form.name ?? "")
    _slug = State(initialValue: creationDefaults?.form.slug ?? "")
  }

  @State private var error: Error?

  @State private var photosPickerIsPresented = false
  @State private var photosPickerItem: PhotosPickerItem?
  @State private var selectedImageData: Data?
  @State private var imageIsLoading = false

  private var slugEnabled: Bool {
    clerk.environment?.organizationSettings.slug.disabled == false
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Create organization")
          HeaderView(style: .subtitle, text: "Enter your organization details to continue")
        }
        .padding(.bottom, 32)

        if let advisory = creationDefaults?.advisory {
          advisoryView(advisory)
            .padding(.bottom, 16)
        }

        logoSection
          .padding(.bottom, 24)

        VStack(spacing: 16) {
          ClerkTextField("Organization name", text: $organizationName)

          if slugEnabled {
            ClerkTextField("Slug", text: $slug)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
          }
        }
        .padding(.bottom, 24)

        AsyncButton {
          await createOrganization()
        } label: { isRunning in
          ContinueButtonLabelView(isActive: isRunning)
        }
        .buttonStyle(.primary())
        .disabled(organizationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        Spacer().frame(height: 32)
        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .navigationBarBackButtonHidden(!showBackButton)
    .navigationBarTitleDisplayMode(.inline)
    .preGlassSolidNavBar()
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        UserButton(presentationContext: .sessionTaskToolbar)
      }
    }
    .clerkErrorPresenting($error)
    .photosPicker(
      isPresented: $photosPickerIsPresented,
      selection: $photosPickerItem,
      matching: .images
    )
    .onChange(of: photosPickerItem) { _, item in
      guard let item else { return }
      Task {
        imageIsLoading = true
        defer { imageIsLoading = false }
        do {
          guard
            let data = try await item.loadTransferable(type: Data.self),
            let resizedData = processImageData(data)
          else {
            throw ClerkClientError(message: "There was an error loading the image from the photos library.")
          }
          selectedImageData = resizedData
        } catch {
          self.error = error
        }
      }
    }
    .onChange(of: organizationName) { _, newValue in
      slug = createSlug(from: newValue)
    }
    .task {
      guard let logoUrl = creationDefaults?.form.logo, let url = URL(string: logoUrl) else { return }
      imageIsLoading = true
      defer { imageIsLoading = false }
      do {
        let (data, _) = try await URLSession.shared.data(from: url)
        selectedImageData = processImageData(data)
      } catch {
        // Logo fetch failure is non-critical — proceed without logo
      }
    }
  }

  // MARK: - Advisory

  private func advisoryView(_ advisory: OrganizationCreationDefaults.Advisory) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(theme.colors.warning)
      Text(advisoryMessage(for: advisory))
        .font(.caption)
        .foregroundStyle(theme.colors.foreground)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(theme.colors.backgroundWarning)
    .clipShape(.rect(cornerRadius: theme.design.borderRadius))
    .overlay {
      RoundedRectangle(cornerRadius: theme.design.borderRadius)
        .strokeBorder(theme.colors.borderWarning, lineWidth: 1)
    }
  }

  private func advisoryMessage(for advisory: OrganizationCreationDefaults.Advisory) -> String {
    switch advisory.code {
    case "organization_already_exists":
      let orgName = advisory.meta["organization_name"] ?? ""
      let orgDomain = advisory.meta["organization_domain"] ?? ""
      return "An organization already exists for the detected company name (\(orgName)) and \(orgDomain). Join by invitation."
    default:
      return advisory.code
    }
  }

  // MARK: - Logo Section

  @ViewBuilder
  private var logoSection: some View {
    if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
      Image(uiImage: uiImage)
        .resizable()
        .scaledToFill()
        .frame(width: 96, height: 96)
        .clipShape(.circle)
        .overlay(alignment: .bottomTrailing) {
          Menu {
            Button("Choose from photo library") {
              photosPickerIsPresented = true
            }
            Button("Remove photo", role: .destructive) {
              self.selectedImageData = nil
              photosPickerItem = nil
            }
          } label: {
            Image("icon-edit", bundle: .module)
              .resizable()
              .scaledToFit()
              .frame(width: 16, height: 16)
              .padding(8)
              .foregroundStyle(theme.colors.mutedForeground)
              .background(theme.colors.background)
              .clipShape(.rect(cornerRadius: theme.design.borderRadius))
              .overlay {
                RoundedRectangle(cornerRadius: theme.design.borderRadius)
                  .strokeBorder(theme.colors.buttonBorder, lineWidth: 1)
              }
              .shadow(color: theme.colors.buttonBorder, radius: 1, x: 0, y: 1)
          }
        }
    } else {
      HStack(spacing: 16) {
        ZStack {
          Circle()
            .fill(theme.colors.muted)
          Circle()
            .strokeBorder(theme.colors.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
          Image(systemName: "building.2")
            .font(.title2)
            .foregroundStyle(theme.colors.mutedForeground)

          if imageIsLoading {
            theme.colors.inputBorderFocused
            SpinnerView(color: theme.colors.primaryForeground)
              .frame(width: 24, height: 24)
          }
        }
        .frame(width: 96, height: 96)

        VStack(alignment: .leading, spacing: 12) {
          Button {
            photosPickerIsPresented = true
          } label: {
            Text("Upload logo", bundle: .module)
              .font(.subheadline)
              .foregroundStyle(theme.colors.foreground)
              .padding(.horizontal, 14)
              .frame(height: 32)
              .background(theme.colors.background)
              .clipShape(.rect(cornerRadius: theme.design.borderRadius))
              .overlay {
                RoundedRectangle(cornerRadius: theme.design.borderRadius)
                  .strokeBorder(theme.colors.buttonBorder, lineWidth: 1)
              }
              .shadow(color: theme.colors.buttonBorder, radius: 1, x: 0, y: 1)
          }
          .buttonStyle(.plain)

          Text("Recommended size 1:1, up to 10MB.", bundle: .module)
            .font(.caption)
            .foregroundStyle(theme.colors.mutedForeground)
        }
      }
    }
  }

  // MARK: - Actions

  private func selectOrganization(id: String) async {
    guard let session = clerk.session else { return }

    do {
      try await clerk.auth.setActive(sessionId: session.id, organizationId: id)
      navigation.handleSessionTaskCompletion(session: clerk.session)
    } catch {
      self.error = error
    }
  }

  private func createOrganization() async {
    let name = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return }

    do {
      let slugValue = slugEnabled ? slug.trimmingCharacters(in: .whitespacesAndNewlines) : nil
      let organization = try await clerk.organizations.create(name: name, slug: slugValue)

      if let selectedImageData {
        try await organization.setLogo(imageData: selectedImageData)
      }

      await selectOrganization(id: organization.id)
    } catch {
      self.error = error
    }
  }

  // MARK: - Helpers

  private func processImageData(_ data: Data) -> Data? {
    UIImage(data: data)?
      .resizedMaintainingAspectRatio(to: .init(width: 200, height: 200))
      .jpegData(compressionQuality: 0.8)
  }

  private func createSlug(from name: String) -> String {
    name
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(
        of: "[^a-z0-9]+",
        with: "-",
        options: .regularExpression
      )
  }
}

#Preview("Create Organization") {
  SessionTaskCreateOrganizationView(creationDefaults: nil)
    .clerkPreview()
}

#endif
