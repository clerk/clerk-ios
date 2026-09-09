// Generated from TypeScript. Do not edit.
import Foundation
import Observation

public struct ClerkState: Sendable {
  public let status: ClerkStatus
  public let loaded: Bool
  public let session: Session?
  public let user: User?
  public let organization: Organization?
  public let signIn: SignIn
  public let signUp: SignUp
  public init(status: ClerkStatus, loaded: Bool, session: Session?, user: User?, organization: Organization?, signIn: SignIn, signUp: SignUp) {
    self.status = status
    self.loaded = loaded
    self.session = session
    self.user = user
    self.organization = organization
    self.signIn = signIn
    self.signUp = signUp
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "status": status.encode(),
      "loaded": .bool(loaded),
      "session": session.map { value in try value.encode() } ?? .null,
      "user": user.map { value in try value.encode() } ?? .null,
      "organization": organization.map { value in try value.encode() } ?? .null,
      "signIn": signIn.encode(),
      "signUp": signUp.encode(),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ClerkState {
    let values = try value.object()

    return try ClerkState(status: ClerkStatus.decode(values["status"] ?? .undefined, in: runtime), loaded: (values["loaded"] ?? .undefined).bool(), session: (values["session"] ?? .undefined).optional { value in try Session.decode(value, in: runtime) }, user: (values["user"] ?? .undefined).optional { value in try User.decode(value, in: runtime) }, organization: (values["organization"] ?? .undefined).optional { value in try Organization.decode(value, in: runtime) }, signIn: SignIn.decode(values["signIn"] ?? .undefined, in: runtime), signUp: SignUp.decode(values["signUp"] ?? .undefined, in: runtime))
  }
}

@MainActor @Observable public final class Clerk: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: ClerkState {
    context.state(handle, as: ClerkState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: true)
  }

  public var status: ClerkStatus {
    state.status
  }

  public var loaded: Bool {
    state.loaded
  }

  public var session: Session? {
    state.session
  }

  public var user: User? {
    state.user
  }

  public var organization: Organization? {
    state.organization
  }

  public var signIn: SignIn {
    state.signIn
  }

  public var signUp: SignUp {
    state.signUp
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try ClerkState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> Clerk {
    try runtime.resource(ResourceHandle.decodeReference(value), as: Clerk.self)
  }

  /// Creates an Organization programmatically, adding the current user as admin. Returns an [`Organization`](https://clerk.com/docs/reference/objects/organization) object.
  ///
  /// > [!NOTE]
  /// > For React-based apps, consider using the [`<CreateOrganization />`](https://clerk.com/docs/reference/components/organization/create-organization) component.
  public func createOrganization(_ params: CreateOrganizationParams) async throws -> Organization {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Clerk.createOrganization", arguments: [params.encode()])
    return try Organization.decode(result, in: runtime)
  }

  /// Gets a single [Organization](https://clerk.com/docs/reference/objects/organization) by ID.
  public func getOrganization(_ organizationId: String) async throws -> Organization {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Clerk.getOrganization", arguments: [.string(organizationId)])
    return try Organization.decode(result, in: runtime)
  }

  public func setActive(_ params: MobileSetActiveParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Clerk.setActive", arguments: [params.encode()])
    _ = result
  }

  public func signOut(_ options: MobileSignOutOptions? = nil) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Clerk.signOut", arguments: [options.map { value in try value.encode() } ?? .undefined])
    _ = result
  }
}

public enum ClerkStatus: Hashable, Sendable {
  case degraded
  case error
  case loading
  case ready
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .degraded: "degraded"
    case .error: "error"
    case .loading: "loading"
    case .ready: "ready"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "degraded": self = .degraded
    case "error": self = .error
    case "loading": self = .loading
    case "ready": self = .ready
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> ClerkStatus {
    try .init(rawValue: value.string())
  }
}

public struct CreateOrganizationParams: Sendable {
  public let name: String
  public let slug: String?
  public init(name: String, slug: String? = nil) {
    self.name = name
    self.slug = slug
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "name": .string(name),
      "slug": slug.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> CreateOrganizationParams {
    let values = try value.object()

    return try CreateOrganizationParams(name: (values["name"] ?? .undefined).string(), slug: (values["slug"] ?? .undefined).optional { value in try value.string() })
  }
}

/// The `Organization` object holds information about an Organization, as well as methods for managing it.
///
/// To use these methods, you must have the **Organizations** feature [enabled in your app's settings in the Clerk Dashboard](https://clerk.com/docs/guides/organizations/configure#enable-organizations).
public struct OrganizationState: Sendable {
  public let id: String
  public let name: String
  public let slug: String?
  public let imageUrl: String
  public let hasImage: Bool
  public let membersCount: Double
  public let pendingInvitationsCount: Double
  public let publicMetadata: [String: JSONValue]
  public let adminDeleteEnabled: Bool
  public let maxAllowedMemberships: Double
  public let selfServeSSOEnabled: Bool
  public let exclusiveMembership: Bool
  public let createdAt: Date
  public let updatedAt: Date
  public init(id: String, name: String, slug: String?, imageUrl: String, hasImage: Bool, membersCount: Double, pendingInvitationsCount: Double, publicMetadata: [String: JSONValue], adminDeleteEnabled: Bool, maxAllowedMemberships: Double, selfServeSSOEnabled: Bool, exclusiveMembership: Bool, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.name = name
    self.slug = slug
    self.imageUrl = imageUrl
    self.hasImage = hasImage
    self.membersCount = membersCount
    self.pendingInvitationsCount = pendingInvitationsCount
    self.publicMetadata = publicMetadata
    self.adminDeleteEnabled = adminDeleteEnabled
    self.maxAllowedMemberships = maxAllowedMemberships
    self.selfServeSSOEnabled = selfServeSSOEnabled
    self.exclusiveMembership = exclusiveMembership
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "name": .string(name),
      "slug": slug.map { value in .string(value) } ?? .null,
      "imageUrl": .string(imageUrl),
      "hasImage": .bool(hasImage),
      "membersCount": .number(membersCount),
      "pendingInvitationsCount": .number(pendingInvitationsCount),
      "publicMetadata": .object(publicMetadata),
      "adminDeleteEnabled": .bool(adminDeleteEnabled),
      "maxAllowedMemberships": .number(maxAllowedMemberships),
      "selfServeSSOEnabled": .bool(selfServeSSOEnabled),
      "exclusiveMembership": .bool(exclusiveMembership),
      "createdAt": .string(createdAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "updatedAt": .string(updatedAt.ISO8601Format(.init(includingFractionalSeconds: true))),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationState {
    let values = try value.object()

    return try OrganizationState(id: (values["id"] ?? .undefined).string(), name: (values["name"] ?? .undefined).string(), slug: (values["slug"] ?? .undefined).optional { value in try value.string() }, imageUrl: (values["imageUrl"] ?? .undefined).string(), hasImage: (values["hasImage"] ?? .undefined).bool(), membersCount: (values["membersCount"] ?? .undefined).number(), pendingInvitationsCount: (values["pendingInvitationsCount"] ?? .undefined).number(), publicMetadata: (values["publicMetadata"] ?? .undefined).object(), adminDeleteEnabled: (values["adminDeleteEnabled"] ?? .undefined).bool(), maxAllowedMemberships: (values["maxAllowedMemberships"] ?? .undefined).number(), selfServeSSOEnabled: (values["selfServeSSOEnabled"] ?? .undefined).bool(), exclusiveMembership: (values["exclusiveMembership"] ?? .undefined).bool(), createdAt: (values["createdAt"] ?? .undefined).date(), updatedAt: (values["updatedAt"] ?? .undefined).date())
  }
}

@MainActor @Observable public final class Organization: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: OrganizationState {
    context.state(handle, as: OrganizationState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var name: String {
    state.name
  }

  public var slug: String? {
    state.slug
  }

  public var imageUrl: String {
    state.imageUrl
  }

  public var hasImage: Bool {
    state.hasImage
  }

  public var membersCount: Double {
    state.membersCount
  }

  public var pendingInvitationsCount: Double {
    state.pendingInvitationsCount
  }

  public var publicMetadata: [String: JSONValue] {
    state.publicMetadata
  }

  public var adminDeleteEnabled: Bool {
    state.adminDeleteEnabled
  }

  public var maxAllowedMemberships: Double {
    state.maxAllowedMemberships
  }

  public var selfServeSSOEnabled: Bool {
    state.selfServeSSOEnabled
  }

  public var exclusiveMembership: Bool {
    state.exclusiveMembership
  }

  public var createdAt: Date {
    state.createdAt
  }

  public var updatedAt: Date {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try OrganizationState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> Organization {
    try runtime.resource(ResourceHandle.decodeReference(value), as: Organization.self)
  }

  /// Updates the current Organization.
  public func update(_ params: UpdateOrganizationParams) async throws -> Organization {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.update", arguments: [params.encode()])
    return try Organization.decode(result, in: runtime)
  }

  /// Gets the list of Organization Memberships.
  public func getMemberships(_ params: GetMembersParams? = nil) async throws -> ClerkPaginatedResponseOrganizationMembership {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.getMemberships", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try ClerkPaginatedResponseOrganizationMembership.decode(result, in: runtime)
  }

  /// Gets the list of invitations.
  public func getInvitations(_ params: GetInvitationsParams? = nil) async throws -> ClerkPaginatedResponseOrganizationInvitation {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.getInvitations", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try ClerkPaginatedResponseOrganizationInvitation.decode(result, in: runtime)
  }

  /// Gets the list of [Roles](https://clerk.com/docs/guides/organizations/control-access/roles-and-permissions) available.
  public func getRoles(_ params: GetRolesParams? = nil) async throws -> GetRolesResponse {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.getRoles", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try GetRolesResponse.decode(result, in: runtime)
  }

  /// Gets the list of domains.
  public func getDomains(_ params: GetDomainsParams? = nil) async throws -> ClerkPaginatedResponseOrganizationDomain {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.getDomains", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try ClerkPaginatedResponseOrganizationDomain.decode(result, in: runtime)
  }

  /// Gets the list of membership requests.
  public func getMembershipRequests(_ params: GetMembershipRequestParams? = nil) async throws -> ClerkPaginatedResponseOrganizationMembershipRequest {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.getMembershipRequests", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try ClerkPaginatedResponseOrganizationMembershipRequest.decode(result, in: runtime)
  }

  /// Adds a user as a member to an organization. A user can only be added to an organization if they are not already a member of it and if they already exist in the same instance as the organization. Only administrators can add members to an organization.
  public func addMember(_ params: AddMemberParams) async throws -> OrganizationMembership {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.addMember", arguments: [params.encode()])
    return try OrganizationMembership.decode(result, in: runtime)
  }

  /// Creates and sends an invitation to the given email address.
  public func inviteMember(_ params: InviteMemberParams) async throws -> OrganizationInvitation {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.inviteMember", arguments: [params.encode()])
    return try OrganizationInvitation.decode(result, in: runtime)
  }

  /// Creates and sends invitations to the given email addresses.
  public func inviteMembers(_ params: InviteMembersParams) async throws -> [OrganizationInvitation] {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.inviteMembers", arguments: [params.encode()])
    return try result.array().map { value in try OrganizationInvitation.decode(value, in: runtime) }
  }

  /// Updates a given member.
  public func updateMember(_ params: UpdateMembershipParams) async throws -> OrganizationMembership {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.updateMember", arguments: [params.encode()])
    return try OrganizationMembership.decode(result, in: runtime)
  }

  /// Removes a member.
  public func removeMember(_ userId: String) async throws -> OrganizationMembership {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.removeMember", arguments: [.string(userId)])
    return try OrganizationMembership.decode(result, in: runtime)
  }

  /// Creates a new domain.
  public func createDomain(_ domainName: String, params: PickCreateOrganizationDomainParamsAndenrollmentMode? = nil) async throws -> OrganizationDomain {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.createDomain", arguments: [.string(domainName), params.map { value in try value.encode() } ?? .undefined])
    return try OrganizationDomain.decode(result, in: runtime)
  }

  /// Starts the verification process of multiple [Verified Domains](https://clerk.com/docs/guides/organizations/add-members/verified-domains) at once by issuing a fresh TXT challenge for each of the given domains in a single request. Each resolved domain's `ownershipVerification` property carries the `txtRecordName` and `txtRecordValue` the Organization [admin](https://clerk.com/docs/guides/organizations/control-access/roles-and-permissions) must publish. A single bad domain does not fail the batch; it lands in the returned [`OrganizationDomainsBulkOwnershipVerificationResource`](https://clerk.com/docs/reference/types/organization-domains-bulk-ownership-verification-resource) object's `errors` array.
  public func prepareOwnershipVerification(_ domainIds: [String]) async throws -> OrganizationDomainsBulkOwnershipVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.prepareOwnershipVerification", arguments: [.array(domainIds.map { value in .string(value) })])
    return try OrganizationDomainsBulkOwnershipVerification.decode(result, in: runtime)
  }

  /// Completes the verification process started by [`prepareOwnershipVerification()`](https://clerk.com/docs/reference/objects/organization#prepare-ownership-verification), by resolving the published TXT record for each of the given domains in a single request. A single bad domain does not fail the batch; it lands in the returned [`OrganizationDomainsBulkOwnershipVerificationResource`](https://clerk.com/docs/reference/types/organization-domains-bulk-ownership-verification-resource) object's `errors` array.
  public func attemptOwnershipVerification(_ domainIds: [String]) async throws -> OrganizationDomainsBulkOwnershipVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.attemptOwnershipVerification", arguments: [.array(domainIds.map { value in .string(value) })])
    return try OrganizationDomainsBulkOwnershipVerification.decode(result, in: runtime)
  }

  /// Gets a domain for an Organization based on the given domain ID.
  public func getDomain(_ value0: OrganizationGetDomain__0) async throws -> OrganizationDomain {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.getDomain", arguments: [value0.encode()])
    return try OrganizationDomain.decode(result, in: runtime)
  }

  public func getEnterpriseConnections(_ params: GetEnterpriseConnectionsParams? = nil) async throws -> [EnterpriseConnection] {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.getEnterpriseConnections", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try result.array().map { value in try EnterpriseConnection.decode(value, in: runtime) }
  }

  public func createEnterpriseConnection(_ params: CreateOrganizationEnterpriseConnectionParams) async throws -> EnterpriseConnection {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.createEnterpriseConnection", arguments: [params.encode()])
    return try EnterpriseConnection.decode(result, in: runtime)
  }

  public func updateEnterpriseConnection(_ enterpriseConnectionId: String, params: UpdateOrganizationEnterpriseConnectionParams) async throws -> EnterpriseConnection {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.updateEnterpriseConnection", arguments: [.string(enterpriseConnectionId), params.encode()])
    return try EnterpriseConnection.decode(result, in: runtime)
  }

  public func deleteEnterpriseConnection(_ enterpriseConnectionId: String) async throws -> DeletedObject {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.deleteEnterpriseConnection", arguments: [.string(enterpriseConnectionId)])
    return try DeletedObject.decode(result, in: runtime)
  }

  public func createEnterpriseConnectionTestRun(_ enterpriseConnectionId: String) async throws -> EnterpriseConnectionTestRunInit {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.createEnterpriseConnectionTestRun", arguments: [.string(enterpriseConnectionId)])
    return try EnterpriseConnectionTestRunInit.decode(result, in: runtime)
  }

  public func getEnterpriseConnectionTestRuns(_ enterpriseConnectionId: String, params: GetEnterpriseConnectionTestRunsParams? = nil) async throws -> ClerkPaginatedResponseEnterpriseConnectionTestRun {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.getEnterpriseConnectionTestRuns", arguments: [.string(enterpriseConnectionId), params.map { value in try value.encode() } ?? .undefined])
    return try ClerkPaginatedResponseEnterpriseConnectionTestRun.decode(result, in: runtime)
  }

  /// Deletes the Organization. Only administrators can delete an Organization.
  ///
  /// Deleting an Organization will also delete all memberships and invitations. **This is not reversible.**
  public func destroy() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.destroy", arguments: [])
    _ = result
  }

  /// Sets or replaces an Organization's logo.
  public func setLogo(_ params: SetOrganizationLogoParams) async throws -> Organization {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.setLogo", arguments: [params.encode()])
    return try Organization.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> Organization {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try Organization.decode(result, in: runtime)
  }

  /// Initializes a payment method.
  public func initializePaymentMethod(_ params: InitializePaymentMethodParams) async throws -> BillingInitializedPaymentMethod {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.initializePaymentMethod", arguments: [params.encode()])
    return try BillingInitializedPaymentMethod.decode(result, in: runtime)
  }

  /// Adds a payment method.
  public func addPaymentMethod(_ params: AddPaymentMethodParams) async throws -> BillingPaymentMethod {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.addPaymentMethod", arguments: [params.encode()])
    return try BillingPaymentMethod.decode(result, in: runtime)
  }

  /// Gets a list of payment methods that have been stored.
  public func getPaymentMethods(_ params: GetPaymentMethodsParams? = nil) async throws -> ClerkPaginatedResponseBillingPaymentMethod {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Organization.getPaymentMethods", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try ClerkPaginatedResponseBillingPaymentMethod.decode(result, in: runtime)
  }
}

public struct UpdateOrganizationParams: Sendable {
  public let name: String
  public let slug: String?
  public init(name: String, slug: String? = nil) {
    self.name = name
    self.slug = slug
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "name": .string(name),
      "slug": slug.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> UpdateOrganizationParams {
    let values = try value.object()

    return try UpdateOrganizationParams(name: (values["name"] ?? .undefined).string(), slug: (values["slug"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct GetMembersParams: Sendable {
  public let initialPage: Double?
  public let pageSize: Double?
  public let role: [String]?
  public let query: String?
  public init(initialPage: Double? = nil, pageSize: Double? = nil, role: [String]? = nil, query: String? = nil) {
    self.initialPage = initialPage
    self.pageSize = pageSize
    self.role = role
    self.query = query
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "initialPage": initialPage.map { value in .number(value) } ?? .undefined,
      "pageSize": pageSize.map { value in .number(value) } ?? .undefined,
      "role": role.map { value in try .array(value.map { value in .string(value) }) } ?? .undefined,
      "query": query.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> GetMembersParams {
    let values = try value.object()

    return try GetMembersParams(initialPage: (values["initialPage"] ?? .undefined).optional { value in try value.number() }, pageSize: (values["pageSize"] ?? .undefined).optional { value in try value.number() }, role: (values["role"] ?? .undefined).optional { value in try value.array().map { value in try value.string() } }, query: (values["query"] ?? .undefined).optional { value in try value.string() })
  }
}

/// An interface that describes the response of a method that returns a paginated list of resources.
///
/// > [!TIP]
/// > Clerk's SDKs always use `Promise<ClerkPaginatedResponse<T>>`. If the promise resolves, you will get back the properties. If the promise is rejected, you will receive a `ClerkAPIResponseError` or network error.
public struct ClerkPaginatedResponseOrganizationMembership: Sendable {
  public let data: [OrganizationMembership]
  public let totalCount: Double
  public init(data: [OrganizationMembership], totalCount: Double) {
    self.data = data
    self.totalCount = totalCount
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "data": .array(data.map { value in try value.encode() }),
      "total_count": .number(totalCount),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ClerkPaginatedResponseOrganizationMembership {
    let values = try value.object()

    return try ClerkPaginatedResponseOrganizationMembership(data: (values["data"] ?? .undefined).array().map { value in try OrganizationMembership.decode(value, in: runtime) }, totalCount: (values["total_count"] ?? .undefined).number())
  }
}

/// The `OrganizationMembership` object is the model around a user's membership in an Organization.
public struct OrganizationMembershipState: Sendable {
  public let id: String
  public let organization: Organization
  public let permissions: [String]
  public let publicMetadata: [String: JSONValue]
  public let publicUserData: PublicUserData?
  public let role: String
  public let roleName: String
  public let createdAt: Date
  public let updatedAt: Date
  public init(id: String, organization: Organization, permissions: [String], publicMetadata: [String: JSONValue], publicUserData: PublicUserData? = nil, role: String, roleName: String, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.organization = organization
    self.permissions = permissions
    self.publicMetadata = publicMetadata
    self.publicUserData = publicUserData
    self.role = role
    self.roleName = roleName
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "organization": organization.encode(),
      "permissions": .array(permissions.map { value in .string(value) }),
      "publicMetadata": .object(publicMetadata),
      "publicUserData": publicUserData.map { value in try value.encode() } ?? .undefined,
      "role": .string(role),
      "roleName": .string(roleName),
      "createdAt": .string(createdAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "updatedAt": .string(updatedAt.ISO8601Format(.init(includingFractionalSeconds: true))),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationMembershipState {
    let values = try value.object()

    return try OrganizationMembershipState(id: (values["id"] ?? .undefined).string(), organization: Organization.decode(values["organization"] ?? .undefined, in: runtime), permissions: (values["permissions"] ?? .undefined).array().map { value in try value.string() }, publicMetadata: (values["publicMetadata"] ?? .undefined).object(), publicUserData: (values["publicUserData"] ?? .undefined).optional { value in try PublicUserData.decode(value, in: runtime) }, role: (values["role"] ?? .undefined).string(), roleName: (values["roleName"] ?? .undefined).string(), createdAt: (values["createdAt"] ?? .undefined).date(), updatedAt: (values["updatedAt"] ?? .undefined).date())
  }
}

@MainActor @Observable public final class OrganizationMembership: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: OrganizationMembershipState {
    context.state(handle, as: OrganizationMembershipState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var organization: Organization {
    state.organization
  }

  public var permissions: [String] {
    state.permissions
  }

  public var publicMetadata: [String: JSONValue] {
    state.publicMetadata
  }

  public var publicUserData: PublicUserData? {
    state.publicUserData
  }

  public var role: String {
    state.role
  }

  public var roleName: String {
    state.roleName
  }

  public var createdAt: Date {
    state.createdAt
  }

  public var updatedAt: Date {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try OrganizationMembershipState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationMembership {
    try runtime.resource(ResourceHandle.decodeReference(value), as: OrganizationMembership.self)
  }

  /// Deletes the membership, removing the user from the Organization.
  public func destroy() async throws -> OrganizationMembership {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationMembership.destroy", arguments: [])
    return try OrganizationMembership.decode(result, in: runtime)
  }

  /// Updates the member's [Role](https://clerk.com/docs/guides/organizations/control-access/roles-and-permissions) in the Organization.
  public func update(_ updateParams: UpdateOrganizationMembershipParams) async throws -> OrganizationMembership {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationMembership.update", arguments: [updateParams.encode()])
    return try OrganizationMembership.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> OrganizationMembership {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationMembership.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try OrganizationMembership.decode(result, in: runtime)
  }
}

/// Information about the user that's publicly available.
public struct PublicUserData: Sendable {
  public let firstName: String?
  public let lastName: String?
  public let imageUrl: String
  public let hasImage: Bool
  public let identifier: String
  public let userId: String?
  public let username: String?
  public let banned: Bool?
  public let deprovisioned: Bool?
  public init(firstName: String?, lastName: String?, imageUrl: String, hasImage: Bool, identifier: String, userId: String? = nil, username: String? = nil, banned: Bool? = nil, deprovisioned: Bool? = nil) {
    self.firstName = firstName
    self.lastName = lastName
    self.imageUrl = imageUrl
    self.hasImage = hasImage
    self.identifier = identifier
    self.userId = userId
    self.username = username
    self.banned = banned
    self.deprovisioned = deprovisioned
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "firstName": firstName.map { value in .string(value) } ?? .null,
      "lastName": lastName.map { value in .string(value) } ?? .null,
      "imageUrl": .string(imageUrl),
      "hasImage": .bool(hasImage),
      "identifier": .string(identifier),
      "userId": userId.map { value in .string(value) } ?? .undefined,
      "username": username.map { value in .string(value) } ?? .undefined,
      "banned": banned.map { value in .bool(value) } ?? .undefined,
      "deprovisioned": deprovisioned.map { value in .bool(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> PublicUserData {
    let values = try value.object()

    return try PublicUserData(firstName: (values["firstName"] ?? .undefined).optional { value in try value.string() }, lastName: (values["lastName"] ?? .undefined).optional { value in try value.string() }, imageUrl: (values["imageUrl"] ?? .undefined).string(), hasImage: (values["hasImage"] ?? .undefined).bool(), identifier: (values["identifier"] ?? .undefined).string(), userId: (values["userId"] ?? .undefined).optional { value in try value.string() }, username: (values["username"] ?? .undefined).optional { value in try value.string() }, banned: (values["banned"] ?? .undefined).optional { value in try value.bool() }, deprovisioned: (values["deprovisioned"] ?? .undefined).optional { value in try value.bool() })
  }
}

public struct UpdateOrganizationMembershipParams: Sendable {
  public let role: String
  public init(role: String) {
    self.role = role
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "role": .string(role),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> UpdateOrganizationMembershipParams {
    let values = try value.object()

    return try UpdateOrganizationMembershipParams(role: (values["role"] ?? .undefined).string())
  }
}

public struct ClerkResourceReloadParams: Sendable {
  public let rotatingTokenNonce: String?
  public init(rotatingTokenNonce: String? = nil) {
    self.rotatingTokenNonce = rotatingTokenNonce
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "rotatingTokenNonce": rotatingTokenNonce.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> ClerkResourceReloadParams {
    let values = try value.object()

    return try ClerkResourceReloadParams(rotatingTokenNonce: (values["rotatingTokenNonce"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct GetInvitationsParams: Sendable {
  public let initialPage: Double?
  public let pageSize: Double?
  public let status: [OrganizationInvitationStatus]?
  public init(initialPage: Double? = nil, pageSize: Double? = nil, status: [OrganizationInvitationStatus]? = nil) {
    self.initialPage = initialPage
    self.pageSize = pageSize
    self.status = status
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "initialPage": initialPage.map { value in .number(value) } ?? .undefined,
      "pageSize": pageSize.map { value in .number(value) } ?? .undefined,
      "status": status.map { value in try .array(value.map { value in try value.encode() }) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> GetInvitationsParams {
    let values = try value.object()

    return try GetInvitationsParams(initialPage: (values["initialPage"] ?? .undefined).optional { value in try value.number() }, pageSize: (values["pageSize"] ?? .undefined).optional { value in try value.number() }, status: (values["status"] ?? .undefined).optional { value in try value.array().map { value in try OrganizationInvitationStatus.decode(value, in: runtime) } })
  }
}

public enum OrganizationInvitationStatus: Hashable, Sendable {
  case pending
  case accepted
  case revoked
  case expired
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .pending: "pending"
    case .accepted: "accepted"
    case .revoked: "revoked"
    case .expired: "expired"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "pending": self = .pending
    case "accepted": self = .accepted
    case "revoked": self = .revoked
    case "expired": self = .expired
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationInvitationStatus {
    try .init(rawValue: value.string())
  }
}

/// An interface that describes the response of a method that returns a paginated list of resources.
///
/// > [!TIP]
/// > Clerk's SDKs always use `Promise<ClerkPaginatedResponse<T>>`. If the promise resolves, you will get back the properties. If the promise is rejected, you will receive a `ClerkAPIResponseError` or network error.
public struct ClerkPaginatedResponseOrganizationInvitation: Sendable {
  public let data: [OrganizationInvitation]
  public let totalCount: Double
  public init(data: [OrganizationInvitation], totalCount: Double) {
    self.data = data
    self.totalCount = totalCount
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "data": .array(data.map { value in try value.encode() }),
      "total_count": .number(totalCount),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ClerkPaginatedResponseOrganizationInvitation {
    let values = try value.object()

    return try ClerkPaginatedResponseOrganizationInvitation(data: (values["data"] ?? .undefined).array().map { value in try OrganizationInvitation.decode(value, in: runtime) }, totalCount: (values["total_count"] ?? .undefined).number())
  }
}

/// The `OrganizationInvitation` object is the model around [an invitation to join an Organization](https://clerk.com/docs/guides/organizations/add-members/invitations).
public struct OrganizationInvitationState: Sendable {
  public let id: String
  public let emailAddress: String
  public let organizationId: String
  public let publicMetadata: [String: JSONValue]
  public let role: String
  public let roleName: String
  public let status: OrganizationInvitationStatus
  public let createdAt: Date
  public let updatedAt: Date
  public init(id: String, emailAddress: String, organizationId: String, publicMetadata: [String: JSONValue], role: String, roleName: String, status: OrganizationInvitationStatus, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.emailAddress = emailAddress
    self.organizationId = organizationId
    self.publicMetadata = publicMetadata
    self.role = role
    self.roleName = roleName
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "emailAddress": .string(emailAddress),
      "organizationId": .string(organizationId),
      "publicMetadata": .object(publicMetadata),
      "role": .string(role),
      "roleName": .string(roleName),
      "status": status.encode(),
      "createdAt": .string(createdAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "updatedAt": .string(updatedAt.ISO8601Format(.init(includingFractionalSeconds: true))),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationInvitationState {
    let values = try value.object()

    return try OrganizationInvitationState(id: (values["id"] ?? .undefined).string(), emailAddress: (values["emailAddress"] ?? .undefined).string(), organizationId: (values["organizationId"] ?? .undefined).string(), publicMetadata: (values["publicMetadata"] ?? .undefined).object(), role: (values["role"] ?? .undefined).string(), roleName: (values["roleName"] ?? .undefined).string(), status: OrganizationInvitationStatus.decode(values["status"] ?? .undefined, in: runtime), createdAt: (values["createdAt"] ?? .undefined).date(), updatedAt: (values["updatedAt"] ?? .undefined).date())
  }
}

@MainActor @Observable public final class OrganizationInvitation: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: OrganizationInvitationState {
    context.state(handle, as: OrganizationInvitationState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var emailAddress: String {
    state.emailAddress
  }

  public var organizationId: String {
    state.organizationId
  }

  public var publicMetadata: [String: JSONValue] {
    state.publicMetadata
  }

  public var role: String {
    state.role
  }

  public var roleName: String {
    state.roleName
  }

  public var status: OrganizationInvitationStatus {
    state.status
  }

  public var createdAt: Date {
    state.createdAt
  }

  public var updatedAt: Date {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try OrganizationInvitationState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationInvitation {
    try runtime.resource(ResourceHandle.decodeReference(value), as: OrganizationInvitation.self)
  }

  /// Revokes the invitation so it can no longer be accepted.
  public func revoke() async throws -> OrganizationInvitation {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationInvitation.revoke", arguments: [])
    return try OrganizationInvitation.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> OrganizationInvitation {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationInvitation.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try OrganizationInvitation.decode(result, in: runtime)
  }
}

public struct GetRolesParams: Sendable {
  public let initialPage: Double?
  public let pageSize: Double?
  public init(initialPage: Double? = nil, pageSize: Double? = nil) {
    self.initialPage = initialPage
    self.pageSize = pageSize
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "initialPage": initialPage.map { value in .number(value) } ?? .undefined,
      "pageSize": pageSize.map { value in .number(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> GetRolesParams {
    let values = try value.object()

    return try GetRolesParams(initialPage: (values["initialPage"] ?? .undefined).optional { value in try value.number() }, pageSize: (values["pageSize"] ?? .undefined).optional { value in try value.number() })
  }
}

public struct GetRolesResponse: Sendable {
  public let hasRoleSetMigration: Bool?
  public let data: [Role]
  public let totalCount: Double
  public init(hasRoleSetMigration: Bool? = nil, data: [Role], totalCount: Double) {
    self.hasRoleSetMigration = hasRoleSetMigration
    self.data = data
    self.totalCount = totalCount
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "has_role_set_migration": hasRoleSetMigration.map { value in .bool(value) } ?? .undefined,
      "data": .array(data.map { value in try value.encode() }),
      "total_count": .number(totalCount),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> GetRolesResponse {
    let values = try value.object()

    return try GetRolesResponse(hasRoleSetMigration: (values["has_role_set_migration"] ?? .undefined).optional { value in try value.bool() }, data: (values["data"] ?? .undefined).array().map { value in try Role.decode(value, in: runtime) }, totalCount: (values["total_count"] ?? .undefined).number())
  }
}

public struct RoleState: Sendable {
  public let id: String
  public let key: String
  public let name: String
  public let description: String
  public let permissions: [Permission]
  public let createdAt: Date
  public let updatedAt: Date
  public init(id: String, key: String, name: String, description: String, permissions: [Permission], createdAt: Date, updatedAt: Date) {
    self.id = id
    self.key = key
    self.name = name
    self.description = description
    self.permissions = permissions
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "key": .string(key),
      "name": .string(name),
      "description": .string(description),
      "permissions": .array(permissions.map { value in try value.encode() }),
      "createdAt": .string(createdAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "updatedAt": .string(updatedAt.ISO8601Format(.init(includingFractionalSeconds: true))),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> RoleState {
    let values = try value.object()

    return try RoleState(id: (values["id"] ?? .undefined).string(), key: (values["key"] ?? .undefined).string(), name: (values["name"] ?? .undefined).string(), description: (values["description"] ?? .undefined).string(), permissions: (values["permissions"] ?? .undefined).array().map { value in try Permission.decode(value, in: runtime) }, createdAt: (values["createdAt"] ?? .undefined).date(), updatedAt: (values["updatedAt"] ?? .undefined).date())
  }
}

@MainActor @Observable public final class Role: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: RoleState {
    context.state(handle, as: RoleState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var key: String {
    state.key
  }

  public var name: String {
    state.name
  }

  public var description: String {
    state.description
  }

  public var permissions: [Permission] {
    state.permissions
  }

  public var createdAt: Date {
    state.createdAt
  }

  public var updatedAt: Date {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try RoleState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> Role {
    try runtime.resource(ResourceHandle.decodeReference(value), as: Role.self)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> Role {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Role.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try Role.decode(result, in: runtime)
  }
}

public struct PermissionState: Sendable {
  public let id: String
  public let key: String
  public let name: String
  public let type: PermissionType
  public let description: String
  public let createdAt: Date
  public let updatedAt: Date
  public init(id: String, key: String, name: String, type: PermissionType, description: String, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.key = key
    self.name = name
    self.type = type
    self.description = description
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "key": .string(key),
      "name": .string(name),
      "type": type.encode(),
      "description": .string(description),
      "createdAt": .string(createdAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "updatedAt": .string(updatedAt.ISO8601Format(.init(includingFractionalSeconds: true))),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PermissionState {
    let values = try value.object()

    return try PermissionState(id: (values["id"] ?? .undefined).string(), key: (values["key"] ?? .undefined).string(), name: (values["name"] ?? .undefined).string(), type: PermissionType.decode(values["type"] ?? .undefined, in: runtime), description: (values["description"] ?? .undefined).string(), createdAt: (values["createdAt"] ?? .undefined).date(), updatedAt: (values["updatedAt"] ?? .undefined).date())
  }
}

@MainActor @Observable public final class Permission: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: PermissionState {
    context.state(handle, as: PermissionState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var key: String {
    state.key
  }

  public var name: String {
    state.name
  }

  public var type: PermissionType {
    state.type
  }

  public var description: String {
    state.description
  }

  public var createdAt: Date {
    state.createdAt
  }

  public var updatedAt: Date {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try PermissionState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> Permission {
    try runtime.resource(ResourceHandle.decodeReference(value), as: Permission.self)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> Permission {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Permission.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try Permission.decode(result, in: runtime)
  }
}

public enum PermissionType: Hashable, Sendable {
  case system
  case user
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .system: "system"
    case .user: "user"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "system": self = .system
    case "user": self = .user
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> PermissionType {
    try .init(rawValue: value.string())
  }
}

public struct GetDomainsParams: Sendable {
  public let initialPage: Double?
  public let pageSize: Double?
  public let enrollmentMode: OrganizationEnrollmentMode?
  public init(initialPage: Double? = nil, pageSize: Double? = nil, enrollmentMode: OrganizationEnrollmentMode? = nil) {
    self.initialPage = initialPage
    self.pageSize = pageSize
    self.enrollmentMode = enrollmentMode
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "initialPage": initialPage.map { value in .number(value) } ?? .undefined,
      "pageSize": pageSize.map { value in .number(value) } ?? .undefined,
      "enrollmentMode": enrollmentMode.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> GetDomainsParams {
    let values = try value.object()

    return try GetDomainsParams(initialPage: (values["initialPage"] ?? .undefined).optional { value in try value.number() }, pageSize: (values["pageSize"] ?? .undefined).optional { value in try value.number() }, enrollmentMode: (values["enrollmentMode"] ?? .undefined).optional { value in try OrganizationEnrollmentMode.decode(value, in: runtime) })
  }
}

public enum OrganizationEnrollmentMode: Hashable, Sendable {
  case manualInvitation
  case automaticInvitation
  case automaticSuggestion
  case enterpriseSso
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .manualInvitation: "manual_invitation"
    case .automaticInvitation: "automatic_invitation"
    case .automaticSuggestion: "automatic_suggestion"
    case .enterpriseSso: "enterprise_sso"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "manual_invitation": self = .manualInvitation
    case "automatic_invitation": self = .automaticInvitation
    case "automatic_suggestion": self = .automaticSuggestion
    case "enterprise_sso": self = .enterpriseSso
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationEnrollmentMode {
    try .init(rawValue: value.string())
  }
}

/// An interface that describes the response of a method that returns a paginated list of resources.
///
/// > [!TIP]
/// > Clerk's SDKs always use `Promise<ClerkPaginatedResponse<T>>`. If the promise resolves, you will get back the properties. If the promise is rejected, you will receive a `ClerkAPIResponseError` or network error.
public struct ClerkPaginatedResponseOrganizationDomain: Sendable {
  public let data: [OrganizationDomain]
  public let totalCount: Double
  public init(data: [OrganizationDomain], totalCount: Double) {
    self.data = data
    self.totalCount = totalCount
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "data": .array(data.map { value in try value.encode() }),
      "total_count": .number(totalCount),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ClerkPaginatedResponseOrganizationDomain {
    let values = try value.object()

    return try ClerkPaginatedResponseOrganizationDomain(data: (values["data"] ?? .undefined).array().map { value in try OrganizationDomain.decode(value, in: runtime) }, totalCount: (values["total_count"] ?? .undefined).number())
  }
}

/// The `OrganizationDomain` object is the model around an Organization's [Verified Domain](https://clerk.com/docs/guides/organizations/add-members/verified-domains).
public struct OrganizationDomainState: Sendable {
  public let id: String
  public let name: String
  public let organizationId: String
  public let enrollmentMode: OrganizationEnrollmentMode
  public let verification: OrganizationDomainVerification?
  public let affiliationVerification: OrganizationDomainVerification?
  public let ownershipVerification: OrganizationDomainOwnershipVerification?
  public let createdAt: Date
  public let updatedAt: Date
  public let affiliationEmailAddress: String?
  public let totalPendingInvitations: Double
  public let totalPendingSuggestions: Double
  public init(id: String, name: String, organizationId: String, enrollmentMode: OrganizationEnrollmentMode, verification: OrganizationDomainVerification?, affiliationVerification: OrganizationDomainVerification?, ownershipVerification: OrganizationDomainOwnershipVerification?, createdAt: Date, updatedAt: Date, affiliationEmailAddress: String?, totalPendingInvitations: Double, totalPendingSuggestions: Double) {
    self.id = id
    self.name = name
    self.organizationId = organizationId
    self.enrollmentMode = enrollmentMode
    self.verification = verification
    self.affiliationVerification = affiliationVerification
    self.ownershipVerification = ownershipVerification
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.affiliationEmailAddress = affiliationEmailAddress
    self.totalPendingInvitations = totalPendingInvitations
    self.totalPendingSuggestions = totalPendingSuggestions
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "name": .string(name),
      "organizationId": .string(organizationId),
      "enrollmentMode": enrollmentMode.encode(),
      "verification": verification.map { value in try value.encode() } ?? .null,
      "affiliationVerification": affiliationVerification.map { value in try value.encode() } ?? .null,
      "ownershipVerification": ownershipVerification.map { value in try value.encode() } ?? .null,
      "createdAt": .string(createdAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "updatedAt": .string(updatedAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "affiliationEmailAddress": affiliationEmailAddress.map { value in .string(value) } ?? .null,
      "totalPendingInvitations": .number(totalPendingInvitations),
      "totalPendingSuggestions": .number(totalPendingSuggestions),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationDomainState {
    let values = try value.object()

    return try OrganizationDomainState(id: (values["id"] ?? .undefined).string(), name: (values["name"] ?? .undefined).string(), organizationId: (values["organizationId"] ?? .undefined).string(), enrollmentMode: OrganizationEnrollmentMode.decode(values["enrollmentMode"] ?? .undefined, in: runtime), verification: (values["verification"] ?? .undefined).optional { value in try OrganizationDomainVerification.decode(value, in: runtime) }, affiliationVerification: (values["affiliationVerification"] ?? .undefined).optional { value in try OrganizationDomainVerification.decode(value, in: runtime) }, ownershipVerification: (values["ownershipVerification"] ?? .undefined).optional { value in try OrganizationDomainOwnershipVerification.decode(value, in: runtime) }, createdAt: (values["createdAt"] ?? .undefined).date(), updatedAt: (values["updatedAt"] ?? .undefined).date(), affiliationEmailAddress: (values["affiliationEmailAddress"] ?? .undefined).optional { value in try value.string() }, totalPendingInvitations: (values["totalPendingInvitations"] ?? .undefined).number(), totalPendingSuggestions: (values["totalPendingSuggestions"] ?? .undefined).number())
  }
}

@MainActor @Observable public final class OrganizationDomain: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: OrganizationDomainState {
    context.state(handle, as: OrganizationDomainState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var name: String {
    state.name
  }

  public var organizationId: String {
    state.organizationId
  }

  public var enrollmentMode: OrganizationEnrollmentMode {
    state.enrollmentMode
  }

  public var verification: OrganizationDomainVerification? {
    state.verification
  }

  public var affiliationVerification: OrganizationDomainVerification? {
    state.affiliationVerification
  }

  public var ownershipVerification: OrganizationDomainOwnershipVerification? {
    state.ownershipVerification
  }

  public var createdAt: Date {
    state.createdAt
  }

  public var updatedAt: Date {
    state.updatedAt
  }

  public var affiliationEmailAddress: String? {
    state.affiliationEmailAddress
  }

  public var totalPendingInvitations: Double {
    state.totalPendingInvitations
  }

  public var totalPendingSuggestions: Double {
    state.totalPendingSuggestions
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try OrganizationDomainState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationDomain {
    try runtime.resource(ResourceHandle.decodeReference(value), as: OrganizationDomain.self)
  }

  /// Begins the verification process of a created Organization domain by sending a verification code to the provided email address.
  public func prepareAffiliationVerification(_ params: PrepareAffiliationVerificationParams) async throws -> OrganizationDomain {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationDomain.prepareAffiliationVerification", arguments: [params.encode()])
    return try OrganizationDomain.decode(result, in: runtime)
  }

  /// Completes the verification process started by [`prepareAffiliationVerification()`](https://clerk.com/docs/reference/types/organization-domain-resource#prepare-affiliation-verification), by validating the provided verification code.
  public func attemptAffiliationVerification(_ params: AttemptAffiliationVerificationParams) async throws -> OrganizationDomain {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationDomain.attemptAffiliationVerification", arguments: [params.encode()])
    return try OrganizationDomain.decode(result, in: runtime)
  }

  /// Deletes the Verified Domain.
  public func delete() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationDomain.delete", arguments: [])
    _ = result
  }

  /// Updates the enrollment mode of the Verified Domain.
  public func updateEnrollmentMode(_ params: UpdateEnrollmentModeParams) async throws -> OrganizationDomain {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationDomain.updateEnrollmentMode", arguments: [params.encode()])
    return try OrganizationDomain.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> OrganizationDomain {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationDomain.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try OrganizationDomain.decode(result, in: runtime)
  }
}

/// The `OrganizationDomainVerification` object holds the affiliation verification details of an Organization's [Verified Domain](/docs/guides/organizations/add-members/verified-domains). Affiliation proves that the current user controls an email address that belongs to the domain.
public struct OrganizationDomainVerification: Sendable {
  public let status: OrganizationDomainVerificationStatus
  public var strategy: String {
    "email_code"
  }

  public let attempts: Double
  public let expiresAt: Date
  public init(status: OrganizationDomainVerificationStatus, attempts: Double, expiresAt: Date) {
    self.status = status
    self.attempts = attempts
    self.expiresAt = expiresAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "status": status.encode(),
      "strategy": .string("email_code"),
      "attempts": .number(attempts),
      "expiresAt": .string(expiresAt.ISO8601Format(.init(includingFractionalSeconds: true))),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationDomainVerification {
    let values = try value.object()
    guard values["strategy"] == .string("email_code") else { throw CoreError.invalidValue }
    return try OrganizationDomainVerification(status: OrganizationDomainVerificationStatus.decode(values["status"] ?? .undefined, in: runtime), attempts: (values["attempts"] ?? .undefined).number(), expiresAt: (values["expiresAt"] ?? .undefined).date())
  }
}

/// The current status of an Organization domain verification.
///
/// <ul>
///  <li>`unverified`: Verification has not been completed yet. An attempt may be pending.</li>
///  <li>`verified`: Verification has been completed.</li>
///  <li>`failed`: Too many verification attempts were made without success.</li>
///  <li>`expired`: The pending verification attempt expired before it could be completed.</li>
/// </ul>
public enum OrganizationDomainVerificationStatus: Hashable, Sendable {
  case expired
  case unverified
  case verified
  case failed
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .expired: "expired"
    case .unverified: "unverified"
    case .verified: "verified"
    case .failed: "failed"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "expired": self = .expired
    case "unverified": self = .unverified
    case "verified": self = .verified
    case "failed": self = .failed
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationDomainVerificationStatus {
    try .init(rawValue: value.string())
  }
}

/// Holds the ownership verification details of an Organization's [Verified Domain](https://clerk.com/docs/guides/organizations/add-members/verified-domains). Ownership proves control of the underlying DNS domain, typically by publishing a TXT record, and is required before the domain can be used for enterprise SSO.
public struct OrganizationDomainOwnershipVerification: Sendable {
  public let status: OrganizationDomainOwnershipVerificationStatus
  public let strategy: OrganizationDomainOwnershipVerificationStrategy
  public let attempts: Double?
  public let expiresAt: Date?
  public let verifiedAt: Date?
  public let txtRecordName: String?
  public let txtRecordValue: String?
  public init(status: OrganizationDomainOwnershipVerificationStatus, strategy: OrganizationDomainOwnershipVerificationStrategy, attempts: Double?, expiresAt: Date?, verifiedAt: Date?, txtRecordName: String?, txtRecordValue: String?) {
    self.status = status
    self.strategy = strategy
    self.attempts = attempts
    self.expiresAt = expiresAt
    self.verifiedAt = verifiedAt
    self.txtRecordName = txtRecordName
    self.txtRecordValue = txtRecordValue
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "status": status.encode(),
      "strategy": strategy.encode(),
      "attempts": attempts.map { value in .number(value) } ?? .null,
      "expiresAt": expiresAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "verifiedAt": verifiedAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "txtRecordName": txtRecordName.map { value in .string(value) } ?? .null,
      "txtRecordValue": txtRecordValue.map { value in .string(value) } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationDomainOwnershipVerification {
    let values = try value.object()

    return try OrganizationDomainOwnershipVerification(status: OrganizationDomainOwnershipVerificationStatus.decode(values["status"] ?? .undefined, in: runtime), strategy: OrganizationDomainOwnershipVerificationStrategy.decode(values["strategy"] ?? .undefined, in: runtime), attempts: (values["attempts"] ?? .undefined).optional { value in try value.number() }, expiresAt: (values["expiresAt"] ?? .undefined).optional { value in try value.date() }, verifiedAt: (values["verifiedAt"] ?? .undefined).optional { value in try value.date() }, txtRecordName: (values["txtRecordName"] ?? .undefined).optional { value in try value.string() }, txtRecordValue: (values["txtRecordValue"] ?? .undefined).optional { value in try value.string() })
  }
}

/// The current status of an Organization domain ownership verification.
///
/// <ul>
///  <li>`unverified`: Ownership has not been established yet. A TXT challenge is pending.</li>
///  <li>`verified`: Ownership has been verified.</li>
///  <li>`expired`: The pending ownership verification attempt expired before ownership could be confirmed. A new TXT challenge must be issued (via `prepareOwnershipVerification()`) to retry.</li>
/// </ul>
public enum OrganizationDomainOwnershipVerificationStatus: Hashable, Sendable {
  case expired
  case unverified
  case verified
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .expired: "expired"
    case .unverified: "unverified"
    case .verified: "verified"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "expired": self = .expired
    case "unverified": self = .unverified
    case "verified": self = .verified
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationDomainOwnershipVerificationStatus {
    try .init(rawValue: value.string())
  }
}

/// The strategy used to verify ownership of an Organization's domain.
public enum OrganizationDomainOwnershipVerificationStrategy: Hashable, Sendable {
  case txt
  case legacy
  case manualOverride
  case parentDomain
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .txt: "txt"
    case .legacy: "legacy"
    case .manualOverride: "manual_override"
    case .parentDomain: "parent_domain"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "txt": self = .txt
    case "legacy": self = .legacy
    case "manual_override": self = .manualOverride
    case "parent_domain": self = .parentDomain
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationDomainOwnershipVerificationStrategy {
    try .init(rawValue: value.string())
  }
}

public struct PrepareAffiliationVerificationParams: Sendable {
  public let affiliationEmailAddress: String
  public init(affiliationEmailAddress: String) {
    self.affiliationEmailAddress = affiliationEmailAddress
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "affiliationEmailAddress": .string(affiliationEmailAddress),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> PrepareAffiliationVerificationParams {
    let values = try value.object()

    return try PrepareAffiliationVerificationParams(affiliationEmailAddress: (values["affiliationEmailAddress"] ?? .undefined).string())
  }
}

public struct AttemptAffiliationVerificationParams: Sendable {
  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> AttemptAffiliationVerificationParams {
    let values = try value.object()

    return try AttemptAffiliationVerificationParams(code: (values["code"] ?? .undefined).string())
  }
}

public struct UpdateEnrollmentModeParams: Sendable {
  public let enrollmentMode: OrganizationEnrollmentMode
  public let deletePending: Bool?
  public init(enrollmentMode: OrganizationEnrollmentMode, deletePending: Bool? = nil) {
    self.enrollmentMode = enrollmentMode
    self.deletePending = deletePending
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "enrollmentMode": enrollmentMode.encode(),
      "deletePending": deletePending.map { value in .bool(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> UpdateEnrollmentModeParams {
    let values = try value.object()

    return try UpdateEnrollmentModeParams(enrollmentMode: OrganizationEnrollmentMode.decode(values["enrollmentMode"] ?? .undefined, in: runtime), deletePending: (values["deletePending"] ?? .undefined).optional { value in try value.bool() })
  }
}

public struct GetMembershipRequestParams: Sendable {
  public let initialPage: Double?
  public let pageSize: Double?
  public let status: OrganizationInvitationStatus?
  public init(initialPage: Double? = nil, pageSize: Double? = nil, status: OrganizationInvitationStatus? = nil) {
    self.initialPage = initialPage
    self.pageSize = pageSize
    self.status = status
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "initialPage": initialPage.map { value in .number(value) } ?? .undefined,
      "pageSize": pageSize.map { value in .number(value) } ?? .undefined,
      "status": status.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> GetMembershipRequestParams {
    let values = try value.object()

    return try GetMembershipRequestParams(initialPage: (values["initialPage"] ?? .undefined).optional { value in try value.number() }, pageSize: (values["pageSize"] ?? .undefined).optional { value in try value.number() }, status: (values["status"] ?? .undefined).optional { value in try OrganizationInvitationStatus.decode(value, in: runtime) })
  }
}

/// An interface that describes the response of a method that returns a paginated list of resources.
///
/// > [!TIP]
/// > Clerk's SDKs always use `Promise<ClerkPaginatedResponse<T>>`. If the promise resolves, you will get back the properties. If the promise is rejected, you will receive a `ClerkAPIResponseError` or network error.
public struct ClerkPaginatedResponseOrganizationMembershipRequest: Sendable {
  public let data: [OrganizationMembershipRequest]
  public let totalCount: Double
  public init(data: [OrganizationMembershipRequest], totalCount: Double) {
    self.data = data
    self.totalCount = totalCount
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "data": .array(data.map { value in try value.encode() }),
      "total_count": .number(totalCount),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ClerkPaginatedResponseOrganizationMembershipRequest {
    let values = try value.object()

    return try ClerkPaginatedResponseOrganizationMembershipRequest(data: (values["data"] ?? .undefined).array().map { value in try OrganizationMembershipRequest.decode(value, in: runtime) }, totalCount: (values["total_count"] ?? .undefined).number())
  }
}

/// The `OrganizationMembershipRequest` object is the model that describes [the request of a user to join an Organization](https://clerk.com/docs/guides/organizations/add-members/verified-domains#membership-requests).
public struct OrganizationMembershipRequestState: Sendable {
  public let id: String
  public let organizationId: String
  public let status: OrganizationInvitationStatus
  public let publicUserData: PublicUserData
  public let createdAt: Date
  public let updatedAt: Date
  public init(id: String, organizationId: String, status: OrganizationInvitationStatus, publicUserData: PublicUserData, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.organizationId = organizationId
    self.status = status
    self.publicUserData = publicUserData
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "organizationId": .string(organizationId),
      "status": status.encode(),
      "publicUserData": publicUserData.encode(),
      "createdAt": .string(createdAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "updatedAt": .string(updatedAt.ISO8601Format(.init(includingFractionalSeconds: true))),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationMembershipRequestState {
    let values = try value.object()

    return try OrganizationMembershipRequestState(id: (values["id"] ?? .undefined).string(), organizationId: (values["organizationId"] ?? .undefined).string(), status: OrganizationInvitationStatus.decode(values["status"] ?? .undefined, in: runtime), publicUserData: PublicUserData.decode(values["publicUserData"] ?? .undefined, in: runtime), createdAt: (values["createdAt"] ?? .undefined).date(), updatedAt: (values["updatedAt"] ?? .undefined).date())
  }
}

@MainActor @Observable public final class OrganizationMembershipRequest: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: OrganizationMembershipRequestState {
    context.state(handle, as: OrganizationMembershipRequestState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var organizationId: String {
    state.organizationId
  }

  public var status: OrganizationInvitationStatus {
    state.status
  }

  public var publicUserData: PublicUserData {
    state.publicUserData
  }

  public var createdAt: Date {
    state.createdAt
  }

  public var updatedAt: Date {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try OrganizationMembershipRequestState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationMembershipRequest {
    try runtime.resource(ResourceHandle.decodeReference(value), as: OrganizationMembershipRequest.self)
  }

  /// Accepts the Membership Request, adding the user to the Organization.
  public func accept() async throws -> OrganizationMembershipRequest {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationMembershipRequest.accept", arguments: [])
    return try OrganizationMembershipRequest.decode(result, in: runtime)
  }

  /// Rejects the Membership Request, declining the user's request to join the Organization.
  public func reject() async throws -> OrganizationMembershipRequest {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationMembershipRequest.reject", arguments: [])
    return try OrganizationMembershipRequest.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> OrganizationMembershipRequest {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationMembershipRequest.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try OrganizationMembershipRequest.decode(result, in: runtime)
  }
}

public struct AddMemberParams: Sendable {
  public let userId: String
  public let role: String
  public init(userId: String, role: String) {
    self.userId = userId
    self.role = role
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "userId": .string(userId),
      "role": .string(role),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> AddMemberParams {
    let values = try value.object()

    return try AddMemberParams(userId: (values["userId"] ?? .undefined).string(), role: (values["role"] ?? .undefined).string())
  }
}

public struct InviteMemberParams: Sendable {
  public let emailAddress: String
  public let role: String
  public init(emailAddress: String, role: String) {
    self.emailAddress = emailAddress
    self.role = role
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "emailAddress": .string(emailAddress),
      "role": .string(role),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> InviteMemberParams {
    let values = try value.object()

    return try InviteMemberParams(emailAddress: (values["emailAddress"] ?? .undefined).string(), role: (values["role"] ?? .undefined).string())
  }
}

public struct InviteMembersParams: Sendable {
  public let emailAddresses: [String]
  public let role: String
  public init(emailAddresses: [String], role: String) {
    self.emailAddresses = emailAddresses
    self.role = role
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "emailAddresses": .array(emailAddresses.map { value in .string(value) }),
      "role": .string(role),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> InviteMembersParams {
    let values = try value.object()

    return try InviteMembersParams(emailAddresses: (values["emailAddresses"] ?? .undefined).array().map { value in try value.string() }, role: (values["role"] ?? .undefined).string())
  }
}

public struct UpdateMembershipParams: Sendable {
  public let userId: String
  public let role: String
  public init(userId: String, role: String) {
    self.userId = userId
    self.role = role
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "userId": .string(userId),
      "role": .string(role),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> UpdateMembershipParams {
    let values = try value.object()

    return try UpdateMembershipParams(userId: (values["userId"] ?? .undefined).string(), role: (values["role"] ?? .undefined).string())
  }
}

/// From T, pick a set of properties whose keys are in the union K
public struct PickCreateOrganizationDomainParamsAndenrollmentMode: Sendable {
  public let enrollmentMode: OrganizationEnrollmentMode?
  public init(enrollmentMode: OrganizationEnrollmentMode? = nil) {
    self.enrollmentMode = enrollmentMode
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "enrollmentMode": enrollmentMode.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PickCreateOrganizationDomainParamsAndenrollmentMode {
    let values = try value.object()

    return try PickCreateOrganizationDomainParamsAndenrollmentMode(enrollmentMode: (values["enrollmentMode"] ?? .undefined).optional { value in try OrganizationEnrollmentMode.decode(value, in: runtime) })
  }
}

/// The `OrganizationDomainsBulkOwnershipVerificationResource` object is the result of a bulk ownership verification flow, such as [`prepareOwnershipVerification()`](https://clerk.com/docs/reference/objects/organization#prepare-ownership-verification) or [`attemptOwnershipVerification()`](https://clerk.com/docs/reference/objects/organization#attempt-ownership-verification), where ownership is verified for several of an Organization's [Verified Domains](https://clerk.com/docs/guides/organizations/add-members/verified-domains) at once. Because the operation can partially succeed, each requested domain is reported in either `data` or `errors`.
public struct OrganizationDomainsBulkOwnershipVerification: Sendable {
  public let data: [OrganizationDomain]
  public let errors: [OrganizationDomainBulkOwnershipVerificationError]
  public init(data: [OrganizationDomain], errors: [OrganizationDomainBulkOwnershipVerificationError]) {
    self.data = data
    self.errors = errors
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "data": .array(data.map { value in try value.encode() }),
      "errors": .array(errors.map { value in try value.encode() }),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationDomainsBulkOwnershipVerification {
    let values = try value.object()

    return try OrganizationDomainsBulkOwnershipVerification(data: (values["data"] ?? .undefined).array().map { value in try OrganizationDomain.decode(value, in: runtime) }, errors: (values["errors"] ?? .undefined).array().map { value in try OrganizationDomainBulkOwnershipVerificationError.decode(value, in: runtime) })
  }
}

public struct OrganizationDomainBulkOwnershipVerificationError: Sendable {
  public let id: String
  public let code: String
  public init(id: String, code: String) {
    self.id = id
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "id": .string(id),
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationDomainBulkOwnershipVerificationError {
    let values = try value.object()

    return try OrganizationDomainBulkOwnershipVerificationError(id: (values["id"] ?? .undefined).string(), code: (values["code"] ?? .undefined).string())
  }
}

public struct OrganizationGetDomain__0: Sendable {
  public let domainId: String
  public init(domainId: String) {
    self.domainId = domainId
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "domainId": .string(domainId),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationGetDomain__0 {
    let values = try value.object()

    return try OrganizationGetDomain__0(domainId: (values["domainId"] ?? .undefined).string())
  }
}

public struct GetEnterpriseConnectionsParams: Sendable {
  public let withOrganizationAccountLinking: Bool?
  public init(withOrganizationAccountLinking: Bool? = nil) {
    self.withOrganizationAccountLinking = withOrganizationAccountLinking
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "withOrganizationAccountLinking": withOrganizationAccountLinking.map { value in .bool(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> GetEnterpriseConnectionsParams {
    let values = try value.object()

    return try GetEnterpriseConnectionsParams(withOrganizationAccountLinking: (values["withOrganizationAccountLinking"] ?? .undefined).optional { value in try value.bool() })
  }
}

public struct EnterpriseConnectionState: Sendable {
  public let id: String
  public let name: String
  public let active: Bool
  public let provider: String
  public let logoPublicUrl: String?
  public let domains: [String]
  public let organizationId: String?
  public let syncUserAttributes: Bool
  public let disableAdditionalIdentifications: Bool
  public let allowOrganizationAccountLinking: Bool
  public let customAttributes: [JSONValue]
  public let oauthConfig: EnterpriseOAuthConfig?
  public let samlConnection: EnterpriseSamlConnectionNested?
  public let createdAt: Date?
  public let updatedAt: Date?
  public init(id: String, name: String, active: Bool, provider: String, logoPublicUrl: String?, domains: [String], organizationId: String?, syncUserAttributes: Bool, disableAdditionalIdentifications: Bool, allowOrganizationAccountLinking: Bool, customAttributes: [JSONValue], oauthConfig: EnterpriseOAuthConfig?, samlConnection: EnterpriseSamlConnectionNested?, createdAt: Date?, updatedAt: Date?) {
    self.id = id
    self.name = name
    self.active = active
    self.provider = provider
    self.logoPublicUrl = logoPublicUrl
    self.domains = domains
    self.organizationId = organizationId
    self.syncUserAttributes = syncUserAttributes
    self.disableAdditionalIdentifications = disableAdditionalIdentifications
    self.allowOrganizationAccountLinking = allowOrganizationAccountLinking
    self.customAttributes = customAttributes
    self.oauthConfig = oauthConfig
    self.samlConnection = samlConnection
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "name": .string(name),
      "active": .bool(active),
      "provider": .string(provider),
      "logoPublicUrl": logoPublicUrl.map { value in .string(value) } ?? .null,
      "domains": .array(domains.map { value in .string(value) }),
      "organizationId": organizationId.map { value in .string(value) } ?? .null,
      "syncUserAttributes": .bool(syncUserAttributes),
      "disableAdditionalIdentifications": .bool(disableAdditionalIdentifications),
      "allowOrganizationAccountLinking": .bool(allowOrganizationAccountLinking),
      "customAttributes": .array(customAttributes.map { value in value }),
      "oauthConfig": oauthConfig.map { value in try value.encode() } ?? .null,
      "samlConnection": samlConnection.map { value in try value.encode() } ?? .null,
      "createdAt": createdAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "updatedAt": updatedAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> EnterpriseConnectionState {
    let values = try value.object()

    return try EnterpriseConnectionState(id: (values["id"] ?? .undefined).string(), name: (values["name"] ?? .undefined).string(), active: (values["active"] ?? .undefined).bool(), provider: (values["provider"] ?? .undefined).string(), logoPublicUrl: (values["logoPublicUrl"] ?? .undefined).optional { value in try value.string() }, domains: (values["domains"] ?? .undefined).array().map { value in try value.string() }, organizationId: (values["organizationId"] ?? .undefined).optional { value in try value.string() }, syncUserAttributes: (values["syncUserAttributes"] ?? .undefined).bool(), disableAdditionalIdentifications: (values["disableAdditionalIdentifications"] ?? .undefined).bool(), allowOrganizationAccountLinking: (values["allowOrganizationAccountLinking"] ?? .undefined).bool(), customAttributes: (values["customAttributes"] ?? .undefined).array().map { value in value }, oauthConfig: (values["oauthConfig"] ?? .undefined).optional { value in try EnterpriseOAuthConfig.decode(value, in: runtime) }, samlConnection: (values["samlConnection"] ?? .undefined).optional { value in try EnterpriseSamlConnectionNested.decode(value, in: runtime) }, createdAt: (values["createdAt"] ?? .undefined).optional { value in try value.date() }, updatedAt: (values["updatedAt"] ?? .undefined).optional { value in try value.date() })
  }
}

@MainActor @Observable public final class EnterpriseConnection: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: EnterpriseConnectionState {
    context.state(handle, as: EnterpriseConnectionState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var name: String {
    state.name
  }

  public var active: Bool {
    state.active
  }

  public var provider: String {
    state.provider
  }

  public var logoPublicUrl: String? {
    state.logoPublicUrl
  }

  public var domains: [String] {
    state.domains
  }

  public var organizationId: String? {
    state.organizationId
  }

  public var syncUserAttributes: Bool {
    state.syncUserAttributes
  }

  public var disableAdditionalIdentifications: Bool {
    state.disableAdditionalIdentifications
  }

  public var allowOrganizationAccountLinking: Bool {
    state.allowOrganizationAccountLinking
  }

  public var customAttributes: [JSONValue] {
    state.customAttributes
  }

  public var oauthConfig: EnterpriseOAuthConfig? {
    state.oauthConfig
  }

  public var samlConnection: EnterpriseSamlConnectionNested? {
    state.samlConnection
  }

  public var createdAt: Date? {
    state.createdAt
  }

  public var updatedAt: Date? {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try EnterpriseConnectionState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> EnterpriseConnection {
    try runtime.resource(ResourceHandle.decodeReference(value), as: EnterpriseConnection.self)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> EnterpriseConnection {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "EnterpriseConnection.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try EnterpriseConnection.decode(result, in: runtime)
  }
}

public struct EnterpriseOAuthConfig: Sendable {
  public let id: String
  public let name: String
  public let clientId: String
  public let providerKey: String?
  public let redirectUri: String?
  public let discoveryUrl: String?
  public let authUrl: String?
  public let tokenUrl: String?
  public let userInfoUrl: String?
  public let logoPublicUrl: Field<String>
  public let requiresPkce: Bool?
  public let createdAt: Date?
  public let updatedAt: Date?
  public init(id: String, name: String, clientId: String, providerKey: String? = nil, redirectUri: String? = nil, discoveryUrl: String? = nil, authUrl: String? = nil, tokenUrl: String? = nil, userInfoUrl: String? = nil, logoPublicUrl: Field<String> = .omitted, requiresPkce: Bool? = nil, createdAt: Date?, updatedAt: Date?) {
    self.id = id
    self.name = name
    self.clientId = clientId
    self.providerKey = providerKey
    self.redirectUri = redirectUri
    self.discoveryUrl = discoveryUrl
    self.authUrl = authUrl
    self.tokenUrl = tokenUrl
    self.userInfoUrl = userInfoUrl
    self.logoPublicUrl = logoPublicUrl
    self.requiresPkce = requiresPkce
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "name": .string(name),
      "clientId": .string(clientId),
      "providerKey": providerKey.map { value in .string(value) } ?? .undefined,
      "redirectUri": redirectUri.map { value in .string(value) } ?? .undefined,
      "discoveryUrl": discoveryUrl.map { value in .string(value) } ?? .undefined,
      "authUrl": authUrl.map { value in .string(value) } ?? .undefined,
      "tokenUrl": tokenUrl.map { value in .string(value) } ?? .undefined,
      "userInfoUrl": userInfoUrl.map { value in .string(value) } ?? .undefined,
      "logoPublicUrl": logoPublicUrl.encode { value in .string(value) },
      "requiresPkce": requiresPkce.map { value in .bool(value) } ?? .undefined,
      "createdAt": createdAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "updatedAt": updatedAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EnterpriseOAuthConfig {
    let values = try value.object()

    return try EnterpriseOAuthConfig(id: (values["id"] ?? .undefined).string(), name: (values["name"] ?? .undefined).string(), clientId: (values["clientId"] ?? .undefined).string(), providerKey: (values["providerKey"] ?? .undefined).optional { value in try value.string() }, redirectUri: (values["redirectUri"] ?? .undefined).optional { value in try value.string() }, discoveryUrl: (values["discoveryUrl"] ?? .undefined).optional { value in try value.string() }, authUrl: (values["authUrl"] ?? .undefined).optional { value in try value.string() }, tokenUrl: (values["tokenUrl"] ?? .undefined).optional { value in try value.string() }, userInfoUrl: (values["userInfoUrl"] ?? .undefined).optional { value in try value.string() }, logoPublicUrl: Field.decode(values["logoPublicUrl"] ?? .undefined) { value in try value.string() }, requiresPkce: (values["requiresPkce"] ?? .undefined).optional { value in try value.bool() }, createdAt: (values["createdAt"] ?? .undefined).optional { value in try value.date() }, updatedAt: (values["updatedAt"] ?? .undefined).optional { value in try value.date() })
  }
}

public struct EnterpriseSamlConnectionNested: Sendable {
  public let id: String
  public let name: String
  public let active: Bool
  public let idpEntityId: String
  public let idpSsoUrl: String
  public let idpCertificate: String
  public let idpCertificateIssuedAt: Double
  public let idpCertificateExpiresAt: Double
  public let idpMetadataUrl: String
  public let idpMetadata: String
  public let acsUrl: String
  public let spEntityId: String
  public let spMetadataUrl: String
  public let allowSubdomains: Bool
  public let allowIdpInitiated: Bool
  public let forceAuthn: Bool
  public init(id: String, name: String, active: Bool, idpEntityId: String, idpSsoUrl: String, idpCertificate: String, idpCertificateIssuedAt: Double, idpCertificateExpiresAt: Double, idpMetadataUrl: String, idpMetadata: String, acsUrl: String, spEntityId: String, spMetadataUrl: String, allowSubdomains: Bool, allowIdpInitiated: Bool, forceAuthn: Bool) {
    self.id = id
    self.name = name
    self.active = active
    self.idpEntityId = idpEntityId
    self.idpSsoUrl = idpSsoUrl
    self.idpCertificate = idpCertificate
    self.idpCertificateIssuedAt = idpCertificateIssuedAt
    self.idpCertificateExpiresAt = idpCertificateExpiresAt
    self.idpMetadataUrl = idpMetadataUrl
    self.idpMetadata = idpMetadata
    self.acsUrl = acsUrl
    self.spEntityId = spEntityId
    self.spMetadataUrl = spMetadataUrl
    self.allowSubdomains = allowSubdomains
    self.allowIdpInitiated = allowIdpInitiated
    self.forceAuthn = forceAuthn
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "id": .string(id),
      "name": .string(name),
      "active": .bool(active),
      "idpEntityId": .string(idpEntityId),
      "idpSsoUrl": .string(idpSsoUrl),
      "idpCertificate": .string(idpCertificate),
      "idpCertificateIssuedAt": .number(idpCertificateIssuedAt),
      "idpCertificateExpiresAt": .number(idpCertificateExpiresAt),
      "idpMetadataUrl": .string(idpMetadataUrl),
      "idpMetadata": .string(idpMetadata),
      "acsUrl": .string(acsUrl),
      "spEntityId": .string(spEntityId),
      "spMetadataUrl": .string(spMetadataUrl),
      "allowSubdomains": .bool(allowSubdomains),
      "allowIdpInitiated": .bool(allowIdpInitiated),
      "forceAuthn": .bool(forceAuthn),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EnterpriseSamlConnectionNested {
    let values = try value.object()

    return try EnterpriseSamlConnectionNested(id: (values["id"] ?? .undefined).string(), name: (values["name"] ?? .undefined).string(), active: (values["active"] ?? .undefined).bool(), idpEntityId: (values["idpEntityId"] ?? .undefined).string(), idpSsoUrl: (values["idpSsoUrl"] ?? .undefined).string(), idpCertificate: (values["idpCertificate"] ?? .undefined).string(), idpCertificateIssuedAt: (values["idpCertificateIssuedAt"] ?? .undefined).number(), idpCertificateExpiresAt: (values["idpCertificateExpiresAt"] ?? .undefined).number(), idpMetadataUrl: (values["idpMetadataUrl"] ?? .undefined).string(), idpMetadata: (values["idpMetadata"] ?? .undefined).string(), acsUrl: (values["acsUrl"] ?? .undefined).string(), spEntityId: (values["spEntityId"] ?? .undefined).string(), spMetadataUrl: (values["spMetadataUrl"] ?? .undefined).string(), allowSubdomains: (values["allowSubdomains"] ?? .undefined).bool(), allowIdpInitiated: (values["allowIdpInitiated"] ?? .undefined).bool(), forceAuthn: (values["forceAuthn"] ?? .undefined).bool())
  }
}

public struct CreateOrganizationEnterpriseConnectionParams: Sendable {
  public let provider: OrganizationEnterpriseConnectionProvider
  public let name: String?
  public let domains: [String]?
  public let organizationId: Field<String>
  public let saml: Field<OrganizationEnterpriseConnectionSamlInput>
  public let oidc: Field<OrganizationEnterpriseConnectionOidcInput>
  public init(provider: OrganizationEnterpriseConnectionProvider, name: String? = nil, domains: [String]? = nil, organizationId: Field<String> = .omitted, saml: Field<OrganizationEnterpriseConnectionSamlInput> = .omitted, oidc: Field<OrganizationEnterpriseConnectionOidcInput> = .omitted) {
    self.provider = provider
    self.name = name
    self.domains = domains
    self.organizationId = organizationId
    self.saml = saml
    self.oidc = oidc
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "provider": provider.encode(),
      "name": name.map { value in .string(value) } ?? .undefined,
      "domains": domains.map { value in try .array(value.map { value in .string(value) }) } ?? .undefined,
      "organizationId": organizationId.encode { value in .string(value) },
      "saml": saml.encode { value in try value.encode() },
      "oidc": oidc.encode { value in try value.encode() },
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> CreateOrganizationEnterpriseConnectionParams {
    let values = try value.object()

    return try CreateOrganizationEnterpriseConnectionParams(provider: OrganizationEnterpriseConnectionProvider.decode(values["provider"] ?? .undefined, in: runtime), name: (values["name"] ?? .undefined).optional { value in try value.string() }, domains: (values["domains"] ?? .undefined).optional { value in try value.array().map { value in try value.string() } }, organizationId: Field.decode(values["organizationId"] ?? .undefined) { value in try value.string() }, saml: Field.decode(values["saml"] ?? .undefined) { value in try OrganizationEnterpriseConnectionSamlInput.decode(value, in: runtime) }, oidc: Field.decode(values["oidc"] ?? .undefined) { value in try OrganizationEnterpriseConnectionOidcInput.decode(value, in: runtime) })
  }
}

public enum OrganizationEnterpriseConnectionProvider: Hashable, Sendable {
  case samlCustom
  case samlOkta
  case samlGoogle
  case samlMicrosoft
  case oidcCustom
  case oidcGithubEnterprise
  case oidcGitlab
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .samlCustom: "saml_custom"
    case .samlOkta: "saml_okta"
    case .samlGoogle: "saml_google"
    case .samlMicrosoft: "saml_microsoft"
    case .oidcCustom: "oidc_custom"
    case .oidcGithubEnterprise: "oidc_github_enterprise"
    case .oidcGitlab: "oidc_gitlab"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "saml_custom": self = .samlCustom
    case "saml_okta": self = .samlOkta
    case "saml_google": self = .samlGoogle
    case "saml_microsoft": self = .samlMicrosoft
    case "oidc_custom": self = .oidcCustom
    case "oidc_github_enterprise": self = .oidcGithubEnterprise
    case "oidc_gitlab": self = .oidcGitlab
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationEnterpriseConnectionProvider {
    try .init(rawValue: value.string())
  }
}

public struct OrganizationEnterpriseConnectionSamlInput: Sendable {
  public let idpEntityId: Field<String>
  public let idpSsoUrl: Field<String>
  public let idpCertificate: Field<String>
  public let idpMetadataUrl: Field<String>
  public let idpMetadata: Field<String>
  public let attributeMapping: Field<[String: JSONValue]>
  public let allowSubdomains: Field<Bool>
  public let allowIdpInitiated: Field<Bool>
  public let forceAuthn: Field<Bool>
  public init(idpEntityId: Field<String> = .omitted, idpSsoUrl: Field<String> = .omitted, idpCertificate: Field<String> = .omitted, idpMetadataUrl: Field<String> = .omitted, idpMetadata: Field<String> = .omitted, attributeMapping: Field<[String: JSONValue]> = .omitted, allowSubdomains: Field<Bool> = .omitted, allowIdpInitiated: Field<Bool> = .omitted, forceAuthn: Field<Bool> = .omitted) {
    self.idpEntityId = idpEntityId
    self.idpSsoUrl = idpSsoUrl
    self.idpCertificate = idpCertificate
    self.idpMetadataUrl = idpMetadataUrl
    self.idpMetadata = idpMetadata
    self.attributeMapping = attributeMapping
    self.allowSubdomains = allowSubdomains
    self.allowIdpInitiated = allowIdpInitiated
    self.forceAuthn = forceAuthn
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "idpEntityId": idpEntityId.encode { value in .string(value) },
      "idpSsoUrl": idpSsoUrl.encode { value in .string(value) },
      "idpCertificate": idpCertificate.encode { value in .string(value) },
      "idpMetadataUrl": idpMetadataUrl.encode { value in .string(value) },
      "idpMetadata": idpMetadata.encode { value in .string(value) },
      "attributeMapping": attributeMapping.encode { value in try .object(value.mapValues { value in value }) },
      "allowSubdomains": allowSubdomains.encode { value in .bool(value) },
      "allowIdpInitiated": allowIdpInitiated.encode { value in .bool(value) },
      "forceAuthn": forceAuthn.encode { value in .bool(value) },
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationEnterpriseConnectionSamlInput {
    let values = try value.object()

    return try OrganizationEnterpriseConnectionSamlInput(idpEntityId: Field.decode(values["idpEntityId"] ?? .undefined) { value in try value.string() }, idpSsoUrl: Field.decode(values["idpSsoUrl"] ?? .undefined) { value in try value.string() }, idpCertificate: Field.decode(values["idpCertificate"] ?? .undefined) { value in try value.string() }, idpMetadataUrl: Field.decode(values["idpMetadataUrl"] ?? .undefined) { value in try value.string() }, idpMetadata: Field.decode(values["idpMetadata"] ?? .undefined) { value in try value.string() }, attributeMapping: Field.decode(values["attributeMapping"] ?? .undefined) { value in try value.object().mapValues { value in value } }, allowSubdomains: Field.decode(values["allowSubdomains"] ?? .undefined) { value in try value.bool() }, allowIdpInitiated: Field.decode(values["allowIdpInitiated"] ?? .undefined) { value in try value.bool() }, forceAuthn: Field.decode(values["forceAuthn"] ?? .undefined) { value in try value.bool() })
  }
}

public struct OrganizationEnterpriseConnectionOidcInput: Sendable {
  public let clientId: Field<String>
  public let clientSecret: Field<String>
  public let discoveryUrl: Field<String>
  public let authUrl: Field<String>
  public let tokenUrl: Field<String>
  public let userInfoUrl: Field<String>
  public let requiresPkce: Field<Bool>
  public init(clientId: Field<String> = .omitted, clientSecret: Field<String> = .omitted, discoveryUrl: Field<String> = .omitted, authUrl: Field<String> = .omitted, tokenUrl: Field<String> = .omitted, userInfoUrl: Field<String> = .omitted, requiresPkce: Field<Bool> = .omitted) {
    self.clientId = clientId
    self.clientSecret = clientSecret
    self.discoveryUrl = discoveryUrl
    self.authUrl = authUrl
    self.tokenUrl = tokenUrl
    self.userInfoUrl = userInfoUrl
    self.requiresPkce = requiresPkce
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "clientId": clientId.encode { value in .string(value) },
      "clientSecret": clientSecret.encode { value in .string(value) },
      "discoveryUrl": discoveryUrl.encode { value in .string(value) },
      "authUrl": authUrl.encode { value in .string(value) },
      "tokenUrl": tokenUrl.encode { value in .string(value) },
      "userInfoUrl": userInfoUrl.encode { value in .string(value) },
      "requiresPkce": requiresPkce.encode { value in .bool(value) },
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationEnterpriseConnectionOidcInput {
    let values = try value.object()

    return try OrganizationEnterpriseConnectionOidcInput(clientId: Field.decode(values["clientId"] ?? .undefined) { value in try value.string() }, clientSecret: Field.decode(values["clientSecret"] ?? .undefined) { value in try value.string() }, discoveryUrl: Field.decode(values["discoveryUrl"] ?? .undefined) { value in try value.string() }, authUrl: Field.decode(values["authUrl"] ?? .undefined) { value in try value.string() }, tokenUrl: Field.decode(values["tokenUrl"] ?? .undefined) { value in try value.string() }, userInfoUrl: Field.decode(values["userInfoUrl"] ?? .undefined) { value in try value.string() }, requiresPkce: Field.decode(values["requiresPkce"] ?? .undefined) { value in try value.bool() })
  }
}

public struct UpdateOrganizationEnterpriseConnectionParams: Sendable {
  public let name: Field<String>
  public let domains: [String]?
  public let active: Field<Bool>
  public let syncUserAttributes: Field<Bool>
  public let disableAdditionalIdentifications: Field<Bool>
  public let organizationId: Field<String>
  public let customAttributes: Field<[String: JSONValue]>
  public let saml: Field<OrganizationEnterpriseConnectionSamlInput>
  public let oidc: Field<OrganizationEnterpriseConnectionOidcInput>
  public init(name: Field<String> = .omitted, domains: [String]? = nil, active: Field<Bool> = .omitted, syncUserAttributes: Field<Bool> = .omitted, disableAdditionalIdentifications: Field<Bool> = .omitted, organizationId: Field<String> = .omitted, customAttributes: Field<[String: JSONValue]> = .omitted, saml: Field<OrganizationEnterpriseConnectionSamlInput> = .omitted, oidc: Field<OrganizationEnterpriseConnectionOidcInput> = .omitted) {
    self.name = name
    self.domains = domains
    self.active = active
    self.syncUserAttributes = syncUserAttributes
    self.disableAdditionalIdentifications = disableAdditionalIdentifications
    self.organizationId = organizationId
    self.customAttributes = customAttributes
    self.saml = saml
    self.oidc = oidc
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "name": name.encode { value in .string(value) },
      "domains": domains.map { value in try .array(value.map { value in .string(value) }) } ?? .undefined,
      "active": active.encode { value in .bool(value) },
      "syncUserAttributes": syncUserAttributes.encode { value in .bool(value) },
      "disableAdditionalIdentifications": disableAdditionalIdentifications.encode { value in .bool(value) },
      "organizationId": organizationId.encode { value in .string(value) },
      "customAttributes": customAttributes.encode { value in try .object(value.mapValues { value in value }) },
      "saml": saml.encode { value in try value.encode() },
      "oidc": oidc.encode { value in try value.encode() },
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> UpdateOrganizationEnterpriseConnectionParams {
    let values = try value.object()

    return try UpdateOrganizationEnterpriseConnectionParams(name: Field.decode(values["name"] ?? .undefined) { value in try value.string() }, domains: (values["domains"] ?? .undefined).optional { value in try value.array().map { value in try value.string() } }, active: Field.decode(values["active"] ?? .undefined) { value in try value.bool() }, syncUserAttributes: Field.decode(values["syncUserAttributes"] ?? .undefined) { value in try value.bool() }, disableAdditionalIdentifications: Field.decode(values["disableAdditionalIdentifications"] ?? .undefined) { value in try value.bool() }, organizationId: Field.decode(values["organizationId"] ?? .undefined) { value in try value.string() }, customAttributes: Field.decode(values["customAttributes"] ?? .undefined) { value in try value.object().mapValues { value in value } }, saml: Field.decode(values["saml"] ?? .undefined) { value in try OrganizationEnterpriseConnectionSamlInput.decode(value, in: runtime) }, oidc: Field.decode(values["oidc"] ?? .undefined) { value in try OrganizationEnterpriseConnectionOidcInput.decode(value, in: runtime) })
  }
}

/// The `DeletedObjectResource` type represents an item that has been deleted from the database.
public struct DeletedObject: Sendable {
  public let object: String
  public let id: String?
  public let slug: String?
  public let deleted: Bool
  public init(object: String, id: String? = nil, slug: String? = nil, deleted: Bool) {
    self.object = object
    self.id = id
    self.slug = slug
    self.deleted = deleted
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "object": .string(object),
      "id": id.map { value in .string(value) } ?? .undefined,
      "slug": slug.map { value in .string(value) } ?? .undefined,
      "deleted": .bool(deleted),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> DeletedObject {
    let values = try value.object()

    return try DeletedObject(object: (values["object"] ?? .undefined).string(), id: (values["id"] ?? .undefined).optional { value in try value.string() }, slug: (values["slug"] ?? .undefined).optional { value in try value.string() }, deleted: (values["deleted"] ?? .undefined).bool())
  }
}

public struct EnterpriseConnectionTestRunInit: Sendable {
  public let url: String
  public init(url: String) {
    self.url = url
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "url": .string(url),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EnterpriseConnectionTestRunInit {
    let values = try value.object()

    return try EnterpriseConnectionTestRunInit(url: (values["url"] ?? .undefined).string())
  }
}

public struct GetEnterpriseConnectionTestRunsParams: Sendable {
  public let initialPage: Double?
  public let pageSize: Double?
  public let status: [EnterpriseConnectionTestRunStatus]?
  public init(initialPage: Double? = nil, pageSize: Double? = nil, status: [EnterpriseConnectionTestRunStatus]? = nil) {
    self.initialPage = initialPage
    self.pageSize = pageSize
    self.status = status
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "initialPage": initialPage.map { value in .number(value) } ?? .undefined,
      "pageSize": pageSize.map { value in .number(value) } ?? .undefined,
      "status": status.map { value in try .array(value.map { value in try value.encode() }) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> GetEnterpriseConnectionTestRunsParams {
    let values = try value.object()

    return try GetEnterpriseConnectionTestRunsParams(initialPage: (values["initialPage"] ?? .undefined).optional { value in try value.number() }, pageSize: (values["pageSize"] ?? .undefined).optional { value in try value.number() }, status: (values["status"] ?? .undefined).optional { value in try value.array().map { value in try EnterpriseConnectionTestRunStatus.decode(value, in: runtime) } })
  }
}

public enum EnterpriseConnectionTestRunStatus: Hashable, Sendable {
  case pending
  case failed
  case success
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .pending: "pending"
    case .failed: "failed"
    case .success: "success"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "pending": self = .pending
    case "failed": self = .failed
    case "success": self = .success
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EnterpriseConnectionTestRunStatus {
    try .init(rawValue: value.string())
  }
}

/// An interface that describes the response of a method that returns a paginated list of resources.
///
/// > [!TIP]
/// > Clerk's SDKs always use `Promise<ClerkPaginatedResponse<T>>`. If the promise resolves, you will get back the properties. If the promise is rejected, you will receive a `ClerkAPIResponseError` or network error.
public struct ClerkPaginatedResponseEnterpriseConnectionTestRun: Sendable {
  public let data: [EnterpriseConnectionTestRun]
  public let totalCount: Double
  public init(data: [EnterpriseConnectionTestRun], totalCount: Double) {
    self.data = data
    self.totalCount = totalCount
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "data": .array(data.map { value in try value.encode() }),
      "total_count": .number(totalCount),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ClerkPaginatedResponseEnterpriseConnectionTestRun {
    let values = try value.object()

    return try ClerkPaginatedResponseEnterpriseConnectionTestRun(data: (values["data"] ?? .undefined).array().map { value in try EnterpriseConnectionTestRun.decode(value, in: runtime) }, totalCount: (values["total_count"] ?? .undefined).number())
  }
}

public struct EnterpriseConnectionTestRunState: Sendable {
  public let id: String
  public let status: String
  public let connectionType: EnterpriseConnectionTestRunConnectionType
  public let parsedUserInfo: EnterpriseConnectionTestRunParsedUserInfo?
  public let logs: [EnterpriseConnectionTestRunLog]
  public let saml: EnterpriseConnectionTestRunSamlPayload?
  public let oauth: EnterpriseConnectionTestRunOauthPayload?
  public let createdAt: Date?
  public init(id: String, status: String, connectionType: EnterpriseConnectionTestRunConnectionType, parsedUserInfo: EnterpriseConnectionTestRunParsedUserInfo?, logs: [EnterpriseConnectionTestRunLog], saml: EnterpriseConnectionTestRunSamlPayload?, oauth: EnterpriseConnectionTestRunOauthPayload?, createdAt: Date?) {
    self.id = id
    self.status = status
    self.connectionType = connectionType
    self.parsedUserInfo = parsedUserInfo
    self.logs = logs
    self.saml = saml
    self.oauth = oauth
    self.createdAt = createdAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "status": .string(status),
      "connectionType": connectionType.encode(),
      "parsedUserInfo": parsedUserInfo.map { value in try value.encode() } ?? .null,
      "logs": .array(logs.map { value in try value.encode() }),
      "saml": saml.map { value in try value.encode() } ?? .null,
      "oauth": oauth.map { value in try value.encode() } ?? .null,
      "createdAt": createdAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> EnterpriseConnectionTestRunState {
    let values = try value.object()

    return try EnterpriseConnectionTestRunState(id: (values["id"] ?? .undefined).string(), status: (values["status"] ?? .undefined).string(), connectionType: EnterpriseConnectionTestRunConnectionType.decode(values["connectionType"] ?? .undefined, in: runtime), parsedUserInfo: (values["parsedUserInfo"] ?? .undefined).optional { value in try EnterpriseConnectionTestRunParsedUserInfo.decode(value, in: runtime) }, logs: (values["logs"] ?? .undefined).array().map { value in try EnterpriseConnectionTestRunLog.decode(value, in: runtime) }, saml: (values["saml"] ?? .undefined).optional { value in try EnterpriseConnectionTestRunSamlPayload.decode(value, in: runtime) }, oauth: (values["oauth"] ?? .undefined).optional { value in try EnterpriseConnectionTestRunOauthPayload.decode(value, in: runtime) }, createdAt: (values["createdAt"] ?? .undefined).optional { value in try value.date() })
  }
}

@MainActor @Observable public final class EnterpriseConnectionTestRun: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: EnterpriseConnectionTestRunState {
    context.state(handle, as: EnterpriseConnectionTestRunState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var status: String {
    state.status
  }

  public var connectionType: EnterpriseConnectionTestRunConnectionType {
    state.connectionType
  }

  public var parsedUserInfo: EnterpriseConnectionTestRunParsedUserInfo? {
    state.parsedUserInfo
  }

  public var logs: [EnterpriseConnectionTestRunLog] {
    state.logs
  }

  public var saml: EnterpriseConnectionTestRunSamlPayload? {
    state.saml
  }

  public var oauth: EnterpriseConnectionTestRunOauthPayload? {
    state.oauth
  }

  public var createdAt: Date? {
    state.createdAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try EnterpriseConnectionTestRunState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> EnterpriseConnectionTestRun {
    try runtime.resource(ResourceHandle.decodeReference(value), as: EnterpriseConnectionTestRun.self)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> EnterpriseConnectionTestRun {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "EnterpriseConnectionTestRun.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try EnterpriseConnectionTestRun.decode(result, in: runtime)
  }
}

public enum EnterpriseConnectionTestRunConnectionType: Hashable, Sendable {
  case saml
  case oauth
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .saml: "saml"
    case .oauth: "oauth"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "saml": self = .saml
    case "oauth": self = .oauth
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EnterpriseConnectionTestRunConnectionType {
    try .init(rawValue: value.string())
  }
}

public struct EnterpriseConnectionTestRunParsedUserInfo: Sendable {
  public let emailAddress: String?
  public let firstName: String?
  public let lastName: String?
  public let userId: String?
  public init(emailAddress: String? = nil, firstName: String? = nil, lastName: String? = nil, userId: String? = nil) {
    self.emailAddress = emailAddress
    self.firstName = firstName
    self.lastName = lastName
    self.userId = userId
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "emailAddress": emailAddress.map { value in .string(value) } ?? .undefined,
      "firstName": firstName.map { value in .string(value) } ?? .undefined,
      "lastName": lastName.map { value in .string(value) } ?? .undefined,
      "userId": userId.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EnterpriseConnectionTestRunParsedUserInfo {
    let values = try value.object()

    return try EnterpriseConnectionTestRunParsedUserInfo(emailAddress: (values["emailAddress"] ?? .undefined).optional { value in try value.string() }, firstName: (values["firstName"] ?? .undefined).optional { value in try value.string() }, lastName: (values["lastName"] ?? .undefined).optional { value in try value.string() }, userId: (values["userId"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct EnterpriseConnectionTestRunLog: Sendable {
  public let level: String?
  public let code: String?
  public let shortMessage: String?
  public let message: String?
  public init(level: String? = nil, code: String? = nil, shortMessage: String? = nil, message: String? = nil) {
    self.level = level
    self.code = code
    self.shortMessage = shortMessage
    self.message = message
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "level": level.map { value in .string(value) } ?? .undefined,
      "code": code.map { value in .string(value) } ?? .undefined,
      "shortMessage": shortMessage.map { value in .string(value) } ?? .undefined,
      "message": message.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EnterpriseConnectionTestRunLog {
    let values = try value.object()

    return try EnterpriseConnectionTestRunLog(level: (values["level"] ?? .undefined).optional { value in try value.string() }, code: (values["code"] ?? .undefined).optional { value in try value.string() }, shortMessage: (values["shortMessage"] ?? .undefined).optional { value in try value.string() }, message: (values["message"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct EnterpriseConnectionTestRunSamlPayload: Sendable {
  public let samlRequest: String?
  public let samlResponse: String?
  public let relayState: String?
  public init(samlRequest: String? = nil, samlResponse: String? = nil, relayState: String? = nil) {
    self.samlRequest = samlRequest
    self.samlResponse = samlResponse
    self.relayState = relayState
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "samlRequest": samlRequest.map { value in .string(value) } ?? .undefined,
      "samlResponse": samlResponse.map { value in .string(value) } ?? .undefined,
      "relayState": relayState.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EnterpriseConnectionTestRunSamlPayload {
    let values = try value.object()

    return try EnterpriseConnectionTestRunSamlPayload(samlRequest: (values["samlRequest"] ?? .undefined).optional { value in try value.string() }, samlResponse: (values["samlResponse"] ?? .undefined).optional { value in try value.string() }, relayState: (values["relayState"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct EnterpriseConnectionTestRunOauthPayload: Sendable {
  public let userInfo: String?
  public init(userInfo: String? = nil) {
    self.userInfo = userInfo
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "userInfo": userInfo.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EnterpriseConnectionTestRunOauthPayload {
    let values = try value.object()

    return try EnterpriseConnectionTestRunOauthPayload(userInfo: (values["userInfo"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct SetOrganizationLogoParams: Sendable {
  public let file: SetOrganizationLogoParamsFile?
  public init(file: SetOrganizationLogoParamsFile?) {
    self.file = file
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "file": file.map { value in try value.encode() } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SetOrganizationLogoParams {
    let values = try value.object()

    return try SetOrganizationLogoParams(file: (values["file"] ?? .undefined).optional { value in try SetOrganizationLogoParamsFile.decode(value, in: runtime) })
  }
}

public indirect enum SetOrganizationLogoParamsFile: Sendable {
  case case1(String)
  case case2(UploadFile)
  case case3(UploadFile)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): .object(["$case": .number(0), "value": .string(value)])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    case .case3(let value): try .object(["$case": .number(2), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SetOrganizationLogoParamsFile {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(payload.string())
    case 1: return try .case2(UploadFile.decode(payload))
    case 2: return try .case3(UploadFile.decode(payload))
    default: throw CoreError.invalidValue
    }
  }
}

public struct InitializePaymentMethodParams: Sendable {
  public var gateway: String {
    "stripe"
  }

  public init() {}

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "gateway": .string("stripe"),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> InitializePaymentMethodParams {
    let values = try value.object()
    guard values["gateway"] == .string("stripe") else { throw CoreError.invalidValue }
    return try InitializePaymentMethodParams()
  }
}

/// The `BillingInitializedPaymentMethodResource` type represents a payment method that has been initialized for checkout session.
public struct BillingInitializedPaymentMethodState: Sendable {
  public let externalClientSecret: String
  public let externalGatewayId: String
  public let paymentMethodOrder: [String]
  public let id: String?
  public init(externalClientSecret: String, externalGatewayId: String, paymentMethodOrder: [String], id: String? = nil) {
    self.externalClientSecret = externalClientSecret
    self.externalGatewayId = externalGatewayId
    self.paymentMethodOrder = paymentMethodOrder
    self.id = id
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "externalClientSecret": .string(externalClientSecret),
      "externalGatewayId": .string(externalGatewayId),
      "paymentMethodOrder": .array(paymentMethodOrder.map { value in .string(value) }),
      "id": id.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> BillingInitializedPaymentMethodState {
    let values = try value.object()

    return try BillingInitializedPaymentMethodState(externalClientSecret: (values["externalClientSecret"] ?? .undefined).string(), externalGatewayId: (values["externalGatewayId"] ?? .undefined).string(), paymentMethodOrder: (values["paymentMethodOrder"] ?? .undefined).array().map { value in try value.string() }, id: (values["id"] ?? .undefined).optional { value in try value.string() })
  }
}

@MainActor @Observable public final class BillingInitializedPaymentMethod: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: BillingInitializedPaymentMethodState {
    context.state(handle, as: BillingInitializedPaymentMethodState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var externalClientSecret: String {
    state.externalClientSecret
  }

  public var externalGatewayId: String {
    state.externalGatewayId
  }

  public var paymentMethodOrder: [String] {
    state.paymentMethodOrder
  }

  public var id: String? {
    state.id
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try BillingInitializedPaymentMethodState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> BillingInitializedPaymentMethod {
    try runtime.resource(ResourceHandle.decodeReference(value), as: BillingInitializedPaymentMethod.self)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> BillingInitializedPaymentMethod {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "BillingInitializedPaymentMethod.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try BillingInitializedPaymentMethod.decode(result, in: runtime)
  }
}

public struct AddPaymentMethodParams: Sendable {
  public var gateway: String {
    "stripe"
  }

  public let paymentToken: String
  public init(paymentToken: String) {
    self.paymentToken = paymentToken
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "gateway": .string("stripe"),
      "paymentToken": .string(paymentToken),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> AddPaymentMethodParams {
    let values = try value.object()
    guard values["gateway"] == .string("stripe") else { throw CoreError.invalidValue }
    return try AddPaymentMethodParams(paymentToken: (values["paymentToken"] ?? .undefined).string())
  }
}

/// The `BillingPaymentMethodResource` type represents a payment method for a checkout session.
public struct BillingPaymentMethodState: Sendable {
  public let id: String
  public let last4: String?
  public let paymentType: String?
  public let cardType: String?
  public let isDefault: Bool?
  public let isRemovable: Bool?
  public let status: BillingPaymentMethodStatus
  public let walletType: Field<String>
  public let expiryYear: Field<Double>
  public let expiryMonth: Field<Double>
  public let createdAt: Field<Date>
  public let updatedAt: Field<Date>
  public init(id: String, last4: String?, paymentType: String? = nil, cardType: String?, isDefault: Bool? = nil, isRemovable: Bool? = nil, status: BillingPaymentMethodStatus, walletType: Field<String> = .omitted, expiryYear: Field<Double> = .omitted, expiryMonth: Field<Double> = .omitted, createdAt: Field<Date> = .omitted, updatedAt: Field<Date> = .omitted) {
    self.id = id
    self.last4 = last4
    self.paymentType = paymentType
    self.cardType = cardType
    self.isDefault = isDefault
    self.isRemovable = isRemovable
    self.status = status
    self.walletType = walletType
    self.expiryYear = expiryYear
    self.expiryMonth = expiryMonth
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "last4": last4.map { value in .string(value) } ?? .null,
      "paymentType": paymentType.map { _ in .string("card") } ?? .undefined,
      "cardType": cardType.map { value in .string(value) } ?? .null,
      "isDefault": isDefault.map { value in .bool(value) } ?? .undefined,
      "isRemovable": isRemovable.map { value in .bool(value) } ?? .undefined,
      "status": status.encode(),
      "walletType": walletType.encode { value in .string(value) },
      "expiryYear": expiryYear.encode { value in .number(value) },
      "expiryMonth": expiryMonth.encode { value in .number(value) },
      "createdAt": createdAt.encode { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) },
      "updatedAt": updatedAt.encode { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) },
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> BillingPaymentMethodState {
    let values = try value.object()

    return try BillingPaymentMethodState(id: (values["id"] ?? .undefined).string(), last4: (values["last4"] ?? .undefined).optional { value in try value.string() }, paymentType: (values["paymentType"] ?? .undefined).optional { value in try value.literal(.string("card")).string() }, cardType: (values["cardType"] ?? .undefined).optional { value in try value.string() }, isDefault: (values["isDefault"] ?? .undefined).optional { value in try value.bool() }, isRemovable: (values["isRemovable"] ?? .undefined).optional { value in try value.bool() }, status: BillingPaymentMethodStatus.decode(values["status"] ?? .undefined, in: runtime), walletType: Field.decode(values["walletType"] ?? .undefined) { value in try value.string() }, expiryYear: Field.decode(values["expiryYear"] ?? .undefined) { value in try value.number() }, expiryMonth: Field.decode(values["expiryMonth"] ?? .undefined) { value in try value.number() }, createdAt: Field.decode(values["createdAt"] ?? .undefined) { value in try value.date() }, updatedAt: Field.decode(values["updatedAt"] ?? .undefined) { value in try value.date() })
  }
}

@MainActor @Observable public final class BillingPaymentMethod: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: BillingPaymentMethodState {
    context.state(handle, as: BillingPaymentMethodState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var last4: String? {
    state.last4
  }

  public var paymentType: String? {
    state.paymentType
  }

  public var cardType: String? {
    state.cardType
  }

  public var isDefault: Bool? {
    state.isDefault
  }

  public var isRemovable: Bool? {
    state.isRemovable
  }

  public var status: BillingPaymentMethodStatus {
    state.status
  }

  public var walletType: Field<String> {
    state.walletType
  }

  public var expiryYear: Field<Double> {
    state.expiryYear
  }

  public var expiryMonth: Field<Double> {
    state.expiryMonth
  }

  public var createdAt: Field<Date> {
    state.createdAt
  }

  public var updatedAt: Field<Date> {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try BillingPaymentMethodState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> BillingPaymentMethod {
    try runtime.resource(ResourceHandle.decodeReference(value), as: BillingPaymentMethod.self)
  }

  /// A function that removes this payment method from the account. Accepts the following parameters:
  /// <ul>
  ///  <li>`orgId?` (`string`): The ID of the Organization to remove the payment method from.</li>
  /// </ul>
  public func remove(_ params: BillingPaymentMethodRemoveParams? = nil) async throws -> DeletedObject {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "BillingPaymentMethod.remove", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try DeletedObject.decode(result, in: runtime)
  }

  /// A function that sets this payment method as the default for the account. Accepts the following parameters:
  /// <ul>
  ///  <li>`orgId?` (`string`): The ID of the Organization to set as the default.</li>
  /// </ul>
  public func makeDefault(_ params: BillingPaymentMethodRemoveParams? = nil) async throws -> JSONValue {
    let runtime = try context.requireRuntime()
    return try await runtime.invoke(owner: self, target: handle, operation: "BillingPaymentMethod.makeDefault", arguments: [params.map { value in try value.encode() } ?? .undefined])
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> BillingPaymentMethod {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "BillingPaymentMethod.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try BillingPaymentMethod.decode(result, in: runtime)
  }
}

/// The status of a payment method.
public enum BillingPaymentMethodStatus: Hashable, Sendable {
  case expired
  case active
  case disconnected
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .expired: "expired"
    case .active: "active"
    case .disconnected: "disconnected"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "expired": self = .expired
    case "active": self = .active
    case "disconnected": self = .disconnected
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> BillingPaymentMethodStatus {
    try .init(rawValue: value.string())
  }
}

public struct BillingPaymentMethodRemoveParams: Sendable {
  public let orgId: String?
  public init(orgId: String? = nil) {
    self.orgId = orgId
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "orgId": orgId.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> BillingPaymentMethodRemoveParams {
    let values = try value.object()

    return try BillingPaymentMethodRemoveParams(orgId: (values["orgId"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct GetPaymentMethodsParams: Sendable {
  public let initialPage: Double?
  public let pageSize: Double?
  public init(initialPage: Double? = nil, pageSize: Double? = nil) {
    self.initialPage = initialPage
    self.pageSize = pageSize
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "initialPage": initialPage.map { value in .number(value) } ?? .undefined,
      "pageSize": pageSize.map { value in .number(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> GetPaymentMethodsParams {
    let values = try value.object()

    return try GetPaymentMethodsParams(initialPage: (values["initialPage"] ?? .undefined).optional { value in try value.number() }, pageSize: (values["pageSize"] ?? .undefined).optional { value in try value.number() })
  }
}

/// An interface that describes the response of a method that returns a paginated list of resources.
///
/// > [!TIP]
/// > Clerk's SDKs always use `Promise<ClerkPaginatedResponse<T>>`. If the promise resolves, you will get back the properties. If the promise is rejected, you will receive a `ClerkAPIResponseError` or network error.
public struct ClerkPaginatedResponseBillingPaymentMethod: Sendable {
  public let data: [BillingPaymentMethod]
  public let totalCount: Double
  public init(data: [BillingPaymentMethod], totalCount: Double) {
    self.data = data
    self.totalCount = totalCount
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "data": .array(data.map { value in try value.encode() }),
      "total_count": .number(totalCount),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ClerkPaginatedResponseBillingPaymentMethod {
    let values = try value.object()

    return try ClerkPaginatedResponseBillingPaymentMethod(data: (values["data"] ?? .undefined).array().map { value in try BillingPaymentMethod.decode(value, in: runtime) }, totalCount: (values["total_count"] ?? .undefined).number())
  }
}

/// The `Session` object is an abstraction over an HTTP session. It models the period of information exchange between a user and the server.
///
/// The `Session` object includes methods for recording session activity and ending the session client-side. For security reasons, sessions can also expire server-side.
///
/// As soon as a [`User`](https://clerk.com/docs/reference/objects/user) signs in, Clerk creates a `Session` for the current [`Client`](https://clerk.com/docs/reference/objects/client). Clients can have more than one sessions at any point in time, but only one of those sessions will be **active**.
///
/// In certain scenarios, a session might be replaced by another one. This is often the case with [multi-session applications](https://clerk.com/docs/guides/secure/session-options#multi-session-applications).
///
/// All sessions that are **expired**, **removed**, **replaced**, **ended** or **abandoned** are not considered valid.
///
/// > [!NOTE]
/// > For more information regarding the different session states, see the [guide on session management](https://clerk.com/docs/guides/secure/session-options).
public struct SessionState: Sendable {
  public let id: String
  public let status: SessionStatus
  public let expireAt: Date
  public let abandonAt: Date
  public let factorVerificationAge: SessionFactorVerificationAgeValue?
  public let lastActiveOrganizationId: String?
  public let lastActiveAt: Date
  public let `actor`: [String: JSONValue]?
  public let agent: [String: JSONValue]?
  public let tasks: [SessionTask]?
  public let currentTask: SessionTask?
  public let user: User?
  public let publicUserData: PublicUserData
  public let createdAt: Date
  public let updatedAt: Date
  public init(id: String, status: SessionStatus, expireAt: Date, abandonAt: Date, factorVerificationAge: SessionFactorVerificationAgeValue?, lastActiveOrganizationId: String?, lastActiveAt: Date, actor: [String: JSONValue]?, agent: [String: JSONValue]?, tasks: [SessionTask]?, currentTask: SessionTask? = nil, user: User?, publicUserData: PublicUserData, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.status = status
    self.expireAt = expireAt
    self.abandonAt = abandonAt
    self.factorVerificationAge = factorVerificationAge
    self.lastActiveOrganizationId = lastActiveOrganizationId
    self.lastActiveAt = lastActiveAt
    self.actor = actor
    self.agent = agent
    self.tasks = tasks
    self.currentTask = currentTask
    self.user = user
    self.publicUserData = publicUserData
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "status": status.encode(),
      "expireAt": .string(expireAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "abandonAt": .string(abandonAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "factorVerificationAge": factorVerificationAge.map { value in try value.encode() } ?? .null,
      "lastActiveOrganizationId": lastActiveOrganizationId.map { value in .string(value) } ?? .null,
      "lastActiveAt": .string(lastActiveAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "actor": actor.map { value in .object(value) } ?? .null,
      "agent": agent.map { value in .object(value) } ?? .null,
      "tasks": tasks.map { value in try .array(value.map { value in try value.encode() }) } ?? .null,
      "currentTask": currentTask.map { value in try value.encode() } ?? .undefined,
      "user": user.map { value in try value.encode() } ?? .null,
      "publicUserData": publicUserData.encode(),
      "createdAt": .string(createdAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "updatedAt": .string(updatedAt.ISO8601Format(.init(includingFractionalSeconds: true))),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionState {
    let values = try value.object()

    return try SessionState(id: (values["id"] ?? .undefined).string(), status: SessionStatus.decode(values["status"] ?? .undefined, in: runtime), expireAt: (values["expireAt"] ?? .undefined).date(), abandonAt: (values["abandonAt"] ?? .undefined).date(), factorVerificationAge: (values["factorVerificationAge"] ?? .undefined).optional { value in try SessionFactorVerificationAgeValue.decode(value, in: runtime) }, lastActiveOrganizationId: (values["lastActiveOrganizationId"] ?? .undefined).optional { value in try value.string() }, lastActiveAt: (values["lastActiveAt"] ?? .undefined).date(), actor: (values["actor"] ?? .undefined).optional { value in try value.object() }, agent: (values["agent"] ?? .undefined).optional { value in try value.object() }, tasks: (values["tasks"] ?? .undefined).optional { value in try value.array().map { value in try SessionTask.decode(value, in: runtime) } }, currentTask: (values["currentTask"] ?? .undefined).optional { value in try SessionTask.decode(value, in: runtime) }, user: (values["user"] ?? .undefined).optional { value in try User.decode(value, in: runtime) }, publicUserData: PublicUserData.decode(values["publicUserData"] ?? .undefined, in: runtime), createdAt: (values["createdAt"] ?? .undefined).date(), updatedAt: (values["updatedAt"] ?? .undefined).date())
  }
}

@MainActor @Observable public final class Session: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: SessionState {
    context.state(handle, as: SessionState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var status: SessionStatus {
    state.status
  }

  public var expireAt: Date {
    state.expireAt
  }

  public var abandonAt: Date {
    state.abandonAt
  }

  public var factorVerificationAge: SessionFactorVerificationAgeValue? {
    state.factorVerificationAge
  }

  public var lastActiveOrganizationId: String? {
    state.lastActiveOrganizationId
  }

  public var lastActiveAt: Date {
    state.lastActiveAt
  }

  public var `actor`: [String: JSONValue]? {
    state.actor
  }

  public var agent: [String: JSONValue]? {
    state.agent
  }

  public var tasks: [SessionTask]? {
    state.tasks
  }

  public var currentTask: SessionTask? {
    state.currentTask
  }

  public var user: User? {
    state.user
  }

  public var publicUserData: PublicUserData {
    state.publicUserData
  }

  public var createdAt: Date {
    state.createdAt
  }

  public var updatedAt: Date {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try SessionState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> Session {
    try runtime.resource(ResourceHandle.decodeReference(value), as: Session.self)
  }

  /// Marks the session as ended. The session will no longer be active for this `Client` and its status will become **ended**.
  public func end() async throws -> Session {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Session.end", arguments: [])
    return try Session.decode(result, in: runtime)
  }

  /// Invalidates the current session by marking it as removed. Once removed, the session will be deactivated for the current Client instance and its `status` will be set to `removed`. This operation cannot be undone.
  public func remove() async throws -> Session {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Session.remove", arguments: [])
    return try Session.decode(result, in: runtime)
  }

  /// Updates the session's last active timestamp to the current time. This method should be called periodically to indicate ongoing user activity and prevent the session from becoming stale. The updated timestamp is used for session management and analytics purposes.
  public func touch(_ params: SessionTouchParams? = nil) async throws -> Session {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Session.touch", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try Session.decode(result, in: runtime)
  }

  /// Gets the current user's [session token](https://clerk.com/docs/guides/sessions/session-tokens) or a [custom JWT template](https://clerk.com/docs/guides/sessions/jwt-templates).
  ///
  /// This method uses a cache so a network request will only be made if the token in memory has expired. The TTL for a Clerk token is one minute. It retries on transient failures (e.g., network errors); when the browser is offline and retries are exhausted, it throws `ClerkOfflineError`.
  ///
  /// Tokens can only be generated if the user is signed in.
  public func getToken(_ options: GetTokenOptions? = nil) async throws -> String? {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Session.getToken", arguments: [options.map { value in try value.encode() } ?? .undefined])
    return try result.optional { value in try value.string() }
  }

  /// Checks if the user is [authorized for the specified Role, Permission, Feature, or Plan](https://clerk.com/docs/guides/secure/authorization-checks) or requires the user to [reverify their credentials](https://clerk.com/docs/guides/secure/reverification) if their last verification is older than allowed.
  public func checkAuthorization(_ isAuthorizedParams: CheckAuthorizationParams) async throws -> Bool {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Session.checkAuthorization", arguments: [isAuthorizedParams.encode()])
    return try result.bool()
  }

  /// Clears the cache for the current session. This is useful if the session has been updated and the cache is no longer valid.
  public func clearCache() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Session.clearCache", arguments: [])
    _ = result
  }

  /// Initiates the reverification flow.
  public func startVerification(_ params: SessionVerifyCreateParams) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Session.startVerification", arguments: [params.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Initiates the [first factor verification](!first-factor-verification) process. This is a required step to complete a reverification flow when using a preparable factor.
  public func prepareFirstFactorVerification(_ factor: SessionVerifyPrepareFirstFactorParams) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Session.prepareFirstFactorVerification", arguments: [factor.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Attempts to complete the [first factor verification](!first-factor-verification) process.
  public func attemptFirstFactorVerification(_ attemptFactor: SessionVerifyAttemptFirstFactorParams) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Session.attemptFirstFactorVerification", arguments: [attemptFactor.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Initiates the [second factor verification](!second-factor-verification) process. This is a required step to complete a reverification flow when using a preparable factor.
  public func prepareSecondFactorVerification(_ params: PhoneCodeSecondFactorConfig) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Session.prepareSecondFactorVerification", arguments: [params.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Attempts to complete the [second factor verification](!second-factor-verification) process.
  public func attemptSecondFactorVerification(_ params: SessionVerifyAttemptSecondFactorParams) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Session.attemptSecondFactorVerification", arguments: [params.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Initiates a verification flow using passkeys.
  public func verifyWithPasskey() async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Session.verifyWithPasskey", arguments: [])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> Session {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Session.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try Session.decode(result, in: runtime)
  }
}

/// The current state of the session.
public enum SessionStatus: Hashable, Sendable {
  case pending
  case revoked
  case expired
  case active
  case abandoned
  case ended
  case removed
  case replaced
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .pending: "pending"
    case .revoked: "revoked"
    case .expired: "expired"
    case .active: "active"
    case .abandoned: "abandoned"
    case .ended: "ended"
    case .removed: "removed"
    case .replaced: "replaced"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "pending": self = .pending
    case "revoked": self = .revoked
    case "expired": self = .expired
    case "active": self = .active
    case "abandoned": self = .abandoned
    case "ended": self = .ended
    case "removed": self = .removed
    case "replaced": self = .replaced
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SessionStatus {
    try .init(rawValue: value.string())
  }
}

/// Represents the current pending task of a session.
public struct SessionTask: Sendable {
  public let key: SessionTaskKey
  public init(key: SessionTaskKey) {
    self.key = key
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "key": key.encode(),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionTask {
    let values = try value.object()

    return try SessionTask(key: SessionTaskKey.decode(values["key"] ?? .undefined, in: runtime))
  }
}

public enum SessionTaskKey: Hashable, Sendable {
  case chooseOrganization
  case resetPassword
  case setupMfa
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .chooseOrganization: "choose-organization"
    case .resetPassword: "reset-password"
    case .setupMfa: "setup-mfa"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "choose-organization": self = .chooseOrganization
    case "reset-password": self = .resetPassword
    case "setup-mfa": self = .setupMfa
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SessionTaskKey {
    try .init(rawValue: value.string())
  }
}

/// The `User` object holds all of the information for a single user of your application and provides a set of methods to manage their account. Each `User` has at least one authentication identifier, which might be their email address, phone number, or a username.
///
/// A user can be contacted at their primary email address or primary phone number. They can have more than one registered email address or phone number, but only one of them will be their primary email address (`User.primaryEmailAddress`) or primary phone number (`User.primaryPhoneNumber`). At the same time, a user can also have one or more external accounts by connecting to [social providers](https://clerk.com/docs/guides/configure/auth-strategies/social-connections/overview) such as Google, Apple, Facebook, and many more (`User.externalAccounts`).
///
/// Finally, a `User` object holds profile data like the user's name, profile picture, and a set of [metadata](https://clerk.com/docs/guides/users/extending) that can be used internally to store arbitrary information. The metadata are split into `publicMetadata` and `privateMetadata`. Both types are set from the [Backend API](https://clerk.com/docs/reference/backend-api){{ target: '_blank' }}, but public metadata can also be accessed from the [Frontend API](https://clerk.com/docs/reference/frontend-api){{ target: '_blank' }}.
public struct UserState: Sendable {
  public let id: String
  public let externalId: String?
  public let primaryEmailAddressId: String?
  public let primaryEmailAddress: EmailAddress?
  public let primaryPhoneNumberId: String?
  public let primaryPhoneNumber: PhoneNumber?
  public let primaryWeb3WalletId: String?
  public let primaryWeb3Wallet: Web3Wallet?
  public let username: String?
  public let fullName: String?
  public let firstName: String?
  public let lastName: String?
  public let imageUrl: String
  public let hasImage: Bool
  public let emailAddresses: [EmailAddress]
  public let phoneNumbers: [PhoneNumber]
  public let web3Wallets: [Web3Wallet]
  public let externalAccounts: [ExternalAccount]
  public let enterpriseAccounts: [EnterpriseAccount]
  public let passkeys: [Passkey]
  public let organizationMemberships: [OrganizationMembership]
  public let passwordEnabled: Bool
  public let totpEnabled: Bool
  public let backupCodeEnabled: Bool
  public let twoFactorEnabled: Bool
  public let publicMetadata: [String: JSONValue]
  public let unsafeMetadata: [String: JSONValue]
  public let lastSignInAt: Date?
  public let legalAcceptedAt: Date?
  public let createOrganizationEnabled: Bool
  public let createOrganizationsLimit: Double?
  public let deleteSelfEnabled: Bool
  public let updatedAt: Date?
  public let createdAt: Date?
  public let verifiedExternalAccounts: [ExternalAccount]
  public let unverifiedExternalAccounts: [ExternalAccount]
  public let verifiedWeb3Wallets: [Web3Wallet]
  public let hasVerifiedEmailAddress: Bool
  public let hasVerifiedPhoneNumber: Bool
  public init(id: String, externalId: String?, primaryEmailAddressId: String?, primaryEmailAddress: EmailAddress?, primaryPhoneNumberId: String?, primaryPhoneNumber: PhoneNumber?, primaryWeb3WalletId: String?, primaryWeb3Wallet: Web3Wallet?, username: String?, fullName: String?, firstName: String?, lastName: String?, imageUrl: String, hasImage: Bool, emailAddresses: [EmailAddress], phoneNumbers: [PhoneNumber], web3Wallets: [Web3Wallet], externalAccounts: [ExternalAccount], enterpriseAccounts: [EnterpriseAccount], passkeys: [Passkey], organizationMemberships: [OrganizationMembership], passwordEnabled: Bool, totpEnabled: Bool, backupCodeEnabled: Bool, twoFactorEnabled: Bool, publicMetadata: [String: JSONValue], unsafeMetadata: [String: JSONValue], lastSignInAt: Date?, legalAcceptedAt: Date?, createOrganizationEnabled: Bool, createOrganizationsLimit: Double?, deleteSelfEnabled: Bool, updatedAt: Date?, createdAt: Date?, verifiedExternalAccounts: [ExternalAccount], unverifiedExternalAccounts: [ExternalAccount], verifiedWeb3Wallets: [Web3Wallet], hasVerifiedEmailAddress: Bool, hasVerifiedPhoneNumber: Bool) {
    self.id = id
    self.externalId = externalId
    self.primaryEmailAddressId = primaryEmailAddressId
    self.primaryEmailAddress = primaryEmailAddress
    self.primaryPhoneNumberId = primaryPhoneNumberId
    self.primaryPhoneNumber = primaryPhoneNumber
    self.primaryWeb3WalletId = primaryWeb3WalletId
    self.primaryWeb3Wallet = primaryWeb3Wallet
    self.username = username
    self.fullName = fullName
    self.firstName = firstName
    self.lastName = lastName
    self.imageUrl = imageUrl
    self.hasImage = hasImage
    self.emailAddresses = emailAddresses
    self.phoneNumbers = phoneNumbers
    self.web3Wallets = web3Wallets
    self.externalAccounts = externalAccounts
    self.enterpriseAccounts = enterpriseAccounts
    self.passkeys = passkeys
    self.organizationMemberships = organizationMemberships
    self.passwordEnabled = passwordEnabled
    self.totpEnabled = totpEnabled
    self.backupCodeEnabled = backupCodeEnabled
    self.twoFactorEnabled = twoFactorEnabled
    self.publicMetadata = publicMetadata
    self.unsafeMetadata = unsafeMetadata
    self.lastSignInAt = lastSignInAt
    self.legalAcceptedAt = legalAcceptedAt
    self.createOrganizationEnabled = createOrganizationEnabled
    self.createOrganizationsLimit = createOrganizationsLimit
    self.deleteSelfEnabled = deleteSelfEnabled
    self.updatedAt = updatedAt
    self.createdAt = createdAt
    self.verifiedExternalAccounts = verifiedExternalAccounts
    self.unverifiedExternalAccounts = unverifiedExternalAccounts
    self.verifiedWeb3Wallets = verifiedWeb3Wallets
    self.hasVerifiedEmailAddress = hasVerifiedEmailAddress
    self.hasVerifiedPhoneNumber = hasVerifiedPhoneNumber
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "externalId": externalId.map { value in .string(value) } ?? .null,
      "primaryEmailAddressId": primaryEmailAddressId.map { value in .string(value) } ?? .null,
      "primaryEmailAddress": primaryEmailAddress.map { value in try value.encode() } ?? .null,
      "primaryPhoneNumberId": primaryPhoneNumberId.map { value in .string(value) } ?? .null,
      "primaryPhoneNumber": primaryPhoneNumber.map { value in try value.encode() } ?? .null,
      "primaryWeb3WalletId": primaryWeb3WalletId.map { value in .string(value) } ?? .null,
      "primaryWeb3Wallet": primaryWeb3Wallet.map { value in try value.encode() } ?? .null,
      "username": username.map { value in .string(value) } ?? .null,
      "fullName": fullName.map { value in .string(value) } ?? .null,
      "firstName": firstName.map { value in .string(value) } ?? .null,
      "lastName": lastName.map { value in .string(value) } ?? .null,
      "imageUrl": .string(imageUrl),
      "hasImage": .bool(hasImage),
      "emailAddresses": .array(emailAddresses.map { value in try value.encode() }),
      "phoneNumbers": .array(phoneNumbers.map { value in try value.encode() }),
      "web3Wallets": .array(web3Wallets.map { value in try value.encode() }),
      "externalAccounts": .array(externalAccounts.map { value in try value.encode() }),
      "enterpriseAccounts": .array(enterpriseAccounts.map { value in try value.encode() }),
      "passkeys": .array(passkeys.map { value in try value.encode() }),
      "organizationMemberships": .array(organizationMemberships.map { value in try value.encode() }),
      "passwordEnabled": .bool(passwordEnabled),
      "totpEnabled": .bool(totpEnabled),
      "backupCodeEnabled": .bool(backupCodeEnabled),
      "twoFactorEnabled": .bool(twoFactorEnabled),
      "publicMetadata": .object(publicMetadata),
      "unsafeMetadata": .object(unsafeMetadata),
      "lastSignInAt": lastSignInAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "legalAcceptedAt": legalAcceptedAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "createOrganizationEnabled": .bool(createOrganizationEnabled),
      "createOrganizationsLimit": createOrganizationsLimit.map { value in .number(value) } ?? .null,
      "deleteSelfEnabled": .bool(deleteSelfEnabled),
      "updatedAt": updatedAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "createdAt": createdAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "verifiedExternalAccounts": .array(verifiedExternalAccounts.map { value in try value.encode() }),
      "unverifiedExternalAccounts": .array(unverifiedExternalAccounts.map { value in try value.encode() }),
      "verifiedWeb3Wallets": .array(verifiedWeb3Wallets.map { value in try value.encode() }),
      "hasVerifiedEmailAddress": .bool(hasVerifiedEmailAddress),
      "hasVerifiedPhoneNumber": .bool(hasVerifiedPhoneNumber),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> UserState {
    let values = try value.object()

    return try UserState(id: (values["id"] ?? .undefined).string(), externalId: (values["externalId"] ?? .undefined).optional { value in try value.string() }, primaryEmailAddressId: (values["primaryEmailAddressId"] ?? .undefined).optional { value in try value.string() }, primaryEmailAddress: (values["primaryEmailAddress"] ?? .undefined).optional { value in try EmailAddress.decode(value, in: runtime) }, primaryPhoneNumberId: (values["primaryPhoneNumberId"] ?? .undefined).optional { value in try value.string() }, primaryPhoneNumber: (values["primaryPhoneNumber"] ?? .undefined).optional { value in try PhoneNumber.decode(value, in: runtime) }, primaryWeb3WalletId: (values["primaryWeb3WalletId"] ?? .undefined).optional { value in try value.string() }, primaryWeb3Wallet: (values["primaryWeb3Wallet"] ?? .undefined).optional { value in try Web3Wallet.decode(value, in: runtime) }, username: (values["username"] ?? .undefined).optional { value in try value.string() }, fullName: (values["fullName"] ?? .undefined).optional { value in try value.string() }, firstName: (values["firstName"] ?? .undefined).optional { value in try value.string() }, lastName: (values["lastName"] ?? .undefined).optional { value in try value.string() }, imageUrl: (values["imageUrl"] ?? .undefined).string(), hasImage: (values["hasImage"] ?? .undefined).bool(), emailAddresses: (values["emailAddresses"] ?? .undefined).array().map { value in try EmailAddress.decode(value, in: runtime) }, phoneNumbers: (values["phoneNumbers"] ?? .undefined).array().map { value in try PhoneNumber.decode(value, in: runtime) }, web3Wallets: (values["web3Wallets"] ?? .undefined).array().map { value in try Web3Wallet.decode(value, in: runtime) }, externalAccounts: (values["externalAccounts"] ?? .undefined).array().map { value in try ExternalAccount.decode(value, in: runtime) }, enterpriseAccounts: (values["enterpriseAccounts"] ?? .undefined).array().map { value in try EnterpriseAccount.decode(value, in: runtime) }, passkeys: (values["passkeys"] ?? .undefined).array().map { value in try Passkey.decode(value, in: runtime) }, organizationMemberships: (values["organizationMemberships"] ?? .undefined).array().map { value in try OrganizationMembership.decode(value, in: runtime) }, passwordEnabled: (values["passwordEnabled"] ?? .undefined).bool(), totpEnabled: (values["totpEnabled"] ?? .undefined).bool(), backupCodeEnabled: (values["backupCodeEnabled"] ?? .undefined).bool(), twoFactorEnabled: (values["twoFactorEnabled"] ?? .undefined).bool(), publicMetadata: (values["publicMetadata"] ?? .undefined).object(), unsafeMetadata: (values["unsafeMetadata"] ?? .undefined).object(), lastSignInAt: (values["lastSignInAt"] ?? .undefined).optional { value in try value.date() }, legalAcceptedAt: (values["legalAcceptedAt"] ?? .undefined).optional { value in try value.date() }, createOrganizationEnabled: (values["createOrganizationEnabled"] ?? .undefined).bool(), createOrganizationsLimit: (values["createOrganizationsLimit"] ?? .undefined).optional { value in try value.number() }, deleteSelfEnabled: (values["deleteSelfEnabled"] ?? .undefined).bool(), updatedAt: (values["updatedAt"] ?? .undefined).optional { value in try value.date() }, createdAt: (values["createdAt"] ?? .undefined).optional { value in try value.date() }, verifiedExternalAccounts: (values["verifiedExternalAccounts"] ?? .undefined).array().map { value in try ExternalAccount.decode(value, in: runtime) }, unverifiedExternalAccounts: (values["unverifiedExternalAccounts"] ?? .undefined).array().map { value in try ExternalAccount.decode(value, in: runtime) }, verifiedWeb3Wallets: (values["verifiedWeb3Wallets"] ?? .undefined).array().map { value in try Web3Wallet.decode(value, in: runtime) }, hasVerifiedEmailAddress: (values["hasVerifiedEmailAddress"] ?? .undefined).bool(), hasVerifiedPhoneNumber: (values["hasVerifiedPhoneNumber"] ?? .undefined).bool())
  }
}

@MainActor @Observable public final class User: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: UserState {
    context.state(handle, as: UserState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var externalId: String? {
    state.externalId
  }

  public var primaryEmailAddressId: String? {
    state.primaryEmailAddressId
  }

  public var primaryEmailAddress: EmailAddress? {
    state.primaryEmailAddress
  }

  public var primaryPhoneNumberId: String? {
    state.primaryPhoneNumberId
  }

  public var primaryPhoneNumber: PhoneNumber? {
    state.primaryPhoneNumber
  }

  public var primaryWeb3WalletId: String? {
    state.primaryWeb3WalletId
  }

  public var primaryWeb3Wallet: Web3Wallet? {
    state.primaryWeb3Wallet
  }

  public var username: String? {
    state.username
  }

  public var fullName: String? {
    state.fullName
  }

  public var firstName: String? {
    state.firstName
  }

  public var lastName: String? {
    state.lastName
  }

  public var imageUrl: String {
    state.imageUrl
  }

  public var hasImage: Bool {
    state.hasImage
  }

  public var emailAddresses: [EmailAddress] {
    state.emailAddresses
  }

  public var phoneNumbers: [PhoneNumber] {
    state.phoneNumbers
  }

  public var web3Wallets: [Web3Wallet] {
    state.web3Wallets
  }

  public var externalAccounts: [ExternalAccount] {
    state.externalAccounts
  }

  public var enterpriseAccounts: [EnterpriseAccount] {
    state.enterpriseAccounts
  }

  public var passkeys: [Passkey] {
    state.passkeys
  }

  public var organizationMemberships: [OrganizationMembership] {
    state.organizationMemberships
  }

  public var passwordEnabled: Bool {
    state.passwordEnabled
  }

  public var totpEnabled: Bool {
    state.totpEnabled
  }

  public var backupCodeEnabled: Bool {
    state.backupCodeEnabled
  }

  public var twoFactorEnabled: Bool {
    state.twoFactorEnabled
  }

  public var publicMetadata: [String: JSONValue] {
    state.publicMetadata
  }

  public var unsafeMetadata: [String: JSONValue] {
    state.unsafeMetadata
  }

  public var lastSignInAt: Date? {
    state.lastSignInAt
  }

  public var legalAcceptedAt: Date? {
    state.legalAcceptedAt
  }

  public var createOrganizationEnabled: Bool {
    state.createOrganizationEnabled
  }

  public var createOrganizationsLimit: Double? {
    state.createOrganizationsLimit
  }

  public var deleteSelfEnabled: Bool {
    state.deleteSelfEnabled
  }

  public var updatedAt: Date? {
    state.updatedAt
  }

  public var createdAt: Date? {
    state.createdAt
  }

  public var verifiedExternalAccounts: [ExternalAccount] {
    state.verifiedExternalAccounts
  }

  public var unverifiedExternalAccounts: [ExternalAccount] {
    state.unverifiedExternalAccounts
  }

  public var verifiedWeb3Wallets: [Web3Wallet] {
    state.verifiedWeb3Wallets
  }

  public var hasVerifiedEmailAddress: Bool {
    state.hasVerifiedEmailAddress
  }

  public var hasVerifiedPhoneNumber: Bool {
    state.hasVerifiedPhoneNumber
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try UserState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> User {
    try runtime.resource(ResourceHandle.decodeReference(value), as: User.self)
  }

  /// Updates the user's attributes. Use this method to save information you collected about the user.
  ///
  /// The appropriate settings must be enabled in the Clerk Dashboard for the user to be able to update their attributes. For example, if you want to use the `update({ firstName })` method, you must enable the **First and last name** setting. It can be found on the [**User & authentication**](https://dashboard.clerk.com/~/user-authentication/user-and-authentication?user_auth_tab=user-profile) page in the Clerk Dashboard.
  public func update(_ params: UpdateUserParams) async throws -> User {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.update", arguments: [params.encode()])
    return try User.decode(result, in: runtime)
  }

  /// Updates the user's `unsafeMetadata` using deep-merge semantics. Unlike [`update()`](https://clerk.com/docs/reference/objects/user#update), which fully replaces `unsafeMetadata`, this method merges the provided value with the existing `unsafeMetadata`. Top-level and nested keys are merged, and any key set to `null` is removed. Only `unsafeMetadata` is writable from the frontend; `publicMetadata` and `privateMetadata` can only be set from the [Backend API](https://clerk.com/docs/reference/backend-api){{ target: '_blank' }}.
  public func updateMetadata(_ params: UpdateUserMetadataParams) async throws -> User {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.updateMetadata", arguments: [params.encode()])
    return try User.decode(result, in: runtime)
  }

  /// Deletes the current user.
  public func delete() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.delete", arguments: [])
    _ = result
  }

  /// Updates the user's password.
  public func updatePassword(_ params: UpdateUserPasswordParams) async throws -> User {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.updatePassword", arguments: [params.encode()])
    return try User.decode(result, in: runtime)
  }

  /// Removes the user's password.
  public func removePassword(_ params: RemoveUserPasswordParams) async throws -> User {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.removePassword", arguments: [params.encode()])
    return try User.decode(result, in: runtime)
  }

  /// Adds an email address for the user. A new [`EmailAddress`](https://clerk.com/docs/reference/types/email-address) will be created and associated with the user.
  ///
  /// > [!WARNING]
  /// > [**Email** must be enabled](https://clerk.com/docs/guides/configure/auth-strategies/sign-up-sign-in-options#email) in your app's settings in the Clerk Dashboard.
  public func createEmailAddress(_ params: CreateEmailAddressParams) async throws -> EmailAddress {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.createEmailAddress", arguments: [params.encode()])
    return try EmailAddress.decode(result, in: runtime)
  }

  /// Creates a passkey for the signed-in user. For an example, see the [custom flow guide](https://clerk.com/docs/guides/development/custom-flows/authentication/passkeys#create-user-passkeys).
  public func createPasskey() async throws -> Passkey {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.createPasskey", arguments: [])
    return try Passkey.decode(result, in: runtime)
  }

  /// Adds a phone number for the user. A new [`PhoneNumber`](https://clerk.com/docs/reference/types/phone-number) will be created and associated with the user.
  ///
  /// > [!WARNING]
  /// > [**Phone** must be enabled](https://clerk.com/docs/guides/configure/auth-strategies/sign-up-sign-in-options#phone) in your app's settings in the Clerk Dashboard.
  public func createPhoneNumber(_ params: CreatePhoneNumberParams) async throws -> PhoneNumber {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.createPhoneNumber", arguments: [params.encode()])
    return try PhoneNumber.decode(result, in: runtime)
  }

  /// Adds a Web3 wallet for the user. A new [`Web3WalletResource`](https://clerk.com/docs/reference/types/web3-wallet) will be created and associated with the user.
  public func createWeb3Wallet(_ params: CreateWeb3WalletParams) async throws -> Web3Wallet {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.createWeb3Wallet", arguments: [params.encode()])
    return try Web3Wallet.decode(result, in: runtime)
  }

  /// A check whether or not the given resource is the primary identifier for the user.
  public func isPrimaryIdentification(_ ident: UserIsPrimaryIdentificationIdent) async throws -> Bool {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.isPrimaryIdentification", arguments: [ident.encode()])
    return try result.bool()
  }

  /// Gets all **active** sessions for this user. This method uses a cache so a network request will only be triggered only once.
  public func getSessions() async throws -> [SessionWithActivities] {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.getSessions", arguments: [])
    return try result.array().map { value in try SessionWithActivities.decode(value, in: runtime) }
  }

  /// Adds the user's profile image or replaces it if one already exists. This method will upload an image and associate it with the user.
  public func setProfileImage(_ params: SetProfileImageParams) async throws -> Image {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.setProfileImage", arguments: [params.encode()])
    return try Image.decode(result, in: runtime)
  }

  /// Adds an external account for the user. A new [`ExternalAccount`](https://clerk.com/docs/reference/types/external-account) will be created and associated with the user. This method is useful if you want to allow an already signed-in user to connect their account with an external provider, such as Facebook, GitHub, etc., so that they can sign in with that provider in the future.
  ///
  /// > [!WARNING]
  /// > The social provider that you want to connect to [must be enabled](https://clerk.com/docs/guides/configure/auth-strategies/sign-up-sign-in-options#sso-connections) in your app's settings in the Clerk Dashboard.
  public func createExternalAccount(_ params: CreateExternalAccountParams) async throws -> ExternalAccount {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.createExternalAccount", arguments: [params.encode()])
    return try ExternalAccount.decode(result, in: runtime)
  }

  public func getOrganizationMemberships(_ params: GetUserOrganizationMembershipParams? = nil) async throws -> ClerkPaginatedResponseOrganizationMembership {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.getOrganizationMemberships", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try ClerkPaginatedResponseOrganizationMembership.decode(result, in: runtime)
  }

  /// Gets a list of Organization invitations for the user.
  public func getOrganizationInvitations(_ params: GetUserOrganizationInvitationsParams? = nil) async throws -> ClerkPaginatedResponseUserOrganizationInvitation {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.getOrganizationInvitations", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try ClerkPaginatedResponseUserOrganizationInvitation.decode(result, in: runtime)
  }

  /// Gets a list of Organization suggestions for the user.
  public func getOrganizationSuggestions(_ params: GetUserOrganizationSuggestionsParams? = nil) async throws -> ClerkPaginatedResponseOrganizationSuggestion {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.getOrganizationSuggestions", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try ClerkPaginatedResponseOrganizationSuggestion.decode(result, in: runtime)
  }

  /// Gets organization creation defaults for the current user.
  public func getOrganizationCreationDefaults() async throws -> OrganizationCreationDefaults {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.getOrganizationCreationDefaults", arguments: [])
    return try OrganizationCreationDefaults.decode(result, in: runtime)
  }

  /// Leaves an organization that the user is a member of.
  public func leaveOrganization(_ organizationId: String) async throws -> DeletedObject {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.leaveOrganization", arguments: [.string(organizationId)])
    return try DeletedObject.decode(result, in: runtime)
  }

  /// Get the enterprise connections for the current user. This method is not intended for public use.
  /// Currently some customers use this to get enterprise connections for account linking purposes.
  public func getEnterpriseConnections(_ params: GetEnterpriseConnectionsParams? = nil) async throws -> [EnterpriseConnection] {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.getEnterpriseConnections", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try result.array().map { value in try EnterpriseConnection.decode(value, in: runtime) }
  }

  /// Generates a TOTP secret for a user that can be used to register the application on the user's authenticator app of choice. If this method is called again (while still unverified), it replaces the previously generated secret.
  public func createTOTP() async throws -> TOTP {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.createTOTP", arguments: [])
    return try TOTP.decode(result, in: runtime)
  }

  /// Verifies a TOTP secret after a user has created it. The user must provide a code from their authenticator app that has been generated using the previously created secret. This way, correct set up and ownership of the authenticator app can be validated.
  public func verifyTOTP(_ params: VerifyTOTPParams) async throws -> TOTP {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.verifyTOTP", arguments: [params.encode()])
    return try TOTP.decode(result, in: runtime)
  }

  /// Disables TOTP by deleting the user's TOTP secret.
  public func disableTOTP() async throws -> DeletedObject {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.disableTOTP", arguments: [])
    return try DeletedObject.decode(result, in: runtime)
  }

  /// Generates a fresh new set of backup codes for the user. Every time the method is called, it will replace the previously generated backup codes.
  public func createBackupCode() async throws -> BackupCode {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.createBackupCode", arguments: [])
    return try BackupCode.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> User {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try User.decode(result, in: runtime)
  }

  /// Initializes a payment method.
  public func initializePaymentMethod(_ params: InitializePaymentMethodParams) async throws -> BillingInitializedPaymentMethod {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.initializePaymentMethod", arguments: [params.encode()])
    return try BillingInitializedPaymentMethod.decode(result, in: runtime)
  }

  /// Adds a payment method.
  public func addPaymentMethod(_ params: AddPaymentMethodParams) async throws -> BillingPaymentMethod {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.addPaymentMethod", arguments: [params.encode()])
    return try BillingPaymentMethod.decode(result, in: runtime)
  }

  /// Gets a list of payment methods that have been stored.
  public func getPaymentMethods(_ params: GetPaymentMethodsParams? = nil) async throws -> ClerkPaginatedResponseBillingPaymentMethod {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "User.getPaymentMethods", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try ClerkPaginatedResponseBillingPaymentMethod.decode(result, in: runtime)
  }
}

public struct EmailAddressState: Sendable {
  public let id: String
  public let emailAddress: String
  public let verification: Verification
  public let matchesSsoConnection: Bool
  public let linkedTo: [IdentificationLink]
  public init(id: String, emailAddress: String, verification: Verification, matchesSsoConnection: Bool, linkedTo: [IdentificationLink]) {
    self.id = id
    self.emailAddress = emailAddress
    self.verification = verification
    self.matchesSsoConnection = matchesSsoConnection
    self.linkedTo = linkedTo
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "emailAddress": .string(emailAddress),
      "verification": verification.encode(),
      "matchesSsoConnection": .bool(matchesSsoConnection),
      "linkedTo": .array(linkedTo.map { value in try value.encode() }),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> EmailAddressState {
    let values = try value.object()

    return try EmailAddressState(id: (values["id"] ?? .undefined).string(), emailAddress: (values["emailAddress"] ?? .undefined).string(), verification: Verification.decode(values["verification"] ?? .undefined, in: runtime), matchesSsoConnection: (values["matchesSsoConnection"] ?? .undefined).bool(), linkedTo: (values["linkedTo"] ?? .undefined).array().map { value in try IdentificationLink.decode(value, in: runtime) })
  }
}

@MainActor @Observable public final class EmailAddress: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: EmailAddressState {
    context.state(handle, as: EmailAddressState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var emailAddress: String {
    state.emailAddress
  }

  public var verification: Verification {
    state.verification
  }

  public var matchesSsoConnection: Bool {
    state.matchesSsoConnection
  }

  public var linkedTo: [IdentificationLink] {
    state.linkedTo
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try EmailAddressState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> EmailAddress {
    try runtime.resource(ResourceHandle.decodeReference(value), as: EmailAddress.self)
  }

  /// Returns a string representation of an object.
  public func stringValue() async throws -> String {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "EmailAddress.toString", arguments: [])
    return try result.string()
  }

  public func prepareVerification(_ params: PrepareEmailAddressVerificationParams) async throws -> EmailAddress {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "EmailAddress.prepareVerification", arguments: [params.encode()])
    return try EmailAddress.decode(result, in: runtime)
  }

  public func attemptVerification(_ params: AttemptEmailAddressVerificationParams) async throws -> EmailAddress {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "EmailAddress.attemptVerification", arguments: [params.encode()])
    return try EmailAddress.decode(result, in: runtime)
  }

  public func createEmailLinkFlow() async throws -> CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddress {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "EmailAddress.createEmailLinkFlow", arguments: [])
    return try CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddress.decode(result, in: runtime)
  }

  public func createEnterpriseSSOLinkFlow() async throws -> CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddress {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "EmailAddress.createEnterpriseSSOLinkFlow", arguments: [])
    return try CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddress.decode(result, in: runtime)
  }

  public func destroy() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "EmailAddress.destroy", arguments: [])
    _ = result
  }

  public func create() async throws -> EmailAddress {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "EmailAddress.create", arguments: [])
    return try EmailAddress.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> EmailAddress {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "EmailAddress.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try EmailAddress.decode(result, in: runtime)
  }
}

public struct VerificationState: Sendable {
  public let attempts: Double?
  public let error: ClerkAPIError?
  public let expireAt: Date?
  public let status: VerificationStatus?
  public let strategy: String?
  public let verifiedAtClient: String?
  public let channel: PhoneCodeChannel?
  public let id: String?
  public init(attempts: Double?, error: ClerkAPIError?, expireAt: Date?, status: VerificationStatus?, strategy: String?, verifiedAtClient: String?, channel: PhoneCodeChannel? = nil, id: String? = nil) {
    self.attempts = attempts
    self.error = error
    self.expireAt = expireAt
    self.status = status
    self.strategy = strategy
    self.verifiedAtClient = verifiedAtClient
    self.channel = channel
    self.id = id
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "attempts": attempts.map { value in .number(value) } ?? .null,
      "error": error.map { value in try value.encode() } ?? .null,
      "expireAt": expireAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "status": status.map { value in try value.encode() } ?? .null,
      "strategy": strategy.map { value in .string(value) } ?? .null,
      "verifiedAtClient": verifiedAtClient.map { value in .string(value) } ?? .null,
      "channel": channel.map { value in try value.encode() } ?? .undefined,
      "id": id.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> VerificationState {
    let values = try value.object()

    return try VerificationState(attempts: (values["attempts"] ?? .undefined).optional { value in try value.number() }, error: (values["error"] ?? .undefined).optional { value in try ClerkAPIError.decode(value, in: runtime) }, expireAt: (values["expireAt"] ?? .undefined).optional { value in try value.date() }, status: (values["status"] ?? .undefined).optional { value in try VerificationStatus.decode(value, in: runtime) }, strategy: (values["strategy"] ?? .undefined).optional { value in try value.string() }, verifiedAtClient: (values["verifiedAtClient"] ?? .undefined).optional { value in try value.string() }, channel: (values["channel"] ?? .undefined).optional { value in try PhoneCodeChannel.decode(value, in: runtime) }, id: (values["id"] ?? .undefined).optional { value in try value.string() })
  }
}

@MainActor @Observable public final class Verification: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: VerificationState {
    context.state(handle, as: VerificationState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var attempts: Double? {
    state.attempts
  }

  public var error: ClerkAPIError? {
    state.error
  }

  public var expireAt: Date? {
    state.expireAt
  }

  public var status: VerificationStatus? {
    state.status
  }

  public var strategy: String? {
    state.strategy
  }

  public var verifiedAtClient: String? {
    state.verifiedAtClient
  }

  public var channel: PhoneCodeChannel? {
    state.channel
  }

  public var id: String? {
    state.id
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try VerificationState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> Verification {
    try runtime.resource(ResourceHandle.decodeReference(value), as: Verification.self)
  }

  public func verifiedFromTheSameClient() async throws -> Bool {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Verification.verifiedFromTheSameClient", arguments: [])
    return try result.bool()
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> Verification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Verification.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try Verification.decode(result, in: runtime)
  }
}

/// An interface that represents an error returned by the Clerk API.
public struct ClerkAPIError: Sendable {
  public let code: String
  public let message: String
  public let longMessage: String?
  public let meta: ClerkAPIErrorMeta?
  public init(code: String, message: String, longMessage: String? = nil, meta: ClerkAPIErrorMeta? = nil) {
    self.code = code
    self.message = message
    self.longMessage = longMessage
    self.meta = meta
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "code": .string(code),
      "message": .string(message),
      "longMessage": longMessage.map { value in .string(value) } ?? .undefined,
      "meta": meta.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ClerkAPIError {
    let values = try value.object()

    return try ClerkAPIError(code: (values["code"] ?? .undefined).string(), message: (values["message"] ?? .undefined).string(), longMessage: (values["longMessage"] ?? .undefined).optional { value in try value.string() }, meta: (values["meta"] ?? .undefined).optional { value in try ClerkAPIErrorMeta.decode(value, in: runtime) })
  }
}

public struct ClerkAPIErrorMeta: Sendable {
  public let paramName: String?
  public let sessionId: String?
  public let emailAddresses: [String]?
  public let identifiers: [String]?
  public let zxcvbn: ClerkAPIErrorMetaZxcvbn?
  public let permissions: [String]?
  public let plan: ClerkAPIErrorMetaPlan?
  public let isPlanUpgradePossible: Bool?
  public let seatsQuantityToAdd: Double?
  public let seatsQuantity: Double?
  public init(paramName: String? = nil, sessionId: String? = nil, emailAddresses: [String]? = nil, identifiers: [String]? = nil, zxcvbn: ClerkAPIErrorMetaZxcvbn? = nil, permissions: [String]? = nil, plan: ClerkAPIErrorMetaPlan? = nil, isPlanUpgradePossible: Bool? = nil, seatsQuantityToAdd: Double? = nil, seatsQuantity: Double? = nil) {
    self.paramName = paramName
    self.sessionId = sessionId
    self.emailAddresses = emailAddresses
    self.identifiers = identifiers
    self.zxcvbn = zxcvbn
    self.permissions = permissions
    self.plan = plan
    self.isPlanUpgradePossible = isPlanUpgradePossible
    self.seatsQuantityToAdd = seatsQuantityToAdd
    self.seatsQuantity = seatsQuantity
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "paramName": paramName.map { value in .string(value) } ?? .undefined,
      "sessionId": sessionId.map { value in .string(value) } ?? .undefined,
      "emailAddresses": emailAddresses.map { value in try .array(value.map { value in .string(value) }) } ?? .undefined,
      "identifiers": identifiers.map { value in try .array(value.map { value in .string(value) }) } ?? .undefined,
      "zxcvbn": zxcvbn.map { value in try value.encode() } ?? .undefined,
      "permissions": permissions.map { value in try .array(value.map { value in .string(value) }) } ?? .undefined,
      "plan": plan.map { value in try value.encode() } ?? .undefined,
      "isPlanUpgradePossible": isPlanUpgradePossible.map { value in .bool(value) } ?? .undefined,
      "seatsQuantityToAdd": seatsQuantityToAdd.map { value in .number(value) } ?? .undefined,
      "seatsQuantity": seatsQuantity.map { value in .number(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ClerkAPIErrorMeta {
    let values = try value.object()

    return try ClerkAPIErrorMeta(paramName: (values["paramName"] ?? .undefined).optional { value in try value.string() }, sessionId: (values["sessionId"] ?? .undefined).optional { value in try value.string() }, emailAddresses: (values["emailAddresses"] ?? .undefined).optional { value in try value.array().map { value in try value.string() } }, identifiers: (values["identifiers"] ?? .undefined).optional { value in try value.array().map { value in try value.string() } }, zxcvbn: (values["zxcvbn"] ?? .undefined).optional { value in try ClerkAPIErrorMetaZxcvbn.decode(value, in: runtime) }, permissions: (values["permissions"] ?? .undefined).optional { value in try value.array().map { value in try value.string() } }, plan: (values["plan"] ?? .undefined).optional { value in try ClerkAPIErrorMetaPlan.decode(value, in: runtime) }, isPlanUpgradePossible: (values["isPlanUpgradePossible"] ?? .undefined).optional { value in try value.bool() }, seatsQuantityToAdd: (values["seatsQuantityToAdd"] ?? .undefined).optional { value in try value.number() }, seatsQuantity: (values["seatsQuantity"] ?? .undefined).optional { value in try value.number() })
  }
}

public struct ClerkAPIErrorMetaZxcvbn: Sendable {
  public let suggestions: [ClerkAPIErrorMetaZxcvbnSuggestionsElement]
  public init(suggestions: [ClerkAPIErrorMetaZxcvbnSuggestionsElement]) {
    self.suggestions = suggestions
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "suggestions": .array(suggestions.map { value in try value.encode() }),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ClerkAPIErrorMetaZxcvbn {
    let values = try value.object()

    return try ClerkAPIErrorMetaZxcvbn(suggestions: (values["suggestions"] ?? .undefined).array().map { value in try ClerkAPIErrorMetaZxcvbnSuggestionsElement.decode(value, in: runtime) })
  }
}

public struct ClerkAPIErrorMetaZxcvbnSuggestionsElement: Sendable {
  public let code: String
  public let message: String
  public init(code: String, message: String) {
    self.code = code
    self.message = message
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "code": .string(code),
      "message": .string(message),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> ClerkAPIErrorMetaZxcvbnSuggestionsElement {
    let values = try value.object()

    return try ClerkAPIErrorMetaZxcvbnSuggestionsElement(code: (values["code"] ?? .undefined).string(), message: (values["message"] ?? .undefined).string())
  }
}

public struct ClerkAPIErrorMetaPlan: Sendable {
  public let amountFormatted: String
  public let annualMonthlyAmountFormatted: String
  public let currencySymbol: String
  public let id: String
  public let name: String
  public init(amountFormatted: String, annualMonthlyAmountFormatted: String, currencySymbol: String, id: String, name: String) {
    self.amountFormatted = amountFormatted
    self.annualMonthlyAmountFormatted = annualMonthlyAmountFormatted
    self.currencySymbol = currencySymbol
    self.id = id
    self.name = name
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "amount_formatted": .string(amountFormatted),
      "annual_monthly_amount_formatted": .string(annualMonthlyAmountFormatted),
      "currency_symbol": .string(currencySymbol),
      "id": .string(id),
      "name": .string(name),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> ClerkAPIErrorMetaPlan {
    let values = try value.object()

    return try ClerkAPIErrorMetaPlan(amountFormatted: (values["amount_formatted"] ?? .undefined).string(), annualMonthlyAmountFormatted: (values["annual_monthly_amount_formatted"] ?? .undefined).string(), currencySymbol: (values["currency_symbol"] ?? .undefined).string(), id: (values["id"] ?? .undefined).string(), name: (values["name"] ?? .undefined).string())
  }
}

public enum VerificationStatus: Hashable, Sendable {
  case expired
  case unverified
  case verified
  case failed
  case transferable
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .expired: "expired"
    case .unverified: "unverified"
    case .verified: "verified"
    case .failed: "failed"
    case .transferable: "transferable"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "expired": self = .expired
    case "unverified": self = .unverified
    case "verified": self = .verified
    case "failed": self = .failed
    case "transferable": self = .transferable
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> VerificationStatus {
    try .init(rawValue: value.string())
  }
}

public enum PhoneCodeChannel: Hashable, Sendable {
  case sms
  case whatsapp
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .sms: "sms"
    case .whatsapp: "whatsapp"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "sms": self = .sms
    case "whatsapp": self = .whatsapp
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> PhoneCodeChannel {
    try .init(rawValue: value.string())
  }
}

public struct IdentificationLinkState: Sendable {
  public let id: String
  public let type: String
  public init(id: String, type: String) {
    self.id = id
    self.type = type
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "id": .string(id),
      "type": .string(type),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> IdentificationLinkState {
    let values = try value.object()

    return try IdentificationLinkState(id: (values["id"] ?? .undefined).string(), type: (values["type"] ?? .undefined).string())
  }
}

@MainActor @Observable public final class IdentificationLink: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: IdentificationLinkState {
    context.state(handle, as: IdentificationLinkState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var type: String {
    state.type
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try IdentificationLinkState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> IdentificationLink {
    try runtime.resource(ResourceHandle.decodeReference(value), as: IdentificationLink.self)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> IdentificationLink {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "IdentificationLink.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try IdentificationLink.decode(result, in: runtime)
  }
}

public indirect enum PrepareEmailAddressVerificationParams: Sendable {
  case case1(EmailAddressPrepareVerificationParamsCase1)
  case case2(EmailAddressPrepareVerificationParamsCase2)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PrepareEmailAddressVerificationParams {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(EmailAddressPrepareVerificationParamsCase1.decode(payload, in: runtime))
    case 1: return try .case2(EmailAddressPrepareVerificationParamsCase2.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct EmailAddressPrepareVerificationParamsCase1: Sendable {
  public var strategy: String {
    "email_code"
  }

  public init() {}

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "strategy": .string("email_code"),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EmailAddressPrepareVerificationParamsCase1 {
    let values = try value.object()
    guard values["strategy"] == .string("email_code") else { throw CoreError.invalidValue }
    return try EmailAddressPrepareVerificationParamsCase1()
  }
}

public struct EmailAddressPrepareVerificationParamsCase2: Sendable {
  public let strategy: EmailAddressPrepareVerificationParamsCase2Strategy
  public let redirectUrl: String
  public init(strategy: EmailAddressPrepareVerificationParamsCase2Strategy, redirectUrl: String) {
    self.strategy = strategy
    self.redirectUrl = redirectUrl
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": strategy.encode(),
      "redirectUrl": .string(redirectUrl),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> EmailAddressPrepareVerificationParamsCase2 {
    let values = try value.object()

    return try EmailAddressPrepareVerificationParamsCase2(strategy: EmailAddressPrepareVerificationParamsCase2Strategy.decode(values["strategy"] ?? .undefined, in: runtime), redirectUrl: (values["redirectUrl"] ?? .undefined).string())
  }
}

public enum EmailAddressPrepareVerificationParamsCase2Strategy: Hashable, Sendable {
  case enterpriseSso
  case emailLink
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .enterpriseSso: "enterprise_sso"
    case .emailLink: "email_link"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "enterprise_sso": self = .enterpriseSso
    case "email_link": self = .emailLink
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EmailAddressPrepareVerificationParamsCase2Strategy {
    try .init(rawValue: value.string())
  }
}

public struct AttemptEmailAddressVerificationParams: Sendable {
  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> AttemptEmailAddressVerificationParams {
    let values = try value.object()

    return try AttemptEmailAddressVerificationParams(code: (values["code"] ?? .undefined).string())
  }
}

public struct CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddressState: Sendable {
  public init() {}

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [:]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddressState {
    let values = try value.object()

    return try CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddressState()
  }
}

@MainActor @Observable public final class CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddress: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddressState {
    context.state(handle, as: CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddressState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddressState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddress {
    try runtime.resource(ResourceHandle.decodeReference(value), as: CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddress.self)
  }

  public func startEmailLinkFlow(_ params: StartEmailLinkFlowParams) async throws -> EmailAddress {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddress.startEmailLinkFlow", arguments: [params.encode()])
    return try EmailAddress.decode(result, in: runtime)
  }

  public func cancelEmailLinkFlow() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddress.cancelEmailLinkFlow", arguments: [])
    _ = result
  }
}

public struct StartEmailLinkFlowParams: Sendable {
  public let redirectUrl: String
  public init(redirectUrl: String) {
    self.redirectUrl = redirectUrl
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "redirectUrl": .string(redirectUrl),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> StartEmailLinkFlowParams {
    let values = try value.object()

    return try StartEmailLinkFlowParams(redirectUrl: (values["redirectUrl"] ?? .undefined).string())
  }
}

public struct CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddressState: Sendable {
  public init() {}

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [:]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddressState {
    let values = try value.object()

    return try CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddressState()
  }
}

@MainActor @Observable public final class CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddress: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddressState {
    context.state(handle, as: CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddressState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddressState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddress {
    try runtime.resource(ResourceHandle.decodeReference(value), as: CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddress.self)
  }

  public func startEnterpriseSSOLinkFlow(_ params: StartEnterpriseSSOLinkFlowParams) async throws -> EmailAddress {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddress.startEnterpriseSSOLinkFlow", arguments: [params.encode()])
    return try EmailAddress.decode(result, in: runtime)
  }

  public func cancelEnterpriseSSOLinkFlow() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddress.cancelEnterpriseSSOLinkFlow", arguments: [])
    _ = result
  }
}

public struct StartEnterpriseSSOLinkFlowParams: Sendable {
  public let redirectUrl: String
  public init(redirectUrl: String) {
    self.redirectUrl = redirectUrl
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "redirectUrl": .string(redirectUrl),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> StartEnterpriseSSOLinkFlowParams {
    let values = try value.object()

    return try StartEnterpriseSSOLinkFlowParams(redirectUrl: (values["redirectUrl"] ?? .undefined).string())
  }
}

public struct PhoneNumberState: Sendable {
  public let id: String
  public let phoneNumber: String
  public let verification: Verification
  public let reservedForSecondFactor: Bool
  public let defaultSecondFactor: Bool
  public let linkedTo: [IdentificationLink]
  public init(id: String, phoneNumber: String, verification: Verification, reservedForSecondFactor: Bool, defaultSecondFactor: Bool, linkedTo: [IdentificationLink]) {
    self.id = id
    self.phoneNumber = phoneNumber
    self.verification = verification
    self.reservedForSecondFactor = reservedForSecondFactor
    self.defaultSecondFactor = defaultSecondFactor
    self.linkedTo = linkedTo
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "phoneNumber": .string(phoneNumber),
      "verification": verification.encode(),
      "reservedForSecondFactor": .bool(reservedForSecondFactor),
      "defaultSecondFactor": .bool(defaultSecondFactor),
      "linkedTo": .array(linkedTo.map { value in try value.encode() }),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PhoneNumberState {
    let values = try value.object()

    return try PhoneNumberState(id: (values["id"] ?? .undefined).string(), phoneNumber: (values["phoneNumber"] ?? .undefined).string(), verification: Verification.decode(values["verification"] ?? .undefined, in: runtime), reservedForSecondFactor: (values["reservedForSecondFactor"] ?? .undefined).bool(), defaultSecondFactor: (values["defaultSecondFactor"] ?? .undefined).bool(), linkedTo: (values["linkedTo"] ?? .undefined).array().map { value in try IdentificationLink.decode(value, in: runtime) })
  }
}

@MainActor @Observable public final class PhoneNumber: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: PhoneNumberState {
    context.state(handle, as: PhoneNumberState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var phoneNumber: String {
    state.phoneNumber
  }

  public var verification: Verification {
    state.verification
  }

  public var reservedForSecondFactor: Bool {
    state.reservedForSecondFactor
  }

  public var defaultSecondFactor: Bool {
    state.defaultSecondFactor
  }

  public var linkedTo: [IdentificationLink] {
    state.linkedTo
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try PhoneNumberState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PhoneNumber {
    try runtime.resource(ResourceHandle.decodeReference(value), as: PhoneNumber.self)
  }

  /// Returns a string representation of an object.
  public func stringValue() async throws -> String {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PhoneNumber.toString", arguments: [])
    return try result.string()
  }

  public func prepareVerification() async throws -> PhoneNumber {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PhoneNumber.prepareVerification", arguments: [])
    return try PhoneNumber.decode(result, in: runtime)
  }

  public func attemptVerification(_ params: AttemptPhoneNumberVerificationParams) async throws -> PhoneNumber {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PhoneNumber.attemptVerification", arguments: [params.encode()])
    return try PhoneNumber.decode(result, in: runtime)
  }

  public func makeDefaultSecondFactor() async throws -> PhoneNumber {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PhoneNumber.makeDefaultSecondFactor", arguments: [])
    return try PhoneNumber.decode(result, in: runtime)
  }

  public func setReservedForSecondFactor(_ params: SetReservedForSecondFactorParams) async throws -> PhoneNumber {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PhoneNumber.setReservedForSecondFactor", arguments: [params.encode()])
    return try PhoneNumber.decode(result, in: runtime)
  }

  public func destroy() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PhoneNumber.destroy", arguments: [])
    _ = result
  }

  public func create() async throws -> PhoneNumber {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PhoneNumber.create", arguments: [])
    return try PhoneNumber.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> PhoneNumber {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PhoneNumber.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try PhoneNumber.decode(result, in: runtime)
  }
}

public struct AttemptPhoneNumberVerificationParams: Sendable {
  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> AttemptPhoneNumberVerificationParams {
    let values = try value.object()

    return try AttemptPhoneNumberVerificationParams(code: (values["code"] ?? .undefined).string())
  }
}

public struct SetReservedForSecondFactorParams: Sendable {
  public let reserved: Bool
  public init(reserved: Bool) {
    self.reserved = reserved
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "reserved": .bool(reserved),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SetReservedForSecondFactorParams {
    let values = try value.object()

    return try SetReservedForSecondFactorParams(reserved: (values["reserved"] ?? .undefined).bool())
  }
}

public struct Web3WalletState: Sendable {
  public let id: String
  public let web3Wallet: String
  public let verification: Verification
  public init(id: String, web3Wallet: String, verification: Verification) {
    self.id = id
    self.web3Wallet = web3Wallet
    self.verification = verification
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "web3Wallet": .string(web3Wallet),
      "verification": verification.encode(),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> Web3WalletState {
    let values = try value.object()

    return try Web3WalletState(id: (values["id"] ?? .undefined).string(), web3Wallet: (values["web3Wallet"] ?? .undefined).string(), verification: Verification.decode(values["verification"] ?? .undefined, in: runtime))
  }
}

@MainActor @Observable public final class Web3Wallet: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: Web3WalletState {
    context.state(handle, as: Web3WalletState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var web3Wallet: String {
    state.web3Wallet
  }

  public var verification: Verification {
    state.verification
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try Web3WalletState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> Web3Wallet {
    try runtime.resource(ResourceHandle.decodeReference(value), as: Web3Wallet.self)
  }

  /// Returns a string representation of an object.
  public func stringValue() async throws -> String {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Web3Wallet.toString", arguments: [])
    return try result.string()
  }

  public func prepareVerification(_ params: PrepareWeb3WalletVerificationParams) async throws -> Web3Wallet {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Web3Wallet.prepareVerification", arguments: [params.encode()])
    return try Web3Wallet.decode(result, in: runtime)
  }

  public func attemptVerification(_ params: AttemptWeb3WalletVerificationParams) async throws -> Web3Wallet {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Web3Wallet.attemptVerification", arguments: [params.encode()])
    return try Web3Wallet.decode(result, in: runtime)
  }

  public func destroy() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Web3Wallet.destroy", arguments: [])
    _ = result
  }

  public func create() async throws -> Web3Wallet {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Web3Wallet.create", arguments: [])
    return try Web3Wallet.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> Web3Wallet {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Web3Wallet.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try Web3Wallet.decode(result, in: runtime)
  }
}

public struct PrepareWeb3WalletVerificationParams: Sendable {
  public let strategy: PrepareWeb3WalletVerificationParamsStrategy
  public init(strategy: PrepareWeb3WalletVerificationParamsStrategy) {
    self.strategy = strategy
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": strategy.encode(),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PrepareWeb3WalletVerificationParams {
    let values = try value.object()

    return try PrepareWeb3WalletVerificationParams(strategy: PrepareWeb3WalletVerificationParamsStrategy.decode(values["strategy"] ?? .undefined, in: runtime))
  }
}

public enum PrepareWeb3WalletVerificationParamsStrategy: Hashable, Sendable {
  case web3MetamaskSignature
  case web3BaseSignature
  case web3CoinbaseWalletSignature
  case web3OkxWalletSignature
  case web3SolanaSignature
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .web3MetamaskSignature: "web3_metamask_signature"
    case .web3BaseSignature: "web3_base_signature"
    case .web3CoinbaseWalletSignature: "web3_coinbase_wallet_signature"
    case .web3OkxWalletSignature: "web3_okx_wallet_signature"
    case .web3SolanaSignature: "web3_solana_signature"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "web3_metamask_signature": self = .web3MetamaskSignature
    case "web3_base_signature": self = .web3BaseSignature
    case "web3_coinbase_wallet_signature": self = .web3CoinbaseWalletSignature
    case "web3_okx_wallet_signature": self = .web3OkxWalletSignature
    case "web3_solana_signature": self = .web3SolanaSignature
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> PrepareWeb3WalletVerificationParamsStrategy {
    try .init(rawValue: value.string())
  }
}

public struct AttemptWeb3WalletVerificationParams: Sendable {
  public let signature: String
  public let strategy: PrepareWeb3WalletVerificationParamsStrategy?
  public init(signature: String, strategy: PrepareWeb3WalletVerificationParamsStrategy? = nil) {
    self.signature = signature
    self.strategy = strategy
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "signature": .string(signature),
      "strategy": strategy.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> AttemptWeb3WalletVerificationParams {
    let values = try value.object()

    return try AttemptWeb3WalletVerificationParams(signature: (values["signature"] ?? .undefined).string(), strategy: (values["strategy"] ?? .undefined).optional { value in try PrepareWeb3WalletVerificationParamsStrategy.decode(value, in: runtime) })
  }
}

public struct ExternalAccountState: Sendable {
  public let id: String
  public let identificationId: String
  public let provider: OAuthProvider
  public let providerUserId: String
  public let emailAddress: String
  public let approvedScopes: String
  public let firstName: String
  public let lastName: String
  public let imageUrl: String
  public let username: String?
  public let phoneNumber: String?
  public let publicMetadata: [String: JSONValue]
  public let label: String?
  public let verification: Verification?
  public init(id: String, identificationId: String, provider: OAuthProvider, providerUserId: String, emailAddress: String, approvedScopes: String, firstName: String, lastName: String, imageUrl: String, username: String? = nil, phoneNumber: String? = nil, publicMetadata: [String: JSONValue], label: String? = nil, verification: Verification?) {
    self.id = id
    self.identificationId = identificationId
    self.provider = provider
    self.providerUserId = providerUserId
    self.emailAddress = emailAddress
    self.approvedScopes = approvedScopes
    self.firstName = firstName
    self.lastName = lastName
    self.imageUrl = imageUrl
    self.username = username
    self.phoneNumber = phoneNumber
    self.publicMetadata = publicMetadata
    self.label = label
    self.verification = verification
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "identificationId": .string(identificationId),
      "provider": provider.encode(),
      "providerUserId": .string(providerUserId),
      "emailAddress": .string(emailAddress),
      "approvedScopes": .string(approvedScopes),
      "firstName": .string(firstName),
      "lastName": .string(lastName),
      "imageUrl": .string(imageUrl),
      "username": username.map { value in .string(value) } ?? .undefined,
      "phoneNumber": phoneNumber.map { value in .string(value) } ?? .undefined,
      "publicMetadata": .object(publicMetadata.mapValues { value in value }),
      "label": label.map { value in .string(value) } ?? .undefined,
      "verification": verification.map { value in try value.encode() } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ExternalAccountState {
    let values = try value.object()

    return try ExternalAccountState(id: (values["id"] ?? .undefined).string(), identificationId: (values["identificationId"] ?? .undefined).string(), provider: OAuthProvider.decode(values["provider"] ?? .undefined, in: runtime), providerUserId: (values["providerUserId"] ?? .undefined).string(), emailAddress: (values["emailAddress"] ?? .undefined).string(), approvedScopes: (values["approvedScopes"] ?? .undefined).string(), firstName: (values["firstName"] ?? .undefined).string(), lastName: (values["lastName"] ?? .undefined).string(), imageUrl: (values["imageUrl"] ?? .undefined).string(), username: (values["username"] ?? .undefined).optional { value in try value.string() }, phoneNumber: (values["phoneNumber"] ?? .undefined).optional { value in try value.string() }, publicMetadata: (values["publicMetadata"] ?? .undefined).object().mapValues { value in value }, label: (values["label"] ?? .undefined).optional { value in try value.string() }, verification: (values["verification"] ?? .undefined).optional { value in try Verification.decode(value, in: runtime) })
  }
}

@MainActor @Observable public final class ExternalAccount: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: ExternalAccountState {
    context.state(handle, as: ExternalAccountState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var identificationId: String {
    state.identificationId
  }

  public var provider: OAuthProvider {
    state.provider
  }

  public var providerUserId: String {
    state.providerUserId
  }

  public var emailAddress: String {
    state.emailAddress
  }

  public var approvedScopes: String {
    state.approvedScopes
  }

  public var firstName: String {
    state.firstName
  }

  public var lastName: String {
    state.lastName
  }

  public var imageUrl: String {
    state.imageUrl
  }

  public var username: String? {
    state.username
  }

  public var phoneNumber: String? {
    state.phoneNumber
  }

  public var publicMetadata: [String: JSONValue] {
    state.publicMetadata
  }

  public var label: String? {
    state.label
  }

  public var verification: Verification? {
    state.verification
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try ExternalAccountState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ExternalAccount {
    try runtime.resource(ResourceHandle.decodeReference(value), as: ExternalAccount.self)
  }

  public func reauthorize(_ params: ReauthorizeExternalAccountParams) async throws -> ExternalAccount {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ExternalAccount.reauthorize", arguments: [params.encode()])
    return try ExternalAccount.decode(result, in: runtime)
  }

  public func destroy() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ExternalAccount.destroy", arguments: [])
    _ = result
  }

  public func providerSlug() async throws -> OAuthProvider {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ExternalAccount.providerSlug", arguments: [])
    return try OAuthProvider.decode(result, in: runtime)
  }

  public func providerTitle() async throws -> String {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ExternalAccount.providerTitle", arguments: [])
    return try result.string()
  }

  public func accountIdentifier() async throws -> String {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ExternalAccount.accountIdentifier", arguments: [])
    return try result.string()
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> ExternalAccount {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ExternalAccount.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try ExternalAccount.decode(result, in: runtime)
  }
}

/// Represents the available OAuth providers.
public enum OAuthProvider: Hashable, Sendable {
  case facebook
  case google
  case hubspot
  case github
  case tiktok
  case gitlab
  case discord
  case twitter
  case twitch
  case linkedin
  case linkedinOidc
  case dropbox
  case atlassian
  case bitbucket
  case microsoft
  case notion
  case apple
  case line
  case instagram
  case coinbase
  case spotify
  case xero
  case box
  case slack
  case linear
  case x
  case enstall
  case huggingface
  case vercel
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .facebook: "facebook"
    case .google: "google"
    case .hubspot: "hubspot"
    case .github: "github"
    case .tiktok: "tiktok"
    case .gitlab: "gitlab"
    case .discord: "discord"
    case .twitter: "twitter"
    case .twitch: "twitch"
    case .linkedin: "linkedin"
    case .linkedinOidc: "linkedin_oidc"
    case .dropbox: "dropbox"
    case .atlassian: "atlassian"
    case .bitbucket: "bitbucket"
    case .microsoft: "microsoft"
    case .notion: "notion"
    case .apple: "apple"
    case .line: "line"
    case .instagram: "instagram"
    case .coinbase: "coinbase"
    case .spotify: "spotify"
    case .xero: "xero"
    case .box: "box"
    case .slack: "slack"
    case .linear: "linear"
    case .x: "x"
    case .enstall: "enstall"
    case .huggingface: "huggingface"
    case .vercel: "vercel"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "facebook": self = .facebook
    case "google": self = .google
    case "hubspot": self = .hubspot
    case "github": self = .github
    case "tiktok": self = .tiktok
    case "gitlab": self = .gitlab
    case "discord": self = .discord
    case "twitter": self = .twitter
    case "twitch": self = .twitch
    case "linkedin": self = .linkedin
    case "linkedin_oidc": self = .linkedinOidc
    case "dropbox": self = .dropbox
    case "atlassian": self = .atlassian
    case "bitbucket": self = .bitbucket
    case "microsoft": self = .microsoft
    case "notion": self = .notion
    case "apple": self = .apple
    case "line": self = .line
    case "instagram": self = .instagram
    case "coinbase": self = .coinbase
    case "spotify": self = .spotify
    case "xero": self = .xero
    case "box": self = .box
    case "slack": self = .slack
    case "linear": self = .linear
    case "x": self = .x
    case "enstall": self = .enstall
    case "huggingface": self = .huggingface
    case "vercel": self = .vercel
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OAuthProvider {
    try .init(rawValue: value.string())
  }
}

public struct ReauthorizeExternalAccountParams: Sendable {
  public let additionalScopes: [String]?
  public let redirectUrl: String?
  public let oidcPrompt: String?
  public let oidcLoginHint: String?
  public init(additionalScopes: [String]? = nil, redirectUrl: String? = nil, oidcPrompt: String? = nil, oidcLoginHint: String? = nil) {
    self.additionalScopes = additionalScopes
    self.redirectUrl = redirectUrl
    self.oidcPrompt = oidcPrompt
    self.oidcLoginHint = oidcLoginHint
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "additionalScopes": additionalScopes.map { value in try .array(value.map { value in .string(value) }) } ?? .undefined,
      "redirectUrl": redirectUrl.map { value in .string(value) } ?? .undefined,
      "oidcPrompt": oidcPrompt.map { value in .string(value) } ?? .undefined,
      "oidcLoginHint": oidcLoginHint.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> ReauthorizeExternalAccountParams {
    let values = try value.object()

    return try ReauthorizeExternalAccountParams(additionalScopes: (values["additionalScopes"] ?? .undefined).optional { value in try value.array().map { value in try value.string() } }, redirectUrl: (values["redirectUrl"] ?? .undefined).optional { value in try value.string() }, oidcPrompt: (values["oidcPrompt"] ?? .undefined).optional { value in try value.string() }, oidcLoginHint: (values["oidcLoginHint"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct EnterpriseAccountState: Sendable {
  public let active: Bool
  public let emailAddress: String
  public let enterpriseConnection: EnterpriseAccountConnection?
  public let enterpriseConnectionId: String?
  public let firstName: String?
  public let lastName: String?
  public let `protocol`: EnterpriseProtocol
  public let provider: EnterpriseProvider
  public let providerUserId: String?
  public let publicMetadata: [String: JSONValue]?
  public let verification: Verification?
  public let lastAuthenticatedAt: Date?
  public let id: String?
  public init(active: Bool, emailAddress: String, enterpriseConnection: EnterpriseAccountConnection?, enterpriseConnectionId: String?, firstName: String?, lastName: String?, protocol: EnterpriseProtocol, provider: EnterpriseProvider, providerUserId: String?, publicMetadata: [String: JSONValue]?, verification: Verification?, lastAuthenticatedAt: Date?, id: String? = nil) {
    self.active = active
    self.emailAddress = emailAddress
    self.enterpriseConnection = enterpriseConnection
    self.enterpriseConnectionId = enterpriseConnectionId
    self.firstName = firstName
    self.lastName = lastName
    self.protocol = `protocol`
    self.provider = provider
    self.providerUserId = providerUserId
    self.publicMetadata = publicMetadata
    self.verification = verification
    self.lastAuthenticatedAt = lastAuthenticatedAt
    self.id = id
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "active": .bool(active),
      "emailAddress": .string(emailAddress),
      "enterpriseConnection": enterpriseConnection.map { value in try value.encode() } ?? .null,
      "enterpriseConnectionId": enterpriseConnectionId.map { value in .string(value) } ?? .null,
      "firstName": firstName.map { value in .string(value) } ?? .null,
      "lastName": lastName.map { value in .string(value) } ?? .null,
      "protocol": self.protocol.encode(),
      "provider": provider.encode(),
      "providerUserId": providerUserId.map { value in .string(value) } ?? .null,
      "publicMetadata": publicMetadata.map { value in try .object(value.mapValues { value in value }) } ?? .null,
      "verification": verification.map { value in try value.encode() } ?? .null,
      "lastAuthenticatedAt": lastAuthenticatedAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "id": id.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> EnterpriseAccountState {
    let values = try value.object()

    return try EnterpriseAccountState(active: (values["active"] ?? .undefined).bool(), emailAddress: (values["emailAddress"] ?? .undefined).string(), enterpriseConnection: (values["enterpriseConnection"] ?? .undefined).optional { value in try EnterpriseAccountConnection.decode(value, in: runtime) }, enterpriseConnectionId: (values["enterpriseConnectionId"] ?? .undefined).optional { value in try value.string() }, firstName: (values["firstName"] ?? .undefined).optional { value in try value.string() }, lastName: (values["lastName"] ?? .undefined).optional { value in try value.string() }, protocol: EnterpriseProtocol.decode(values["protocol"] ?? .undefined, in: runtime), provider: EnterpriseProvider.decode(values["provider"] ?? .undefined, in: runtime), providerUserId: (values["providerUserId"] ?? .undefined).optional { value in try value.string() }, publicMetadata: (values["publicMetadata"] ?? .undefined).optional { value in try value.object().mapValues { value in value } }, verification: (values["verification"] ?? .undefined).optional { value in try Verification.decode(value, in: runtime) }, lastAuthenticatedAt: (values["lastAuthenticatedAt"] ?? .undefined).optional { value in try value.date() }, id: (values["id"] ?? .undefined).optional { value in try value.string() })
  }
}

@MainActor @Observable public final class EnterpriseAccount: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: EnterpriseAccountState {
    context.state(handle, as: EnterpriseAccountState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var active: Bool {
    state.active
  }

  public var emailAddress: String {
    state.emailAddress
  }

  public var enterpriseConnection: EnterpriseAccountConnection? {
    state.enterpriseConnection
  }

  public var enterpriseConnectionId: String? {
    state.enterpriseConnectionId
  }

  public var firstName: String? {
    state.firstName
  }

  public var lastName: String? {
    state.lastName
  }

  public var `protocol`: EnterpriseProtocol {
    state.protocol
  }

  public var provider: EnterpriseProvider {
    state.provider
  }

  public var providerUserId: String? {
    state.providerUserId
  }

  public var publicMetadata: [String: JSONValue]? {
    state.publicMetadata
  }

  public var verification: Verification? {
    state.verification
  }

  public var lastAuthenticatedAt: Date? {
    state.lastAuthenticatedAt
  }

  public var id: String? {
    state.id
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try EnterpriseAccountState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> EnterpriseAccount {
    try runtime.resource(ResourceHandle.decodeReference(value), as: EnterpriseAccount.self)
  }

  public func destroy() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "EnterpriseAccount.destroy", arguments: [])
    _ = result
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> EnterpriseAccount {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "EnterpriseAccount.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try EnterpriseAccount.decode(result, in: runtime)
  }
}

public struct EnterpriseAccountConnectionState: Sendable {
  public let active: Bool
  public let allowIdpInitiated: Bool
  public let allowSubdomains: Bool
  public let disableAdditionalIdentifications: Bool
  public let domain: String
  public let logoPublicUrl: String?
  public let name: String
  public let `protocol`: EnterpriseProtocol
  public let provider: EnterpriseProvider
  public let syncUserAttributes: Bool
  public let allowOrganizationAccountLinking: Bool
  public let enterpriseConnectionId: String?
  public let id: String?
  public init(active: Bool, allowIdpInitiated: Bool, allowSubdomains: Bool, disableAdditionalIdentifications: Bool, domain: String, logoPublicUrl: String?, name: String, protocol: EnterpriseProtocol, provider: EnterpriseProvider, syncUserAttributes: Bool, allowOrganizationAccountLinking: Bool, enterpriseConnectionId: String?, id: String? = nil) {
    self.active = active
    self.allowIdpInitiated = allowIdpInitiated
    self.allowSubdomains = allowSubdomains
    self.disableAdditionalIdentifications = disableAdditionalIdentifications
    self.domain = domain
    self.logoPublicUrl = logoPublicUrl
    self.name = name
    self.protocol = `protocol`
    self.provider = provider
    self.syncUserAttributes = syncUserAttributes
    self.allowOrganizationAccountLinking = allowOrganizationAccountLinking
    self.enterpriseConnectionId = enterpriseConnectionId
    self.id = id
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "active": .bool(active),
      "allowIdpInitiated": .bool(allowIdpInitiated),
      "allowSubdomains": .bool(allowSubdomains),
      "disableAdditionalIdentifications": .bool(disableAdditionalIdentifications),
      "domain": .string(domain),
      "logoPublicUrl": logoPublicUrl.map { value in .string(value) } ?? .null,
      "name": .string(name),
      "protocol": self.protocol.encode(),
      "provider": provider.encode(),
      "syncUserAttributes": .bool(syncUserAttributes),
      "allowOrganizationAccountLinking": .bool(allowOrganizationAccountLinking),
      "enterpriseConnectionId": enterpriseConnectionId.map { value in .string(value) } ?? .null,
      "id": id.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> EnterpriseAccountConnectionState {
    let values = try value.object()

    return try EnterpriseAccountConnectionState(active: (values["active"] ?? .undefined).bool(), allowIdpInitiated: (values["allowIdpInitiated"] ?? .undefined).bool(), allowSubdomains: (values["allowSubdomains"] ?? .undefined).bool(), disableAdditionalIdentifications: (values["disableAdditionalIdentifications"] ?? .undefined).bool(), domain: (values["domain"] ?? .undefined).string(), logoPublicUrl: (values["logoPublicUrl"] ?? .undefined).optional { value in try value.string() }, name: (values["name"] ?? .undefined).string(), protocol: EnterpriseProtocol.decode(values["protocol"] ?? .undefined, in: runtime), provider: EnterpriseProvider.decode(values["provider"] ?? .undefined, in: runtime), syncUserAttributes: (values["syncUserAttributes"] ?? .undefined).bool(), allowOrganizationAccountLinking: (values["allowOrganizationAccountLinking"] ?? .undefined).bool(), enterpriseConnectionId: (values["enterpriseConnectionId"] ?? .undefined).optional { value in try value.string() }, id: (values["id"] ?? .undefined).optional { value in try value.string() })
  }
}

@MainActor @Observable public final class EnterpriseAccountConnection: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: EnterpriseAccountConnectionState {
    context.state(handle, as: EnterpriseAccountConnectionState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var active: Bool {
    state.active
  }

  public var allowIdpInitiated: Bool {
    state.allowIdpInitiated
  }

  public var allowSubdomains: Bool {
    state.allowSubdomains
  }

  public var disableAdditionalIdentifications: Bool {
    state.disableAdditionalIdentifications
  }

  public var domain: String {
    state.domain
  }

  public var logoPublicUrl: String? {
    state.logoPublicUrl
  }

  public var name: String {
    state.name
  }

  public var `protocol`: EnterpriseProtocol {
    state.protocol
  }

  public var provider: EnterpriseProvider {
    state.provider
  }

  public var syncUserAttributes: Bool {
    state.syncUserAttributes
  }

  public var allowOrganizationAccountLinking: Bool {
    state.allowOrganizationAccountLinking
  }

  public var enterpriseConnectionId: String? {
    state.enterpriseConnectionId
  }

  public var id: String? {
    state.id
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try EnterpriseAccountConnectionState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> EnterpriseAccountConnection {
    try runtime.resource(ResourceHandle.decodeReference(value), as: EnterpriseAccountConnection.self)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> EnterpriseAccountConnection {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "EnterpriseAccountConnection.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try EnterpriseAccountConnection.decode(result, in: runtime)
  }
}

public enum EnterpriseProtocol: Hashable, Sendable {
  case saml
  case oauth
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .saml: "saml"
    case .oauth: "oauth"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "saml": self = .saml
    case "oauth": self = .oauth
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EnterpriseProtocol {
    try .init(rawValue: value.string())
  }
}

public enum EnterpriseProvider: Hashable, Sendable {
  case samlCustom
  case samlOkta
  case samlGoogle
  case samlMicrosoft
  case oauthFacebook
  case oauthGoogle
  case oauthHubspot
  case oauthGithub
  case oauthTiktok
  case oauthGitlab
  case oauthDiscord
  case oauthTwitter
  case oauthTwitch
  case oauthLinkedin
  case oauthLinkedinOidc
  case oauthDropbox
  case oauthAtlassian
  case oauthBitbucket
  case oauthMicrosoft
  case oauthNotion
  case oauthApple
  case oauthLine
  case oauthInstagram
  case oauthCoinbase
  case oauthSpotify
  case oauthXero
  case oauthBox
  case oauthSlack
  case oauthLinear
  case oauthX
  case oauthEnstall
  case oauthHuggingface
  case oauthVercel
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .samlCustom: "saml_custom"
    case .samlOkta: "saml_okta"
    case .samlGoogle: "saml_google"
    case .samlMicrosoft: "saml_microsoft"
    case .oauthFacebook: "oauth_facebook"
    case .oauthGoogle: "oauth_google"
    case .oauthHubspot: "oauth_hubspot"
    case .oauthGithub: "oauth_github"
    case .oauthTiktok: "oauth_tiktok"
    case .oauthGitlab: "oauth_gitlab"
    case .oauthDiscord: "oauth_discord"
    case .oauthTwitter: "oauth_twitter"
    case .oauthTwitch: "oauth_twitch"
    case .oauthLinkedin: "oauth_linkedin"
    case .oauthLinkedinOidc: "oauth_linkedin_oidc"
    case .oauthDropbox: "oauth_dropbox"
    case .oauthAtlassian: "oauth_atlassian"
    case .oauthBitbucket: "oauth_bitbucket"
    case .oauthMicrosoft: "oauth_microsoft"
    case .oauthNotion: "oauth_notion"
    case .oauthApple: "oauth_apple"
    case .oauthLine: "oauth_line"
    case .oauthInstagram: "oauth_instagram"
    case .oauthCoinbase: "oauth_coinbase"
    case .oauthSpotify: "oauth_spotify"
    case .oauthXero: "oauth_xero"
    case .oauthBox: "oauth_box"
    case .oauthSlack: "oauth_slack"
    case .oauthLinear: "oauth_linear"
    case .oauthX: "oauth_x"
    case .oauthEnstall: "oauth_enstall"
    case .oauthHuggingface: "oauth_huggingface"
    case .oauthVercel: "oauth_vercel"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "saml_custom": self = .samlCustom
    case "saml_okta": self = .samlOkta
    case "saml_google": self = .samlGoogle
    case "saml_microsoft": self = .samlMicrosoft
    case "oauth_facebook": self = .oauthFacebook
    case "oauth_google": self = .oauthGoogle
    case "oauth_hubspot": self = .oauthHubspot
    case "oauth_github": self = .oauthGithub
    case "oauth_tiktok": self = .oauthTiktok
    case "oauth_gitlab": self = .oauthGitlab
    case "oauth_discord": self = .oauthDiscord
    case "oauth_twitter": self = .oauthTwitter
    case "oauth_twitch": self = .oauthTwitch
    case "oauth_linkedin": self = .oauthLinkedin
    case "oauth_linkedin_oidc": self = .oauthLinkedinOidc
    case "oauth_dropbox": self = .oauthDropbox
    case "oauth_atlassian": self = .oauthAtlassian
    case "oauth_bitbucket": self = .oauthBitbucket
    case "oauth_microsoft": self = .oauthMicrosoft
    case "oauth_notion": self = .oauthNotion
    case "oauth_apple": self = .oauthApple
    case "oauth_line": self = .oauthLine
    case "oauth_instagram": self = .oauthInstagram
    case "oauth_coinbase": self = .oauthCoinbase
    case "oauth_spotify": self = .oauthSpotify
    case "oauth_xero": self = .oauthXero
    case "oauth_box": self = .oauthBox
    case "oauth_slack": self = .oauthSlack
    case "oauth_linear": self = .oauthLinear
    case "oauth_x": self = .oauthX
    case "oauth_enstall": self = .oauthEnstall
    case "oauth_huggingface": self = .oauthHuggingface
    case "oauth_vercel": self = .oauthVercel
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EnterpriseProvider {
    try .init(rawValue: value.string())
  }
}

public struct PasskeyState: Sendable {
  public let id: String
  public let name: String?
  public let verification: PasskeyVerification?
  public let lastUsedAt: Date?
  public let updatedAt: Date
  public let createdAt: Date
  public init(id: String, name: String?, verification: PasskeyVerification?, lastUsedAt: Date?, updatedAt: Date, createdAt: Date) {
    self.id = id
    self.name = name
    self.verification = verification
    self.lastUsedAt = lastUsedAt
    self.updatedAt = updatedAt
    self.createdAt = createdAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "name": name.map { value in .string(value) } ?? .null,
      "verification": verification.map { value in try value.encode() } ?? .null,
      "lastUsedAt": lastUsedAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "updatedAt": .string(updatedAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "createdAt": .string(createdAt.ISO8601Format(.init(includingFractionalSeconds: true))),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PasskeyState {
    let values = try value.object()

    return try PasskeyState(id: (values["id"] ?? .undefined).string(), name: (values["name"] ?? .undefined).optional { value in try value.string() }, verification: (values["verification"] ?? .undefined).optional { value in try PasskeyVerification.decode(value, in: runtime) }, lastUsedAt: (values["lastUsedAt"] ?? .undefined).optional { value in try value.date() }, updatedAt: (values["updatedAt"] ?? .undefined).date(), createdAt: (values["createdAt"] ?? .undefined).date())
  }
}

@MainActor @Observable public final class Passkey: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: PasskeyState {
    context.state(handle, as: PasskeyState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var name: String? {
    state.name
  }

  public var verification: PasskeyVerification? {
    state.verification
  }

  public var lastUsedAt: Date? {
    state.lastUsedAt
  }

  public var updatedAt: Date {
    state.updatedAt
  }

  public var createdAt: Date {
    state.createdAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try PasskeyState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> Passkey {
    try runtime.resource(ResourceHandle.decodeReference(value), as: Passkey.self)
  }

  public func update(_ params: Partialtype) async throws -> Passkey {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Passkey.update", arguments: [params.encode()])
    return try Passkey.decode(result, in: runtime)
  }

  public func delete() async throws -> DeletedObject {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Passkey.delete", arguments: [])
    return try DeletedObject.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> Passkey {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Passkey.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try Passkey.decode(result, in: runtime)
  }
}

public struct PasskeyVerificationState: Sendable {
  public let attempts: Double?
  public let error: ClerkAPIError?
  public let expireAt: Date?
  public let status: VerificationStatus?
  public let strategy: String?
  public let verifiedAtClient: String?
  public let channel: PhoneCodeChannel?
  public let id: String?
  public init(attempts: Double?, error: ClerkAPIError?, expireAt: Date?, status: VerificationStatus?, strategy: String?, verifiedAtClient: String?, channel: PhoneCodeChannel? = nil, id: String? = nil) {
    self.attempts = attempts
    self.error = error
    self.expireAt = expireAt
    self.status = status
    self.strategy = strategy
    self.verifiedAtClient = verifiedAtClient
    self.channel = channel
    self.id = id
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "attempts": attempts.map { value in .number(value) } ?? .null,
      "error": error.map { value in try value.encode() } ?? .null,
      "expireAt": expireAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "status": status.map { value in try value.encode() } ?? .null,
      "strategy": strategy.map { value in .string(value) } ?? .null,
      "verifiedAtClient": verifiedAtClient.map { value in .string(value) } ?? .null,
      "channel": channel.map { value in try value.encode() } ?? .undefined,
      "id": id.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PasskeyVerificationState {
    let values = try value.object()

    return try PasskeyVerificationState(attempts: (values["attempts"] ?? .undefined).optional { value in try value.number() }, error: (values["error"] ?? .undefined).optional { value in try ClerkAPIError.decode(value, in: runtime) }, expireAt: (values["expireAt"] ?? .undefined).optional { value in try value.date() }, status: (values["status"] ?? .undefined).optional { value in try VerificationStatus.decode(value, in: runtime) }, strategy: (values["strategy"] ?? .undefined).optional { value in try value.string() }, verifiedAtClient: (values["verifiedAtClient"] ?? .undefined).optional { value in try value.string() }, channel: (values["channel"] ?? .undefined).optional { value in try PhoneCodeChannel.decode(value, in: runtime) }, id: (values["id"] ?? .undefined).optional { value in try value.string() })
  }
}

@MainActor @Observable public final class PasskeyVerification: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: PasskeyVerificationState {
    context.state(handle, as: PasskeyVerificationState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var attempts: Double? {
    state.attempts
  }

  public var error: ClerkAPIError? {
    state.error
  }

  public var expireAt: Date? {
    state.expireAt
  }

  public var status: VerificationStatus? {
    state.status
  }

  public var strategy: String? {
    state.strategy
  }

  public var verifiedAtClient: String? {
    state.verifiedAtClient
  }

  public var channel: PhoneCodeChannel? {
    state.channel
  }

  public var id: String? {
    state.id
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try PasskeyVerificationState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PasskeyVerification {
    try runtime.resource(ResourceHandle.decodeReference(value), as: PasskeyVerification.self)
  }

  public func verifiedFromTheSameClient() async throws -> Bool {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PasskeyVerification.verifiedFromTheSameClient", arguments: [])
    return try result.bool()
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> PasskeyVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PasskeyVerification.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try PasskeyVerification.decode(result, in: runtime)
  }
}

/// Make all properties in T optional
public struct Partialtype: Sendable {
  public let name: Field<String>
  public init(name: Field<String> = .omitted) {
    self.name = name
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "name": name.encode { value in .string(value) },
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> Partialtype {
    let values = try value.object()

    return try Partialtype(name: Field.decode(values["name"] ?? .undefined) { value in try value.string() })
  }
}

public struct UpdateUserParams: Sendable {
  public let username: Field<String>
  public let firstName: Field<String>
  public let lastName: Field<String>
  public let primaryEmailAddressId: Field<String>
  public let primaryPhoneNumberId: Field<String>
  public let primaryWeb3WalletId: Field<String>
  public let unsafeMetadata: [String: JSONValue]?
  public init(username: Field<String> = .omitted, firstName: Field<String> = .omitted, lastName: Field<String> = .omitted, primaryEmailAddressId: Field<String> = .omitted, primaryPhoneNumberId: Field<String> = .omitted, primaryWeb3WalletId: Field<String> = .omitted, unsafeMetadata: [String: JSONValue]? = nil) {
    self.username = username
    self.firstName = firstName
    self.lastName = lastName
    self.primaryEmailAddressId = primaryEmailAddressId
    self.primaryPhoneNumberId = primaryPhoneNumberId
    self.primaryWeb3WalletId = primaryWeb3WalletId
    self.unsafeMetadata = unsafeMetadata
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "username": username.encode { value in .string(value) },
      "firstName": firstName.encode { value in .string(value) },
      "lastName": lastName.encode { value in .string(value) },
      "primaryEmailAddressId": primaryEmailAddressId.encode { value in .string(value) },
      "primaryPhoneNumberId": primaryPhoneNumberId.encode { value in .string(value) },
      "primaryWeb3WalletId": primaryWeb3WalletId.encode { value in .string(value) },
      "unsafeMetadata": unsafeMetadata.map { value in .object(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> UpdateUserParams {
    let values = try value.object()

    return try UpdateUserParams(username: Field.decode(values["username"] ?? .undefined) { value in try value.string() }, firstName: Field.decode(values["firstName"] ?? .undefined) { value in try value.string() }, lastName: Field.decode(values["lastName"] ?? .undefined) { value in try value.string() }, primaryEmailAddressId: Field.decode(values["primaryEmailAddressId"] ?? .undefined) { value in try value.string() }, primaryPhoneNumberId: Field.decode(values["primaryPhoneNumberId"] ?? .undefined) { value in try value.string() }, primaryWeb3WalletId: Field.decode(values["primaryWeb3WalletId"] ?? .undefined) { value in try value.string() }, unsafeMetadata: (values["unsafeMetadata"] ?? .undefined).optional { value in try value.object() })
  }
}

public struct UpdateUserMetadataParams: Sendable {
  public let unsafeMetadata: [String: JSONValue]
  public init(unsafeMetadata: [String: JSONValue]) {
    self.unsafeMetadata = unsafeMetadata
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "unsafeMetadata": .object(unsafeMetadata),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> UpdateUserMetadataParams {
    let values = try value.object()

    return try UpdateUserMetadataParams(unsafeMetadata: (values["unsafeMetadata"] ?? .undefined).object())
  }
}

public struct UpdateUserPasswordParams: Sendable {
  public let newPassword: String
  public let currentPassword: String?
  public let signOutOfOtherSessions: Bool?
  public init(newPassword: String, currentPassword: String? = nil, signOutOfOtherSessions: Bool? = nil) {
    self.newPassword = newPassword
    self.currentPassword = currentPassword
    self.signOutOfOtherSessions = signOutOfOtherSessions
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "newPassword": .string(newPassword),
      "currentPassword": currentPassword.map { value in .string(value) } ?? .undefined,
      "signOutOfOtherSessions": signOutOfOtherSessions.map { value in .bool(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> UpdateUserPasswordParams {
    let values = try value.object()

    return try UpdateUserPasswordParams(newPassword: (values["newPassword"] ?? .undefined).string(), currentPassword: (values["currentPassword"] ?? .undefined).optional { value in try value.string() }, signOutOfOtherSessions: (values["signOutOfOtherSessions"] ?? .undefined).optional { value in try value.bool() })
  }
}

public struct RemoveUserPasswordParams: Sendable {
  public let currentPassword: String?
  public init(currentPassword: String? = nil) {
    self.currentPassword = currentPassword
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "currentPassword": currentPassword.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> RemoveUserPasswordParams {
    let values = try value.object()

    return try RemoveUserPasswordParams(currentPassword: (values["currentPassword"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct CreateEmailAddressParams: Sendable {
  public let email: String
  public init(email: String) {
    self.email = email
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "email": .string(email),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> CreateEmailAddressParams {
    let values = try value.object()

    return try CreateEmailAddressParams(email: (values["email"] ?? .undefined).string())
  }
}

public struct CreatePhoneNumberParams: Sendable {
  public let phoneNumber: String
  public init(phoneNumber: String) {
    self.phoneNumber = phoneNumber
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "phoneNumber": .string(phoneNumber),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> CreatePhoneNumberParams {
    let values = try value.object()

    return try CreatePhoneNumberParams(phoneNumber: (values["phoneNumber"] ?? .undefined).string())
  }
}

public struct CreateWeb3WalletParams: Sendable {
  public let web3Wallet: String
  public init(web3Wallet: String) {
    self.web3Wallet = web3Wallet
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "web3Wallet": .string(web3Wallet),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> CreateWeb3WalletParams {
    let values = try value.object()

    return try CreateWeb3WalletParams(web3Wallet: (values["web3Wallet"] ?? .undefined).string())
  }
}

public indirect enum UserIsPrimaryIdentificationIdent: Sendable {
  case case1(EmailAddress)
  case case2(PhoneNumber)
  case case3(Web3Wallet)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    case .case3(let value): try .object(["$case": .number(2), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> UserIsPrimaryIdentificationIdent {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(EmailAddress.decode(payload, in: runtime))
    case 1: return try .case2(PhoneNumber.decode(payload, in: runtime))
    case 2: return try .case3(Web3Wallet.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct SessionWithActivitiesState: Sendable {
  public let id: String
  public let status: String
  public let expireAt: Date
  public let abandonAt: Date
  public let lastActiveAt: Date
  public let latestActivity: SessionActivity
  public let `actor`: [String: JSONValue]?
  public init(id: String, status: String, expireAt: Date, abandonAt: Date, lastActiveAt: Date, latestActivity: SessionActivity, actor: [String: JSONValue]?) {
    self.id = id
    self.status = status
    self.expireAt = expireAt
    self.abandonAt = abandonAt
    self.lastActiveAt = lastActiveAt
    self.latestActivity = latestActivity
    self.actor = actor
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "status": .string(status),
      "expireAt": .string(expireAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "abandonAt": .string(abandonAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "lastActiveAt": .string(lastActiveAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "latestActivity": latestActivity.encode(),
      "actor": actor.map { value in .object(value) } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionWithActivitiesState {
    let values = try value.object()

    return try SessionWithActivitiesState(id: (values["id"] ?? .undefined).string(), status: (values["status"] ?? .undefined).string(), expireAt: (values["expireAt"] ?? .undefined).date(), abandonAt: (values["abandonAt"] ?? .undefined).date(), lastActiveAt: (values["lastActiveAt"] ?? .undefined).date(), latestActivity: SessionActivity.decode(values["latestActivity"] ?? .undefined, in: runtime), actor: (values["actor"] ?? .undefined).optional { value in try value.object() })
  }
}

@MainActor @Observable public final class SessionWithActivities: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: SessionWithActivitiesState {
    context.state(handle, as: SessionWithActivitiesState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var status: String {
    state.status
  }

  public var expireAt: Date {
    state.expireAt
  }

  public var abandonAt: Date {
    state.abandonAt
  }

  public var lastActiveAt: Date {
    state.lastActiveAt
  }

  public var latestActivity: SessionActivity {
    state.latestActivity
  }

  public var `actor`: [String: JSONValue]? {
    state.actor
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try SessionWithActivitiesState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionWithActivities {
    try runtime.resource(ResourceHandle.decodeReference(value), as: SessionWithActivities.self)
  }

  public func revoke() async throws -> SessionWithActivities {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SessionWithActivities.revoke", arguments: [])
    return try SessionWithActivities.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> SessionWithActivities {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SessionWithActivities.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try SessionWithActivities.decode(result, in: runtime)
  }
}

public struct SessionActivity: Sendable {
  public let id: String
  public let browserName: String?
  public let browserVersion: String?
  public let deviceType: String?
  public let ipAddress: String?
  public let city: String?
  public let country: String?
  public let isMobile: Bool?
  public init(id: String, browserName: String? = nil, browserVersion: String? = nil, deviceType: String? = nil, ipAddress: String? = nil, city: String? = nil, country: String? = nil, isMobile: Bool? = nil) {
    self.id = id
    self.browserName = browserName
    self.browserVersion = browserVersion
    self.deviceType = deviceType
    self.ipAddress = ipAddress
    self.city = city
    self.country = country
    self.isMobile = isMobile
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "browserName": browserName.map { value in .string(value) } ?? .undefined,
      "browserVersion": browserVersion.map { value in .string(value) } ?? .undefined,
      "deviceType": deviceType.map { value in .string(value) } ?? .undefined,
      "ipAddress": ipAddress.map { value in .string(value) } ?? .undefined,
      "city": city.map { value in .string(value) } ?? .undefined,
      "country": country.map { value in .string(value) } ?? .undefined,
      "isMobile": isMobile.map { value in .bool(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SessionActivity {
    let values = try value.object()

    return try SessionActivity(id: (values["id"] ?? .undefined).string(), browserName: (values["browserName"] ?? .undefined).optional { value in try value.string() }, browserVersion: (values["browserVersion"] ?? .undefined).optional { value in try value.string() }, deviceType: (values["deviceType"] ?? .undefined).optional { value in try value.string() }, ipAddress: (values["ipAddress"] ?? .undefined).optional { value in try value.string() }, city: (values["city"] ?? .undefined).optional { value in try value.string() }, country: (values["country"] ?? .undefined).optional { value in try value.string() }, isMobile: (values["isMobile"] ?? .undefined).optional { value in try value.bool() })
  }
}

public struct SetProfileImageParams: Sendable {
  public let file: SetOrganizationLogoParamsFile?
  public init(file: SetOrganizationLogoParamsFile?) {
    self.file = file
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "file": file.map { value in try value.encode() } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SetProfileImageParams {
    let values = try value.object()

    return try SetProfileImageParams(file: (values["file"] ?? .undefined).optional { value in try SetOrganizationLogoParamsFile.decode(value, in: runtime) })
  }
}

/// Represents information about an image.
public struct ImageState: Sendable {
  public let id: String?
  public let name: String?
  public let publicUrl: String?
  public init(id: String? = nil, name: String?, publicUrl: String?) {
    self.id = id
    self.name = name
    self.publicUrl = publicUrl
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": id.map { value in .string(value) } ?? .undefined,
      "name": name.map { value in .string(value) } ?? .null,
      "publicUrl": publicUrl.map { value in .string(value) } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> ImageState {
    let values = try value.object()

    return try ImageState(id: (values["id"] ?? .undefined).optional { value in try value.string() }, name: (values["name"] ?? .undefined).optional { value in try value.string() }, publicUrl: (values["publicUrl"] ?? .undefined).optional { value in try value.string() })
  }
}

@MainActor @Observable public final class Image: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: ImageState {
    context.state(handle, as: ImageState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String? {
    state.id
  }

  public var name: String? {
    state.name
  }

  public var publicUrl: String? {
    state.publicUrl
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try ImageState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> Image {
    try runtime.resource(ResourceHandle.decodeReference(value), as: Image.self)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> Image {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "Image.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try Image.decode(result, in: runtime)
  }
}

public struct CreateExternalAccountParams: Sendable {
  public let strategy: OAuthStrategy?
  public let enterpriseConnectionId: String?
  public let redirectUrl: String?
  public let additionalScopes: [String]?
  public let oidcPrompt: String?
  public let oidcLoginHint: String?
  public init(strategy: OAuthStrategy? = nil, enterpriseConnectionId: String? = nil, redirectUrl: String? = nil, additionalScopes: [String]? = nil, oidcPrompt: String? = nil, oidcLoginHint: String? = nil) {
    self.strategy = strategy
    self.enterpriseConnectionId = enterpriseConnectionId
    self.redirectUrl = redirectUrl
    self.additionalScopes = additionalScopes
    self.oidcPrompt = oidcPrompt
    self.oidcLoginHint = oidcLoginHint
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": strategy.map { value in try value.encode() } ?? .undefined,
      "enterpriseConnectionId": enterpriseConnectionId.map { value in .string(value) } ?? .undefined,
      "redirectUrl": redirectUrl.map { value in .string(value) } ?? .undefined,
      "additionalScopes": additionalScopes.map { value in try .array(value.map { value in .string(value) }) } ?? .undefined,
      "oidcPrompt": oidcPrompt.map { value in .string(value) } ?? .undefined,
      "oidcLoginHint": oidcLoginHint.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> CreateExternalAccountParams {
    let values = try value.object()

    return try CreateExternalAccountParams(strategy: (values["strategy"] ?? .undefined).optional { value in try OAuthStrategy.decode(value, in: runtime) }, enterpriseConnectionId: (values["enterpriseConnectionId"] ?? .undefined).optional { value in try value.string() }, redirectUrl: (values["redirectUrl"] ?? .undefined).optional { value in try value.string() }, additionalScopes: (values["additionalScopes"] ?? .undefined).optional { value in try value.array().map { value in try value.string() } }, oidcPrompt: (values["oidcPrompt"] ?? .undefined).optional { value in try value.string() }, oidcLoginHint: (values["oidcLoginHint"] ?? .undefined).optional { value in try value.string() })
  }
}

/// OAuth-related authentication strategies (`oauth_<provider>` and custom OAuth).
public enum OAuthStrategy: Hashable, Sendable {
  case oauthFacebook
  case oauthGoogle
  case oauthHubspot
  case oauthGithub
  case oauthTiktok
  case oauthGitlab
  case oauthDiscord
  case oauthTwitter
  case oauthTwitch
  case oauthLinkedin
  case oauthLinkedinOidc
  case oauthDropbox
  case oauthAtlassian
  case oauthBitbucket
  case oauthMicrosoft
  case oauthNotion
  case oauthApple
  case oauthLine
  case oauthInstagram
  case oauthCoinbase
  case oauthSpotify
  case oauthXero
  case oauthBox
  case oauthSlack
  case oauthLinear
  case oauthX
  case oauthEnstall
  case oauthHuggingface
  case oauthVercel
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .oauthFacebook: "oauth_facebook"
    case .oauthGoogle: "oauth_google"
    case .oauthHubspot: "oauth_hubspot"
    case .oauthGithub: "oauth_github"
    case .oauthTiktok: "oauth_tiktok"
    case .oauthGitlab: "oauth_gitlab"
    case .oauthDiscord: "oauth_discord"
    case .oauthTwitter: "oauth_twitter"
    case .oauthTwitch: "oauth_twitch"
    case .oauthLinkedin: "oauth_linkedin"
    case .oauthLinkedinOidc: "oauth_linkedin_oidc"
    case .oauthDropbox: "oauth_dropbox"
    case .oauthAtlassian: "oauth_atlassian"
    case .oauthBitbucket: "oauth_bitbucket"
    case .oauthMicrosoft: "oauth_microsoft"
    case .oauthNotion: "oauth_notion"
    case .oauthApple: "oauth_apple"
    case .oauthLine: "oauth_line"
    case .oauthInstagram: "oauth_instagram"
    case .oauthCoinbase: "oauth_coinbase"
    case .oauthSpotify: "oauth_spotify"
    case .oauthXero: "oauth_xero"
    case .oauthBox: "oauth_box"
    case .oauthSlack: "oauth_slack"
    case .oauthLinear: "oauth_linear"
    case .oauthX: "oauth_x"
    case .oauthEnstall: "oauth_enstall"
    case .oauthHuggingface: "oauth_huggingface"
    case .oauthVercel: "oauth_vercel"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "oauth_facebook": self = .oauthFacebook
    case "oauth_google": self = .oauthGoogle
    case "oauth_hubspot": self = .oauthHubspot
    case "oauth_github": self = .oauthGithub
    case "oauth_tiktok": self = .oauthTiktok
    case "oauth_gitlab": self = .oauthGitlab
    case "oauth_discord": self = .oauthDiscord
    case "oauth_twitter": self = .oauthTwitter
    case "oauth_twitch": self = .oauthTwitch
    case "oauth_linkedin": self = .oauthLinkedin
    case "oauth_linkedin_oidc": self = .oauthLinkedinOidc
    case "oauth_dropbox": self = .oauthDropbox
    case "oauth_atlassian": self = .oauthAtlassian
    case "oauth_bitbucket": self = .oauthBitbucket
    case "oauth_microsoft": self = .oauthMicrosoft
    case "oauth_notion": self = .oauthNotion
    case "oauth_apple": self = .oauthApple
    case "oauth_line": self = .oauthLine
    case "oauth_instagram": self = .oauthInstagram
    case "oauth_coinbase": self = .oauthCoinbase
    case "oauth_spotify": self = .oauthSpotify
    case "oauth_xero": self = .oauthXero
    case "oauth_box": self = .oauthBox
    case "oauth_slack": self = .oauthSlack
    case "oauth_linear": self = .oauthLinear
    case "oauth_x": self = .oauthX
    case "oauth_enstall": self = .oauthEnstall
    case "oauth_huggingface": self = .oauthHuggingface
    case "oauth_vercel": self = .oauthVercel
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OAuthStrategy {
    try .init(rawValue: value.string())
  }
}

public struct GetUserOrganizationMembershipParams: Sendable {
  public let initialPage: Double?
  public let pageSize: Double?
  public init(initialPage: Double? = nil, pageSize: Double? = nil) {
    self.initialPage = initialPage
    self.pageSize = pageSize
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "initialPage": initialPage.map { value in .number(value) } ?? .undefined,
      "pageSize": pageSize.map { value in .number(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> GetUserOrganizationMembershipParams {
    let values = try value.object()

    return try GetUserOrganizationMembershipParams(initialPage: (values["initialPage"] ?? .undefined).optional { value in try value.number() }, pageSize: (values["pageSize"] ?? .undefined).optional { value in try value.number() })
  }
}

public struct GetUserOrganizationInvitationsParams: Sendable {
  public let initialPage: Double?
  public let pageSize: Double?
  public let status: OrganizationInvitationStatus?
  public init(initialPage: Double? = nil, pageSize: Double? = nil, status: OrganizationInvitationStatus? = nil) {
    self.initialPage = initialPage
    self.pageSize = pageSize
    self.status = status
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "initialPage": initialPage.map { value in .number(value) } ?? .undefined,
      "pageSize": pageSize.map { value in .number(value) } ?? .undefined,
      "status": status.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> GetUserOrganizationInvitationsParams {
    let values = try value.object()

    return try GetUserOrganizationInvitationsParams(initialPage: (values["initialPage"] ?? .undefined).optional { value in try value.number() }, pageSize: (values["pageSize"] ?? .undefined).optional { value in try value.number() }, status: (values["status"] ?? .undefined).optional { value in try OrganizationInvitationStatus.decode(value, in: runtime) })
  }
}

/// An interface that describes the response of a method that returns a paginated list of resources.
///
/// > [!TIP]
/// > Clerk's SDKs always use `Promise<ClerkPaginatedResponse<T>>`. If the promise resolves, you will get back the properties. If the promise is rejected, you will receive a `ClerkAPIResponseError` or network error.
public struct ClerkPaginatedResponseUserOrganizationInvitation: Sendable {
  public let data: [UserOrganizationInvitation]
  public let totalCount: Double
  public init(data: [UserOrganizationInvitation], totalCount: Double) {
    self.data = data
    self.totalCount = totalCount
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "data": .array(data.map { value in try value.encode() }),
      "total_count": .number(totalCount),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ClerkPaginatedResponseUserOrganizationInvitation {
    let values = try value.object()

    return try ClerkPaginatedResponseUserOrganizationInvitation(data: (values["data"] ?? .undefined).array().map { value in try UserOrganizationInvitation.decode(value, in: runtime) }, totalCount: (values["total_count"] ?? .undefined).number())
  }
}

/// The `OrganizationInvitation` object is the model around an organization invitation.
public struct UserOrganizationInvitationState: Sendable {
  public let id: String
  public let emailAddress: String
  public let publicOrganizationData: UserOrganizationInvitationPublicOrganizationData
  public let publicMetadata: [String: JSONValue]
  public let role: String
  public let status: OrganizationInvitationStatus
  public let createdAt: Date
  public let updatedAt: Date
  public init(id: String, emailAddress: String, publicOrganizationData: UserOrganizationInvitationPublicOrganizationData, publicMetadata: [String: JSONValue], role: String, status: OrganizationInvitationStatus, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.emailAddress = emailAddress
    self.publicOrganizationData = publicOrganizationData
    self.publicMetadata = publicMetadata
    self.role = role
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "emailAddress": .string(emailAddress),
      "publicOrganizationData": publicOrganizationData.encode(),
      "publicMetadata": .object(publicMetadata),
      "role": .string(role),
      "status": status.encode(),
      "createdAt": .string(createdAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "updatedAt": .string(updatedAt.ISO8601Format(.init(includingFractionalSeconds: true))),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> UserOrganizationInvitationState {
    let values = try value.object()

    return try UserOrganizationInvitationState(id: (values["id"] ?? .undefined).string(), emailAddress: (values["emailAddress"] ?? .undefined).string(), publicOrganizationData: UserOrganizationInvitationPublicOrganizationData.decode(values["publicOrganizationData"] ?? .undefined, in: runtime), publicMetadata: (values["publicMetadata"] ?? .undefined).object(), role: (values["role"] ?? .undefined).string(), status: OrganizationInvitationStatus.decode(values["status"] ?? .undefined, in: runtime), createdAt: (values["createdAt"] ?? .undefined).date(), updatedAt: (values["updatedAt"] ?? .undefined).date())
  }
}

@MainActor @Observable public final class UserOrganizationInvitation: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: UserOrganizationInvitationState {
    context.state(handle, as: UserOrganizationInvitationState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var emailAddress: String {
    state.emailAddress
  }

  public var publicOrganizationData: UserOrganizationInvitationPublicOrganizationData {
    state.publicOrganizationData
  }

  public var publicMetadata: [String: JSONValue] {
    state.publicMetadata
  }

  public var role: String {
    state.role
  }

  public var status: OrganizationInvitationStatus {
    state.status
  }

  public var createdAt: Date {
    state.createdAt
  }

  public var updatedAt: Date {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try UserOrganizationInvitationState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> UserOrganizationInvitation {
    try runtime.resource(ResourceHandle.decodeReference(value), as: UserOrganizationInvitation.self)
  }

  public func accept() async throws -> UserOrganizationInvitation {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "UserOrganizationInvitation.accept", arguments: [])
    return try UserOrganizationInvitation.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> UserOrganizationInvitation {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "UserOrganizationInvitation.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try UserOrganizationInvitation.decode(result, in: runtime)
  }
}

public struct UserOrganizationInvitationPublicOrganizationData: Sendable {
  public let hasImage: Bool
  public let imageUrl: String
  public let name: String
  public let id: String
  public let slug: String?
  public init(hasImage: Bool, imageUrl: String, name: String, id: String, slug: String?) {
    self.hasImage = hasImage
    self.imageUrl = imageUrl
    self.name = name
    self.id = id
    self.slug = slug
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "hasImage": .bool(hasImage),
      "imageUrl": .string(imageUrl),
      "name": .string(name),
      "id": .string(id),
      "slug": slug.map { value in .string(value) } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> UserOrganizationInvitationPublicOrganizationData {
    let values = try value.object()

    return try UserOrganizationInvitationPublicOrganizationData(hasImage: (values["hasImage"] ?? .undefined).bool(), imageUrl: (values["imageUrl"] ?? .undefined).string(), name: (values["name"] ?? .undefined).string(), id: (values["id"] ?? .undefined).string(), slug: (values["slug"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct GetUserOrganizationSuggestionsParams: Sendable {
  public let initialPage: Double?
  public let pageSize: Double?
  public let status: GetUserOrganizationSuggestionsParamsStatus?
  public init(initialPage: Double? = nil, pageSize: Double? = nil, status: GetUserOrganizationSuggestionsParamsStatus? = nil) {
    self.initialPage = initialPage
    self.pageSize = pageSize
    self.status = status
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "initialPage": initialPage.map { value in .number(value) } ?? .undefined,
      "pageSize": pageSize.map { value in .number(value) } ?? .undefined,
      "status": status.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> GetUserOrganizationSuggestionsParams {
    let values = try value.object()

    return try GetUserOrganizationSuggestionsParams(initialPage: (values["initialPage"] ?? .undefined).optional { value in try value.number() }, pageSize: (values["pageSize"] ?? .undefined).optional { value in try value.number() }, status: (values["status"] ?? .undefined).optional { value in try GetUserOrganizationSuggestionsParamsStatus.decode(value, in: runtime) })
  }
}

public indirect enum GetUserOrganizationSuggestionsParamsStatus: Sendable {
  case case1(String)
  case case2(String)
  case case3([OrganizationSuggestionStatus])
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): .object(["$case": .number(0), "value": .string("pending")])
    case .case2(let value): .object(["$case": .number(1), "value": .string("accepted")])
    case .case3(let value): try .object(["$case": .number(2), "value": .array(value.map { value in try value.encode() })])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> GetUserOrganizationSuggestionsParamsStatus {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(payload.literal(.string("pending")).string())
    case 1: return try .case2(payload.literal(.string("accepted")).string())
    case 2: return try .case3(payload.array().map { value in try OrganizationSuggestionStatus.decode(value, in: runtime) })
    default: throw CoreError.invalidValue
    }
  }
}

public enum OrganizationSuggestionStatus: Hashable, Sendable {
  case pending
  case accepted
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .pending: "pending"
    case .accepted: "accepted"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "pending": self = .pending
    case "accepted": self = .accepted
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationSuggestionStatus {
    try .init(rawValue: value.string())
  }
}

/// An interface that describes the response of a method that returns a paginated list of resources.
///
/// > [!TIP]
/// > Clerk's SDKs always use `Promise<ClerkPaginatedResponse<T>>`. If the promise resolves, you will get back the properties. If the promise is rejected, you will receive a `ClerkAPIResponseError` or network error.
public struct ClerkPaginatedResponseOrganizationSuggestion: Sendable {
  public let data: [OrganizationSuggestion]
  public let totalCount: Double
  public init(data: [OrganizationSuggestion], totalCount: Double) {
    self.data = data
    self.totalCount = totalCount
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "data": .array(data.map { value in try value.encode() }),
      "total_count": .number(totalCount),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ClerkPaginatedResponseOrganizationSuggestion {
    let values = try value.object()

    return try ClerkPaginatedResponseOrganizationSuggestion(data: (values["data"] ?? .undefined).array().map { value in try OrganizationSuggestion.decode(value, in: runtime) }, totalCount: (values["total_count"] ?? .undefined).number())
  }
}

/// The `OrganizationSuggestion` object is the model around [a suggestion to join an Organization](https://clerk.com/docs/guides/organizations/add-members/verified-domains#automatic-suggestions).
public struct OrganizationSuggestionState: Sendable {
  public let id: String
  public let publicOrganizationData: OrganizationSuggestionPublicOrganizationData
  public let status: OrganizationSuggestionStatus
  public let createdAt: Date
  public let updatedAt: Date
  public init(id: String, publicOrganizationData: OrganizationSuggestionPublicOrganizationData, status: OrganizationSuggestionStatus, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.publicOrganizationData = publicOrganizationData
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "publicOrganizationData": publicOrganizationData.encode(),
      "status": status.encode(),
      "createdAt": .string(createdAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "updatedAt": .string(updatedAt.ISO8601Format(.init(includingFractionalSeconds: true))),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationSuggestionState {
    let values = try value.object()

    return try OrganizationSuggestionState(id: (values["id"] ?? .undefined).string(), publicOrganizationData: OrganizationSuggestionPublicOrganizationData.decode(values["publicOrganizationData"] ?? .undefined, in: runtime), status: OrganizationSuggestionStatus.decode(values["status"] ?? .undefined, in: runtime), createdAt: (values["createdAt"] ?? .undefined).date(), updatedAt: (values["updatedAt"] ?? .undefined).date())
  }
}

@MainActor @Observable public final class OrganizationSuggestion: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: OrganizationSuggestionState {
    context.state(handle, as: OrganizationSuggestionState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var publicOrganizationData: OrganizationSuggestionPublicOrganizationData {
    state.publicOrganizationData
  }

  public var status: OrganizationSuggestionStatus {
    state.status
  }

  public var createdAt: Date {
    state.createdAt
  }

  public var updatedAt: Date {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try OrganizationSuggestionState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationSuggestion {
    try runtime.resource(ResourceHandle.decodeReference(value), as: OrganizationSuggestion.self)
  }

  /// Accepts the suggestion, creating a request to join the Organization.
  public func accept() async throws -> OrganizationSuggestion {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationSuggestion.accept", arguments: [])
    return try OrganizationSuggestion.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> OrganizationSuggestion {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationSuggestion.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try OrganizationSuggestion.decode(result, in: runtime)
  }
}

public struct OrganizationSuggestionPublicOrganizationData: Sendable {
  public let hasImage: Bool
  public let imageUrl: String
  public let name: String
  public let id: String
  public let slug: String?
  public init(hasImage: Bool, imageUrl: String, name: String, id: String, slug: String?) {
    self.hasImage = hasImage
    self.imageUrl = imageUrl
    self.name = name
    self.id = id
    self.slug = slug
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "hasImage": .bool(hasImage),
      "imageUrl": .string(imageUrl),
      "name": .string(name),
      "id": .string(id),
      "slug": slug.map { value in .string(value) } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationSuggestionPublicOrganizationData {
    let values = try value.object()

    return try OrganizationSuggestionPublicOrganizationData(hasImage: (values["hasImage"] ?? .undefined).bool(), imageUrl: (values["imageUrl"] ?? .undefined).string(), name: (values["name"] ?? .undefined).string(), id: (values["id"] ?? .undefined).string(), slug: (values["slug"] ?? .undefined).optional { value in try value.string() })
  }
}

/// The `OrganizationCreationDefaults` object holds the suggested default values to use when creating an Organization, along with an advisory surfacing a potential issue with the suggested defaults.
public struct OrganizationCreationDefaultsState: Sendable {
  public let advisory: OrganizationCreationDefaultsAdvisory?
  public let form: OrganizationCreationDefaultsForm
  public let id: String?
  public init(advisory: OrganizationCreationDefaultsAdvisory?, form: OrganizationCreationDefaultsForm, id: String? = nil) {
    self.advisory = advisory
    self.form = form
    self.id = id
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "advisory": advisory.map { value in try value.encode() } ?? .null,
      "form": form.encode(),
      "id": id.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationCreationDefaultsState {
    let values = try value.object()

    return try OrganizationCreationDefaultsState(advisory: (values["advisory"] ?? .undefined).optional { value in try OrganizationCreationDefaultsAdvisory.decode(value, in: runtime) }, form: OrganizationCreationDefaultsForm.decode(values["form"] ?? .undefined, in: runtime), id: (values["id"] ?? .undefined).optional { value in try value.string() })
  }
}

@MainActor @Observable public final class OrganizationCreationDefaults: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: OrganizationCreationDefaultsState {
    context.state(handle, as: OrganizationCreationDefaultsState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var advisory: OrganizationCreationDefaultsAdvisory? {
    state.advisory
  }

  public var form: OrganizationCreationDefaultsForm {
    state.form
  }

  public var id: String? {
    state.id
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try OrganizationCreationDefaultsState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OrganizationCreationDefaults {
    try runtime.resource(ResourceHandle.decodeReference(value), as: OrganizationCreationDefaults.self)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> OrganizationCreationDefaults {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "OrganizationCreationDefaults.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try OrganizationCreationDefaults.decode(result, in: runtime)
  }
}

public struct OrganizationCreationDefaultsAdvisory: Sendable {
  public var code: String {
    "organization_already_exists"
  }

  public var severity: String {
    "warning"
  }

  public let meta: [String: String]
  public init(meta: [String: String]) {
    self.meta = meta
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "code": .string("organization_already_exists"),
      "severity": .string("warning"),
      "meta": .object(meta.mapValues { value in .string(value) }),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationCreationDefaultsAdvisory {
    let values = try value.object()
    guard values["code"] == .string("organization_already_exists") else { throw CoreError.invalidValue }
    guard values["severity"] == .string("warning") else { throw CoreError.invalidValue }
    return try OrganizationCreationDefaultsAdvisory(meta: (values["meta"] ?? .undefined).object().mapValues { value in try value.string() })
  }
}

public struct OrganizationCreationDefaultsForm: Sendable {
  public let name: String
  public let slug: String
  public let logo: String?
  public let blurHash: String?
  public init(name: String, slug: String, logo: String?, blurHash: String?) {
    self.name = name
    self.slug = slug
    self.logo = logo
    self.blurHash = blurHash
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "name": .string(name),
      "slug": .string(slug),
      "logo": logo.map { value in .string(value) } ?? .null,
      "blurHash": blurHash.map { value in .string(value) } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OrganizationCreationDefaultsForm {
    let values = try value.object()

    return try OrganizationCreationDefaultsForm(name: (values["name"] ?? .undefined).string(), slug: (values["slug"] ?? .undefined).string(), logo: (values["logo"] ?? .undefined).optional { value in try value.string() }, blurHash: (values["blurHash"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct TOTPState: Sendable {
  public let id: String
  public let secret: String?
  public let uri: String?
  public let verified: Bool
  public let backupCodes: [String]?
  public let createdAt: Date?
  public let updatedAt: Date?
  public init(id: String, secret: String? = nil, uri: String? = nil, verified: Bool, backupCodes: [String]? = nil, createdAt: Date?, updatedAt: Date?) {
    self.id = id
    self.secret = secret
    self.uri = uri
    self.verified = verified
    self.backupCodes = backupCodes
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "secret": secret.map { value in .string(value) } ?? .undefined,
      "uri": uri.map { value in .string(value) } ?? .undefined,
      "verified": .bool(verified),
      "backupCodes": backupCodes.map { value in try .array(value.map { value in .string(value) }) } ?? .undefined,
      "createdAt": createdAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "updatedAt": updatedAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> TOTPState {
    let values = try value.object()

    return try TOTPState(id: (values["id"] ?? .undefined).string(), secret: (values["secret"] ?? .undefined).optional { value in try value.string() }, uri: (values["uri"] ?? .undefined).optional { value in try value.string() }, verified: (values["verified"] ?? .undefined).bool(), backupCodes: (values["backupCodes"] ?? .undefined).optional { value in try value.array().map { value in try value.string() } }, createdAt: (values["createdAt"] ?? .undefined).optional { value in try value.date() }, updatedAt: (values["updatedAt"] ?? .undefined).optional { value in try value.date() })
  }
}

@MainActor @Observable public final class TOTP: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: TOTPState {
    context.state(handle, as: TOTPState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var secret: String? {
    state.secret
  }

  public var uri: String? {
    state.uri
  }

  public var verified: Bool {
    state.verified
  }

  public var backupCodes: [String]? {
    state.backupCodes
  }

  public var createdAt: Date? {
    state.createdAt
  }

  public var updatedAt: Date? {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try TOTPState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> TOTP {
    try runtime.resource(ResourceHandle.decodeReference(value), as: TOTP.self)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> TOTP {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "TOTP.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try TOTP.decode(result, in: runtime)
  }
}

public struct VerifyTOTPParams: Sendable {
  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> VerifyTOTPParams {
    let values = try value.object()

    return try VerifyTOTPParams(code: (values["code"] ?? .undefined).string())
  }
}

public struct BackupCodeState: Sendable {
  public let id: String
  public let codes: [String]
  public let createdAt: Date?
  public let updatedAt: Date?
  public init(id: String, codes: [String], createdAt: Date?, updatedAt: Date?) {
    self.id = id
    self.codes = codes
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "codes": .array(codes.map { value in .string(value) }),
      "createdAt": createdAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "updatedAt": updatedAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> BackupCodeState {
    let values = try value.object()

    return try BackupCodeState(id: (values["id"] ?? .undefined).string(), codes: (values["codes"] ?? .undefined).array().map { value in try value.string() }, createdAt: (values["createdAt"] ?? .undefined).optional { value in try value.date() }, updatedAt: (values["updatedAt"] ?? .undefined).optional { value in try value.date() })
  }
}

@MainActor @Observable public final class BackupCode: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: BackupCodeState {
    context.state(handle, as: BackupCodeState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String {
    state.id
  }

  public var codes: [String] {
    state.codes
  }

  public var createdAt: Date? {
    state.createdAt
  }

  public var updatedAt: Date? {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try BackupCodeState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> BackupCode {
    try runtime.resource(ResourceHandle.decodeReference(value), as: BackupCode.self)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> BackupCode {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "BackupCode.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try BackupCode.decode(result, in: runtime)
  }
}

public struct SessionTouchParams: Sendable {
  public let intent: SessionTouchIntent?
  public init(intent: SessionTouchIntent? = nil) {
    self.intent = intent
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "intent": intent.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionTouchParams {
    let values = try value.object()

    return try SessionTouchParams(intent: (values["intent"] ?? .undefined).optional { value in try SessionTouchIntent.decode(value, in: runtime) })
  }
}

public enum SessionTouchIntent: Hashable, Sendable {
  case focus
  case selectSession
  case selectOrg
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .focus: "focus"
    case .selectSession: "select_session"
    case .selectOrg: "select_org"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "focus": self = .focus
    case "select_session": self = .selectSession
    case "select_org": self = .selectOrg
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SessionTouchIntent {
    try .init(rawValue: value.string())
  }
}

public struct GetTokenOptions: Sendable {
  public let organizationId: String?
  public let skipCache: Bool?
  public let template: String?
  public init(organizationId: String? = nil, skipCache: Bool? = nil, template: String? = nil) {
    self.organizationId = organizationId
    self.skipCache = skipCache
    self.template = template
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "organizationId": organizationId.map { value in .string(value) } ?? .undefined,
      "skipCache": skipCache.map { value in .bool(value) } ?? .undefined,
      "template": template.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> GetTokenOptions {
    let values = try value.object()

    return try GetTokenOptions(organizationId: (values["organizationId"] ?? .undefined).optional { value in try value.string() }, skipCache: (values["skipCache"] ?? .undefined).optional { value in try value.bool() }, template: (values["template"] ?? .undefined).optional { value in try value.string() })
  }
}

public indirect enum CheckAuthorizationParams: Sendable {
  case case1(SessionCheckAuthorizationIsAuthorizedParamsCase1)
  case case2(SessionCheckAuthorizationIsAuthorizedParamsCase2)
  case case3(SessionCheckAuthorizationIsAuthorizedParamsCase3)
  case case4(SessionCheckAuthorizationIsAuthorizedParamsCase4)
  case case5(SessionCheckAuthorizationIsAuthorizedParamsCase5)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    case .case3(let value): try .object(["$case": .number(2), "value": value.encode()])
    case .case4(let value): try .object(["$case": .number(3), "value": value.encode()])
    case .case5(let value): try .object(["$case": .number(4), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> CheckAuthorizationParams {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(SessionCheckAuthorizationIsAuthorizedParamsCase1.decode(payload, in: runtime))
    case 1: return try .case2(SessionCheckAuthorizationIsAuthorizedParamsCase2.decode(payload, in: runtime))
    case 2: return try .case3(SessionCheckAuthorizationIsAuthorizedParamsCase3.decode(payload, in: runtime))
    case 3: return try .case4(SessionCheckAuthorizationIsAuthorizedParamsCase4.decode(payload, in: runtime))
    case 4: return try .case5(SessionCheckAuthorizationIsAuthorizedParamsCase5.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct SessionCheckAuthorizationIsAuthorizedParamsCase1: Sendable {
  public let role: String
  public let reverification: ReverificationConfig?
  public init(role: String, reverification: ReverificationConfig? = nil) {
    self.role = role
    self.reverification = reverification
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "role": .string(role),
      "reverification": reverification.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionCheckAuthorizationIsAuthorizedParamsCase1 {
    let values = try value.object()

    return try SessionCheckAuthorizationIsAuthorizedParamsCase1(role: (values["role"] ?? .undefined).string(), reverification: (values["reverification"] ?? .undefined).optional { value in try ReverificationConfig.decode(value, in: runtime) })
  }
}

/// The `ReverificationConfig` type has the following properties:
public indirect enum ReverificationConfig: Sendable {
  case case1(String)
  case case2(String)
  case case3(String)
  case case4(String)
  case case5(SessionCheckAuthorizationIsAuthorizedParamsCase1ReverificationCase5)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): .object(["$case": .number(0), "value": .string("strict_mfa")])
    case .case2(let value): .object(["$case": .number(1), "value": .string("strict")])
    case .case3(let value): .object(["$case": .number(2), "value": .string("moderate")])
    case .case4(let value): .object(["$case": .number(3), "value": .string("lax")])
    case .case5(let value): try .object(["$case": .number(4), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ReverificationConfig {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(payload.literal(.string("strict_mfa")).string())
    case 1: return try .case2(payload.literal(.string("strict")).string())
    case 2: return try .case3(payload.literal(.string("moderate")).string())
    case 3: return try .case4(payload.literal(.string("lax")).string())
    case 4: return try .case5(SessionCheckAuthorizationIsAuthorizedParamsCase1ReverificationCase5.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct SessionCheckAuthorizationIsAuthorizedParamsCase1ReverificationCase5: Sendable {
  public let level: SessionVerificationLevel
  public let afterMinutes: Double
  public init(level: SessionVerificationLevel, afterMinutes: Double) {
    self.level = level
    self.afterMinutes = afterMinutes
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "level": level.encode(),
      "afterMinutes": .number(afterMinutes),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionCheckAuthorizationIsAuthorizedParamsCase1ReverificationCase5 {
    let values = try value.object()

    return try SessionCheckAuthorizationIsAuthorizedParamsCase1ReverificationCase5(level: SessionVerificationLevel.decode(values["level"] ?? .undefined, in: runtime), afterMinutes: (values["afterMinutes"] ?? .undefined).number())
  }
}

public enum SessionVerificationLevel: Hashable, Sendable {
  case firstFactor
  case secondFactor
  case multiFactor
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .firstFactor: "first_factor"
    case .secondFactor: "second_factor"
    case .multiFactor: "multi_factor"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "first_factor": self = .firstFactor
    case "second_factor": self = .secondFactor
    case "multi_factor": self = .multiFactor
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SessionVerificationLevel {
    try .init(rawValue: value.string())
  }
}

public struct SessionCheckAuthorizationIsAuthorizedParamsCase2: Sendable {
  public let permission: String
  public let reverification: ReverificationConfig?
  public init(permission: String, reverification: ReverificationConfig? = nil) {
    self.permission = permission
    self.reverification = reverification
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "permission": .string(permission),
      "reverification": reverification.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionCheckAuthorizationIsAuthorizedParamsCase2 {
    let values = try value.object()

    return try SessionCheckAuthorizationIsAuthorizedParamsCase2(permission: (values["permission"] ?? .undefined).string(), reverification: (values["reverification"] ?? .undefined).optional { value in try ReverificationConfig.decode(value, in: runtime) })
  }
}

public struct SessionCheckAuthorizationIsAuthorizedParamsCase3: Sendable {
  public let feature: String
  public let reverification: ReverificationConfig?
  public init(feature: String, reverification: ReverificationConfig? = nil) {
    self.feature = feature
    self.reverification = reverification
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "feature": .string(feature),
      "reverification": reverification.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionCheckAuthorizationIsAuthorizedParamsCase3 {
    let values = try value.object()

    return try SessionCheckAuthorizationIsAuthorizedParamsCase3(feature: (values["feature"] ?? .undefined).string(), reverification: (values["reverification"] ?? .undefined).optional { value in try ReverificationConfig.decode(value, in: runtime) })
  }
}

public struct SessionCheckAuthorizationIsAuthorizedParamsCase4: Sendable {
  public let plan: String
  public let reverification: ReverificationConfig?
  public init(plan: String, reverification: ReverificationConfig? = nil) {
    self.plan = plan
    self.reverification = reverification
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "plan": .string(plan),
      "reverification": reverification.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionCheckAuthorizationIsAuthorizedParamsCase4 {
    let values = try value.object()

    return try SessionCheckAuthorizationIsAuthorizedParamsCase4(plan: (values["plan"] ?? .undefined).string(), reverification: (values["reverification"] ?? .undefined).optional { value in try ReverificationConfig.decode(value, in: runtime) })
  }
}

public struct SessionCheckAuthorizationIsAuthorizedParamsCase5: Sendable {
  public let reverification: ReverificationConfig?
  public init(reverification: ReverificationConfig? = nil) {
    self.reverification = reverification
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "reverification": reverification.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionCheckAuthorizationIsAuthorizedParamsCase5 {
    let values = try value.object()

    return try SessionCheckAuthorizationIsAuthorizedParamsCase5(reverification: (values["reverification"] ?? .undefined).optional { value in try ReverificationConfig.decode(value, in: runtime) })
  }
}

public struct SessionVerifyCreateParams: Sendable {
  public let level: SessionVerificationLevel
  public init(level: SessionVerificationLevel) {
    self.level = level
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "level": level.encode(),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionVerifyCreateParams {
    let values = try value.object()

    return try SessionVerifyCreateParams(level: SessionVerificationLevel.decode(values["level"] ?? .undefined, in: runtime))
  }
}

public struct SessionVerificationState: Sendable {
  public let status: SessionVerificationStatus
  public let level: SessionVerificationLevel
  public let session: Session
  public let firstFactorVerification: Verification
  public let secondFactorVerification: Verification
  public let supportedFirstFactors: [SessionVerificationFirstFactor]?
  public let supportedSecondFactors: [SessionVerificationSecondFactor]?
  public let id: String?
  public init(status: SessionVerificationStatus, level: SessionVerificationLevel, session: Session, firstFactorVerification: Verification, secondFactorVerification: Verification, supportedFirstFactors: [SessionVerificationFirstFactor]?, supportedSecondFactors: [SessionVerificationSecondFactor]?, id: String? = nil) {
    self.status = status
    self.level = level
    self.session = session
    self.firstFactorVerification = firstFactorVerification
    self.secondFactorVerification = secondFactorVerification
    self.supportedFirstFactors = supportedFirstFactors
    self.supportedSecondFactors = supportedSecondFactors
    self.id = id
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "status": status.encode(),
      "level": level.encode(),
      "session": session.encode(),
      "firstFactorVerification": firstFactorVerification.encode(),
      "secondFactorVerification": secondFactorVerification.encode(),
      "supportedFirstFactors": supportedFirstFactors.map { value in try .array(value.map { value in try value.encode() }) } ?? .null,
      "supportedSecondFactors": supportedSecondFactors.map { value in try .array(value.map { value in try value.encode() }) } ?? .null,
      "id": id.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionVerificationState {
    let values = try value.object()

    return try SessionVerificationState(status: SessionVerificationStatus.decode(values["status"] ?? .undefined, in: runtime), level: SessionVerificationLevel.decode(values["level"] ?? .undefined, in: runtime), session: Session.decode(values["session"] ?? .undefined, in: runtime), firstFactorVerification: Verification.decode(values["firstFactorVerification"] ?? .undefined, in: runtime), secondFactorVerification: Verification.decode(values["secondFactorVerification"] ?? .undefined, in: runtime), supportedFirstFactors: (values["supportedFirstFactors"] ?? .undefined).optional { value in try value.array().map { value in try SessionVerificationFirstFactor.decode(value, in: runtime) } }, supportedSecondFactors: (values["supportedSecondFactors"] ?? .undefined).optional { value in try value.array().map { value in try SessionVerificationSecondFactor.decode(value, in: runtime) } }, id: (values["id"] ?? .undefined).optional { value in try value.string() })
  }
}

@MainActor @Observable public final class SessionVerification: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: SessionVerificationState {
    context.state(handle, as: SessionVerificationState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var status: SessionVerificationStatus {
    state.status
  }

  public var level: SessionVerificationLevel {
    state.level
  }

  public var session: Session {
    state.session
  }

  public var firstFactorVerification: Verification {
    state.firstFactorVerification
  }

  public var secondFactorVerification: Verification {
    state.secondFactorVerification
  }

  public var supportedFirstFactors: [SessionVerificationFirstFactor]? {
    state.supportedFirstFactors
  }

  public var supportedSecondFactors: [SessionVerificationSecondFactor]? {
    state.supportedSecondFactors
  }

  public var id: String? {
    state.id
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try SessionVerificationState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionVerification {
    try runtime.resource(ResourceHandle.decodeReference(value), as: SessionVerification.self)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SessionVerification.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try SessionVerification.decode(result, in: runtime)
  }
}

public enum SessionVerificationStatus: Hashable, Sendable {
  case needsFirstFactor
  case needsSecondFactor
  case complete
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .needsFirstFactor: "needs_first_factor"
    case .needsSecondFactor: "needs_second_factor"
    case .complete: "complete"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "needs_first_factor": self = .needsFirstFactor
    case "needs_second_factor": self = .needsSecondFactor
    case "complete": self = .complete
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SessionVerificationStatus {
    try .init(rawValue: value.string())
  }
}

public indirect enum SessionVerificationFirstFactor: Sendable {
  case case1(EmailCodeFactor)
  case case2(PhoneCodeFactor)
  case case3(PasswordFactor)
  case case4(PasskeyFactor)
  case case5(EnterpriseSSOFactor)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    case .case3(let value): try .object(["$case": .number(2), "value": value.encode()])
    case .case4(let value): try .object(["$case": .number(3), "value": value.encode()])
    case .case5(let value): try .object(["$case": .number(4), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionVerificationFirstFactor {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(EmailCodeFactor.decode(payload, in: runtime))
    case 1: return try .case2(PhoneCodeFactor.decode(payload, in: runtime))
    case 2: return try .case3(PasswordFactor.decode(payload, in: runtime))
    case 3: return try .case4(PasskeyFactor.decode(payload, in: runtime))
    case 4: return try .case5(EnterpriseSSOFactor.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct EmailCodeFactor: Sendable {
  public var strategy: String {
    "email_code"
  }

  public let emailAddressId: String
  public let safeIdentifier: String
  public let primary: Bool?
  public init(emailAddressId: String, safeIdentifier: String, primary: Bool? = nil) {
    self.emailAddressId = emailAddressId
    self.safeIdentifier = safeIdentifier
    self.primary = primary
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": .string("email_code"),
      "emailAddressId": .string(emailAddressId),
      "safeIdentifier": .string(safeIdentifier),
      "primary": primary.map { value in .bool(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EmailCodeFactor {
    let values = try value.object()
    guard values["strategy"] == .string("email_code") else { throw CoreError.invalidValue }
    return try EmailCodeFactor(emailAddressId: (values["emailAddressId"] ?? .undefined).string(), safeIdentifier: (values["safeIdentifier"] ?? .undefined).string(), primary: (values["primary"] ?? .undefined).optional { value in try value.bool() })
  }
}

public struct PhoneCodeFactor: Sendable {
  public var strategy: String {
    "phone_code"
  }

  public let phoneNumberId: String
  public let safeIdentifier: String
  public let primary: Bool?
  public let `default`: Bool?
  public let channel: PhoneCodeChannel?
  public init(phoneNumberId: String, safeIdentifier: String, primary: Bool? = nil, default: Bool? = nil, channel: PhoneCodeChannel? = nil) {
    self.phoneNumberId = phoneNumberId
    self.safeIdentifier = safeIdentifier
    self.primary = primary
    self.default = `default`
    self.channel = channel
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": .string("phone_code"),
      "phoneNumberId": .string(phoneNumberId),
      "safeIdentifier": .string(safeIdentifier),
      "primary": primary.map { value in .bool(value) } ?? .undefined,
      "default": self.default.map { value in .bool(value) } ?? .undefined,
      "channel": channel.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PhoneCodeFactor {
    let values = try value.object()
    guard values["strategy"] == .string("phone_code") else { throw CoreError.invalidValue }
    return try PhoneCodeFactor(phoneNumberId: (values["phoneNumberId"] ?? .undefined).string(), safeIdentifier: (values["safeIdentifier"] ?? .undefined).string(), primary: (values["primary"] ?? .undefined).optional { value in try value.bool() }, default: (values["default"] ?? .undefined).optional { value in try value.bool() }, channel: (values["channel"] ?? .undefined).optional { value in try PhoneCodeChannel.decode(value, in: runtime) })
  }
}

public struct PasswordFactor: Sendable {
  public var strategy: String {
    "password"
  }

  public init() {}

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "strategy": .string("password"),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> PasswordFactor {
    let values = try value.object()
    guard values["strategy"] == .string("password") else { throw CoreError.invalidValue }
    return try PasswordFactor()
  }
}

public struct PasskeyFactor: Sendable {
  public var strategy: String {
    "passkey"
  }

  public init() {}

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "strategy": .string("passkey"),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> PasskeyFactor {
    let values = try value.object()
    guard values["strategy"] == .string("passkey") else { throw CoreError.invalidValue }
    return try PasskeyFactor()
  }
}

public struct EnterpriseSSOFactor: Sendable {
  public var strategy: String {
    "enterprise_sso"
  }

  public let enterpriseConnectionId: String?
  public let enterpriseConnectionName: String?
  public init(enterpriseConnectionId: String? = nil, enterpriseConnectionName: String? = nil) {
    self.enterpriseConnectionId = enterpriseConnectionId
    self.enterpriseConnectionName = enterpriseConnectionName
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": .string("enterprise_sso"),
      "enterpriseConnectionId": enterpriseConnectionId.map { value in .string(value) } ?? .undefined,
      "enterpriseConnectionName": enterpriseConnectionName.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EnterpriseSSOFactor {
    let values = try value.object()
    guard values["strategy"] == .string("enterprise_sso") else { throw CoreError.invalidValue }
    return try EnterpriseSSOFactor(enterpriseConnectionId: (values["enterpriseConnectionId"] ?? .undefined).optional { value in try value.string() }, enterpriseConnectionName: (values["enterpriseConnectionName"] ?? .undefined).optional { value in try value.string() })
  }
}

public indirect enum SessionVerificationSecondFactor: Sendable {
  case case1(PhoneCodeFactor)
  case case2(TOTPFactor)
  case case3(BackupCodeFactor)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    case .case3(let value): try .object(["$case": .number(2), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionVerificationSecondFactor {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(PhoneCodeFactor.decode(payload, in: runtime))
    case 1: return try .case2(TOTPFactor.decode(payload, in: runtime))
    case 2: return try .case3(BackupCodeFactor.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct TOTPFactor: Sendable {
  public var strategy: String {
    "totp"
  }

  public init() {}

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "strategy": .string("totp"),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> TOTPFactor {
    let values = try value.object()
    guard values["strategy"] == .string("totp") else { throw CoreError.invalidValue }
    return try TOTPFactor()
  }
}

public struct BackupCodeFactor: Sendable {
  public var strategy: String {
    "backup_code"
  }

  public init() {}

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "strategy": .string("backup_code"),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> BackupCodeFactor {
    let values = try value.object()
    guard values["strategy"] == .string("backup_code") else { throw CoreError.invalidValue }
    return try BackupCodeFactor()
  }
}

public indirect enum SessionVerifyPrepareFirstFactorParams: Sendable {
  case case1(PasskeyFactor)
  case case2(EmailCodeConfig)
  case case3(PhoneCodeConfig)
  case case4(OmitEnterpriseSSOConfigAndactionCompleteRedirectUrl)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    case .case3(let value): try .object(["$case": .number(2), "value": value.encode()])
    case .case4(let value): try .object(["$case": .number(3), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionVerifyPrepareFirstFactorParams {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(PasskeyFactor.decode(payload, in: runtime))
    case 1: return try .case2(EmailCodeConfig.decode(payload, in: runtime))
    case 2: return try .case3(PhoneCodeConfig.decode(payload, in: runtime))
    case 3: return try .case4(OmitEnterpriseSSOConfigAndactionCompleteRedirectUrl.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct EmailCodeConfig: Sendable {
  public let primary: Bool?
  public let emailAddressId: String
  public var strategy: String {
    "email_code"
  }

  public init(primary: Bool? = nil, emailAddressId: String) {
    self.primary = primary
    self.emailAddressId = emailAddressId
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "primary": primary.map { value in .bool(value) } ?? .undefined,
      "emailAddressId": .string(emailAddressId),
      "strategy": .string("email_code"),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EmailCodeConfig {
    let values = try value.object()
    guard values["strategy"] == .string("email_code") else { throw CoreError.invalidValue }
    return try EmailCodeConfig(primary: (values["primary"] ?? .undefined).optional { value in try value.bool() }, emailAddressId: (values["emailAddressId"] ?? .undefined).string())
  }
}

public struct PhoneCodeConfig: Sendable {
  public let primary: Bool?
  public let phoneNumberId: String
  public var strategy: String {
    "phone_code"
  }

  public let `default`: Bool?
  public let channel: PhoneCodeChannel?
  public init(primary: Bool? = nil, phoneNumberId: String, default: Bool? = nil, channel: PhoneCodeChannel? = nil) {
    self.primary = primary
    self.phoneNumberId = phoneNumberId
    self.default = `default`
    self.channel = channel
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "primary": primary.map { value in .bool(value) } ?? .undefined,
      "phoneNumberId": .string(phoneNumberId),
      "strategy": .string("phone_code"),
      "default": self.default.map { value in .bool(value) } ?? .undefined,
      "channel": channel.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PhoneCodeConfig {
    let values = try value.object()
    guard values["strategy"] == .string("phone_code") else { throw CoreError.invalidValue }
    return try PhoneCodeConfig(primary: (values["primary"] ?? .undefined).optional { value in try value.bool() }, phoneNumberId: (values["phoneNumberId"] ?? .undefined).string(), default: (values["default"] ?? .undefined).optional { value in try value.bool() }, channel: (values["channel"] ?? .undefined).optional { value in try PhoneCodeChannel.decode(value, in: runtime) })
  }
}

/// Construct a type with the properties of T except for those in type K.
public struct OmitEnterpriseSSOConfigAndactionCompleteRedirectUrl: Sendable {
  public let emailAddressId: String?
  public var strategy: String {
    "enterprise_sso"
  }

  public let enterpriseConnectionId: String?
  public let enterpriseConnectionName: String?
  public let redirectUrl: String
  public let oidcPrompt: String?
  public init(emailAddressId: String? = nil, enterpriseConnectionId: String? = nil, enterpriseConnectionName: String? = nil, redirectUrl: String, oidcPrompt: String? = nil) {
    self.emailAddressId = emailAddressId
    self.enterpriseConnectionId = enterpriseConnectionId
    self.enterpriseConnectionName = enterpriseConnectionName
    self.redirectUrl = redirectUrl
    self.oidcPrompt = oidcPrompt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "emailAddressId": emailAddressId.map { value in .string(value) } ?? .undefined,
      "strategy": .string("enterprise_sso"),
      "enterpriseConnectionId": enterpriseConnectionId.map { value in .string(value) } ?? .undefined,
      "enterpriseConnectionName": enterpriseConnectionName.map { value in .string(value) } ?? .undefined,
      "redirectUrl": .string(redirectUrl),
      "oidcPrompt": oidcPrompt.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> OmitEnterpriseSSOConfigAndactionCompleteRedirectUrl {
    let values = try value.object()
    guard values["strategy"] == .string("enterprise_sso") else { throw CoreError.invalidValue }
    return try OmitEnterpriseSSOConfigAndactionCompleteRedirectUrl(emailAddressId: (values["emailAddressId"] ?? .undefined).optional { value in try value.string() }, enterpriseConnectionId: (values["enterpriseConnectionId"] ?? .undefined).optional { value in try value.string() }, enterpriseConnectionName: (values["enterpriseConnectionName"] ?? .undefined).optional { value in try value.string() }, redirectUrl: (values["redirectUrl"] ?? .undefined).string(), oidcPrompt: (values["oidcPrompt"] ?? .undefined).optional { value in try value.string() })
  }
}

public indirect enum SessionVerifyAttemptFirstFactorParams: Sendable {
  case case1(EmailCodeAttempt)
  case case2(PhoneCodeAttempt)
  case case3(PasswordAttempt)
  case case4(PasskeyAttempt)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    case .case3(let value): try .object(["$case": .number(2), "value": value.encode()])
    case .case4(let value): try .object(["$case": .number(3), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionVerifyAttemptFirstFactorParams {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(EmailCodeAttempt.decode(payload, in: runtime))
    case 1: return try .case2(PhoneCodeAttempt.decode(payload, in: runtime))
    case 2: return try .case3(PasswordAttempt.decode(payload, in: runtime))
    case 3: return try .case4(PasskeyAttempt.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct EmailCodeAttempt: Sendable {
  public var strategy: String {
    "email_code"
  }

  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "strategy": .string("email_code"),
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EmailCodeAttempt {
    let values = try value.object()
    guard values["strategy"] == .string("email_code") else { throw CoreError.invalidValue }
    return try EmailCodeAttempt(code: (values["code"] ?? .undefined).string())
  }
}

public struct PhoneCodeAttempt: Sendable {
  public var strategy: String {
    "phone_code"
  }

  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "strategy": .string("phone_code"),
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> PhoneCodeAttempt {
    let values = try value.object()
    guard values["strategy"] == .string("phone_code") else { throw CoreError.invalidValue }
    return try PhoneCodeAttempt(code: (values["code"] ?? .undefined).string())
  }
}

public struct PasswordAttempt: Sendable {
  public var strategy: String {
    "password"
  }

  public let password: String
  public init(password: String) {
    self.password = password
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "strategy": .string("password"),
      "password": .string(password),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> PasswordAttempt {
    let values = try value.object()
    guard values["strategy"] == .string("password") else { throw CoreError.invalidValue }
    return try PasswordAttempt(password: (values["password"] ?? .undefined).string())
  }
}

public struct PasskeyAttempt: Sendable {
  public var strategy: String {
    "passkey"
  }

  public let publicKeyCredential: PublicKeyCredentialWithAuthenticatorAssertionResponse
  public init(publicKeyCredential: PublicKeyCredentialWithAuthenticatorAssertionResponse) {
    self.publicKeyCredential = publicKeyCredential
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": .string("passkey"),
      "publicKeyCredential": publicKeyCredential.encode(),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PasskeyAttempt {
    let values = try value.object()
    guard values["strategy"] == .string("passkey") else { throw CoreError.invalidValue }
    return try PasskeyAttempt(publicKeyCredential: PublicKeyCredentialWithAuthenticatorAssertionResponse.decode(values["publicKeyCredential"] ?? .undefined, in: runtime))
  }
}

public struct PublicKeyCredentialWithAuthenticatorAssertionResponse: Sendable {
  public let id: String
  public let authenticatorAttachment: String?
  public let rawId: Data
  public let type: String
  public let response: AuthenticatorAssertionResponse
  public init(id: String, authenticatorAttachment: String?, rawId: Data, type: String, response: AuthenticatorAssertionResponse) {
    self.id = id
    self.authenticatorAttachment = authenticatorAttachment
    self.rawId = rawId
    self.type = type
    self.response = response
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": .string(id),
      "authenticatorAttachment": authenticatorAttachment.map { value in .string(value) } ?? .null,
      "rawId": .object(["base64": .string(rawId.base64EncodedString())]),
      "type": .string(type),
      "response": response.encode(),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PublicKeyCredentialWithAuthenticatorAssertionResponse {
    let values = try value.object()

    return try PublicKeyCredentialWithAuthenticatorAssertionResponse(id: (values["id"] ?? .undefined).string(), authenticatorAttachment: (values["authenticatorAttachment"] ?? .undefined).optional { value in try value.string() }, rawId: (values["rawId"] ?? .undefined).data(), type: (values["type"] ?? .undefined).string(), response: AuthenticatorAssertionResponse.decode(values["response"] ?? .undefined, in: runtime))
  }
}

/// The **`AuthenticatorAssertionResponse`** interface of the Web Authentication API contains a digital signature from the private key of a particular WebAuthn credential. The relying party's server can verify this signature to authenticate a user, for example when they sign in.
/// Available only in secure contexts.
///
/// [MDN Reference](https://developer.mozilla.org/docs/Web/API/AuthenticatorAssertionResponse)
public struct AuthenticatorAssertionResponse: Sendable {
  public let authenticatorData: Data
  public let signature: Data
  public let userHandle: Data?
  public let clientDataJSON: Data
  public init(authenticatorData: Data, signature: Data, userHandle: Data?, clientDataJSON: Data) {
    self.authenticatorData = authenticatorData
    self.signature = signature
    self.userHandle = userHandle
    self.clientDataJSON = clientDataJSON
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "authenticatorData": .object(["base64": .string(authenticatorData.base64EncodedString())]),
      "signature": .object(["base64": .string(signature.base64EncodedString())]),
      "userHandle": userHandle.map { value in .object(["base64": .string(value.base64EncodedString())]) } ?? .null,
      "clientDataJSON": .object(["base64": .string(clientDataJSON.base64EncodedString())]),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> AuthenticatorAssertionResponse {
    let values = try value.object()

    return try AuthenticatorAssertionResponse(authenticatorData: (values["authenticatorData"] ?? .undefined).data(), signature: (values["signature"] ?? .undefined).data(), userHandle: (values["userHandle"] ?? .undefined).optional { value in try value.data() }, clientDataJSON: (values["clientDataJSON"] ?? .undefined).data())
  }
}

public struct PhoneCodeSecondFactorConfig: Sendable {
  public var strategy: String {
    "phone_code"
  }

  public let phoneNumberId: String?
  public init(phoneNumberId: String? = nil) {
    self.phoneNumberId = phoneNumberId
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": .string("phone_code"),
      "phoneNumberId": phoneNumberId.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> PhoneCodeSecondFactorConfig {
    let values = try value.object()
    guard values["strategy"] == .string("phone_code") else { throw CoreError.invalidValue }
    return try PhoneCodeSecondFactorConfig(phoneNumberId: (values["phoneNumberId"] ?? .undefined).optional { value in try value.string() })
  }
}

public indirect enum SessionVerifyAttemptSecondFactorParams: Sendable {
  case case1(PhoneCodeAttempt)
  case case2(TOTPAttempt)
  case case3(BackupCodeAttempt)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    case .case3(let value): try .object(["$case": .number(2), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SessionVerifyAttemptSecondFactorParams {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(PhoneCodeAttempt.decode(payload, in: runtime))
    case 1: return try .case2(TOTPAttempt.decode(payload, in: runtime))
    case 2: return try .case3(BackupCodeAttempt.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct TOTPAttempt: Sendable {
  public var strategy: String {
    "totp"
  }

  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "strategy": .string("totp"),
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> TOTPAttempt {
    let values = try value.object()
    guard values["strategy"] == .string("totp") else { throw CoreError.invalidValue }
    return try TOTPAttempt(code: (values["code"] ?? .undefined).string())
  }
}

public struct BackupCodeAttempt: Sendable {
  public var strategy: String {
    "backup_code"
  }

  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "strategy": .string("backup_code"),
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> BackupCodeAttempt {
    let values = try value.object()
    guard values["strategy"] == .string("backup_code") else { throw CoreError.invalidValue }
    return try BackupCodeAttempt(code: (values["code"] ?? .undefined).string())
  }
}

/// The `SignInFuture` class holds the state of the current sign-in and provides helper methods to navigate and complete the sign-in process. It is used to manage the sign-in lifecycle, including the first and second factor verification, and the creation of a new session.
public struct SignInState: Sendable {
  public let id: String?
  public let supportedFirstFactors: [SignInFirstFactor]
  public let supportedSecondFactors: [SignInSecondFactor]
  public let status: SignInStatus
  public let isTransferable: Bool
  public let existingSession: SignInExistingSession?
  public let firstFactorVerification: Verification
  public let secondFactorVerification: Verification
  public let identifier: String?
  public let createdSessionId: String?
  public let userData: UserData
  public let protectCheck: ProtectCheck?
  public let canBeDiscarded: Bool
  public let emailCode: SignInEmailCode
  public let emailLink: SignInEmailLink
  public let phoneCode: SignInPhoneCode
  public let resetPasswordEmailCode: SignInResetPasswordEmailCode
  public let resetPasswordPhoneCode: SignInResetPasswordPhoneCode
  public let mfa: SignInMfa
  public init(id: String? = nil, supportedFirstFactors: [SignInFirstFactor], supportedSecondFactors: [SignInSecondFactor], status: SignInStatus, isTransferable: Bool, existingSession: SignInExistingSession? = nil, firstFactorVerification: Verification, secondFactorVerification: Verification, identifier: String?, createdSessionId: String?, userData: UserData, protectCheck: ProtectCheck?, canBeDiscarded: Bool, emailCode: SignInEmailCode, emailLink: SignInEmailLink, phoneCode: SignInPhoneCode, resetPasswordEmailCode: SignInResetPasswordEmailCode, resetPasswordPhoneCode: SignInResetPasswordPhoneCode, mfa: SignInMfa) {
    self.id = id
    self.supportedFirstFactors = supportedFirstFactors
    self.supportedSecondFactors = supportedSecondFactors
    self.status = status
    self.isTransferable = isTransferable
    self.existingSession = existingSession
    self.firstFactorVerification = firstFactorVerification
    self.secondFactorVerification = secondFactorVerification
    self.identifier = identifier
    self.createdSessionId = createdSessionId
    self.userData = userData
    self.protectCheck = protectCheck
    self.canBeDiscarded = canBeDiscarded
    self.emailCode = emailCode
    self.emailLink = emailLink
    self.phoneCode = phoneCode
    self.resetPasswordEmailCode = resetPasswordEmailCode
    self.resetPasswordPhoneCode = resetPasswordPhoneCode
    self.mfa = mfa
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": id.map { value in .string(value) } ?? .undefined,
      "supportedFirstFactors": .array(supportedFirstFactors.map { value in try value.encode() }),
      "supportedSecondFactors": .array(supportedSecondFactors.map { value in try value.encode() }),
      "status": status.encode(),
      "isTransferable": .bool(isTransferable),
      "existingSession": existingSession.map { value in try value.encode() } ?? .undefined,
      "firstFactorVerification": firstFactorVerification.encode(),
      "secondFactorVerification": secondFactorVerification.encode(),
      "identifier": identifier.map { value in .string(value) } ?? .null,
      "createdSessionId": createdSessionId.map { value in .string(value) } ?? .null,
      "userData": userData.encode(),
      "protectCheck": protectCheck.map { value in try value.encode() } ?? .null,
      "canBeDiscarded": .bool(canBeDiscarded),
      "emailCode": emailCode.encode(),
      "emailLink": emailLink.encode(),
      "phoneCode": phoneCode.encode(),
      "resetPasswordEmailCode": resetPasswordEmailCode.encode(),
      "resetPasswordPhoneCode": resetPasswordPhoneCode.encode(),
      "mfa": mfa.encode(),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInState {
    let values = try value.object()

    return try SignInState(id: (values["id"] ?? .undefined).optional { value in try value.string() }, supportedFirstFactors: (values["supportedFirstFactors"] ?? .undefined).array().map { value in try SignInFirstFactor.decode(value, in: runtime) }, supportedSecondFactors: (values["supportedSecondFactors"] ?? .undefined).array().map { value in try SignInSecondFactor.decode(value, in: runtime) }, status: SignInStatus.decode(values["status"] ?? .undefined, in: runtime), isTransferable: (values["isTransferable"] ?? .undefined).bool(), existingSession: (values["existingSession"] ?? .undefined).optional { value in try SignInExistingSession.decode(value, in: runtime) }, firstFactorVerification: Verification.decode(values["firstFactorVerification"] ?? .undefined, in: runtime), secondFactorVerification: Verification.decode(values["secondFactorVerification"] ?? .undefined, in: runtime), identifier: (values["identifier"] ?? .undefined).optional { value in try value.string() }, createdSessionId: (values["createdSessionId"] ?? .undefined).optional { value in try value.string() }, userData: UserData.decode(values["userData"] ?? .undefined, in: runtime), protectCheck: (values["protectCheck"] ?? .undefined).optional { value in try ProtectCheck.decode(value, in: runtime) }, canBeDiscarded: (values["canBeDiscarded"] ?? .undefined).bool(), emailCode: SignInEmailCode.decode(values["emailCode"] ?? .undefined, in: runtime), emailLink: SignInEmailLink.decode(values["emailLink"] ?? .undefined, in: runtime), phoneCode: SignInPhoneCode.decode(values["phoneCode"] ?? .undefined, in: runtime), resetPasswordEmailCode: SignInResetPasswordEmailCode.decode(values["resetPasswordEmailCode"] ?? .undefined, in: runtime), resetPasswordPhoneCode: SignInResetPasswordPhoneCode.decode(values["resetPasswordPhoneCode"] ?? .undefined, in: runtime), mfa: SignInMfa.decode(values["mfa"] ?? .undefined, in: runtime))
  }
}

@MainActor @Observable public final class SignIn: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: SignInState {
    context.state(handle, as: SignInState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String? {
    state.id
  }

  public var supportedFirstFactors: [SignInFirstFactor] {
    state.supportedFirstFactors
  }

  public var supportedSecondFactors: [SignInSecondFactor] {
    state.supportedSecondFactors
  }

  public var status: SignInStatus {
    state.status
  }

  public var isTransferable: Bool {
    state.isTransferable
  }

  public var existingSession: SignInExistingSession? {
    state.existingSession
  }

  public var firstFactorVerification: Verification {
    state.firstFactorVerification
  }

  public var secondFactorVerification: Verification {
    state.secondFactorVerification
  }

  public var identifier: String? {
    state.identifier
  }

  public var createdSessionId: String? {
    state.createdSessionId
  }

  public var userData: UserData {
    state.userData
  }

  public var protectCheck: ProtectCheck? {
    state.protectCheck
  }

  public var canBeDiscarded: Bool {
    state.canBeDiscarded
  }

  public var emailCode: SignInEmailCode {
    state.emailCode
  }

  public var emailLink: SignInEmailLink {
    state.emailLink
  }

  public var phoneCode: SignInPhoneCode {
    state.phoneCode
  }

  public var resetPasswordEmailCode: SignInResetPasswordEmailCode {
    state.resetPasswordEmailCode
  }

  public var resetPasswordPhoneCode: SignInResetPasswordPhoneCode {
    state.resetPasswordPhoneCode
  }

  public var mfa: SignInMfa {
    state.mfa
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try SignInState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignIn {
    try runtime.resource(ResourceHandle.decodeReference(value), as: SignIn.self)
  }

  /// Creates a new `SignIn` instance initialized with the provided parameters. The instance maintains the sign-in lifecycle state through its `status` property, which updates as the authentication flow progresses. Once the sign-in process is complete, call the `signIn.finalize()` method to set the newly created session as the active session.
  ///
  /// What you must pass to `params` depends on which [sign-in options](https://clerk.com/docs/guides/configure/auth-strategies/sign-up-sign-in-options) you have enabled in your app's settings in the Clerk Dashboard.
  ///
  /// You can complete the sign-in process in one step if you supply the required fields to `create()`. Otherwise, Clerk's sign-in process provides great flexibility and allows users to easily create multi-step sign-in flows.
  ///
  /// > [!IMPORTANT]
  /// > The `signIn.create()` method is intended for advanced use cases. For most use cases, prefer the use of the factor-specific methods such as `signIn.password()`, `signIn.emailCode.sendCode()`, etc.
  public func create(_ params: SignInCreateParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignIn.create", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Submits a password to sign-in.
  public func password(_ params: SignInPasswordParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignIn.password", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Performs an SSO-based sign-in (Social/OAuth or Enterprise).
  public func sso(_ params: SignInSSOParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignIn.sso", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Performs a ticket-based sign-in.
  public func ticket(_ params: SignInTicketParams? = nil) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignIn.ticket", arguments: [params.map { value in try value.encode() } ?? .undefined])
    try runtime.checkErrorResult(result)
  }

  /// Initiates a passkey-based authentication flow, enabling users to authenticate using a previously registered passkey. When called without parameters, this method requires a prior call to `SignIn.create({ strategy: 'passkey' })` to initialize the sign-in context. This pattern is particularly useful in scenarios where the authentication strategy needs to be determined dynamically at runtime.
  public func passkey(_ params: SignInPasskeyParams? = nil) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignIn.passkey", arguments: [params.map { value in try value.encode() } ?? .undefined])
    try runtime.checkErrorResult(result)
  }

  /// Submits a proof token to resolve a pending protect check challenge. The response may contain another `protectCheck` (a chained challenge) which must be resolved iteratively.
  public func submitProtectCheck(_ params: SignInSubmitProtectCheckParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignIn.submitProtectCheck", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Converts a sign-in with `status === 'complete'` into an active session. Will cause anything observing the session state (such as the [`useUser()`](https://clerk.com/docs/reference/hooks/use-user) hook) to update automatically.
  public func finalize() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignIn.finalize", arguments: [])
    try runtime.checkErrorResult(result)
  }

  /// Resets the current sign-in attempt by clearing all local state back to null. This is useful when you want to allow users to go back to the beginning of the sign-in flow (e.g., to change their identifier during verification).
  ///
  /// Unlike other methods, `reset()` does not trigger the `fetchStatus` to change to `'fetching'` and does not make any API calls - it only clears local state.
  public func reset() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignIn.reset", arguments: [])
    try runtime.checkErrorResult(result)
  }
}

public indirect enum SignInFirstFactor: Sendable {
  case case1(EmailCodeFactor)
  case case2(PhoneCodeFactor)
  case case3(PasswordFactor)
  case case4(PasskeyFactor)
  case case5(EnterpriseSSOFactor)
  case case6(EmailLinkFactor)
  case case7(ResetPasswordPhoneCodeFactor)
  case case8(ResetPasswordEmailCodeFactor)
  case case9(Web3SignatureFactor)
  case case10(OauthFactor)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    case .case3(let value): try .object(["$case": .number(2), "value": value.encode()])
    case .case4(let value): try .object(["$case": .number(3), "value": value.encode()])
    case .case5(let value): try .object(["$case": .number(4), "value": value.encode()])
    case .case6(let value): try .object(["$case": .number(5), "value": value.encode()])
    case .case7(let value): try .object(["$case": .number(6), "value": value.encode()])
    case .case8(let value): try .object(["$case": .number(7), "value": value.encode()])
    case .case9(let value): try .object(["$case": .number(8), "value": value.encode()])
    case .case10(let value): try .object(["$case": .number(9), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInFirstFactor {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(EmailCodeFactor.decode(payload, in: runtime))
    case 1: return try .case2(PhoneCodeFactor.decode(payload, in: runtime))
    case 2: return try .case3(PasswordFactor.decode(payload, in: runtime))
    case 3: return try .case4(PasskeyFactor.decode(payload, in: runtime))
    case 4: return try .case5(EnterpriseSSOFactor.decode(payload, in: runtime))
    case 5: return try .case6(EmailLinkFactor.decode(payload, in: runtime))
    case 6: return try .case7(ResetPasswordPhoneCodeFactor.decode(payload, in: runtime))
    case 7: return try .case8(ResetPasswordEmailCodeFactor.decode(payload, in: runtime))
    case 8: return try .case9(Web3SignatureFactor.decode(payload, in: runtime))
    case 9: return try .case10(OauthFactor.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct EmailLinkFactor: Sendable {
  public var strategy: String {
    "email_link"
  }

  public let emailAddressId: String
  public let safeIdentifier: String
  public let primary: Bool?
  public init(emailAddressId: String, safeIdentifier: String, primary: Bool? = nil) {
    self.emailAddressId = emailAddressId
    self.safeIdentifier = safeIdentifier
    self.primary = primary
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": .string("email_link"),
      "emailAddressId": .string(emailAddressId),
      "safeIdentifier": .string(safeIdentifier),
      "primary": primary.map { value in .bool(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> EmailLinkFactor {
    let values = try value.object()
    guard values["strategy"] == .string("email_link") else { throw CoreError.invalidValue }
    return try EmailLinkFactor(emailAddressId: (values["emailAddressId"] ?? .undefined).string(), safeIdentifier: (values["safeIdentifier"] ?? .undefined).string(), primary: (values["primary"] ?? .undefined).optional { value in try value.bool() })
  }
}

public struct ResetPasswordPhoneCodeFactor: Sendable {
  public var strategy: String {
    "reset_password_phone_code"
  }

  public let phoneNumberId: String
  public let safeIdentifier: String
  public let primary: Bool?
  public init(phoneNumberId: String, safeIdentifier: String, primary: Bool? = nil) {
    self.phoneNumberId = phoneNumberId
    self.safeIdentifier = safeIdentifier
    self.primary = primary
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": .string("reset_password_phone_code"),
      "phoneNumberId": .string(phoneNumberId),
      "safeIdentifier": .string(safeIdentifier),
      "primary": primary.map { value in .bool(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> ResetPasswordPhoneCodeFactor {
    let values = try value.object()
    guard values["strategy"] == .string("reset_password_phone_code") else { throw CoreError.invalidValue }
    return try ResetPasswordPhoneCodeFactor(phoneNumberId: (values["phoneNumberId"] ?? .undefined).string(), safeIdentifier: (values["safeIdentifier"] ?? .undefined).string(), primary: (values["primary"] ?? .undefined).optional { value in try value.bool() })
  }
}

public struct ResetPasswordEmailCodeFactor: Sendable {
  public var strategy: String {
    "reset_password_email_code"
  }

  public let emailAddressId: String
  public let safeIdentifier: String
  public let primary: Bool?
  public init(emailAddressId: String, safeIdentifier: String, primary: Bool? = nil) {
    self.emailAddressId = emailAddressId
    self.safeIdentifier = safeIdentifier
    self.primary = primary
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": .string("reset_password_email_code"),
      "emailAddressId": .string(emailAddressId),
      "safeIdentifier": .string(safeIdentifier),
      "primary": primary.map { value in .bool(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> ResetPasswordEmailCodeFactor {
    let values = try value.object()
    guard values["strategy"] == .string("reset_password_email_code") else { throw CoreError.invalidValue }
    return try ResetPasswordEmailCodeFactor(emailAddressId: (values["emailAddressId"] ?? .undefined).string(), safeIdentifier: (values["safeIdentifier"] ?? .undefined).string(), primary: (values["primary"] ?? .undefined).optional { value in try value.bool() })
  }
}

public struct Web3SignatureFactor: Sendable {
  public let strategy: PrepareWeb3WalletVerificationParamsStrategy
  public let web3WalletId: String
  public let primary: Bool?
  public let walletName: String?
  public init(strategy: PrepareWeb3WalletVerificationParamsStrategy, web3WalletId: String, primary: Bool? = nil, walletName: String? = nil) {
    self.strategy = strategy
    self.web3WalletId = web3WalletId
    self.primary = primary
    self.walletName = walletName
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": strategy.encode(),
      "web3WalletId": .string(web3WalletId),
      "primary": primary.map { value in .bool(value) } ?? .undefined,
      "walletName": walletName.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> Web3SignatureFactor {
    let values = try value.object()

    return try Web3SignatureFactor(strategy: PrepareWeb3WalletVerificationParamsStrategy.decode(values["strategy"] ?? .undefined, in: runtime), web3WalletId: (values["web3WalletId"] ?? .undefined).string(), primary: (values["primary"] ?? .undefined).optional { value in try value.bool() }, walletName: (values["walletName"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct OauthFactor: Sendable {
  public let strategy: OAuthStrategy
  public init(strategy: OAuthStrategy) {
    self.strategy = strategy
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": strategy.encode(),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> OauthFactor {
    let values = try value.object()

    return try OauthFactor(strategy: OAuthStrategy.decode(values["strategy"] ?? .undefined, in: runtime))
  }
}

public indirect enum SignInSecondFactor: Sendable {
  case case1(EmailCodeFactor)
  case case2(PhoneCodeFactor)
  case case3(TOTPFactor)
  case case4(BackupCodeFactor)
  case case5(EmailLinkFactor)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    case .case3(let value): try .object(["$case": .number(2), "value": value.encode()])
    case .case4(let value): try .object(["$case": .number(3), "value": value.encode()])
    case .case5(let value): try .object(["$case": .number(4), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInSecondFactor {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(EmailCodeFactor.decode(payload, in: runtime))
    case 1: return try .case2(PhoneCodeFactor.decode(payload, in: runtime))
    case 2: return try .case3(TOTPFactor.decode(payload, in: runtime))
    case 3: return try .case4(BackupCodeFactor.decode(payload, in: runtime))
    case 4: return try .case5(EmailLinkFactor.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public enum SignInStatus: Hashable, Sendable {
  case needsFirstFactor
  case needsSecondFactor
  case complete
  case needsIdentifier
  case needsClientTrust
  case needsNewPassword
  case needsProtectCheck
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .needsFirstFactor: "needs_first_factor"
    case .needsSecondFactor: "needs_second_factor"
    case .complete: "complete"
    case .needsIdentifier: "needs_identifier"
    case .needsClientTrust: "needs_client_trust"
    case .needsNewPassword: "needs_new_password"
    case .needsProtectCheck: "needs_protect_check"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "needs_first_factor": self = .needsFirstFactor
    case "needs_second_factor": self = .needsSecondFactor
    case "complete": self = .complete
    case "needs_identifier": self = .needsIdentifier
    case "needs_client_trust": self = .needsClientTrust
    case "needs_new_password": self = .needsNewPassword
    case "needs_protect_check": self = .needsProtectCheck
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInStatus {
    try .init(rawValue: value.string())
  }
}

public struct SignInExistingSession: Sendable {
  public let sessionId: String
  public init(sessionId: String) {
    self.sessionId = sessionId
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "sessionId": .string(sessionId),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInExistingSession {
    let values = try value.object()

    return try SignInExistingSession(sessionId: (values["sessionId"] ?? .undefined).string())
  }
}

public struct UserData: Sendable {
  public let firstName: String?
  public let lastName: String?
  public let imageUrl: String?
  public let hasImage: Bool?
  public init(firstName: String? = nil, lastName: String? = nil, imageUrl: String? = nil, hasImage: Bool? = nil) {
    self.firstName = firstName
    self.lastName = lastName
    self.imageUrl = imageUrl
    self.hasImage = hasImage
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "firstName": firstName.map { value in .string(value) } ?? .undefined,
      "lastName": lastName.map { value in .string(value) } ?? .undefined,
      "imageUrl": imageUrl.map { value in .string(value) } ?? .undefined,
      "hasImage": hasImage.map { value in .bool(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> UserData {
    let values = try value.object()

    return try UserData(firstName: (values["firstName"] ?? .undefined).optional { value in try value.string() }, lastName: (values["lastName"] ?? .undefined).optional { value in try value.string() }, imageUrl: (values["imageUrl"] ?? .undefined).optional { value in try value.string() }, hasImage: (values["hasImage"] ?? .undefined).optional { value in try value.bool() })
  }
}

/// A pending Clerk Protect challenge that must be completed before the current sign-in or sign-up attempt can continue.
///
/// This resource is only returned when Protect mid-flow challenges are enabled for the instance. When present, load the challenge SDK from `sdkUrl`, initialize it with `token` and `uiHints`, and submit the proof token returned by the SDK with `submitProtectCheck()`.
public struct ProtectCheck: Sendable {
  public var status: String {
    "pending"
  }

  public let sdkUrl: String
  public let expiresAt: Double?
  public let uiHints: [String: String]?
  public init(sdkUrl: String, expiresAt: Double? = nil, uiHints: [String: String]? = nil) {
    self.sdkUrl = sdkUrl
    self.expiresAt = expiresAt
    self.uiHints = uiHints
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "status": .string("pending"),
      "sdkUrl": .string(sdkUrl),
      "expiresAt": expiresAt.map { value in .number(value) } ?? .undefined,
      "uiHints": uiHints.map { value in try .object(value.mapValues { value in .string(value) }) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> ProtectCheck {
    let values = try value.object()
    guard values["status"] == .string("pending") else { throw CoreError.invalidValue }
    return try ProtectCheck(sdkUrl: (values["sdkUrl"] ?? .undefined).string(), expiresAt: (values["expiresAt"] ?? .undefined).optional { value in try value.number() }, uiHints: (values["uiHints"] ?? .undefined).optional { value in try value.object().mapValues { value in try value.string() } })
  }
}

public struct SignInCreateParams: Sendable {
  public let identifier: String?
  public let password: String?
  public let strategy: SignInCreateParamsStrategy?
  public let redirectUrl: String?
  public let actionCompleteRedirectUrl: String?
  public let transfer: Bool?
  public let ticket: String?
  public let signUpIfMissing: Bool?
  public init(identifier: String? = nil, password: String? = nil, strategy: SignInCreateParamsStrategy? = nil, redirectUrl: String? = nil, actionCompleteRedirectUrl: String? = nil, transfer: Bool? = nil, ticket: String? = nil, signUpIfMissing: Bool? = nil) {
    self.identifier = identifier
    self.password = password
    self.strategy = strategy
    self.redirectUrl = redirectUrl
    self.actionCompleteRedirectUrl = actionCompleteRedirectUrl
    self.transfer = transfer
    self.ticket = ticket
    self.signUpIfMissing = signUpIfMissing
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "identifier": identifier.map { value in .string(value) } ?? .undefined,
      "password": password.map { value in .string(value) } ?? .undefined,
      "strategy": strategy.map { value in try value.encode() } ?? .undefined,
      "redirectUrl": redirectUrl.map { value in .string(value) } ?? .undefined,
      "actionCompleteRedirectUrl": actionCompleteRedirectUrl.map { value in .string(value) } ?? .undefined,
      "transfer": transfer.map { value in .bool(value) } ?? .undefined,
      "ticket": ticket.map { value in .string(value) } ?? .undefined,
      "signUpIfMissing": signUpIfMissing.map { value in .bool(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInCreateParams {
    let values = try value.object()

    return try SignInCreateParams(identifier: (values["identifier"] ?? .undefined).optional { value in try value.string() }, password: (values["password"] ?? .undefined).optional { value in try value.string() }, strategy: (values["strategy"] ?? .undefined).optional { value in try SignInCreateParamsStrategy.decode(value, in: runtime) }, redirectUrl: (values["redirectUrl"] ?? .undefined).optional { value in try value.string() }, actionCompleteRedirectUrl: (values["actionCompleteRedirectUrl"] ?? .undefined).optional { value in try value.string() }, transfer: (values["transfer"] ?? .undefined).optional { value in try value.bool() }, ticket: (values["ticket"] ?? .undefined).optional { value in try value.string() }, signUpIfMissing: (values["signUpIfMissing"] ?? .undefined).optional { value in try value.bool() })
  }
}

public enum SignInCreateParamsStrategy: Hashable, Sendable {
  case enterpriseSso
  case oauthFacebook
  case oauthGoogle
  case oauthHubspot
  case oauthGithub
  case oauthTiktok
  case oauthGitlab
  case oauthDiscord
  case oauthTwitter
  case oauthTwitch
  case oauthLinkedin
  case oauthLinkedinOidc
  case oauthDropbox
  case oauthAtlassian
  case oauthBitbucket
  case oauthMicrosoft
  case oauthNotion
  case oauthApple
  case oauthLine
  case oauthInstagram
  case oauthCoinbase
  case oauthSpotify
  case oauthXero
  case oauthBox
  case oauthSlack
  case oauthLinear
  case oauthX
  case oauthEnstall
  case oauthHuggingface
  case oauthVercel
  case passkey
  case ticket
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .enterpriseSso: "enterprise_sso"
    case .oauthFacebook: "oauth_facebook"
    case .oauthGoogle: "oauth_google"
    case .oauthHubspot: "oauth_hubspot"
    case .oauthGithub: "oauth_github"
    case .oauthTiktok: "oauth_tiktok"
    case .oauthGitlab: "oauth_gitlab"
    case .oauthDiscord: "oauth_discord"
    case .oauthTwitter: "oauth_twitter"
    case .oauthTwitch: "oauth_twitch"
    case .oauthLinkedin: "oauth_linkedin"
    case .oauthLinkedinOidc: "oauth_linkedin_oidc"
    case .oauthDropbox: "oauth_dropbox"
    case .oauthAtlassian: "oauth_atlassian"
    case .oauthBitbucket: "oauth_bitbucket"
    case .oauthMicrosoft: "oauth_microsoft"
    case .oauthNotion: "oauth_notion"
    case .oauthApple: "oauth_apple"
    case .oauthLine: "oauth_line"
    case .oauthInstagram: "oauth_instagram"
    case .oauthCoinbase: "oauth_coinbase"
    case .oauthSpotify: "oauth_spotify"
    case .oauthXero: "oauth_xero"
    case .oauthBox: "oauth_box"
    case .oauthSlack: "oauth_slack"
    case .oauthLinear: "oauth_linear"
    case .oauthX: "oauth_x"
    case .oauthEnstall: "oauth_enstall"
    case .oauthHuggingface: "oauth_huggingface"
    case .oauthVercel: "oauth_vercel"
    case .passkey: "passkey"
    case .ticket: "ticket"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "enterprise_sso": self = .enterpriseSso
    case "oauth_facebook": self = .oauthFacebook
    case "oauth_google": self = .oauthGoogle
    case "oauth_hubspot": self = .oauthHubspot
    case "oauth_github": self = .oauthGithub
    case "oauth_tiktok": self = .oauthTiktok
    case "oauth_gitlab": self = .oauthGitlab
    case "oauth_discord": self = .oauthDiscord
    case "oauth_twitter": self = .oauthTwitter
    case "oauth_twitch": self = .oauthTwitch
    case "oauth_linkedin": self = .oauthLinkedin
    case "oauth_linkedin_oidc": self = .oauthLinkedinOidc
    case "oauth_dropbox": self = .oauthDropbox
    case "oauth_atlassian": self = .oauthAtlassian
    case "oauth_bitbucket": self = .oauthBitbucket
    case "oauth_microsoft": self = .oauthMicrosoft
    case "oauth_notion": self = .oauthNotion
    case "oauth_apple": self = .oauthApple
    case "oauth_line": self = .oauthLine
    case "oauth_instagram": self = .oauthInstagram
    case "oauth_coinbase": self = .oauthCoinbase
    case "oauth_spotify": self = .oauthSpotify
    case "oauth_xero": self = .oauthXero
    case "oauth_box": self = .oauthBox
    case "oauth_slack": self = .oauthSlack
    case "oauth_linear": self = .oauthLinear
    case "oauth_x": self = .oauthX
    case "oauth_enstall": self = .oauthEnstall
    case "oauth_huggingface": self = .oauthHuggingface
    case "oauth_vercel": self = .oauthVercel
    case "passkey": self = .passkey
    case "ticket": self = .ticket
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInCreateParamsStrategy {
    try .init(rawValue: value.string())
  }
}

/// Parameters for submitting a password to sign-in.
public indirect enum SignInPasswordParams: Sendable {
  case case1(SignInPasswordParamsCase1)
  case case2(SignInPasswordParamsCase2)
  case case3(SignInPasswordParamsCase3)
  case case4(SignInPasswordParamsCase4)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    case .case3(let value): try .object(["$case": .number(2), "value": value.encode()])
    case .case4(let value): try .object(["$case": .number(3), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInPasswordParams {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(SignInPasswordParamsCase1.decode(payload, in: runtime))
    case 1: return try .case2(SignInPasswordParamsCase2.decode(payload, in: runtime))
    case 2: return try .case3(SignInPasswordParamsCase3.decode(payload, in: runtime))
    case 3: return try .case4(SignInPasswordParamsCase4.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct SignInPasswordParamsCase1: Sendable {
  public let password: String
  public let identifier: String
  public init(password: String, identifier: String) {
    self.password = password
    self.identifier = identifier
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "password": .string(password),
      "identifier": .string(identifier),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInPasswordParamsCase1 {
    let values = try value.object()

    return try SignInPasswordParamsCase1(password: (values["password"] ?? .undefined).string(), identifier: (values["identifier"] ?? .undefined).string())
  }
}

public struct SignInPasswordParamsCase2: Sendable {
  public let password: String
  public let emailAddress: String
  public init(password: String, emailAddress: String) {
    self.password = password
    self.emailAddress = emailAddress
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "password": .string(password),
      "emailAddress": .string(emailAddress),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInPasswordParamsCase2 {
    let values = try value.object()

    return try SignInPasswordParamsCase2(password: (values["password"] ?? .undefined).string(), emailAddress: (values["emailAddress"] ?? .undefined).string())
  }
}

public struct SignInPasswordParamsCase3: Sendable {
  public let password: String
  public let phoneNumber: String
  public init(password: String, phoneNumber: String) {
    self.password = password
    self.phoneNumber = phoneNumber
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "password": .string(password),
      "phoneNumber": .string(phoneNumber),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInPasswordParamsCase3 {
    let values = try value.object()

    return try SignInPasswordParamsCase3(password: (values["password"] ?? .undefined).string(), phoneNumber: (values["phoneNumber"] ?? .undefined).string())
  }
}

public struct SignInPasswordParamsCase4: Sendable {
  public let password: String
  public init(password: String) {
    self.password = password
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "password": .string(password),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInPasswordParamsCase4 {
    let values = try value.object()

    return try SignInPasswordParamsCase4(password: (values["password"] ?? .undefined).string())
  }
}

public struct SignInEmailCodeState: Sendable {
  public init() {}

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [:]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInEmailCodeState {
    let values = try value.object()

    return try SignInEmailCodeState()
  }
}

@MainActor @Observable public final class SignInEmailCode: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: SignInEmailCodeState {
    context.state(handle, as: SignInEmailCodeState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try SignInEmailCodeState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInEmailCode {
    try runtime.resource(ResourceHandle.decodeReference(value), as: SignInEmailCode.self)
  }

  /// Sends an email code to sign-in.
  public func sendCode(_ params: SignInEmailCodeSendParams? = nil) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInEmailCode.sendCode", arguments: [params.map { value in try value.encode() } ?? .undefined])
    try runtime.checkErrorResult(result)
  }

  /// Verifies a code sent with the [`emailCode.sendCode()`](https://clerk.com/docs/reference/objects/sign-in-future#email-code-send-code) method.
  public func verifyCode(_ params: SignInEmailCodeVerifyParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInEmailCode.verifyCode", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }
}

/// Parameters for sending a sign-in email verification code.
public indirect enum SignInEmailCodeSendParams: Sendable {
  case case1(SignInEmailCodeSendCodeParamsCase1)
  case case2(SignInEmailCodeSendCodeParamsCase2)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInEmailCodeSendParams {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(SignInEmailCodeSendCodeParamsCase1.decode(payload, in: runtime))
    case 1: return try .case2(SignInEmailCodeSendCodeParamsCase2.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct SignInEmailCodeSendCodeParamsCase1: Sendable {
  public let emailAddress: String?
  public init(emailAddress: String? = nil) {
    self.emailAddress = emailAddress
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "emailAddress": emailAddress.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInEmailCodeSendCodeParamsCase1 {
    let values = try value.object()

    return try SignInEmailCodeSendCodeParamsCase1(emailAddress: (values["emailAddress"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct SignInEmailCodeSendCodeParamsCase2: Sendable {
  public let emailAddressId: String?
  public init(emailAddressId: String? = nil) {
    self.emailAddressId = emailAddressId
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "emailAddressId": emailAddressId.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInEmailCodeSendCodeParamsCase2 {
    let values = try value.object()

    return try SignInEmailCodeSendCodeParamsCase2(emailAddressId: (values["emailAddressId"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct SignInEmailCodeVerifyParams: Sendable {
  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInEmailCodeVerifyParams {
    let values = try value.object()

    return try SignInEmailCodeVerifyParams(code: (values["code"] ?? .undefined).string())
  }
}

public struct SignInEmailLinkState: Sendable {
  public let verification: SignInEmailLinkVerification?
  public init(verification: SignInEmailLinkVerification?) {
    self.verification = verification
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "verification": verification.map { value in try value.encode() } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInEmailLinkState {
    let values = try value.object()

    return try SignInEmailLinkState(verification: (values["verification"] ?? .undefined).optional { value in try SignInEmailLinkVerification.decode(value, in: runtime) })
  }
}

@MainActor @Observable public final class SignInEmailLink: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: SignInEmailLinkState {
    context.state(handle, as: SignInEmailLinkState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var verification: SignInEmailLinkVerification? {
    state.verification
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try SignInEmailLinkState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInEmailLink {
    try runtime.resource(ResourceHandle.decodeReference(value), as: SignInEmailLink.self)
  }

  /// Sends an email link to sign in with.
  public func sendLink(_ params: SignInEmailLinkSendParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInEmailLink.sendLink", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Waits for email link verification to complete or expire.
  public func waitForVerification() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInEmailLink.waitForVerification", arguments: [])
    try runtime.checkErrorResult(result)
  }
}

/// Parameters for sending a sign-in email link.
public indirect enum SignInEmailLinkSendParams: Sendable {
  case case1(SignInEmailLinkSendLinkParamsCase1)
  case case2(SignInEmailLinkSendLinkParamsCase2)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInEmailLinkSendParams {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(SignInEmailLinkSendLinkParamsCase1.decode(payload, in: runtime))
    case 1: return try .case2(SignInEmailLinkSendLinkParamsCase2.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct SignInEmailLinkSendLinkParamsCase1: Sendable {
  public let verificationUrl: String
  public let emailAddress: String?
  public init(verificationUrl: String, emailAddress: String? = nil) {
    self.verificationUrl = verificationUrl
    self.emailAddress = emailAddress
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "verificationUrl": .string(verificationUrl),
      "emailAddress": emailAddress.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInEmailLinkSendLinkParamsCase1 {
    let values = try value.object()

    return try SignInEmailLinkSendLinkParamsCase1(verificationUrl: (values["verificationUrl"] ?? .undefined).string(), emailAddress: (values["emailAddress"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct SignInEmailLinkSendLinkParamsCase2: Sendable {
  public let verificationUrl: String
  public let emailAddressId: String?
  public init(verificationUrl: String, emailAddressId: String? = nil) {
    self.verificationUrl = verificationUrl
    self.emailAddressId = emailAddressId
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "verificationUrl": .string(verificationUrl),
      "emailAddressId": emailAddressId.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInEmailLinkSendLinkParamsCase2 {
    let values = try value.object()

    return try SignInEmailLinkSendLinkParamsCase2(verificationUrl: (values["verificationUrl"] ?? .undefined).string(), emailAddressId: (values["emailAddressId"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct SignInEmailLinkVerification: Sendable {
  public let status: SignInEmailLinkVerificationStatus
  public let createdSessionId: String
  public let verifiedFromTheSameClient: Bool
  public init(status: SignInEmailLinkVerificationStatus, createdSessionId: String, verifiedFromTheSameClient: Bool) {
    self.status = status
    self.createdSessionId = createdSessionId
    self.verifiedFromTheSameClient = verifiedFromTheSameClient
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "status": status.encode(),
      "createdSessionId": .string(createdSessionId),
      "verifiedFromTheSameClient": .bool(verifiedFromTheSameClient),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInEmailLinkVerification {
    let values = try value.object()

    return try SignInEmailLinkVerification(status: SignInEmailLinkVerificationStatus.decode(values["status"] ?? .undefined, in: runtime), createdSessionId: (values["createdSessionId"] ?? .undefined).string(), verifiedFromTheSameClient: (values["verifiedFromTheSameClient"] ?? .undefined).bool())
  }
}

public enum SignInEmailLinkVerificationStatus: Hashable, Sendable {
  case expired
  case verified
  case failed
  case clientMismatch
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .expired: "expired"
    case .verified: "verified"
    case .failed: "failed"
    case .clientMismatch: "client_mismatch"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "expired": self = .expired
    case "verified": self = .verified
    case "failed": self = .failed
    case "client_mismatch": self = .clientMismatch
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInEmailLinkVerificationStatus {
    try .init(rawValue: value.string())
  }
}

public struct SignInPhoneCodeState: Sendable {
  public init() {}

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [:]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInPhoneCodeState {
    let values = try value.object()

    return try SignInPhoneCodeState()
  }
}

@MainActor @Observable public final class SignInPhoneCode: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: SignInPhoneCodeState {
    context.state(handle, as: SignInPhoneCodeState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try SignInPhoneCodeState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInPhoneCode {
    try runtime.resource(ResourceHandle.decodeReference(value), as: SignInPhoneCode.self)
  }

  /// Sends a phone code to sign in with.
  public func sendCode(_ params: SignInPhoneCodeSendParams? = nil) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInPhoneCode.sendCode", arguments: [params.map { value in try value.encode() } ?? .undefined])
    try runtime.checkErrorResult(result)
  }

  /// Verifies a code sent with the [`phoneCode.sendCode()`](https://clerk.com/docs/reference/objects/sign-in-future#phone-code-send-code) method.
  public func verifyCode(_ params: SignInPhoneCodeVerifyParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInPhoneCode.verifyCode", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }
}

public indirect enum SignInPhoneCodeSendParams: Sendable {
  case case1(SignInPhoneCodeSendCodeParamsCase1)
  case case2(SignInPhoneCodeSendCodeParamsCase2)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInPhoneCodeSendParams {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(SignInPhoneCodeSendCodeParamsCase1.decode(payload, in: runtime))
    case 1: return try .case2(SignInPhoneCodeSendCodeParamsCase2.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct SignInPhoneCodeSendCodeParamsCase1: Sendable {
  public let channel: PhoneCodeChannel?
  public let phoneNumber: String?
  public init(channel: PhoneCodeChannel? = nil, phoneNumber: String? = nil) {
    self.channel = channel
    self.phoneNumber = phoneNumber
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "channel": channel.map { value in try value.encode() } ?? .undefined,
      "phoneNumber": phoneNumber.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInPhoneCodeSendCodeParamsCase1 {
    let values = try value.object()

    return try SignInPhoneCodeSendCodeParamsCase1(channel: (values["channel"] ?? .undefined).optional { value in try PhoneCodeChannel.decode(value, in: runtime) }, phoneNumber: (values["phoneNumber"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct SignInPhoneCodeSendCodeParamsCase2: Sendable {
  public let channel: PhoneCodeChannel?
  public let phoneNumberId: String
  public init(channel: PhoneCodeChannel? = nil, phoneNumberId: String) {
    self.channel = channel
    self.phoneNumberId = phoneNumberId
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "channel": channel.map { value in try value.encode() } ?? .undefined,
      "phoneNumberId": .string(phoneNumberId),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInPhoneCodeSendCodeParamsCase2 {
    let values = try value.object()

    return try SignInPhoneCodeSendCodeParamsCase2(channel: (values["channel"] ?? .undefined).optional { value in try PhoneCodeChannel.decode(value, in: runtime) }, phoneNumberId: (values["phoneNumberId"] ?? .undefined).string())
  }
}

public struct SignInPhoneCodeVerifyParams: Sendable {
  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInPhoneCodeVerifyParams {
    let values = try value.object()

    return try SignInPhoneCodeVerifyParams(code: (values["code"] ?? .undefined).string())
  }
}

public struct SignInResetPasswordEmailCodeState: Sendable {
  public init() {}

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [:]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInResetPasswordEmailCodeState {
    let values = try value.object()

    return try SignInResetPasswordEmailCodeState()
  }
}

@MainActor @Observable public final class SignInResetPasswordEmailCode: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: SignInResetPasswordEmailCodeState {
    context.state(handle, as: SignInResetPasswordEmailCodeState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try SignInResetPasswordEmailCodeState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInResetPasswordEmailCode {
    try runtime.resource(ResourceHandle.decodeReference(value), as: SignInResetPasswordEmailCode.self)
  }

  /// Sends a password reset code to the first email address on the account.
  public func sendCode() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInResetPasswordEmailCode.sendCode", arguments: [])
    try runtime.checkErrorResult(result)
  }

  /// Verifies a password reset code sent with the [`resetPasswordEmailCode.sendCode()`](https://clerk.com/docs/reference/objects/sign-in-future#reset-password-email-code-send-code) method. Will cause `signIn.status` to become `'needs_new_password'`. This is when you will call the [`resetPasswordEmailCode.submitPassword()`](https://clerk.com/docs/reference/objects/sign-in-future#reset-password-email-code-submit-password) method to complete the password reset flow.
  public func verifyCode(_ params: SignInEmailCodeVerifyParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInResetPasswordEmailCode.verifyCode", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Submits a new password and moves the sign-in status to `'complete'`.
  public func submitPassword(_ params: SignInResetPasswordSubmitParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInResetPasswordEmailCode.submitPassword", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }
}

public struct SignInResetPasswordSubmitParams: Sendable {
  public let password: String
  public let signOutOfOtherSessions: Bool?
  public init(password: String, signOutOfOtherSessions: Bool? = nil) {
    self.password = password
    self.signOutOfOtherSessions = signOutOfOtherSessions
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "password": .string(password),
      "signOutOfOtherSessions": signOutOfOtherSessions.map { value in .bool(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInResetPasswordSubmitParams {
    let values = try value.object()

    return try SignInResetPasswordSubmitParams(password: (values["password"] ?? .undefined).string(), signOutOfOtherSessions: (values["signOutOfOtherSessions"] ?? .undefined).optional { value in try value.bool() })
  }
}

public struct SignInResetPasswordPhoneCodeState: Sendable {
  public init() {}

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [:]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInResetPasswordPhoneCodeState {
    let values = try value.object()

    return try SignInResetPasswordPhoneCodeState()
  }
}

@MainActor @Observable public final class SignInResetPasswordPhoneCode: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: SignInResetPasswordPhoneCodeState {
    context.state(handle, as: SignInResetPasswordPhoneCodeState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try SignInResetPasswordPhoneCodeState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInResetPasswordPhoneCode {
    try runtime.resource(ResourceHandle.decodeReference(value), as: SignInResetPasswordPhoneCode.self)
  }

  /// Sends a password reset code to the first phone number on the account.
  public func sendCode(_ params: SignInResetPasswordPhoneCodeSendParams? = nil) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInResetPasswordPhoneCode.sendCode", arguments: [params.map { value in try value.encode() } ?? .undefined])
    try runtime.checkErrorResult(result)
  }

  /// Verifies a password reset code sent with the [`resetPasswordPhoneCode.sendCode()`](https://clerk.com/docs/reference/objects/sign-in-future#reset-password-phone-code-send-code) method. Will cause `signIn.status` to become `'needs_new_password'`. This is when you will call the [`resetPasswordPhoneCode.submitPassword()`](https://clerk.com/docs/reference/objects/sign-in-future#reset-password-phone-code-submit-password) method to complete the password reset flow.
  public func verifyCode(_ params: SignInResetPasswordPhoneCodeVerifyParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInResetPasswordPhoneCode.verifyCode", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Submits a new password and moves the sign-in status to `'complete'`.
  public func submitPassword(_ params: SignInResetPasswordSubmitParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInResetPasswordPhoneCode.submitPassword", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }
}

public struct SignInResetPasswordPhoneCodeSendParams: Sendable {
  public let phoneNumber: String?
  public init(phoneNumber: String? = nil) {
    self.phoneNumber = phoneNumber
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "phoneNumber": phoneNumber.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInResetPasswordPhoneCodeSendParams {
    let values = try value.object()

    return try SignInResetPasswordPhoneCodeSendParams(phoneNumber: (values["phoneNumber"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct SignInResetPasswordPhoneCodeVerifyParams: Sendable {
  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInResetPasswordPhoneCodeVerifyParams {
    let values = try value.object()

    return try SignInResetPasswordPhoneCodeVerifyParams(code: (values["code"] ?? .undefined).string())
  }
}

public struct SignInSSOParams: Sendable {
  public let strategy: SignInSSOParamsStrategy
  public let oidcPrompt: String?
  public let enterpriseConnectionId: String?
  public let identifier: String?
  public init(strategy: SignInSSOParamsStrategy, oidcPrompt: String? = nil, enterpriseConnectionId: String? = nil, identifier: String? = nil) {
    self.strategy = strategy
    self.oidcPrompt = oidcPrompt
    self.enterpriseConnectionId = enterpriseConnectionId
    self.identifier = identifier
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": strategy.encode(),
      "oidcPrompt": oidcPrompt.map { value in .string(value) } ?? .undefined,
      "enterpriseConnectionId": enterpriseConnectionId.map { value in .string(value) } ?? .undefined,
      "identifier": identifier.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInSSOParams {
    let values = try value.object()

    return try SignInSSOParams(strategy: SignInSSOParamsStrategy.decode(values["strategy"] ?? .undefined, in: runtime), oidcPrompt: (values["oidcPrompt"] ?? .undefined).optional { value in try value.string() }, enterpriseConnectionId: (values["enterpriseConnectionId"] ?? .undefined).optional { value in try value.string() }, identifier: (values["identifier"] ?? .undefined).optional { value in try value.string() })
  }
}

public enum SignInSSOParamsStrategy: Hashable, Sendable {
  case enterpriseSso
  case oauthFacebook
  case oauthGoogle
  case oauthHubspot
  case oauthGithub
  case oauthTiktok
  case oauthGitlab
  case oauthDiscord
  case oauthTwitter
  case oauthTwitch
  case oauthLinkedin
  case oauthLinkedinOidc
  case oauthDropbox
  case oauthAtlassian
  case oauthBitbucket
  case oauthMicrosoft
  case oauthNotion
  case oauthApple
  case oauthLine
  case oauthInstagram
  case oauthCoinbase
  case oauthSpotify
  case oauthXero
  case oauthBox
  case oauthSlack
  case oauthLinear
  case oauthX
  case oauthEnstall
  case oauthHuggingface
  case oauthVercel
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .enterpriseSso: "enterprise_sso"
    case .oauthFacebook: "oauth_facebook"
    case .oauthGoogle: "oauth_google"
    case .oauthHubspot: "oauth_hubspot"
    case .oauthGithub: "oauth_github"
    case .oauthTiktok: "oauth_tiktok"
    case .oauthGitlab: "oauth_gitlab"
    case .oauthDiscord: "oauth_discord"
    case .oauthTwitter: "oauth_twitter"
    case .oauthTwitch: "oauth_twitch"
    case .oauthLinkedin: "oauth_linkedin"
    case .oauthLinkedinOidc: "oauth_linkedin_oidc"
    case .oauthDropbox: "oauth_dropbox"
    case .oauthAtlassian: "oauth_atlassian"
    case .oauthBitbucket: "oauth_bitbucket"
    case .oauthMicrosoft: "oauth_microsoft"
    case .oauthNotion: "oauth_notion"
    case .oauthApple: "oauth_apple"
    case .oauthLine: "oauth_line"
    case .oauthInstagram: "oauth_instagram"
    case .oauthCoinbase: "oauth_coinbase"
    case .oauthSpotify: "oauth_spotify"
    case .oauthXero: "oauth_xero"
    case .oauthBox: "oauth_box"
    case .oauthSlack: "oauth_slack"
    case .oauthLinear: "oauth_linear"
    case .oauthX: "oauth_x"
    case .oauthEnstall: "oauth_enstall"
    case .oauthHuggingface: "oauth_huggingface"
    case .oauthVercel: "oauth_vercel"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "enterprise_sso": self = .enterpriseSso
    case "oauth_facebook": self = .oauthFacebook
    case "oauth_google": self = .oauthGoogle
    case "oauth_hubspot": self = .oauthHubspot
    case "oauth_github": self = .oauthGithub
    case "oauth_tiktok": self = .oauthTiktok
    case "oauth_gitlab": self = .oauthGitlab
    case "oauth_discord": self = .oauthDiscord
    case "oauth_twitter": self = .oauthTwitter
    case "oauth_twitch": self = .oauthTwitch
    case "oauth_linkedin": self = .oauthLinkedin
    case "oauth_linkedin_oidc": self = .oauthLinkedinOidc
    case "oauth_dropbox": self = .oauthDropbox
    case "oauth_atlassian": self = .oauthAtlassian
    case "oauth_bitbucket": self = .oauthBitbucket
    case "oauth_microsoft": self = .oauthMicrosoft
    case "oauth_notion": self = .oauthNotion
    case "oauth_apple": self = .oauthApple
    case "oauth_line": self = .oauthLine
    case "oauth_instagram": self = .oauthInstagram
    case "oauth_coinbase": self = .oauthCoinbase
    case "oauth_spotify": self = .oauthSpotify
    case "oauth_xero": self = .oauthXero
    case "oauth_box": self = .oauthBox
    case "oauth_slack": self = .oauthSlack
    case "oauth_linear": self = .oauthLinear
    case "oauth_x": self = .oauthX
    case "oauth_enstall": self = .oauthEnstall
    case "oauth_huggingface": self = .oauthHuggingface
    case "oauth_vercel": self = .oauthVercel
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInSSOParamsStrategy {
    try .init(rawValue: value.string())
  }
}

public struct SignInMfaState: Sendable {
  public init() {}

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [:]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInMfaState {
    let values = try value.object()

    return try SignInMfaState()
  }
}

@MainActor @Observable public final class SignInMfa: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: SignInMfaState {
    context.state(handle, as: SignInMfaState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try SignInMfaState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInMfa {
    try runtime.resource(ResourceHandle.decodeReference(value), as: SignInMfa.self)
  }

  /// Sends a phone code to sign in with as a second factor.
  public func sendPhoneCode() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInMfa.sendPhoneCode", arguments: [])
    try runtime.checkErrorResult(result)
  }

  /// Verifies a phone code sent with the [`mfa.sendPhoneCode()`](https://clerk.com/docs/reference/objects/sign-in-future#mfa-send-phone-code) method.
  public func verifyPhoneCode(_ params: SignInMFAPhoneCodeVerifyParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInMfa.verifyPhoneCode", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Sends an email code to sign in with as a second factor.
  public func sendEmailCode() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInMfa.sendEmailCode", arguments: [])
    try runtime.checkErrorResult(result)
  }

  /// Verifies an email code sent with the [`mfa.sendEmailCode()`](https://clerk.com/docs/reference/objects/sign-in-future#mfa-send-email-code) method.
  public func verifyEmailCode(_ params: SignInMFAEmailCodeVerifyParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInMfa.verifyEmailCode", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Verifies an authenticator app (TOTP) code to sign in with as a second factor.
  public func verifyTOTP(_ params: SignInTOTPVerifyParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInMfa.verifyTOTP", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Verifies a backup code to sign in with as a second factor.
  public func verifyBackupCode(_ params: SignInBackupCodeVerifyParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignInMfa.verifyBackupCode", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }
}

public struct SignInMFAPhoneCodeVerifyParams: Sendable {
  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInMFAPhoneCodeVerifyParams {
    let values = try value.object()

    return try SignInMFAPhoneCodeVerifyParams(code: (values["code"] ?? .undefined).string())
  }
}

public struct SignInMFAEmailCodeVerifyParams: Sendable {
  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInMFAEmailCodeVerifyParams {
    let values = try value.object()

    return try SignInMFAEmailCodeVerifyParams(code: (values["code"] ?? .undefined).string())
  }
}

public struct SignInTOTPVerifyParams: Sendable {
  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInTOTPVerifyParams {
    let values = try value.object()

    return try SignInTOTPVerifyParams(code: (values["code"] ?? .undefined).string())
  }
}

public struct SignInBackupCodeVerifyParams: Sendable {
  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInBackupCodeVerifyParams {
    let values = try value.object()

    return try SignInBackupCodeVerifyParams(code: (values["code"] ?? .undefined).string())
  }
}

public struct SignInTicketParams: Sendable {
  public let ticket: String
  public init(ticket: String) {
    self.ticket = ticket
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "ticket": .string(ticket),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInTicketParams {
    let values = try value.object()

    return try SignInTicketParams(ticket: (values["ticket"] ?? .undefined).string())
  }
}

public struct SignInPasskeyParams: Sendable {
  public let flow: SignInPasskeyParamsFlow?
  public init(flow: SignInPasskeyParamsFlow? = nil) {
    self.flow = flow
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "flow": flow.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignInPasskeyParams {
    let values = try value.object()

    return try SignInPasskeyParams(flow: (values["flow"] ?? .undefined).optional { value in try SignInPasskeyParamsFlow.decode(value, in: runtime) })
  }
}

public enum SignInPasskeyParamsFlow: Hashable, Sendable {
  case autofill
  case discoverable
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .autofill: "autofill"
    case .discoverable: "discoverable"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "autofill": self = .autofill
    case "discoverable": self = .discoverable
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInPasskeyParamsFlow {
    try .init(rawValue: value.string())
  }
}

public struct SignInSubmitProtectCheckParams: Sendable {
  public let proofToken: String
  public init(proofToken: String) {
    self.proofToken = proofToken
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "proofToken": .string(proofToken),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignInSubmitProtectCheckParams {
    let values = try value.object()

    return try SignInSubmitProtectCheckParams(proofToken: (values["proofToken"] ?? .undefined).string())
  }
}

/// The `SignUpFuture` class holds the state of the current sign-up attempt and provides methods to drive custom sign-up flows, including email/phone verification, password, SSO, ticket-based, and Web3-based account creation.
public struct SignUpState: Sendable {
  public let id: String?
  public let status: SignUpStatus
  public let requiredFields: [SignUpField]
  public let optionalFields: [SignUpField]
  public let missingFields: [SignUpField]
  public let unverifiedFields: [SignUpIdentificationField]
  public let isTransferable: Bool
  public let existingSession: SignUpExistingSession?
  public let username: String?
  public let firstName: String?
  public let lastName: String?
  public let emailAddress: String?
  public let phoneNumber: String?
  public let web3Wallet: String?
  public let hasPassword: Bool
  public let unsafeMetadata: [String: JSONValue]
  public let createdSessionId: String?
  public let createdUserId: String?
  public let abandonAt: Double?
  public let legalAcceptedAt: Double?
  public let locale: String?
  public let protectCheck: ProtectCheck?
  public let canBeDiscarded: Bool
  public let verifications: SignUpVerifications
  public init(id: String? = nil, status: SignUpStatus, requiredFields: [SignUpField], optionalFields: [SignUpField], missingFields: [SignUpField], unverifiedFields: [SignUpIdentificationField], isTransferable: Bool, existingSession: SignUpExistingSession? = nil, username: String?, firstName: String?, lastName: String?, emailAddress: String?, phoneNumber: String?, web3Wallet: String?, hasPassword: Bool, unsafeMetadata: [String: JSONValue], createdSessionId: String?, createdUserId: String?, abandonAt: Double?, legalAcceptedAt: Double?, locale: String?, protectCheck: ProtectCheck?, canBeDiscarded: Bool, verifications: SignUpVerifications) {
    self.id = id
    self.status = status
    self.requiredFields = requiredFields
    self.optionalFields = optionalFields
    self.missingFields = missingFields
    self.unverifiedFields = unverifiedFields
    self.isTransferable = isTransferable
    self.existingSession = existingSession
    self.username = username
    self.firstName = firstName
    self.lastName = lastName
    self.emailAddress = emailAddress
    self.phoneNumber = phoneNumber
    self.web3Wallet = web3Wallet
    self.hasPassword = hasPassword
    self.unsafeMetadata = unsafeMetadata
    self.createdSessionId = createdSessionId
    self.createdUserId = createdUserId
    self.abandonAt = abandonAt
    self.legalAcceptedAt = legalAcceptedAt
    self.locale = locale
    self.protectCheck = protectCheck
    self.canBeDiscarded = canBeDiscarded
    self.verifications = verifications
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "id": id.map { value in .string(value) } ?? .undefined,
      "status": status.encode(),
      "requiredFields": .array(requiredFields.map { value in try value.encode() }),
      "optionalFields": .array(optionalFields.map { value in try value.encode() }),
      "missingFields": .array(missingFields.map { value in try value.encode() }),
      "unverifiedFields": .array(unverifiedFields.map { value in try value.encode() }),
      "isTransferable": .bool(isTransferable),
      "existingSession": existingSession.map { value in try value.encode() } ?? .undefined,
      "username": username.map { value in .string(value) } ?? .null,
      "firstName": firstName.map { value in .string(value) } ?? .null,
      "lastName": lastName.map { value in .string(value) } ?? .null,
      "emailAddress": emailAddress.map { value in .string(value) } ?? .null,
      "phoneNumber": phoneNumber.map { value in .string(value) } ?? .null,
      "web3Wallet": web3Wallet.map { value in .string(value) } ?? .null,
      "hasPassword": .bool(hasPassword),
      "unsafeMetadata": .object(unsafeMetadata),
      "createdSessionId": createdSessionId.map { value in .string(value) } ?? .null,
      "createdUserId": createdUserId.map { value in .string(value) } ?? .null,
      "abandonAt": abandonAt.map { value in .number(value) } ?? .null,
      "legalAcceptedAt": legalAcceptedAt.map { value in .number(value) } ?? .null,
      "locale": locale.map { value in .string(value) } ?? .null,
      "protectCheck": protectCheck.map { value in try value.encode() } ?? .null,
      "canBeDiscarded": .bool(canBeDiscarded),
      "verifications": verifications.encode(),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignUpState {
    let values = try value.object()

    return try SignUpState(id: (values["id"] ?? .undefined).optional { value in try value.string() }, status: SignUpStatus.decode(values["status"] ?? .undefined, in: runtime), requiredFields: (values["requiredFields"] ?? .undefined).array().map { value in try SignUpField.decode(value, in: runtime) }, optionalFields: (values["optionalFields"] ?? .undefined).array().map { value in try SignUpField.decode(value, in: runtime) }, missingFields: (values["missingFields"] ?? .undefined).array().map { value in try SignUpField.decode(value, in: runtime) }, unverifiedFields: (values["unverifiedFields"] ?? .undefined).array().map { value in try SignUpIdentificationField.decode(value, in: runtime) }, isTransferable: (values["isTransferable"] ?? .undefined).bool(), existingSession: (values["existingSession"] ?? .undefined).optional { value in try SignUpExistingSession.decode(value, in: runtime) }, username: (values["username"] ?? .undefined).optional { value in try value.string() }, firstName: (values["firstName"] ?? .undefined).optional { value in try value.string() }, lastName: (values["lastName"] ?? .undefined).optional { value in try value.string() }, emailAddress: (values["emailAddress"] ?? .undefined).optional { value in try value.string() }, phoneNumber: (values["phoneNumber"] ?? .undefined).optional { value in try value.string() }, web3Wallet: (values["web3Wallet"] ?? .undefined).optional { value in try value.string() }, hasPassword: (values["hasPassword"] ?? .undefined).bool(), unsafeMetadata: (values["unsafeMetadata"] ?? .undefined).object(), createdSessionId: (values["createdSessionId"] ?? .undefined).optional { value in try value.string() }, createdUserId: (values["createdUserId"] ?? .undefined).optional { value in try value.string() }, abandonAt: (values["abandonAt"] ?? .undefined).optional { value in try value.number() }, legalAcceptedAt: (values["legalAcceptedAt"] ?? .undefined).optional { value in try value.number() }, locale: (values["locale"] ?? .undefined).optional { value in try value.string() }, protectCheck: (values["protectCheck"] ?? .undefined).optional { value in try ProtectCheck.decode(value, in: runtime) }, canBeDiscarded: (values["canBeDiscarded"] ?? .undefined).bool(), verifications: SignUpVerifications.decode(values["verifications"] ?? .undefined, in: runtime))
  }
}

@MainActor @Observable public final class SignUp: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: SignUpState {
    context.state(handle, as: SignUpState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var id: String? {
    state.id
  }

  public var status: SignUpStatus {
    state.status
  }

  public var requiredFields: [SignUpField] {
    state.requiredFields
  }

  public var optionalFields: [SignUpField] {
    state.optionalFields
  }

  public var missingFields: [SignUpField] {
    state.missingFields
  }

  public var unverifiedFields: [SignUpIdentificationField] {
    state.unverifiedFields
  }

  public var isTransferable: Bool {
    state.isTransferable
  }

  public var existingSession: SignUpExistingSession? {
    state.existingSession
  }

  public var username: String? {
    state.username
  }

  public var firstName: String? {
    state.firstName
  }

  public var lastName: String? {
    state.lastName
  }

  public var emailAddress: String? {
    state.emailAddress
  }

  public var phoneNumber: String? {
    state.phoneNumber
  }

  public var web3Wallet: String? {
    state.web3Wallet
  }

  public var hasPassword: Bool {
    state.hasPassword
  }

  public var unsafeMetadata: [String: JSONValue] {
    state.unsafeMetadata
  }

  public var createdSessionId: String? {
    state.createdSessionId
  }

  public var createdUserId: String? {
    state.createdUserId
  }

  public var abandonAt: Double? {
    state.abandonAt
  }

  public var legalAcceptedAt: Double? {
    state.legalAcceptedAt
  }

  public var locale: String? {
    state.locale
  }

  public var protectCheck: ProtectCheck? {
    state.protectCheck
  }

  public var canBeDiscarded: Bool {
    state.canBeDiscarded
  }

  public var verifications: SignUpVerifications {
    state.verifications
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try SignUpState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignUp {
    try runtime.resource(ResourceHandle.decodeReference(value), as: SignUp.self)
  }

  /// Creates a new `SignUp` instance initialized with the provided parameters. The instance maintains the sign-up lifecycle state through its `status` property, which updates as the authentication flow progresses. Will also deactivate any existing sign-up process the client may already have in progress. Once the sign-up process is complete, call the [`signUp.finalize()`](https://clerk.com/docs/reference/objects/sign-up-future#finalize) method to set the newly created session as the active session.
  ///
  /// What you must pass to `params` depends on which [sign-up options](https://clerk.com/docs/guides/configure/auth-strategies/sign-up-sign-in-options) you have enabled in your app's settings in the Clerk Dashboard.
  ///
  /// You can complete the sign-up process in one step if you supply the required fields to `create()`. Otherwise, Clerk's sign-up process provides great flexibility and allows users to easily create multi-step sign-up flows.
  ///
  /// > [!IMPORTANT]
  /// > The `signUp.create()` method is intended for advanced use cases. For most use cases, prefer the use of the factor-specific methods such as `signUp.password()`, `signUp.sso()`, etc.
  public func create(_ params: SignUpCreateParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUp.create", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Updates the current `SignUpFuture` instance with the provided parameters.
  public func update(_ params: SignUpUpdateParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUp.update", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Performs a password-based sign-up.
  public func password(_ params: SignUpPasswordParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUp.password", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Performs an SSO-based sign-up ([Social/OAuth](https://clerk.com/docs/guides/configure/auth-strategies/social-connections/overview) or [Enterprise](https://clerk.com/docs/guides/configure/auth-strategies/enterprise-connections/overview)).
  public func sso(_ params: SignUpSSOParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUp.sso", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Performs a ticket-based sign-up.
  public func ticket(_ params: SignUpTicketParams? = nil) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUp.ticket", arguments: [params.map { value in try value.encode() } ?? .undefined])
    try runtime.checkErrorResult(result)
  }

  /// Submits a proof token to resolve a pending protect check challenge. The response may contain another `protectCheck` (a chained challenge) which must be resolved iteratively.
  public func submitProtectCheck(_ params: SignUpSubmitProtectCheckParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUp.submitProtectCheck", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Converts a sign-up with `status === 'complete'` into an active session. Will cause anything observing the session state (such as the [`useUser()`](https://clerk.com/docs/reference/hooks/use-user) hook) to update automatically.
  public func finalize() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUp.finalize", arguments: [])
    try runtime.checkErrorResult(result)
  }

  /// Resets the current sign-up attempt by clearing all local state back to null. This is useful when you want to allow users to go back to the beginning of the sign-up flow (e.g., to change their email address during verification).
  ///
  /// Unlike other methods, `reset()` does not trigger the `fetchStatus` to change to `'fetching'` and does not make any API calls - it only clears local state.
  public func reset() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUp.reset", arguments: [])
    try runtime.checkErrorResult(result)
  }
}

public enum SignUpStatus: Hashable, Sendable {
  case abandoned
  case complete
  case missingRequirements
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .abandoned: "abandoned"
    case .complete: "complete"
    case .missingRequirements: "missing_requirements"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "abandoned": self = .abandoned
    case "complete": self = .complete
    case "missing_requirements": self = .missingRequirements
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpStatus {
    try .init(rawValue: value.string())
  }
}

public enum SignUpField: Hashable, Sendable {
  case enterpriseSso
  case oauthFacebook
  case oauthGoogle
  case oauthHubspot
  case oauthGithub
  case oauthTiktok
  case oauthGitlab
  case oauthDiscord
  case oauthTwitter
  case oauthTwitch
  case oauthLinkedin
  case oauthLinkedinOidc
  case oauthDropbox
  case oauthAtlassian
  case oauthBitbucket
  case oauthMicrosoft
  case oauthNotion
  case oauthApple
  case oauthLine
  case oauthInstagram
  case oauthCoinbase
  case oauthSpotify
  case oauthXero
  case oauthBox
  case oauthSlack
  case oauthLinear
  case oauthX
  case oauthEnstall
  case oauthHuggingface
  case oauthVercel
  case username
  case firstName
  case lastName
  case password
  case legalAccepted
  case emailAddress
  case phoneNumber
  case emailAddressOrPhoneNumber
  case web3Wallet
  case protectCheck
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .enterpriseSso: "enterprise_sso"
    case .oauthFacebook: "oauth_facebook"
    case .oauthGoogle: "oauth_google"
    case .oauthHubspot: "oauth_hubspot"
    case .oauthGithub: "oauth_github"
    case .oauthTiktok: "oauth_tiktok"
    case .oauthGitlab: "oauth_gitlab"
    case .oauthDiscord: "oauth_discord"
    case .oauthTwitter: "oauth_twitter"
    case .oauthTwitch: "oauth_twitch"
    case .oauthLinkedin: "oauth_linkedin"
    case .oauthLinkedinOidc: "oauth_linkedin_oidc"
    case .oauthDropbox: "oauth_dropbox"
    case .oauthAtlassian: "oauth_atlassian"
    case .oauthBitbucket: "oauth_bitbucket"
    case .oauthMicrosoft: "oauth_microsoft"
    case .oauthNotion: "oauth_notion"
    case .oauthApple: "oauth_apple"
    case .oauthLine: "oauth_line"
    case .oauthInstagram: "oauth_instagram"
    case .oauthCoinbase: "oauth_coinbase"
    case .oauthSpotify: "oauth_spotify"
    case .oauthXero: "oauth_xero"
    case .oauthBox: "oauth_box"
    case .oauthSlack: "oauth_slack"
    case .oauthLinear: "oauth_linear"
    case .oauthX: "oauth_x"
    case .oauthEnstall: "oauth_enstall"
    case .oauthHuggingface: "oauth_huggingface"
    case .oauthVercel: "oauth_vercel"
    case .username: "username"
    case .firstName: "first_name"
    case .lastName: "last_name"
    case .password: "password"
    case .legalAccepted: "legal_accepted"
    case .emailAddress: "email_address"
    case .phoneNumber: "phone_number"
    case .emailAddressOrPhoneNumber: "email_address_or_phone_number"
    case .web3Wallet: "web3_wallet"
    case .protectCheck: "protect_check"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "enterprise_sso": self = .enterpriseSso
    case "oauth_facebook": self = .oauthFacebook
    case "oauth_google": self = .oauthGoogle
    case "oauth_hubspot": self = .oauthHubspot
    case "oauth_github": self = .oauthGithub
    case "oauth_tiktok": self = .oauthTiktok
    case "oauth_gitlab": self = .oauthGitlab
    case "oauth_discord": self = .oauthDiscord
    case "oauth_twitter": self = .oauthTwitter
    case "oauth_twitch": self = .oauthTwitch
    case "oauth_linkedin": self = .oauthLinkedin
    case "oauth_linkedin_oidc": self = .oauthLinkedinOidc
    case "oauth_dropbox": self = .oauthDropbox
    case "oauth_atlassian": self = .oauthAtlassian
    case "oauth_bitbucket": self = .oauthBitbucket
    case "oauth_microsoft": self = .oauthMicrosoft
    case "oauth_notion": self = .oauthNotion
    case "oauth_apple": self = .oauthApple
    case "oauth_line": self = .oauthLine
    case "oauth_instagram": self = .oauthInstagram
    case "oauth_coinbase": self = .oauthCoinbase
    case "oauth_spotify": self = .oauthSpotify
    case "oauth_xero": self = .oauthXero
    case "oauth_box": self = .oauthBox
    case "oauth_slack": self = .oauthSlack
    case "oauth_linear": self = .oauthLinear
    case "oauth_x": self = .oauthX
    case "oauth_enstall": self = .oauthEnstall
    case "oauth_huggingface": self = .oauthHuggingface
    case "oauth_vercel": self = .oauthVercel
    case "username": self = .username
    case "first_name": self = .firstName
    case "last_name": self = .lastName
    case "password": self = .password
    case "legal_accepted": self = .legalAccepted
    case "email_address": self = .emailAddress
    case "phone_number": self = .phoneNumber
    case "email_address_or_phone_number": self = .emailAddressOrPhoneNumber
    case "web3_wallet": self = .web3Wallet
    case "protect_check": self = .protectCheck
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpField {
    try .init(rawValue: value.string())
  }
}

public enum SignUpIdentificationField: Hashable, Sendable {
  case enterpriseSso
  case oauthFacebook
  case oauthGoogle
  case oauthHubspot
  case oauthGithub
  case oauthTiktok
  case oauthGitlab
  case oauthDiscord
  case oauthTwitter
  case oauthTwitch
  case oauthLinkedin
  case oauthLinkedinOidc
  case oauthDropbox
  case oauthAtlassian
  case oauthBitbucket
  case oauthMicrosoft
  case oauthNotion
  case oauthApple
  case oauthLine
  case oauthInstagram
  case oauthCoinbase
  case oauthSpotify
  case oauthXero
  case oauthBox
  case oauthSlack
  case oauthLinear
  case oauthX
  case oauthEnstall
  case oauthHuggingface
  case oauthVercel
  case username
  case emailAddress
  case phoneNumber
  case emailAddressOrPhoneNumber
  case web3Wallet
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .enterpriseSso: "enterprise_sso"
    case .oauthFacebook: "oauth_facebook"
    case .oauthGoogle: "oauth_google"
    case .oauthHubspot: "oauth_hubspot"
    case .oauthGithub: "oauth_github"
    case .oauthTiktok: "oauth_tiktok"
    case .oauthGitlab: "oauth_gitlab"
    case .oauthDiscord: "oauth_discord"
    case .oauthTwitter: "oauth_twitter"
    case .oauthTwitch: "oauth_twitch"
    case .oauthLinkedin: "oauth_linkedin"
    case .oauthLinkedinOidc: "oauth_linkedin_oidc"
    case .oauthDropbox: "oauth_dropbox"
    case .oauthAtlassian: "oauth_atlassian"
    case .oauthBitbucket: "oauth_bitbucket"
    case .oauthMicrosoft: "oauth_microsoft"
    case .oauthNotion: "oauth_notion"
    case .oauthApple: "oauth_apple"
    case .oauthLine: "oauth_line"
    case .oauthInstagram: "oauth_instagram"
    case .oauthCoinbase: "oauth_coinbase"
    case .oauthSpotify: "oauth_spotify"
    case .oauthXero: "oauth_xero"
    case .oauthBox: "oauth_box"
    case .oauthSlack: "oauth_slack"
    case .oauthLinear: "oauth_linear"
    case .oauthX: "oauth_x"
    case .oauthEnstall: "oauth_enstall"
    case .oauthHuggingface: "oauth_huggingface"
    case .oauthVercel: "oauth_vercel"
    case .username: "username"
    case .emailAddress: "email_address"
    case .phoneNumber: "phone_number"
    case .emailAddressOrPhoneNumber: "email_address_or_phone_number"
    case .web3Wallet: "web3_wallet"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "enterprise_sso": self = .enterpriseSso
    case "oauth_facebook": self = .oauthFacebook
    case "oauth_google": self = .oauthGoogle
    case "oauth_hubspot": self = .oauthHubspot
    case "oauth_github": self = .oauthGithub
    case "oauth_tiktok": self = .oauthTiktok
    case "oauth_gitlab": self = .oauthGitlab
    case "oauth_discord": self = .oauthDiscord
    case "oauth_twitter": self = .oauthTwitter
    case "oauth_twitch": self = .oauthTwitch
    case "oauth_linkedin": self = .oauthLinkedin
    case "oauth_linkedin_oidc": self = .oauthLinkedinOidc
    case "oauth_dropbox": self = .oauthDropbox
    case "oauth_atlassian": self = .oauthAtlassian
    case "oauth_bitbucket": self = .oauthBitbucket
    case "oauth_microsoft": self = .oauthMicrosoft
    case "oauth_notion": self = .oauthNotion
    case "oauth_apple": self = .oauthApple
    case "oauth_line": self = .oauthLine
    case "oauth_instagram": self = .oauthInstagram
    case "oauth_coinbase": self = .oauthCoinbase
    case "oauth_spotify": self = .oauthSpotify
    case "oauth_xero": self = .oauthXero
    case "oauth_box": self = .oauthBox
    case "oauth_slack": self = .oauthSlack
    case "oauth_linear": self = .oauthLinear
    case "oauth_x": self = .oauthX
    case "oauth_enstall": self = .oauthEnstall
    case "oauth_huggingface": self = .oauthHuggingface
    case "oauth_vercel": self = .oauthVercel
    case "username": self = .username
    case "email_address": self = .emailAddress
    case "phone_number": self = .phoneNumber
    case "email_address_or_phone_number": self = .emailAddressOrPhoneNumber
    case "web3_wallet": self = .web3Wallet
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpIdentificationField {
    try .init(rawValue: value.string())
  }
}

public struct SignUpExistingSession: Sendable {
  public let sessionId: String
  public init(sessionId: String) {
    self.sessionId = sessionId
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "sessionId": .string(sessionId),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpExistingSession {
    let values = try value.object()

    return try SignUpExistingSession(sessionId: (values["sessionId"] ?? .undefined).string())
  }
}

public struct SignUpCreateParams: Sendable {
  public let strategy: SignUpCreateParamsStrategy?
  public let emailAddress: String?
  public let phoneNumber: String?
  public let username: String?
  public let password: String?
  public let transfer: Bool?
  public let ticket: String?
  public let web3Wallet: String?
  public let firstName: String?
  public let lastName: String?
  public let unsafeMetadata: [String: JSONValue]?
  public let legalAccepted: Bool?
  public let locale: String?
  public init(strategy: SignUpCreateParamsStrategy? = nil, emailAddress: String? = nil, phoneNumber: String? = nil, username: String? = nil, password: String? = nil, transfer: Bool? = nil, ticket: String? = nil, web3Wallet: String? = nil, firstName: String? = nil, lastName: String? = nil, unsafeMetadata: [String: JSONValue]? = nil, legalAccepted: Bool? = nil, locale: String? = nil) {
    self.strategy = strategy
    self.emailAddress = emailAddress
    self.phoneNumber = phoneNumber
    self.username = username
    self.password = password
    self.transfer = transfer
    self.ticket = ticket
    self.web3Wallet = web3Wallet
    self.firstName = firstName
    self.lastName = lastName
    self.unsafeMetadata = unsafeMetadata
    self.legalAccepted = legalAccepted
    self.locale = locale
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": strategy.map { value in try value.encode() } ?? .undefined,
      "emailAddress": emailAddress.map { value in .string(value) } ?? .undefined,
      "phoneNumber": phoneNumber.map { value in .string(value) } ?? .undefined,
      "username": username.map { value in .string(value) } ?? .undefined,
      "password": password.map { value in .string(value) } ?? .undefined,
      "transfer": transfer.map { value in .bool(value) } ?? .undefined,
      "ticket": ticket.map { value in .string(value) } ?? .undefined,
      "web3Wallet": web3Wallet.map { value in .string(value) } ?? .undefined,
      "firstName": firstName.map { value in .string(value) } ?? .undefined,
      "lastName": lastName.map { value in .string(value) } ?? .undefined,
      "unsafeMetadata": unsafeMetadata.map { value in .object(value) } ?? .undefined,
      "legalAccepted": legalAccepted.map { value in .bool(value) } ?? .undefined,
      "locale": locale.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignUpCreateParams {
    let values = try value.object()

    return try SignUpCreateParams(strategy: (values["strategy"] ?? .undefined).optional { value in try SignUpCreateParamsStrategy.decode(value, in: runtime) }, emailAddress: (values["emailAddress"] ?? .undefined).optional { value in try value.string() }, phoneNumber: (values["phoneNumber"] ?? .undefined).optional { value in try value.string() }, username: (values["username"] ?? .undefined).optional { value in try value.string() }, password: (values["password"] ?? .undefined).optional { value in try value.string() }, transfer: (values["transfer"] ?? .undefined).optional { value in try value.bool() }, ticket: (values["ticket"] ?? .undefined).optional { value in try value.string() }, web3Wallet: (values["web3Wallet"] ?? .undefined).optional { value in try value.string() }, firstName: (values["firstName"] ?? .undefined).optional { value in try value.string() }, lastName: (values["lastName"] ?? .undefined).optional { value in try value.string() }, unsafeMetadata: (values["unsafeMetadata"] ?? .undefined).optional { value in try value.object() }, legalAccepted: (values["legalAccepted"] ?? .undefined).optional { value in try value.bool() }, locale: (values["locale"] ?? .undefined).optional { value in try value.string() })
  }
}

public enum SignUpCreateParamsStrategy: Hashable, Sendable {
  case enterpriseSso
  case oauthFacebook
  case oauthGoogle
  case oauthHubspot
  case oauthGithub
  case oauthTiktok
  case oauthGitlab
  case oauthDiscord
  case oauthTwitter
  case oauthTwitch
  case oauthLinkedin
  case oauthLinkedinOidc
  case oauthDropbox
  case oauthAtlassian
  case oauthBitbucket
  case oauthMicrosoft
  case oauthNotion
  case oauthApple
  case oauthLine
  case oauthInstagram
  case oauthCoinbase
  case oauthSpotify
  case oauthXero
  case oauthBox
  case oauthSlack
  case oauthLinear
  case oauthX
  case oauthEnstall
  case oauthHuggingface
  case oauthVercel
  case phoneCode
  case ticket
  case googleOneTap
  case oauthTokenApple
  case unrecognized(String)
  public var rawValue: String {
    switch self {
    case .enterpriseSso: "enterprise_sso"
    case .oauthFacebook: "oauth_facebook"
    case .oauthGoogle: "oauth_google"
    case .oauthHubspot: "oauth_hubspot"
    case .oauthGithub: "oauth_github"
    case .oauthTiktok: "oauth_tiktok"
    case .oauthGitlab: "oauth_gitlab"
    case .oauthDiscord: "oauth_discord"
    case .oauthTwitter: "oauth_twitter"
    case .oauthTwitch: "oauth_twitch"
    case .oauthLinkedin: "oauth_linkedin"
    case .oauthLinkedinOidc: "oauth_linkedin_oidc"
    case .oauthDropbox: "oauth_dropbox"
    case .oauthAtlassian: "oauth_atlassian"
    case .oauthBitbucket: "oauth_bitbucket"
    case .oauthMicrosoft: "oauth_microsoft"
    case .oauthNotion: "oauth_notion"
    case .oauthApple: "oauth_apple"
    case .oauthLine: "oauth_line"
    case .oauthInstagram: "oauth_instagram"
    case .oauthCoinbase: "oauth_coinbase"
    case .oauthSpotify: "oauth_spotify"
    case .oauthXero: "oauth_xero"
    case .oauthBox: "oauth_box"
    case .oauthSlack: "oauth_slack"
    case .oauthLinear: "oauth_linear"
    case .oauthX: "oauth_x"
    case .oauthEnstall: "oauth_enstall"
    case .oauthHuggingface: "oauth_huggingface"
    case .oauthVercel: "oauth_vercel"
    case .phoneCode: "phone_code"
    case .ticket: "ticket"
    case .googleOneTap: "google_one_tap"
    case .oauthTokenApple: "oauth_token_apple"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "enterprise_sso": self = .enterpriseSso
    case "oauth_facebook": self = .oauthFacebook
    case "oauth_google": self = .oauthGoogle
    case "oauth_hubspot": self = .oauthHubspot
    case "oauth_github": self = .oauthGithub
    case "oauth_tiktok": self = .oauthTiktok
    case "oauth_gitlab": self = .oauthGitlab
    case "oauth_discord": self = .oauthDiscord
    case "oauth_twitter": self = .oauthTwitter
    case "oauth_twitch": self = .oauthTwitch
    case "oauth_linkedin": self = .oauthLinkedin
    case "oauth_linkedin_oidc": self = .oauthLinkedinOidc
    case "oauth_dropbox": self = .oauthDropbox
    case "oauth_atlassian": self = .oauthAtlassian
    case "oauth_bitbucket": self = .oauthBitbucket
    case "oauth_microsoft": self = .oauthMicrosoft
    case "oauth_notion": self = .oauthNotion
    case "oauth_apple": self = .oauthApple
    case "oauth_line": self = .oauthLine
    case "oauth_instagram": self = .oauthInstagram
    case "oauth_coinbase": self = .oauthCoinbase
    case "oauth_spotify": self = .oauthSpotify
    case "oauth_xero": self = .oauthXero
    case "oauth_box": self = .oauthBox
    case "oauth_slack": self = .oauthSlack
    case "oauth_linear": self = .oauthLinear
    case "oauth_x": self = .oauthX
    case "oauth_enstall": self = .oauthEnstall
    case "oauth_huggingface": self = .oauthHuggingface
    case "oauth_vercel": self = .oauthVercel
    case "phone_code": self = .phoneCode
    case "ticket": self = .ticket
    case "google_one_tap": self = .googleOneTap
    case "oauth_token_apple": self = .oauthTokenApple
    default: self = .unrecognized(rawValue)
    }
  }

  public func encode() throws -> JSONValue {
    .string(rawValue)
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpCreateParamsStrategy {
    try .init(rawValue: value.string())
  }
}

public struct SignUpUpdateParams: Sendable {
  public let emailAddress: String?
  public let phoneNumber: String?
  public let username: String?
  public let firstName: String?
  public let lastName: String?
  public let unsafeMetadata: [String: JSONValue]?
  public let legalAccepted: Bool?
  public let locale: String?
  public init(emailAddress: String? = nil, phoneNumber: String? = nil, username: String? = nil, firstName: String? = nil, lastName: String? = nil, unsafeMetadata: [String: JSONValue]? = nil, legalAccepted: Bool? = nil, locale: String? = nil) {
    self.emailAddress = emailAddress
    self.phoneNumber = phoneNumber
    self.username = username
    self.firstName = firstName
    self.lastName = lastName
    self.unsafeMetadata = unsafeMetadata
    self.legalAccepted = legalAccepted
    self.locale = locale
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "emailAddress": emailAddress.map { value in .string(value) } ?? .undefined,
      "phoneNumber": phoneNumber.map { value in .string(value) } ?? .undefined,
      "username": username.map { value in .string(value) } ?? .undefined,
      "firstName": firstName.map { value in .string(value) } ?? .undefined,
      "lastName": lastName.map { value in .string(value) } ?? .undefined,
      "unsafeMetadata": unsafeMetadata.map { value in .object(value) } ?? .undefined,
      "legalAccepted": legalAccepted.map { value in .bool(value) } ?? .undefined,
      "locale": locale.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpUpdateParams {
    let values = try value.object()

    return try SignUpUpdateParams(emailAddress: (values["emailAddress"] ?? .undefined).optional { value in try value.string() }, phoneNumber: (values["phoneNumber"] ?? .undefined).optional { value in try value.string() }, username: (values["username"] ?? .undefined).optional { value in try value.string() }, firstName: (values["firstName"] ?? .undefined).optional { value in try value.string() }, lastName: (values["lastName"] ?? .undefined).optional { value in try value.string() }, unsafeMetadata: (values["unsafeMetadata"] ?? .undefined).optional { value in try value.object() }, legalAccepted: (values["legalAccepted"] ?? .undefined).optional { value in try value.bool() }, locale: (values["locale"] ?? .undefined).optional { value in try value.string() })
  }
}

/// Contains information about the available verification strategies for a sign-up attempt.
public struct SignUpVerificationsState: Sendable {
  public let emailAddress: SignUpVerification
  public let phoneNumber: SignUpVerification
  public let web3Wallet: Verification
  public let externalAccount: Verification
  public let emailLinkVerification: SignUpVerificationsEmailLinkVerification?
  public init(emailAddress: SignUpVerification, phoneNumber: SignUpVerification, web3Wallet: Verification, externalAccount: Verification, emailLinkVerification: SignUpVerificationsEmailLinkVerification?) {
    self.emailAddress = emailAddress
    self.phoneNumber = phoneNumber
    self.web3Wallet = web3Wallet
    self.externalAccount = externalAccount
    self.emailLinkVerification = emailLinkVerification
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "emailAddress": emailAddress.encode(),
      "phoneNumber": phoneNumber.encode(),
      "web3Wallet": web3Wallet.encode(),
      "externalAccount": externalAccount.encode(),
      "emailLinkVerification": emailLinkVerification.map { value in try value.encode() } ?? .null,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignUpVerificationsState {
    let values = try value.object()

    return try SignUpVerificationsState(emailAddress: SignUpVerification.decode(values["emailAddress"] ?? .undefined, in: runtime), phoneNumber: SignUpVerification.decode(values["phoneNumber"] ?? .undefined, in: runtime), web3Wallet: Verification.decode(values["web3Wallet"] ?? .undefined, in: runtime), externalAccount: Verification.decode(values["externalAccount"] ?? .undefined, in: runtime), emailLinkVerification: (values["emailLinkVerification"] ?? .undefined).optional { value in try SignUpVerificationsEmailLinkVerification.decode(value, in: runtime) })
  }
}

@MainActor @Observable public final class SignUpVerifications: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: SignUpVerificationsState {
    context.state(handle, as: SignUpVerificationsState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var emailAddress: SignUpVerification {
    state.emailAddress
  }

  public var phoneNumber: SignUpVerification {
    state.phoneNumber
  }

  public var web3Wallet: Verification {
    state.web3Wallet
  }

  public var externalAccount: Verification {
    state.externalAccount
  }

  public var emailLinkVerification: SignUpVerificationsEmailLinkVerification? {
    state.emailLinkVerification
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try SignUpVerificationsState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignUpVerifications {
    try runtime.resource(ResourceHandle.decodeReference(value), as: SignUpVerifications.self)
  }

  /// Sends an email code to verify an email address.
  public func sendEmailCode() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUpVerifications.sendEmailCode", arguments: [])
    try runtime.checkErrorResult(result)
  }

  /// Verifies a code sent with the [`verifications.sendEmailCode()`](https://clerk.com/docs/reference/objects/sign-up-future#verifications-send-email-code) method.
  public func verifyEmailCode(_ params: SignUpEmailCodeVerifyParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUpVerifications.verifyEmailCode", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Sends an email link to verify an email address.
  public func sendEmailLink(_ params: SignUpEmailLinkSendParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUpVerifications.sendEmailLink", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }

  /// Will wait for email link verification to complete or expire after calling [`verifications.sendEmailLink()`](https://clerk.com/docs/reference/objects/sign-up-future#verifications-send-email-link).
  public func waitForEmailLinkVerification() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUpVerifications.waitForEmailLinkVerification", arguments: [])
    try runtime.checkErrorResult(result)
  }

  /// Sends a phone code to verify a phone number.
  public func sendPhoneCode(_ params: SignUpPhoneCodeSendParams? = nil) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUpVerifications.sendPhoneCode", arguments: [params.map { value in try value.encode() } ?? .undefined])
    try runtime.checkErrorResult(result)
  }

  /// Verifies a code sent with the [`verifications.sendPhoneCode()`](https://clerk.com/docs/reference/objects/sign-up-future#verifications-send-phone-code) method.
  public func verifyPhoneCode(_ params: SignUpPhoneCodeVerifyParams) async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUpVerifications.verifyPhoneCode", arguments: [params.encode()])
    try runtime.checkErrorResult(result)
  }
}

public struct SignUpVerificationState: Sendable {
  public let supportedStrategies: [String]
  public let nextAction: String
  public let attempts: Double?
  public let error: ClerkAPIError?
  public let expireAt: Date?
  public let status: VerificationStatus?
  public let strategy: String?
  public let verifiedAtClient: String?
  public let channel: PhoneCodeChannel?
  public let id: String?
  public init(supportedStrategies: [String], nextAction: String, attempts: Double?, error: ClerkAPIError?, expireAt: Date?, status: VerificationStatus?, strategy: String?, verifiedAtClient: String?, channel: PhoneCodeChannel? = nil, id: String? = nil) {
    self.supportedStrategies = supportedStrategies
    self.nextAction = nextAction
    self.attempts = attempts
    self.error = error
    self.expireAt = expireAt
    self.status = status
    self.strategy = strategy
    self.verifiedAtClient = verifiedAtClient
    self.channel = channel
    self.id = id
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "supportedStrategies": .array(supportedStrategies.map { value in .string(value) }),
      "nextAction": .string(nextAction),
      "attempts": attempts.map { value in .number(value) } ?? .null,
      "error": error.map { value in try value.encode() } ?? .null,
      "expireAt": expireAt.map { value in .string(value.ISO8601Format(.init(includingFractionalSeconds: true))) } ?? .null,
      "status": status.map { value in try value.encode() } ?? .null,
      "strategy": strategy.map { value in .string(value) } ?? .null,
      "verifiedAtClient": verifiedAtClient.map { value in .string(value) } ?? .null,
      "channel": channel.map { value in try value.encode() } ?? .undefined,
      "id": id.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignUpVerificationState {
    let values = try value.object()

    return try SignUpVerificationState(supportedStrategies: (values["supportedStrategies"] ?? .undefined).array().map { value in try value.string() }, nextAction: (values["nextAction"] ?? .undefined).string(), attempts: (values["attempts"] ?? .undefined).optional { value in try value.number() }, error: (values["error"] ?? .undefined).optional { value in try ClerkAPIError.decode(value, in: runtime) }, expireAt: (values["expireAt"] ?? .undefined).optional { value in try value.date() }, status: (values["status"] ?? .undefined).optional { value in try VerificationStatus.decode(value, in: runtime) }, strategy: (values["strategy"] ?? .undefined).optional { value in try value.string() }, verifiedAtClient: (values["verifiedAtClient"] ?? .undefined).optional { value in try value.string() }, channel: (values["channel"] ?? .undefined).optional { value in try PhoneCodeChannel.decode(value, in: runtime) }, id: (values["id"] ?? .undefined).optional { value in try value.string() })
  }
}

@MainActor @Observable public final class SignUpVerification: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: SignUpVerificationState {
    context.state(handle, as: SignUpVerificationState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var supportedStrategies: [String] {
    state.supportedStrategies
  }

  public var nextAction: String {
    state.nextAction
  }

  public var attempts: Double? {
    state.attempts
  }

  public var error: ClerkAPIError? {
    state.error
  }

  public var expireAt: Date? {
    state.expireAt
  }

  public var status: VerificationStatus? {
    state.status
  }

  public var strategy: String? {
    state.strategy
  }

  public var verifiedAtClient: String? {
    state.verifiedAtClient
  }

  public var channel: PhoneCodeChannel? {
    state.channel
  }

  public var id: String? {
    state.id
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try SignUpVerificationState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignUpVerification {
    try runtime.resource(ResourceHandle.decodeReference(value), as: SignUpVerification.self)
  }

  public func verifiedFromTheSameClient() async throws -> Bool {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUpVerification.verifiedFromTheSameClient", arguments: [])
    return try result.bool()
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> SignUpVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "SignUpVerification.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try SignUpVerification.decode(result, in: runtime)
  }
}

public struct SignUpVerificationsEmailLinkVerification: Sendable {
  public let status: SignInEmailLinkVerificationStatus
  public let createdSessionId: String
  public let verifiedFromTheSameClient: Bool
  public init(status: SignInEmailLinkVerificationStatus, createdSessionId: String, verifiedFromTheSameClient: Bool) {
    self.status = status
    self.createdSessionId = createdSessionId
    self.verifiedFromTheSameClient = verifiedFromTheSameClient
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "status": status.encode(),
      "createdSessionId": .string(createdSessionId),
      "verifiedFromTheSameClient": .bool(verifiedFromTheSameClient),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignUpVerificationsEmailLinkVerification {
    let values = try value.object()

    return try SignUpVerificationsEmailLinkVerification(status: SignInEmailLinkVerificationStatus.decode(values["status"] ?? .undefined, in: runtime), createdSessionId: (values["createdSessionId"] ?? .undefined).string(), verifiedFromTheSameClient: (values["verifiedFromTheSameClient"] ?? .undefined).bool())
  }
}

public struct SignUpEmailCodeVerifyParams: Sendable {
  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpEmailCodeVerifyParams {
    let values = try value.object()

    return try SignUpEmailCodeVerifyParams(code: (values["code"] ?? .undefined).string())
  }
}

public struct SignUpEmailLinkSendParams: Sendable {
  public let verificationUrl: String
  public init(verificationUrl: String) {
    self.verificationUrl = verificationUrl
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "verificationUrl": .string(verificationUrl),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpEmailLinkSendParams {
    let values = try value.object()

    return try SignUpEmailLinkSendParams(verificationUrl: (values["verificationUrl"] ?? .undefined).string())
  }
}

public struct SignUpPhoneCodeSendParams: Sendable {
  public let channel: PhoneCodeChannel?
  public init(channel: PhoneCodeChannel? = nil) {
    self.channel = channel
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "channel": channel.map { value in try value.encode() } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignUpPhoneCodeSendParams {
    let values = try value.object()

    return try SignUpPhoneCodeSendParams(channel: (values["channel"] ?? .undefined).optional { value in try PhoneCodeChannel.decode(value, in: runtime) })
  }
}

public struct SignUpPhoneCodeVerifyParams: Sendable {
  public let code: String
  public init(code: String) {
    self.code = code
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "code": .string(code),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpPhoneCodeVerifyParams {
    let values = try value.object()

    return try SignUpPhoneCodeVerifyParams(code: (values["code"] ?? .undefined).string())
  }
}

public indirect enum SignUpPasswordParams: Sendable {
  case case1(SignUpPasswordParamsCase1)
  case case2(SignUpPasswordParamsCase2)
  case case3(SignUpPasswordParamsCase3)
  case case4(SignUpPasswordParamsCase4)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): try .object(["$case": .number(0), "value": value.encode()])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    case .case3(let value): try .object(["$case": .number(2), "value": value.encode()])
    case .case4(let value): try .object(["$case": .number(3), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> SignUpPasswordParams {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(SignUpPasswordParamsCase1.decode(payload, in: runtime))
    case 1: return try .case2(SignUpPasswordParamsCase2.decode(payload, in: runtime))
    case 2: return try .case3(SignUpPasswordParamsCase3.decode(payload, in: runtime))
    case 3: return try .case4(SignUpPasswordParamsCase4.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct SignUpPasswordParamsCase1: Sendable {
  public let firstName: String?
  public let lastName: String?
  public let unsafeMetadata: [String: JSONValue]?
  public let legalAccepted: Bool?
  public let locale: String?
  public let password: String
  public let emailAddress: String
  public let phoneNumber: String?
  public let username: String?
  public init(firstName: String? = nil, lastName: String? = nil, unsafeMetadata: [String: JSONValue]? = nil, legalAccepted: Bool? = nil, locale: String? = nil, password: String, emailAddress: String, phoneNumber: String? = nil, username: String? = nil) {
    self.firstName = firstName
    self.lastName = lastName
    self.unsafeMetadata = unsafeMetadata
    self.legalAccepted = legalAccepted
    self.locale = locale
    self.password = password
    self.emailAddress = emailAddress
    self.phoneNumber = phoneNumber
    self.username = username
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "firstName": firstName.map { value in .string(value) } ?? .undefined,
      "lastName": lastName.map { value in .string(value) } ?? .undefined,
      "unsafeMetadata": unsafeMetadata.map { value in .object(value) } ?? .undefined,
      "legalAccepted": legalAccepted.map { value in .bool(value) } ?? .undefined,
      "locale": locale.map { value in .string(value) } ?? .undefined,
      "password": .string(password),
      "emailAddress": .string(emailAddress),
      "phoneNumber": phoneNumber.map { value in .string(value) } ?? .undefined,
      "username": username.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpPasswordParamsCase1 {
    let values = try value.object()

    return try SignUpPasswordParamsCase1(firstName: (values["firstName"] ?? .undefined).optional { value in try value.string() }, lastName: (values["lastName"] ?? .undefined).optional { value in try value.string() }, unsafeMetadata: (values["unsafeMetadata"] ?? .undefined).optional { value in try value.object() }, legalAccepted: (values["legalAccepted"] ?? .undefined).optional { value in try value.bool() }, locale: (values["locale"] ?? .undefined).optional { value in try value.string() }, password: (values["password"] ?? .undefined).string(), emailAddress: (values["emailAddress"] ?? .undefined).string(), phoneNumber: (values["phoneNumber"] ?? .undefined).optional { value in try value.string() }, username: (values["username"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct SignUpPasswordParamsCase2: Sendable {
  public let firstName: String?
  public let lastName: String?
  public let unsafeMetadata: [String: JSONValue]?
  public let legalAccepted: Bool?
  public let locale: String?
  public let password: String
  public let emailAddress: String?
  public let phoneNumber: String
  public let username: String?
  public init(firstName: String? = nil, lastName: String? = nil, unsafeMetadata: [String: JSONValue]? = nil, legalAccepted: Bool? = nil, locale: String? = nil, password: String, emailAddress: String? = nil, phoneNumber: String, username: String? = nil) {
    self.firstName = firstName
    self.lastName = lastName
    self.unsafeMetadata = unsafeMetadata
    self.legalAccepted = legalAccepted
    self.locale = locale
    self.password = password
    self.emailAddress = emailAddress
    self.phoneNumber = phoneNumber
    self.username = username
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "firstName": firstName.map { value in .string(value) } ?? .undefined,
      "lastName": lastName.map { value in .string(value) } ?? .undefined,
      "unsafeMetadata": unsafeMetadata.map { value in .object(value) } ?? .undefined,
      "legalAccepted": legalAccepted.map { value in .bool(value) } ?? .undefined,
      "locale": locale.map { value in .string(value) } ?? .undefined,
      "password": .string(password),
      "emailAddress": emailAddress.map { value in .string(value) } ?? .undefined,
      "phoneNumber": .string(phoneNumber),
      "username": username.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpPasswordParamsCase2 {
    let values = try value.object()

    return try SignUpPasswordParamsCase2(firstName: (values["firstName"] ?? .undefined).optional { value in try value.string() }, lastName: (values["lastName"] ?? .undefined).optional { value in try value.string() }, unsafeMetadata: (values["unsafeMetadata"] ?? .undefined).optional { value in try value.object() }, legalAccepted: (values["legalAccepted"] ?? .undefined).optional { value in try value.bool() }, locale: (values["locale"] ?? .undefined).optional { value in try value.string() }, password: (values["password"] ?? .undefined).string(), emailAddress: (values["emailAddress"] ?? .undefined).optional { value in try value.string() }, phoneNumber: (values["phoneNumber"] ?? .undefined).string(), username: (values["username"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct SignUpPasswordParamsCase3: Sendable {
  public let firstName: String?
  public let lastName: String?
  public let unsafeMetadata: [String: JSONValue]?
  public let legalAccepted: Bool?
  public let locale: String?
  public let password: String
  public let emailAddress: String?
  public let phoneNumber: String?
  public let username: String
  public init(firstName: String? = nil, lastName: String? = nil, unsafeMetadata: [String: JSONValue]? = nil, legalAccepted: Bool? = nil, locale: String? = nil, password: String, emailAddress: String? = nil, phoneNumber: String? = nil, username: String) {
    self.firstName = firstName
    self.lastName = lastName
    self.unsafeMetadata = unsafeMetadata
    self.legalAccepted = legalAccepted
    self.locale = locale
    self.password = password
    self.emailAddress = emailAddress
    self.phoneNumber = phoneNumber
    self.username = username
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "firstName": firstName.map { value in .string(value) } ?? .undefined,
      "lastName": lastName.map { value in .string(value) } ?? .undefined,
      "unsafeMetadata": unsafeMetadata.map { value in .object(value) } ?? .undefined,
      "legalAccepted": legalAccepted.map { value in .bool(value) } ?? .undefined,
      "locale": locale.map { value in .string(value) } ?? .undefined,
      "password": .string(password),
      "emailAddress": emailAddress.map { value in .string(value) } ?? .undefined,
      "phoneNumber": phoneNumber.map { value in .string(value) } ?? .undefined,
      "username": .string(username),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpPasswordParamsCase3 {
    let values = try value.object()

    return try SignUpPasswordParamsCase3(firstName: (values["firstName"] ?? .undefined).optional { value in try value.string() }, lastName: (values["lastName"] ?? .undefined).optional { value in try value.string() }, unsafeMetadata: (values["unsafeMetadata"] ?? .undefined).optional { value in try value.object() }, legalAccepted: (values["legalAccepted"] ?? .undefined).optional { value in try value.bool() }, locale: (values["locale"] ?? .undefined).optional { value in try value.string() }, password: (values["password"] ?? .undefined).string(), emailAddress: (values["emailAddress"] ?? .undefined).optional { value in try value.string() }, phoneNumber: (values["phoneNumber"] ?? .undefined).optional { value in try value.string() }, username: (values["username"] ?? .undefined).string())
  }
}

public struct SignUpPasswordParamsCase4: Sendable {
  public let firstName: String?
  public let lastName: String?
  public let unsafeMetadata: [String: JSONValue]?
  public let legalAccepted: Bool?
  public let locale: String?
  public let password: String
  public let emailAddress: String?
  public let phoneNumber: String?
  public let username: String?
  public init(firstName: String? = nil, lastName: String? = nil, unsafeMetadata: [String: JSONValue]? = nil, legalAccepted: Bool? = nil, locale: String? = nil, password: String, emailAddress: String? = nil, phoneNumber: String? = nil, username: String? = nil) {
    self.firstName = firstName
    self.lastName = lastName
    self.unsafeMetadata = unsafeMetadata
    self.legalAccepted = legalAccepted
    self.locale = locale
    self.password = password
    self.emailAddress = emailAddress
    self.phoneNumber = phoneNumber
    self.username = username
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "firstName": firstName.map { value in .string(value) } ?? .undefined,
      "lastName": lastName.map { value in .string(value) } ?? .undefined,
      "unsafeMetadata": unsafeMetadata.map { value in .object(value) } ?? .undefined,
      "legalAccepted": legalAccepted.map { value in .bool(value) } ?? .undefined,
      "locale": locale.map { value in .string(value) } ?? .undefined,
      "password": .string(password),
      "emailAddress": emailAddress.map { value in .string(value) } ?? .undefined,
      "phoneNumber": phoneNumber.map { value in .string(value) } ?? .undefined,
      "username": username.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpPasswordParamsCase4 {
    let values = try value.object()

    return try SignUpPasswordParamsCase4(firstName: (values["firstName"] ?? .undefined).optional { value in try value.string() }, lastName: (values["lastName"] ?? .undefined).optional { value in try value.string() }, unsafeMetadata: (values["unsafeMetadata"] ?? .undefined).optional { value in try value.object() }, legalAccepted: (values["legalAccepted"] ?? .undefined).optional { value in try value.bool() }, locale: (values["locale"] ?? .undefined).optional { value in try value.string() }, password: (values["password"] ?? .undefined).string(), emailAddress: (values["emailAddress"] ?? .undefined).optional { value in try value.string() }, phoneNumber: (values["phoneNumber"] ?? .undefined).optional { value in try value.string() }, username: (values["username"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct SignUpSSOParams: Sendable {
  public let strategy: String
  public let oidcPrompt: String?
  public let enterpriseConnectionId: String?
  public let emailAddress: String?
  public let firstName: String?
  public let lastName: String?
  public let unsafeMetadata: [String: JSONValue]?
  public let legalAccepted: Bool?
  public let locale: String?
  public init(strategy: String, oidcPrompt: String? = nil, enterpriseConnectionId: String? = nil, emailAddress: String? = nil, firstName: String? = nil, lastName: String? = nil, unsafeMetadata: [String: JSONValue]? = nil, legalAccepted: Bool? = nil, locale: String? = nil) {
    self.strategy = strategy
    self.oidcPrompt = oidcPrompt
    self.enterpriseConnectionId = enterpriseConnectionId
    self.emailAddress = emailAddress
    self.firstName = firstName
    self.lastName = lastName
    self.unsafeMetadata = unsafeMetadata
    self.legalAccepted = legalAccepted
    self.locale = locale
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "strategy": .string(strategy),
      "oidcPrompt": oidcPrompt.map { value in .string(value) } ?? .undefined,
      "enterpriseConnectionId": enterpriseConnectionId.map { value in .string(value) } ?? .undefined,
      "emailAddress": emailAddress.map { value in .string(value) } ?? .undefined,
      "firstName": firstName.map { value in .string(value) } ?? .undefined,
      "lastName": lastName.map { value in .string(value) } ?? .undefined,
      "unsafeMetadata": unsafeMetadata.map { value in .object(value) } ?? .undefined,
      "legalAccepted": legalAccepted.map { value in .bool(value) } ?? .undefined,
      "locale": locale.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpSSOParams {
    let values = try value.object()

    return try SignUpSSOParams(strategy: (values["strategy"] ?? .undefined).string(), oidcPrompt: (values["oidcPrompt"] ?? .undefined).optional { value in try value.string() }, enterpriseConnectionId: (values["enterpriseConnectionId"] ?? .undefined).optional { value in try value.string() }, emailAddress: (values["emailAddress"] ?? .undefined).optional { value in try value.string() }, firstName: (values["firstName"] ?? .undefined).optional { value in try value.string() }, lastName: (values["lastName"] ?? .undefined).optional { value in try value.string() }, unsafeMetadata: (values["unsafeMetadata"] ?? .undefined).optional { value in try value.object() }, legalAccepted: (values["legalAccepted"] ?? .undefined).optional { value in try value.bool() }, locale: (values["locale"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct SignUpTicketParams: Sendable {
  public let ticket: String
  public let firstName: String?
  public let lastName: String?
  public let unsafeMetadata: [String: JSONValue]?
  public let legalAccepted: Bool?
  public let locale: String?
  public init(ticket: String, firstName: String? = nil, lastName: String? = nil, unsafeMetadata: [String: JSONValue]? = nil, legalAccepted: Bool? = nil, locale: String? = nil) {
    self.ticket = ticket
    self.firstName = firstName
    self.lastName = lastName
    self.unsafeMetadata = unsafeMetadata
    self.legalAccepted = legalAccepted
    self.locale = locale
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "ticket": .string(ticket),
      "firstName": firstName.map { value in .string(value) } ?? .undefined,
      "lastName": lastName.map { value in .string(value) } ?? .undefined,
      "unsafeMetadata": unsafeMetadata.map { value in .object(value) } ?? .undefined,
      "legalAccepted": legalAccepted.map { value in .bool(value) } ?? .undefined,
      "locale": locale.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpTicketParams {
    let values = try value.object()

    return try SignUpTicketParams(ticket: (values["ticket"] ?? .undefined).string(), firstName: (values["firstName"] ?? .undefined).optional { value in try value.string() }, lastName: (values["lastName"] ?? .undefined).optional { value in try value.string() }, unsafeMetadata: (values["unsafeMetadata"] ?? .undefined).optional { value in try value.object() }, legalAccepted: (values["legalAccepted"] ?? .undefined).optional { value in try value.bool() }, locale: (values["locale"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct SignUpSubmitProtectCheckParams: Sendable {
  public let proofToken: String
  public init(proofToken: String) {
    self.proofToken = proofToken
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = [
      "proofToken": .string(proofToken),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SignUpSubmitProtectCheckParams {
    let values = try value.object()

    return try SignUpSubmitProtectCheckParams(proofToken: (values["proofToken"] ?? .undefined).string())
  }
}

public struct MobileSetActiveParams: Sendable {
  public let session: Field<MobileSetActiveParamsSession>
  public let organization: Field<MobileSetActiveParamsOrganization>
  public init(session: Field<MobileSetActiveParamsSession> = .omitted, organization: Field<MobileSetActiveParamsOrganization> = .omitted) {
    self.session = session
    self.organization = organization
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "session": session.encode { value in try value.encode() },
      "organization": organization.encode { value in try value.encode() },
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> MobileSetActiveParams {
    let values = try value.object()

    return try MobileSetActiveParams(session: Field.decode(values["session"] ?? .undefined) { value in try MobileSetActiveParamsSession.decode(value, in: runtime) }, organization: Field.decode(values["organization"] ?? .undefined) { value in try MobileSetActiveParamsOrganization.decode(value, in: runtime) })
  }
}

public indirect enum MobileSetActiveParamsSession: Sendable {
  case case1(String)
  case case2(ActiveSession)
  case case3(PendingSession)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): .object(["$case": .number(0), "value": .string(value)])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    case .case3(let value): try .object(["$case": .number(2), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> MobileSetActiveParamsSession {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(payload.string())
    case 1: return try .case2(ActiveSession.decode(payload, in: runtime))
    case 2: return try .case3(PendingSession.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

/// Represents a session resource that has completed all pending tasks
/// and authentication factors
public struct ActiveSessionState: Sendable {
  public var status: String {
    "active"
  }

  public let user: User
  public let id: String
  public let expireAt: Date
  public let abandonAt: Date
  public let factorVerificationAge: ActiveSessionFactorVerificationAgeValue?
  public let lastActiveOrganizationId: String?
  public let lastActiveAt: Date
  public let `actor`: [String: JSONValue]?
  public let agent: [String: JSONValue]?
  public let tasks: [SessionTask]?
  public let currentTask: SessionTask?
  public let publicUserData: PublicUserData
  public let createdAt: Date
  public let updatedAt: Date
  public init(user: User, id: String, expireAt: Date, abandonAt: Date, factorVerificationAge: ActiveSessionFactorVerificationAgeValue?, lastActiveOrganizationId: String?, lastActiveAt: Date, actor: [String: JSONValue]?, agent: [String: JSONValue]?, tasks: [SessionTask]?, currentTask: SessionTask? = nil, publicUserData: PublicUserData, createdAt: Date, updatedAt: Date) {
    self.user = user
    self.id = id
    self.expireAt = expireAt
    self.abandonAt = abandonAt
    self.factorVerificationAge = factorVerificationAge
    self.lastActiveOrganizationId = lastActiveOrganizationId
    self.lastActiveAt = lastActiveAt
    self.actor = actor
    self.agent = agent
    self.tasks = tasks
    self.currentTask = currentTask
    self.publicUserData = publicUserData
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "status": .string("active"),
      "user": user.encode(),
      "id": .string(id),
      "expireAt": .string(expireAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "abandonAt": .string(abandonAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "factorVerificationAge": factorVerificationAge.map { value in try value.encode() } ?? .null,
      "lastActiveOrganizationId": lastActiveOrganizationId.map { value in .string(value) } ?? .null,
      "lastActiveAt": .string(lastActiveAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "actor": actor.map { value in .object(value) } ?? .null,
      "agent": agent.map { value in .object(value) } ?? .null,
      "tasks": tasks.map { value in try .array(value.map { value in try value.encode() }) } ?? .null,
      "currentTask": currentTask.map { value in try value.encode() } ?? .undefined,
      "publicUserData": publicUserData.encode(),
      "createdAt": .string(createdAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "updatedAt": .string(updatedAt.ISO8601Format(.init(includingFractionalSeconds: true))),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ActiveSessionState {
    let values = try value.object()
    guard values["status"] == .string("active") else { throw CoreError.invalidValue }
    return try ActiveSessionState(user: User.decode(values["user"] ?? .undefined, in: runtime), id: (values["id"] ?? .undefined).string(), expireAt: (values["expireAt"] ?? .undefined).date(), abandonAt: (values["abandonAt"] ?? .undefined).date(), factorVerificationAge: (values["factorVerificationAge"] ?? .undefined).optional { value in try ActiveSessionFactorVerificationAgeValue.decode(value, in: runtime) }, lastActiveOrganizationId: (values["lastActiveOrganizationId"] ?? .undefined).optional { value in try value.string() }, lastActiveAt: (values["lastActiveAt"] ?? .undefined).date(), actor: (values["actor"] ?? .undefined).optional { value in try value.object() }, agent: (values["agent"] ?? .undefined).optional { value in try value.object() }, tasks: (values["tasks"] ?? .undefined).optional { value in try value.array().map { value in try SessionTask.decode(value, in: runtime) } }, currentTask: (values["currentTask"] ?? .undefined).optional { value in try SessionTask.decode(value, in: runtime) }, publicUserData: PublicUserData.decode(values["publicUserData"] ?? .undefined, in: runtime), createdAt: (values["createdAt"] ?? .undefined).date(), updatedAt: (values["updatedAt"] ?? .undefined).date())
  }
}

@MainActor @Observable public final class ActiveSession: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: ActiveSessionState {
    context.state(handle, as: ActiveSessionState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var status: String {
    state.status
  }

  public var user: User {
    state.user
  }

  public var id: String {
    state.id
  }

  public var expireAt: Date {
    state.expireAt
  }

  public var abandonAt: Date {
    state.abandonAt
  }

  public var factorVerificationAge: ActiveSessionFactorVerificationAgeValue? {
    state.factorVerificationAge
  }

  public var lastActiveOrganizationId: String? {
    state.lastActiveOrganizationId
  }

  public var lastActiveAt: Date {
    state.lastActiveAt
  }

  public var `actor`: [String: JSONValue]? {
    state.actor
  }

  public var agent: [String: JSONValue]? {
    state.agent
  }

  public var tasks: [SessionTask]? {
    state.tasks
  }

  public var currentTask: SessionTask? {
    state.currentTask
  }

  public var publicUserData: PublicUserData {
    state.publicUserData
  }

  public var createdAt: Date {
    state.createdAt
  }

  public var updatedAt: Date {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try ActiveSessionState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> ActiveSession {
    try runtime.resource(ResourceHandle.decodeReference(value), as: ActiveSession.self)
  }

  /// Marks the session as ended. The session will no longer be active for this `Client` and its status will become **ended**.
  public func end() async throws -> Session {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ActiveSession.end", arguments: [])
    return try Session.decode(result, in: runtime)
  }

  /// Invalidates the current session by marking it as removed. Once removed, the session will be deactivated for the current Client instance and its `status` will be set to `removed`. This operation cannot be undone.
  public func remove() async throws -> Session {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ActiveSession.remove", arguments: [])
    return try Session.decode(result, in: runtime)
  }

  /// Updates the session's last active timestamp to the current time. This method should be called periodically to indicate ongoing user activity and prevent the session from becoming stale. The updated timestamp is used for session management and analytics purposes.
  public func touch(_ params: SessionTouchParams? = nil) async throws -> Session {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ActiveSession.touch", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try Session.decode(result, in: runtime)
  }

  /// Gets the current user's [session token](https://clerk.com/docs/guides/sessions/session-tokens) or a [custom JWT template](https://clerk.com/docs/guides/sessions/jwt-templates).
  ///
  /// This method uses a cache so a network request will only be made if the token in memory has expired. The TTL for a Clerk token is one minute. It retries on transient failures (e.g., network errors); when the browser is offline and retries are exhausted, it throws `ClerkOfflineError`.
  ///
  /// Tokens can only be generated if the user is signed in.
  public func getToken(_ options: GetTokenOptions? = nil) async throws -> String? {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ActiveSession.getToken", arguments: [options.map { value in try value.encode() } ?? .undefined])
    return try result.optional { value in try value.string() }
  }

  /// Checks if the user is [authorized for the specified Role, Permission, Feature, or Plan](https://clerk.com/docs/guides/secure/authorization-checks) or requires the user to [reverify their credentials](https://clerk.com/docs/guides/secure/reverification) if their last verification is older than allowed.
  public func checkAuthorization(_ isAuthorizedParams: CheckAuthorizationParams) async throws -> Bool {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ActiveSession.checkAuthorization", arguments: [isAuthorizedParams.encode()])
    return try result.bool()
  }

  /// Clears the cache for the current session. This is useful if the session has been updated and the cache is no longer valid.
  public func clearCache() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ActiveSession.clearCache", arguments: [])
    _ = result
  }

  /// Initiates the reverification flow.
  public func startVerification(_ params: SessionVerifyCreateParams) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ActiveSession.startVerification", arguments: [params.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Initiates the [first factor verification](!first-factor-verification) process. This is a required step to complete a reverification flow when using a preparable factor.
  public func prepareFirstFactorVerification(_ factor: SessionVerifyPrepareFirstFactorParams) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ActiveSession.prepareFirstFactorVerification", arguments: [factor.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Attempts to complete the [first factor verification](!first-factor-verification) process.
  public func attemptFirstFactorVerification(_ attemptFactor: SessionVerifyAttemptFirstFactorParams) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ActiveSession.attemptFirstFactorVerification", arguments: [attemptFactor.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Initiates the [second factor verification](!second-factor-verification) process. This is a required step to complete a reverification flow when using a preparable factor.
  public func prepareSecondFactorVerification(_ params: PhoneCodeSecondFactorConfig) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ActiveSession.prepareSecondFactorVerification", arguments: [params.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Attempts to complete the [second factor verification](!second-factor-verification) process.
  public func attemptSecondFactorVerification(_ params: SessionVerifyAttemptSecondFactorParams) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ActiveSession.attemptSecondFactorVerification", arguments: [params.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Initiates a verification flow using passkeys.
  public func verifyWithPasskey() async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ActiveSession.verifyWithPasskey", arguments: [])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> ActiveSession {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "ActiveSession.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try ActiveSession.decode(result, in: runtime)
  }
}

/// Represents a session resource that has completed sign-in but has pending tasks
public struct PendingSessionState: Sendable {
  public var status: String {
    "pending"
  }

  public let user: User
  public let currentTask: SessionTask
  public let id: String
  public let expireAt: Date
  public let abandonAt: Date
  public let factorVerificationAge: PendingSessionFactorVerificationAgeValue?
  public let lastActiveOrganizationId: String?
  public let lastActiveAt: Date
  public let `actor`: [String: JSONValue]?
  public let agent: [String: JSONValue]?
  public let tasks: [SessionTask]?
  public let publicUserData: PublicUserData
  public let createdAt: Date
  public let updatedAt: Date
  public init(user: User, currentTask: SessionTask, id: String, expireAt: Date, abandonAt: Date, factorVerificationAge: PendingSessionFactorVerificationAgeValue?, lastActiveOrganizationId: String?, lastActiveAt: Date, actor: [String: JSONValue]?, agent: [String: JSONValue]?, tasks: [SessionTask]?, publicUserData: PublicUserData, createdAt: Date, updatedAt: Date) {
    self.user = user
    self.currentTask = currentTask
    self.id = id
    self.expireAt = expireAt
    self.abandonAt = abandonAt
    self.factorVerificationAge = factorVerificationAge
    self.lastActiveOrganizationId = lastActiveOrganizationId
    self.lastActiveAt = lastActiveAt
    self.actor = actor
    self.agent = agent
    self.tasks = tasks
    self.publicUserData = publicUserData
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "status": .string("pending"),
      "user": user.encode(),
      "currentTask": currentTask.encode(),
      "id": .string(id),
      "expireAt": .string(expireAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "abandonAt": .string(abandonAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "factorVerificationAge": factorVerificationAge.map { value in try value.encode() } ?? .null,
      "lastActiveOrganizationId": lastActiveOrganizationId.map { value in .string(value) } ?? .null,
      "lastActiveAt": .string(lastActiveAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "actor": actor.map { value in .object(value) } ?? .null,
      "agent": agent.map { value in .object(value) } ?? .null,
      "tasks": tasks.map { value in try .array(value.map { value in try value.encode() }) } ?? .null,
      "publicUserData": publicUserData.encode(),
      "createdAt": .string(createdAt.ISO8601Format(.init(includingFractionalSeconds: true))),
      "updatedAt": .string(updatedAt.ISO8601Format(.init(includingFractionalSeconds: true))),
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PendingSessionState {
    let values = try value.object()
    guard values["status"] == .string("pending") else { throw CoreError.invalidValue }
    return try PendingSessionState(user: User.decode(values["user"] ?? .undefined, in: runtime), currentTask: SessionTask.decode(values["currentTask"] ?? .undefined, in: runtime), id: (values["id"] ?? .undefined).string(), expireAt: (values["expireAt"] ?? .undefined).date(), abandonAt: (values["abandonAt"] ?? .undefined).date(), factorVerificationAge: (values["factorVerificationAge"] ?? .undefined).optional { value in try PendingSessionFactorVerificationAgeValue.decode(value, in: runtime) }, lastActiveOrganizationId: (values["lastActiveOrganizationId"] ?? .undefined).optional { value in try value.string() }, lastActiveAt: (values["lastActiveAt"] ?? .undefined).date(), actor: (values["actor"] ?? .undefined).optional { value in try value.object() }, agent: (values["agent"] ?? .undefined).optional { value in try value.object() }, tasks: (values["tasks"] ?? .undefined).optional { value in try value.array().map { value in try SessionTask.decode(value, in: runtime) } }, publicUserData: PublicUserData.decode(values["publicUserData"] ?? .undefined, in: runtime), createdAt: (values["createdAt"] ?? .undefined).date(), updatedAt: (values["updatedAt"] ?? .undefined).date())
  }
}

@MainActor @Observable public final class PendingSession: CoreResource {
  public let handle: ResourceHandle
  public let context: ResourceContext
  public var isInvalidated: Bool {
    context.isInvalidated(handle)
  }

  public var state: PendingSessionState {
    context.state(handle, as: PendingSessionState.self)
  }

  public init(handle: ResourceHandle, runtime: CoreRuntime) {
    self.handle = handle; context = ResourceContext(runtime: runtime, handle: handle, ownsRuntime: false)
  }

  public var status: String {
    state.status
  }

  public var user: User {
    state.user
  }

  public var currentTask: SessionTask {
    state.currentTask
  }

  public var id: String {
    state.id
  }

  public var expireAt: Date {
    state.expireAt
  }

  public var abandonAt: Date {
    state.abandonAt
  }

  public var factorVerificationAge: PendingSessionFactorVerificationAgeValue? {
    state.factorVerificationAge
  }

  public var lastActiveOrganizationId: String? {
    state.lastActiveOrganizationId
  }

  public var lastActiveAt: Date {
    state.lastActiveAt
  }

  public var `actor`: [String: JSONValue]? {
    state.actor
  }

  public var agent: [String: JSONValue]? {
    state.agent
  }

  public var tasks: [SessionTask]? {
    state.tasks
  }

  public var publicUserData: PublicUserData {
    state.publicUserData
  }

  public var createdAt: Date {
    state.createdAt
  }

  public var updatedAt: Date {
    state.updatedAt
  }

  public func prepare(_ value: JSONValue) throws -> any Sendable {
    try PendingSessionState.decode(value, in: context.requireRuntime())
  }

  public func encode() throws -> JSONValue {
    .object(["$ref": handle.json])
  }

  public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> PendingSession {
    try runtime.resource(ResourceHandle.decodeReference(value), as: PendingSession.self)
  }

  /// Marks the session as ended. The session will no longer be active for this `Client` and its status will become **ended**.
  public func end() async throws -> Session {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PendingSession.end", arguments: [])
    return try Session.decode(result, in: runtime)
  }

  /// Invalidates the current session by marking it as removed. Once removed, the session will be deactivated for the current Client instance and its `status` will be set to `removed`. This operation cannot be undone.
  public func remove() async throws -> Session {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PendingSession.remove", arguments: [])
    return try Session.decode(result, in: runtime)
  }

  /// Updates the session's last active timestamp to the current time. This method should be called periodically to indicate ongoing user activity and prevent the session from becoming stale. The updated timestamp is used for session management and analytics purposes.
  public func touch(_ params: SessionTouchParams? = nil) async throws -> Session {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PendingSession.touch", arguments: [params.map { value in try value.encode() } ?? .undefined])
    return try Session.decode(result, in: runtime)
  }

  /// Gets the current user's [session token](https://clerk.com/docs/guides/sessions/session-tokens) or a [custom JWT template](https://clerk.com/docs/guides/sessions/jwt-templates).
  ///
  /// This method uses a cache so a network request will only be made if the token in memory has expired. The TTL for a Clerk token is one minute. It retries on transient failures (e.g., network errors); when the browser is offline and retries are exhausted, it throws `ClerkOfflineError`.
  ///
  /// Tokens can only be generated if the user is signed in.
  public func getToken(_ options: GetTokenOptions? = nil) async throws -> String? {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PendingSession.getToken", arguments: [options.map { value in try value.encode() } ?? .undefined])
    return try result.optional { value in try value.string() }
  }

  /// Checks if the user is [authorized for the specified Role, Permission, Feature, or Plan](https://clerk.com/docs/guides/secure/authorization-checks) or requires the user to [reverify their credentials](https://clerk.com/docs/guides/secure/reverification) if their last verification is older than allowed.
  public func checkAuthorization(_ isAuthorizedParams: CheckAuthorizationParams) async throws -> Bool {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PendingSession.checkAuthorization", arguments: [isAuthorizedParams.encode()])
    return try result.bool()
  }

  /// Clears the cache for the current session. This is useful if the session has been updated and the cache is no longer valid.
  public func clearCache() async throws {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PendingSession.clearCache", arguments: [])
    _ = result
  }

  /// Initiates the reverification flow.
  public func startVerification(_ params: SessionVerifyCreateParams) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PendingSession.startVerification", arguments: [params.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Initiates the [first factor verification](!first-factor-verification) process. This is a required step to complete a reverification flow when using a preparable factor.
  public func prepareFirstFactorVerification(_ factor: SessionVerifyPrepareFirstFactorParams) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PendingSession.prepareFirstFactorVerification", arguments: [factor.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Attempts to complete the [first factor verification](!first-factor-verification) process.
  public func attemptFirstFactorVerification(_ attemptFactor: SessionVerifyAttemptFirstFactorParams) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PendingSession.attemptFirstFactorVerification", arguments: [attemptFactor.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Initiates the [second factor verification](!second-factor-verification) process. This is a required step to complete a reverification flow when using a preparable factor.
  public func prepareSecondFactorVerification(_ params: PhoneCodeSecondFactorConfig) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PendingSession.prepareSecondFactorVerification", arguments: [params.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Attempts to complete the [second factor verification](!second-factor-verification) process.
  public func attemptSecondFactorVerification(_ params: SessionVerifyAttemptSecondFactorParams) async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PendingSession.attemptSecondFactorVerification", arguments: [params.encode()])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Initiates a verification flow using passkeys.
  public func verifyWithPasskey() async throws -> SessionVerification {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PendingSession.verifyWithPasskey", arguments: [])
    return try SessionVerification.decode(result, in: runtime)
  }

  /// Reloads the resource, which is useful when you want to access the latest user data after performing a mutation. To make the updated data immediately available, this method forces a session token refresh instead of waiting for the automatic refresh cycle that could temporarily retain stale information. Learn more about [forcing a token refresh](https://clerk.com/docs/guides/sessions/force-token-refresh).
  public func reload(_ p: ClerkResourceReloadParams? = nil) async throws -> PendingSession {
    let runtime = try context.requireRuntime()
    let result = try await runtime.invoke(owner: self, target: handle, operation: "PendingSession.reload", arguments: [p.map { value in try value.encode() } ?? .undefined])
    return try PendingSession.decode(result, in: runtime)
  }
}

public indirect enum MobileSetActiveParamsOrganization: Sendable {
  case case1(String)
  case case2(Organization)
  @MainActor public func encode() throws -> JSONValue {
    switch self {
    case .case1(let value): .object(["$case": .number(0), "value": .string(value)])
    case .case2(let value): try .object(["$case": .number(1), "value": value.encode()])
    }
  }

  @MainActor public static func decode(_ value: JSONValue, in runtime: CoreRuntime) throws -> MobileSetActiveParamsOrganization {
    let values = try value.object()
    let payload = values["value"] ?? .undefined
    switch try (values["$case"] ?? .undefined).number() {
    case 0: return try .case1(payload.string())
    case 1: return try .case2(Organization.decode(payload, in: runtime))
    default: throw CoreError.invalidValue
    }
  }
}

public struct MobileSignOutOptions: Sendable {
  public let sessionId: String?
  public init(sessionId: String? = nil) {
    self.sessionId = sessionId
  }

  @MainActor public func encode() throws -> JSONValue {
    let values: [String: JSONValue] = try [
      "sessionId": sessionId.map { value in .string(value) } ?? .undefined,
    ]
    return .object(values.filter { !$0.value.isUndefined })
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> MobileSignOutOptions {
    let values = try value.object()

    return try MobileSignOutOptions(sessionId: (values["sessionId"] ?? .undefined).optional { value in try value.string() })
  }
}

public struct SessionFactorVerificationAgeValue: Sendable {
  public let item0: Double
  public let item1: Double
  public init(item0: Double, item1: Double) {
    self.item0 = item0; self.item1 = item1
  }

  @MainActor public func encode() throws -> JSONValue {
    .array([.number(item0), .number(item1)])
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> SessionFactorVerificationAgeValue {
    let values = try value.array()
    guard values.count == 2 else { throw CoreError.invalidValue }
    return try SessionFactorVerificationAgeValue(item0: values[0].number(), item1: values[1].number())
  }
}

public struct ActiveSessionFactorVerificationAgeValue: Sendable {
  public let item0: Double
  public let item1: Double
  public init(item0: Double, item1: Double) {
    self.item0 = item0; self.item1 = item1
  }

  @MainActor public func encode() throws -> JSONValue {
    .array([.number(item0), .number(item1)])
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> ActiveSessionFactorVerificationAgeValue {
    let values = try value.array()
    guard values.count == 2 else { throw CoreError.invalidValue }
    return try ActiveSessionFactorVerificationAgeValue(item0: values[0].number(), item1: values[1].number())
  }
}

public struct PendingSessionFactorVerificationAgeValue: Sendable {
  public let item0: Double
  public let item1: Double
  public init(item0: Double, item1: Double) {
    self.item0 = item0; self.item1 = item1
  }

  @MainActor public func encode() throws -> JSONValue {
    .array([.number(item0), .number(item1)])
  }

  @MainActor public static func decode(_ value: JSONValue, in _: CoreRuntime) throws -> PendingSessionFactorVerificationAgeValue {
    let values = try value.array()
    guard values.count == 2 else { throw CoreError.invalidValue }
    return try PendingSessionFactorVerificationAgeValue(item0: values[0].number(), item1: values[1].number())
  }
}

@MainActor public enum GeneratedBindings {
  public static let contractHash = "0a52bc1140be0af0d047410ae267d11c38ed7c2244a335deb211c30131b85616"
  public static let protocolVersion = 1
  public static func makeResource(_ handle: ResourceHandle, runtime: CoreRuntime) throws -> any CoreResource {
    switch handle.type {
    case "Clerk": return Clerk(handle: handle, runtime: runtime)
    case "Organization": return Organization(handle: handle, runtime: runtime)
    case "OrganizationMembership": return OrganizationMembership(handle: handle, runtime: runtime)
    case "OrganizationInvitation": return OrganizationInvitation(handle: handle, runtime: runtime)
    case "Role": return Role(handle: handle, runtime: runtime)
    case "Permission": return Permission(handle: handle, runtime: runtime)
    case "OrganizationDomain": return OrganizationDomain(handle: handle, runtime: runtime)
    case "OrganizationMembershipRequest": return OrganizationMembershipRequest(handle: handle, runtime: runtime)
    case "EnterpriseConnection": return EnterpriseConnection(handle: handle, runtime: runtime)
    case "EnterpriseConnectionTestRun": return EnterpriseConnectionTestRun(handle: handle, runtime: runtime)
    case "BillingInitializedPaymentMethod": return BillingInitializedPaymentMethod(handle: handle, runtime: runtime)
    case "BillingPaymentMethod": return BillingPaymentMethod(handle: handle, runtime: runtime)
    case "Session": return Session(handle: handle, runtime: runtime)
    case "User": return User(handle: handle, runtime: runtime)
    case "EmailAddress": return EmailAddress(handle: handle, runtime: runtime)
    case "Verification": return Verification(handle: handle, runtime: runtime)
    case "IdentificationLink": return IdentificationLink(handle: handle, runtime: runtime)
    case "CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddress": return CreateEmailLinkFlowReturnStartEmailLinkFlowParamsAndEmailAddress(handle: handle, runtime: runtime)
    case "CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddress": return CreateEnterpriseSSOLinkFlowReturnStartEnterpriseSSOLinkFlowParamsAndEmailAddress(handle: handle, runtime: runtime)
    case "PhoneNumber": return PhoneNumber(handle: handle, runtime: runtime)
    case "Web3Wallet": return Web3Wallet(handle: handle, runtime: runtime)
    case "ExternalAccount": return ExternalAccount(handle: handle, runtime: runtime)
    case "EnterpriseAccount": return EnterpriseAccount(handle: handle, runtime: runtime)
    case "EnterpriseAccountConnection": return EnterpriseAccountConnection(handle: handle, runtime: runtime)
    case "Passkey": return Passkey(handle: handle, runtime: runtime)
    case "PasskeyVerification": return PasskeyVerification(handle: handle, runtime: runtime)
    case "SessionWithActivities": return SessionWithActivities(handle: handle, runtime: runtime)
    case "Image": return Image(handle: handle, runtime: runtime)
    case "UserOrganizationInvitation": return UserOrganizationInvitation(handle: handle, runtime: runtime)
    case "OrganizationSuggestion": return OrganizationSuggestion(handle: handle, runtime: runtime)
    case "OrganizationCreationDefaults": return OrganizationCreationDefaults(handle: handle, runtime: runtime)
    case "TOTP": return TOTP(handle: handle, runtime: runtime)
    case "BackupCode": return BackupCode(handle: handle, runtime: runtime)
    case "SessionVerification": return SessionVerification(handle: handle, runtime: runtime)
    case "SignIn": return SignIn(handle: handle, runtime: runtime)
    case "SignInEmailCode": return SignInEmailCode(handle: handle, runtime: runtime)
    case "SignInEmailLink": return SignInEmailLink(handle: handle, runtime: runtime)
    case "SignInPhoneCode": return SignInPhoneCode(handle: handle, runtime: runtime)
    case "SignInResetPasswordEmailCode": return SignInResetPasswordEmailCode(handle: handle, runtime: runtime)
    case "SignInResetPasswordPhoneCode": return SignInResetPasswordPhoneCode(handle: handle, runtime: runtime)
    case "SignInMfa": return SignInMfa(handle: handle, runtime: runtime)
    case "SignUp": return SignUp(handle: handle, runtime: runtime)
    case "SignUpVerifications": return SignUpVerifications(handle: handle, runtime: runtime)
    case "SignUpVerification": return SignUpVerification(handle: handle, runtime: runtime)
    case "ActiveSession": return ActiveSession(handle: handle, runtime: runtime)
    case "PendingSession": return PendingSession(handle: handle, runtime: runtime)
    default: throw CoreError.invalidResource
    }
  }
}
