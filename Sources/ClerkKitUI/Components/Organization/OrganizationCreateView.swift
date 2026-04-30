//
//  OrganizationCreateView.swift
//

#if os(iOS)

import ClerkKit
import NukeUI
import PhotosUI
import SwiftUI

struct OrganizationCreateView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  private let mode: OrganizationCreateViewMode
  private let creationDefaults: OrganizationCreationDefaults?
  private let onComplete: () -> Void

  @State private var organization: Organization? = nil
  @State private var organizationName: String
  @State private var slug: String
  @State private var error: Error?
  @State private var slugValidationError: ClerkClientError?
  @State private var photosPickerIsPresented = false
  @State private var photosPickerItem: PhotosPickerItem?
  @State private var selectedImageData: Data?
  @State private var imageLoadTask: Task<Void, Never>?
  @State private var preloadedLogoTask: Task<Void, Never>?
  @State private var isPickerImageLoading = false
  @State private var isPreloadedLogoLoading = false

  private var isUpdateMode: Bool {
    if case .update = mode {
      return true
    }

    return false
  }

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

  private var submitTitle: LocalizedStringKey {
    isUpdateMode ? "Save" : "Create organization"
  }

  private var remoteLogoUrl: URL? {
    guard
      selectedImageData == nil,
      let imageUrl = organization?.imageUrl,
      !imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return nil
    }

    return URL(string: imageUrl)
  }

  private var showsLogoMenu: Bool {
    selectedImageData != nil || remoteLogoUrl != nil
  }

  private var logoCanBeRemoved: Bool {
    selectedImageData != nil || organization?.hasImage == true
  }

  init(
    creationDefaults: OrganizationCreationDefaults?,
    onComplete: @escaping () -> Void
  ) {
    mode = .create
    self.creationDefaults = creationDefaults
    self.onComplete = onComplete
    _organizationName = State(initialValue: creationDefaults?.form?.name ?? "")
    _slug = State(initialValue: creationDefaults?.form?.slug ?? "")
  }

  init(
    organization: Organization,
    onComplete: @escaping () -> Void = {}
  ) {
    mode = .update
    creationDefaults = nil
    self.onComplete = onComplete
    _organization = State(initialValue: organization)
    _organizationName = State(initialValue: organization.name)
    _slug = State(initialValue: organization.slug ?? "")
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        if !isUpdateMode {
          VStack(spacing: 8) {
            HeaderView(style: .title, text: "Create organization")
            HeaderView(style: .subtitle, text: "Enter your organization details to continue")
          }
          .padding(.bottom, 32)

          if let advisory = creationDefaults?.advisory, let advisoryMessage = advisoryMessage(for: advisory) {
            WarningText(verbatim: advisoryMessage)
              .padding(.bottom, 16)
          }
        }

        formContent
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .clerkErrorPresenting($error)
    .photosPicker(
      isPresented: $photosPickerIsPresented,
      selection: $photosPickerItem,
      matching: .images
    )
    .onChange(of: photosPickerItem) { _, item in
      guard let item else { return }
      loadSelectedImage(item)
    }
    .onChange(of: organizationName) { _, newValue in
      if !isUpdateMode {
        slug = createSlug(from: newValue)
      }
      slugValidationError = nil
    }
    .onChange(of: slug) { _, _ in
      slugValidationError = nil
    }
    .taskOnce {
      if !isUpdateMode {
        loadDefaultLogo()
      }
    }
  }
}

// MARK: - Form Content

extension OrganizationCreateView {
  private var formContent: some View {
    Group {
      logoSection
        .frame(maxWidth: .infinity, alignment: showsLogoMenu ? .center : .leading)
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
        await submit()
      } label: { isRunning in
        Text(submitTitle, bundle: .module)
          .frame(maxWidth: .infinity)
          .overlayProgressView(isActive: isRunning) {
            SpinnerView(color: theme.colors.primaryForeground)
          }
      }
      .buttonStyle(.primary())
      .disabled(trimmedOrganizationName.isEmpty || imageIsLoading)

      Spacer().frame(height: 32)
      SecuredByClerkView()
    }
  }
}

// MARK: - Logo Section

