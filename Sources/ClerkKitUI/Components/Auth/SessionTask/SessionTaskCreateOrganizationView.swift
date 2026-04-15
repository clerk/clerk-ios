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
    _organizationName = State(initialValue: creationDefaults?.form?.name ?? "")
    _slug = State(initialValue: creationDefaults?.form?.slug ?? "")
  }

  @State private var error: Error?
  @State private var slugValidationError: ClerkClientError?

  @State private var photosPickerIsPresented = false
  @State private var photosPickerItem: PhotosPickerItem?
  @State private var selectedImageData: Data?
  @State private var imageLoadTask: Task<Void, Never>?
  @State private var preloadedLogoTask: Task<Void, Never>?
  @State private var isPickerImageLoading = false
  @State private var isPreloadedLogoLoading = false

  private var slugEnabled: Bool {
    clerk.environment?.organizationSettings.slug.disabled == false
  }

  private var imageIsLoading: Bool {
    isPickerImageLoading || isPreloadedLogoLoading
  }

  private var trimmedOrganizationName: String {
    organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var trimmedSlug: String {
    slug.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Create organization")
          HeaderView(style: .subtitle, text: "Enter your organization details to continue")
        }
        .padding(.bottom, 32)

        if let advisory = creationDefaults?.advisory, let advisoryMessage = advisoryMessage(for: advisory) {
          WarningText(verbatim: advisoryMessage)
            .padding(.bottom, 16)
        }

        logoSection
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.bottom, 24)

        VStack(spacing: 16) {
          ClerkTextField("Organization name", text: $organizationName)

          if slugEnabled {
            VStack(alignment: .leading, spacing: 8) {
              ClerkTextField(
                "Slug",
                text: $slug,
                fieldState: slugValidationError == nil ? .default : .error
              )
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()

              if let slugValidationError {
                ErrorText(error: slugValidationError, alignment: .leading)
              }
            }
          }
        }
        .padding(.bottom, 24)

        AsyncButton {
          await createOrganization()
        } label: { isRunning in
          ContinueButtonLabelView(isActive: isRunning)
        }
        .buttonStyle(.primary())
        .disabled(trimmedOrganizationName.isEmpty)

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
      imageLoadTask?.cancel()
      isPreloadedLogoLoading = false
      preloadedLogoTask?.cancel()
      error = nil
      imageLoadTask = Task {
        isPickerImageLoading = true
        defer {
          if !Task.isCancelled {
            isPickerImageLoading = false
          }
        }
        do {
          guard
            let data = try await item.loadTransferable(type: Data.self),
            let resizedData = processImageData(data)
          else {
            throw ClerkClientError(message: "There was an error loading the image from the photos library.")
          }
          guard !Task.isCancelled else { return }
          selectedImageData = resizedData
        } catch {
          guard !Task.isCancelled else { return }
          self.error = error
        }
      }
    }
    .onChange(of: organizationName) { _, newValue in
      slug = createSlug(from: newValue)
      slugValidationError = nil
    }
    .onChange(of: slug) { _, _ in
      slugValidationError = nil
    }
    .taskOnce {
      loadDefaultLogo()
    }
  }

  // MARK: - Advisory

  private func advisoryMessage(for advisory: OrganizationCreationDefaults.Advisory) -> String? {
    switch advisory.code {
    case "organization_already_exists":
      let orgName = advisory.meta["organization_name"] ?? ""
      let orgDomain = advisory.meta["organization_domain"] ?? ""
      return "An organization already exists for the detected company name (\(orgName)) and \(orgDomain). Join by invitation."
    default:
      return nil
    }
  }

  // MARK: - Logo Section

  private var logoSection: some View {
    HStack(spacing: 16) {
      ZStack {
        if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
        } else {
          Circle()
            .fill(theme.colors.muted)
          Circle()
            .strokeBorder(theme.colors.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
          Image(systemName: "building.2")
            .font(.title2)
            .foregroundStyle(theme.colors.mutedForeground)
        }

        if imageIsLoading {
          theme.colors.inputBorderFocused
          SpinnerView(color: theme.colors.primaryForeground)
            .frame(width: 24, height: 24)
        }
      }
      .frame(width: 96, height: 96)
      .clipShape(.circle)

      VStack(alignment: .leading, spacing: 12) {
        Button {
          photosPickerIsPresented = true
        } label: {
          PillButtonLabelView("Upload logo")
        }
        .buttonStyle(.plain)

        Text("Recommended size 1:1, up to 10MB.", bundle: .module)
          .font(.caption)
          .foregroundStyle(theme.colors.mutedForeground)
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
    await imageLoadTask?.value
    guard error == nil else { return }

    let name = trimmedOrganizationName
    guard !name.isEmpty else { return }

    guard !slugEnabled || isValidSlug(trimmedSlug) else {
      slugValidationError = ClerkClientError(
        message: "Enter a slug using lowercase letters, numbers, and hyphens."
      )
      return
    }

    do {
      let slugValue = slugEnabled ? trimmedSlug : nil
      let organization = try await clerk.organizations.create(name: name, slug: slugValue)

      if let logoData = await organizationLogoDataForUpload() {
        do {
          try await organization.setLogo(imageData: logoData)
        } catch {
          ClerkLogger.error("Failed to set organization logo", error: error)
        }
      }

      await selectOrganization(id: organization.id)
    } catch {
      self.error = error
    }
  }

  // MARK: - Helpers

  private func loadDefaultLogo() {
    guard let logoUrl = creationDefaults?.form?.logo, let url = URL(string: logoUrl) else { return }

    preloadedLogoTask = Task {
      isPreloadedLogoLoading = true
      defer {
        if !Task.isCancelled {
          isPreloadedLogoLoading = false
        }
      }

      do {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard !Task.isCancelled else { return }
        guard selectedImageData == nil else { return }
        selectedImageData = processImageData(data)
      } catch {
        // Logo fetch failure is non-critical — proceed without logo
      }
    }
  }

  private func organizationLogoDataForUpload() async -> Data? {
    if let selectedImageData {
      return selectedImageData
    }

    await preloadedLogoTask?.value
    return selectedImageData
  }

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

  private func isValidSlug(_ slug: String) -> Bool {
    slug.range(of: "^(?=.*[a-z0-9])[a-z0-9\\-]+$", options: .regularExpression) != nil
  }
}

#Preview("Create Organization") {
  SessionTaskCreateOrganizationView(creationDefaults: nil)
    .clerkPreview()
}

#endif
