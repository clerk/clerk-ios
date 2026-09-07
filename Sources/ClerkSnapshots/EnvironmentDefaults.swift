import Foundation

extension AttributeData {
  public static let empty = AttributeData(
    enabled: false,
    required: false,
    verifications: [],
    usedForFirstFactor: false,
    firstFactors: [],
    usedForSecondFactor: false,
    secondFactors: [],
    verifyAtSignUp: false
  )
}

extension Attributes {
  public static let empty = Attributes(
    emailAddress: .empty,
    phoneNumber: .empty,
    web3Wallet: .empty,
    passkey: .empty,
    username: .empty,
    password: .empty,
    backupCode: .empty,
    firstName: .empty,
    lastName: .empty,
    authenticatorApp: .empty
  )
}

extension Actions {
  public static let empty = Actions(deleteSelf: false, createOrganization: false)
}

extension OAuthProviderSettings {
  public static let empty = OAuthProviderSettings(
    enabled: false,
    required: false,
    authenticatable: false,
    strategy: "",
    name: ""
  )

  public static func disabled(strategy: String, name: String = "") -> OAuthProviderSettings {
    OAuthProviderSettings(
      enabled: false,
      required: false,
      authenticatable: false,
      strategy: strategy,
      name: name
    )
  }
}

extension OAuthProviders {
  public static let empty = OAuthProviders(
    oauthFacebook: .disabled(strategy: "oauth_facebook", name: "Facebook"),
    oauthGoogle: .disabled(strategy: "oauth_google", name: "Google"),
    oauthHubspot: .disabled(strategy: "oauth_hubspot", name: "HubSpot"),
    oauthGithub: .disabled(strategy: "oauth_github", name: "GitHub"),
    oauthTiktok: .disabled(strategy: "oauth_tiktok", name: "TikTok"),
    oauthGitlab: .disabled(strategy: "oauth_gitlab", name: "GitLab"),
    oauthDiscord: .disabled(strategy: "oauth_discord", name: "Discord"),
    oauthTwitter: .disabled(strategy: "oauth_twitter", name: "Twitter"),
    oauthTwitch: .disabled(strategy: "oauth_twitch", name: "Twitch"),
    oauthLinkedin: .disabled(strategy: "oauth_linkedin", name: "LinkedIn"),
    oauthLinkedinOidc: .disabled(strategy: "oauth_linkedin_oidc", name: "LinkedIn"),
    oauthDropbox: .disabled(strategy: "oauth_dropbox", name: "Dropbox"),
    oauthAtlassian: .disabled(strategy: "oauth_atlassian", name: "Atlassian"),
    oauthBitbucket: .disabled(strategy: "oauth_bitbucket", name: "Bitbucket"),
    oauthMicrosoft: .disabled(strategy: "oauth_microsoft", name: "Microsoft"),
    oauthNotion: .disabled(strategy: "oauth_notion", name: "Notion"),
    oauthApple: .disabled(strategy: "oauth_apple", name: "Apple"),
    oauthLine: .disabled(strategy: "oauth_line", name: "LINE"),
    oauthInstagram: .disabled(strategy: "oauth_instagram", name: "Instagram"),
    oauthCoinbase: .disabled(strategy: "oauth_coinbase", name: "Coinbase"),
    oauthSpotify: .disabled(strategy: "oauth_spotify", name: "Spotify"),
    oauthXero: .disabled(strategy: "oauth_xero", name: "Xero"),
    oauthBox: .disabled(strategy: "oauth_box", name: "Box"),
    oauthSlack: .disabled(strategy: "oauth_slack", name: "Slack"),
    oauthLinear: .disabled(strategy: "oauth_linear", name: "Linear"),
    oauthX: .disabled(strategy: "oauth_x", name: "X"),
    oauthEnstall: .disabled(strategy: "oauth_enstall", name: "Enstall"),
    oauthHuggingface: .disabled(strategy: "oauth_huggingface", name: "Hugging Face"),
    oauthVercel: .disabled(strategy: "oauth_vercel", name: "Vercel")
  )
}

extension EnterpriseSSOSettings {
  public static let empty = EnterpriseSSOSettings(enabled: false, selfServeSso: false)
}

extension SignInDataSecondFactor {
  public static let empty = SignInDataSecondFactor(required: false, enabled: false)
}

extension SignInData {
  public static let empty = SignInData(secondFactor: .empty)
}

extension SignUpData {
  public static let empty = SignUpData(
    allowlistOnly: false,
    progressive: false,
    captchaEnabled: false,
    mode: .public,
    legalConsentEnabled: false
  )
}

extension PasswordSettingsData {
  public static let empty = PasswordSettingsData(
    allowedSpecialCharacters: "",
    disableHibp: false,
    minLength: 0,
    maxLength: 0,
    requireSpecialChar: false,
    requireNumbers: false,
    requireUppercase: false,
    requireLowercase: false,
    showZxcvbn: false,
    minZxcvbnStrength: 0
  )
}

extension PasskeySettingsData {
  public static let empty = PasskeySettingsData(allowAutofill: false, showSignInButton: false)
}

extension UsernameSettingsData {
  public static let empty = UsernameSettingsData(minLength: 0, maxLength: 0)
}

extension UserSettings {
  public static let empty = UserSettings(
    attributes: .empty,
    actions: .empty,
    social: .empty,
    enterpriseSso: .empty,
    signIn: .empty,
    signUp: .empty,
    passwordSettings: .empty,
    passkeySettings: .empty,
    usernameSettings: .empty
  )
}