extension OrganizationCreateView {
  private var logoSection: some View {
    Group {
      if showsLogoMenu {
        logoAvatar
      } else {
        HStack(spacing: 16) {
          logoAvatar

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
    }
  }

  private var logoAvatar: some View {
    ZStack {
      logoContent

      if imageIsLoading {
        theme.colors.inputBorderFocused
        SpinnerView(color: theme.colors.primaryForeground)
          .frame(width: 24, height: 24)
      }
    }
    .frame(width: 96, height: 96)
    .clipShape(.circle)
    .overlay(alignment: .bottomTrailing) {
      if showsLogoMenu {
        Menu {
          logoMenuContent
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
    }
  }

  @ViewBuilder
  private var logoContent: some View {
    if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
      Image(uiImage: uiImage)
        .resizable()
        .scaledToFill()
    } else if let remoteLogoUrl {
      LazyImage(url: remoteLogoUrl) { state in
        if let image = state.image {
          image
            .resizable()
            .scaledToFill()
        } else {
          logoPlaceholder
        }
      }
    } else {
      logoPlaceholder
    }
  }

  private var logoPlaceholder: some View {
    ZStack {
      Circle()
        .fill(theme.colors.muted)
      Circle()
        .strokeBorder(theme.colors.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
      Image(systemName: "building.2")
        .font(.title2)
        .foregroundStyle(theme.colors.mutedForeground)
    }
  }

  @ViewBuilder
  private var logoMenuContent: some View {
    Button("Choose from photo library") {
      photosPickerIsPresented = true
    }

    if logoCanBeRemoved {
      AsyncButton(role: .destructive) {
        await removeLogo()
      } label: { _ in
        Text("Remove logo", bundle: .module)
      }
    }
  }
}

// MARK: - Actions

extension OrganizationCreateView {
  private func submit() async {
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
      switch mode {
      case .create:
        try await createOrganization(name: name, slug: slugEnabled ? trimmedSlug : nil)
      case .update:
        try await updateOrganization(name: name, slug: slugEnabled ? trimmedSlug : nil)
      }
    } catch {
      self.error = error
      ClerkLogger.error("Failed to save organization profile", error: error)
    }
  }

  private func createOrganization(
    name: String,
    slug: String?
  ) async throws {
    var organization = try await clerk.organizations.create(name: name, slug: slug)

    if let logoData = await organizationLogoDataForUpload() {
      do {
        organization = try await organization.setLogo(imageData: logoData)
      } catch {
        ClerkLogger.error("Failed to set organization logo", error: error)
      }
    }

    if let session = clerk.session {
      try await clerk.auth.setActive(sessionId: session.id, organizationId: organization.id)
    }
    onComplete()
  }

  private func updateOrganization(
    name: String,
    slug: String?
  ) async throws {
    guard var organization else { return }

    let updatedOrganization = try await organization.update(name: name, slug: slug)
    organization = clerk.organization ?? updatedOrganization
    self.organization = organization

    onComplete()
  }

  private func loadSelectedImage(_ item: PhotosPickerItem) {
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
        if isUpdateMode {
          try await setOrganizationLogo(imageData: resizedData)
        } else {
          selectedImageData = resizedData
        }
      } catch {
        guard !Task.isCancelled else { return }
        self.error = error
        ClerkLogger.error("Failed to set organization logo", error: error)
      }
    }
  }

  private func setOrganizationLogo(imageData: Data) async throws {
    guard var organization else { return }

    let updatedOrganization = try await organization.setLogo(imageData: imageData)
    organization = clerk.organization ?? updatedOrganization
    self.organization = organization
    selectedImageData = imageData
  }

  private func removeLogo() async {
    if isUpdateMode {
      guard var organization else { return }

      isPickerImageLoading = true
      defer { isPickerImageLoading = false }

      do {
        try await organization.deleteLogo()
        if let syncedOrganization = clerk.organization {
          organization = syncedOrganization
        } else {
          organization.hasImage = false
          organization.imageUrl = ""
        }
        self.organization = organization
        selectedImageData = nil
      } catch {
        self.error = error
        ClerkLogger.error("Failed to delete organization logo", error: error)
      }
    } else {
      selectedImageData = nil
    }
  }
}

// MARK: - Helpers

extension OrganizationCreateView {
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
        // Logo fetch failure is non-critical; proceed without logo.
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

private enum OrganizationCreateViewMode {
  case create
  case update
}

#Preview("Create Organization") {
  NavigationStack {
    OrganizationCreateView(creationDefaults: nil) {}
      .clerkPreview()
  }
}

#Preview("Update Organization") {
  NavigationStack {
    OrganizationCreateView(organization: .mock)
      .environment(Clerk.preview { preview in
        var user = User.mock
        user.organizationMemberships = [.mockWithUserData]

        var session = Session.mock
        session.lastActiveOrganizationId = Organization.mock.id
        session.user = user

        var client = Client.mock
        client.sessions = [session]
        client.lastActiveSessionId = session.id

        preview.client = client
        preview.environment = .mock
      })
  }
}

#endif
