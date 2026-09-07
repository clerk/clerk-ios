import ClerkSnapshots
import Foundation

extension Clerk.Environment {
  public typealias DisplayConfig = ClerkSnapshots.DisplayConfig
}

extension Clerk.Environment.DisplayConfig {
  public typealias PreferredSignInStrategy = DisplayConfigPreferredSignInStrategy

  public var instanceEnvironment: InstanceEnvironmentType {
    InstanceEnvironmentType(rawValue: instanceEnvironmentType)
  }

  public init(
    instanceEnvironmentType: InstanceEnvironmentType,
    applicationName: String,
    preferredSignInStrategy: PreferredSignInStrategy,
    supportEmail: String?,
    showDevmodeWarning: Bool,
    branded: Bool,
    logoImageUrl: String,
    homeUrl: String,
    privacyPolicyUrl: String?,
    termsUrl: String?
  ) {
    self.init(
      object: "display_config",
      id: "",
      afterSignInUrl: "",
      afterSignOutAllUrl: "",
      afterSignOutOneUrl: "",
      afterSignUpUrl: "",
      afterSwitchSessionUrl: "",
      applicationName: applicationName,
      branded: branded,
      captchaProvider: "",
      homeUrl: homeUrl,
      instanceEnvironmentType: instanceEnvironmentType.rawValue,
      logoImageUrl: logoImageUrl,
      faviconImageUrl: "",
      preferredSignInStrategy: preferredSignInStrategy,
      signInUrl: "",
      signUpUrl: "",
      supportEmail: supportEmail ?? "",
      theme: .empty,
      userProfileUrl: "",
      organizationProfileUrl: "",
      createOrganizationUrl: "",
      afterLeaveOrganizationUrl: "",
      afterCreateOrganizationUrl: "",
      showDevmodeWarning: showDevmodeWarning,
      termsUrl: termsUrl ?? "",
      privacyPolicyUrl: privacyPolicyUrl ?? "",
      waitlistUrl: "",
      afterJoinWaitlistUrl: ""
    )
  }
}