extension DisplayThemeGeneral {
  public static let empty = DisplayThemeGeneral(
    color: "",
    backgroundColor: .null,
    fontFamily: "",
    fontColor: "",
    labelFontWeight: "",
    padding: "",
    borderRadius: "",
    boxShadow: ""
  )
}

extension DisplayThemeButtons {
  public static let empty = DisplayThemeButtons(fontColor: "", fontFamily: "", fontWeight: "")
}

extension DisplayThemeAccounts {
  public static let empty = DisplayThemeAccounts(backgroundColor: .null)
}

extension DisplayTheme {
  public static let empty = DisplayTheme(general: .empty, buttons: .empty, accounts: .empty)
}

extension DisplayConfig {
  public static let empty = DisplayConfig(
    object: "display_config",
    id: "",
    afterSignInUrl: "",
    afterSignOutAllUrl: "",
    afterSignOutOneUrl: "",
    afterSignUpUrl: "",
    afterSwitchSessionUrl: "",
    applicationName: "",
    branded: false,
    captchaProvider: "",
    homeUrl: "",
    instanceEnvironmentType: "",
    logoImageUrl: "",
    faviconImageUrl: "",
    preferredSignInStrategy: .otp,
    signInUrl: "",
    signUpUrl: "",
    supportEmail: "",
    theme: .empty,
    userProfileUrl: "",
    organizationProfileUrl: "",
    createOrganizationUrl: "",
    afterLeaveOrganizationUrl: "",
    afterCreateOrganizationUrl: "",
    showDevmodeWarning: false,
    termsUrl: "",
    privacyPolicyUrl: "",
    waitlistUrl: "",
    afterJoinWaitlistUrl: ""
  )
}

extension CommerceSettingsBillingOrganization {
  public static let empty = CommerceSettingsBillingOrganization(enabled: false, hasPaidPlans: false)
}

extension CommerceSettingsBilling {
  public static let empty = CommerceSettingsBilling(organization: .empty, user: .empty)
}

extension CommerceSettings {
  public static let empty = CommerceSettings(billing: .empty, id: "", object: "commerce_settings")
}

extension OrganizationSettingsActions {
  public static let empty = OrganizationSettingsActions(adminDelete: false)
}

extension OrganizationSettingsDomains {
  public static let empty = OrganizationSettingsDomains(enabled: false, enrollmentModes: [])
}

extension OrganizationSettingsSlug {
  public static let empty = OrganizationSettingsSlug(disabled: false)
}

extension OrganizationSettingsOrganizationCreationDefaults {
  public static let empty = OrganizationSettingsOrganizationCreationDefaults(enabled: false)
}

extension OrganizationSettings {
  public static let empty = OrganizationSettings(
    enabled: false,
    maxAllowedMemberships: 1,
    forceOrganizationSelection: false,
    actions: .empty,
    domains: .empty,
    slug: .empty,
    organizationCreationDefaults: .empty
  )
}

extension APIKeysSettings {
  public static let empty = APIKeysSettings(
    userApiKeysEnabled: false,
    orgsApiKeysEnabled: false,
    id: "",
    object: "api_keys_settings"
  )
}

extension ProtectConfig {
  public static let empty = ProtectConfig(object: "protect_config", id: "")
}

extension Token {
  public static let empty = Token(object: "token", jwt: "", id: "")
}

extension PublicUserData {
  public static let empty = PublicUserData(imageUrl: "", hasImage: false, identifier: "")
}

extension User {
  public static let empty = User(
    object: "user",
    id: "",
    imageUrl: "",
    hasImage: false,
    emailAddresses: [],
    phoneNumbers: [],
    web3Wallets: [],
    externalAccounts: [],
    enterpriseAccounts: [],
    passkeys: [],
    organizationMemberships: [],
    passwordEnabled: false,
    profileImageId: "",
    totpEnabled: false,
    backupCodeEnabled: false,
    twoFactorEnabled: false,
    publicMetadata: .object([:]),
    unsafeMetadata: .object([:]),
    createOrganizationEnabled: false,
    deleteSelfEnabled: false,
    updatedAt: Date(timeIntervalSince1970: 0),
    createdAt: Date(timeIntervalSince1970: 0)
  )
}

extension Verification {
  public static var empty: Verification {
    Verification(
      status: .unverified,
      verifiedAtClient: "",
      strategy: "",
      attempts: 0,
      expireAt: Date(timeIntervalSince1970: 0),
      error: ClerkAPIError(code: "", message: ""),
      id: "",
      object: "verification"
    )
  }
}

extension SignUpVerification {
  public static let empty = SignUpVerification(
    nextAction: "",
    supportedStrategies: [],
    status: .unverified,
    verifiedAtClient: "",
    strategy: "",
    attempts: 0,
    expireAt: Date(timeIntervalSince1970: 0),
    error: ClerkAPIError(code: "", message: ""),
    id: "",
    object: "verification"
  )
}

extension ClerkEnvironment {
  public static let empty = ClerkEnvironment(
    apiKeysSettings: .empty,
    authConfig: AuthConfig(
      singleSessionMode: false,
      reverification: false,
      id: "",
      object: "auth_config"
    ),
    commerceSettings: .empty,
    displayConfig: .empty,
    maintenanceMode: false,
    organizationSettings: .empty,
    userSettings: .empty,
    protectConfig: .empty,
    id: "",
    object: "environment"
  )
}
