import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";

const javascript = path.resolve(process.argv[2] ?? "../javascript");
const { fixture, response } = await import(
  pathToFileURL(
    path.join(javascript, "packages/mobile-runtime/test/protocol-fixture.mjs"),
  )
);
const { fixtures, sessionFixture } = await import(
  pathToFileURL(
    path.join(javascript, "packages/mobile-runtime/test/native-fixtures.mjs"),
  )
);
const directory = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../Sources/ClerkKitUI/Resources/Preview",
);
await fs.mkdir(directory, { recursive: true });
const now = 1700000000000;
const verified = (strategy) => ({
  status: "verified",
  strategy,
  attempts: 0,
  expire_at: null,
  error: null,
  verified_at_client: null,
});
const organization = {
  object: "organization",
  id: "org_preview",
  name: "Organization Name",
  slug: "org-slug",
  image_url: "",
  has_image: false,
  members_count: 3,
  pending_invitations_count: 1,
  max_allowed_memberships: 100,
  admin_delete_enabled: true,
  created_at: now,
  updated_at: now,
  public_metadata: {},
};
const membership = {
  object: "organization_membership",
  id: "orgmem_preview",
  role: "org:admin",
  role_name: "Admin",
  permissions: ["org:sys_memberships:read"],
  public_metadata: {},
  created_at: now,
  updated_at: now,
  organization,
  public_user_data: {
    first_name: "First",
    last_name: "Last",
    image_url: "",
    has_image: false,
    identifier: "identifier",
    user_id: "user_preview",
  },
};
const session = sessionFixture();
Object.assign(session, {
  id: "sess_preview",
  expire_at: 4102444800000,
  abandon_at: 4102444800000,
});
Object.assign(session.user, {
  id: "user_preview",
  first_name: "First",
  last_name: "Last",
  username: "username",
  has_image: false,
  create_organization_enabled: true,
  create_organizations_limit: 0,
  delete_self_enabled: true,
  backup_code_enabled: true,
  two_factor_enabled: true,
  primary_email_address_id: "ema_1",
  primary_phone_number_id: "phone_1",
  organization_memberships: [membership],
  email_addresses: [1, 2].map((i) => ({
    object: "email_address",
    id: `ema_${i}`,
    email_address: i === 1 ? "user@email.com" : "user2@email.com",
    verification: verified("email_code"),
    matches_sso_connection: false,
    linked_to: [],
    created_at: now,
  })),
  phone_numbers: [1, 2, 3].map((i) => ({
    object: "phone_number",
    id: `phone_${i}`,
    phone_number: `+1555555010${i - 1}`,
    reserved_for_second_factor: i === 3,
    default_second_factor: i === 3,
    verification: verified("phone_code"),
    linked_to: [],
    created_at: now,
  })),
  passkeys: [
    {
      object: "passkey",
      id: "passkey_preview",
      name: "iCloud Keychain",
      verification: verified("passkey"),
      created_at: now,
      updated_at: now,
      last_used_at: now,
    },
  ],
  external_accounts: [1, 2, 3].map((i) => ({
    object: "external_account",
    id: `ext_${i}`,
    identification_id: `ident_${i}`,
    provider: "oauth_google",
    provider_user_id: "1",
    email_address: "user@gmail.com",
    approved_scopes: "email openid profile",
    first_name: "First",
    last_name: "Last",
    image_url: "",
    username: "username",
    phone_number: "",
    public_metadata: {},
    verification: {
      ...verified("oauth_google"),
      status: i === 3 ? "unverified" : "verified",
    },
    created_at: now,
  })),
});
const sessions = [
  session,
  {
    ...structuredClone(session),
    id: "sess_preview_2",
    user: {
      ...structuredClone(session.user),
      id: "user_preview_2",
      first_name: null,
      last_name: null,
      username: "username2",
    },
  },
];
const activities = sessions.map((s, i) => ({
  ...s,
  latest_activity: {
    id: `activity_${i}`,
    browser_name: i ? "Chrome" : "Safari",
    browser_version: i ? "119.0.0" : "17.1.1",
    device_type: i ? "Macintosh" : "iPhone",
    ip_address: "196.172.122.88",
    city: "Detroit",
    country: "US",
    is_mobile: !i,
  },
}));
const baseDomain = {
  object: "organization_domain",
  id: "domain_preview",
  name: "name",
  organization_id: organization.id,
  enrollment_mode: "enrollment_mode",
  verification: {
    status: "unverified",
    strategy: "email_code",
    attempts: 1,
    expires_at: 4102444800000,
    error: null,
    verified_at_client: null,
  },
  affiliation_email_address: null,
  total_pending_invitations: 3,
  total_pending_suggestions: 3,
  created_at: now,
  updated_at: now,
};
for (const variant of [
  "default",
  "signedOut",
  "profile",
  "members",
  "domains",
  "enrollment",
  "completeProfile",
  "longOrganizationName",
]) {
  const client = {
    ...structuredClone(fixtures.client),
    id: "client_preview",
    sessions: structuredClone(sessions),
    last_active_session_id: session.id,
    sign_in: structuredClone(fixtures.signIn),
    sign_up: structuredClone(fixtures.signUp),
  };
  const environment = structuredClone(fixtures.environment);
  environment.organization_settings.domains.enabled = true;
  environment.organization_settings.domains.enrollment_modes = [
    "manual_invitation",
    "automatic_invitation",
    "automatic_suggestion",
  ];
  if (variant === "signedOut") {
    client.sessions = [];
    client.last_active_session_id = null;
  }
  if (variant === "completeProfile")
    client.sign_up.missing_fields = [
      "first_name",
      "last_name",
      "legal_accepted",
    ];
  if (["profile", "members", "domains", "enrollment"].includes(variant)) {
    client.sessions[0].last_active_organization_id = organization.id;
    client.sessions[0].user.organization_memberships[0].permissions =
      variant === "members"
        ? ["org:sys_memberships:read", "org:sys_memberships:manage"]
        : variant === "domains"
          ? ["org:sys_domains:read", "org:sys_domains:manage"]
          : [
              "org:sys_profile:manage",
              "org:sys_memberships:read",
              "org:sys_domains:read",
              "org:sys_profile:delete",
            ];
  }
  if (variant === "longOrganizationName")
    client.sessions[0].user.organization_memberships[0].organization.name =
      "Acme International Product Research and Operations";
  const domains =
    variant === "domains"
      ? [
          {
            ...baseDomain,
            id: "domain_1",
            name: "clerk.com",
            verification: { ...baseDomain.verification, status: "unverified" },
          },
          {
            ...baseDomain,
            id: "domain_2",
            name: "clerky.com",
            enrollment_mode: "manual_invitation",
            verification: { ...baseDomain.verification, status: "verified" },
          },
        ]
      : [
          {
            ...baseDomain,
            ...(variant === "enrollment"
              ? {
                  name: "clerky.com",
                  enrollment_mode: "manual_invitation",
                  verification: {
                    ...baseDomain.verification,
                    status: "verified",
                  },
                }
              : {}),
          },
        ];
  const f = await fixture({
    client,
    http(request) {
      const url = new URL(request.url);
      if (url.pathname.endsWith("/environment")) return response(environment);
      if (url.pathname.endsWith("/tokens")) return response(fixtures.token);
      if (url.pathname.endsWith("/touch"))
        return response({ client, response: client.sessions[0] });
      if (url.pathname.endsWith("/me/sessions/active"))
        return { status: 200, headers: {}, body: JSON.stringify(activities) };
      if (url.pathname.endsWith("/me"))
        return response(client.sessions[0].user);
      if (url.pathname.endsWith("/domains"))
        return response({ data: domains, total_count: domains.length });
      if (url.pathname.endsWith("/roles"))
        return response({
          data: [
            {
              object: "role",
              id: "role_preview",
              permissions: [],
              created_at: now,
              updated_at: now,
              key: "org:admin",
              name: "Admin",
              description: "Administrator",
            },
          ],
          total_count: 1,
        });
      if (url.pathname.endsWith("/memberships"))
        return response({
          data: [client.sessions[0].user.organization_memberships[0]],
          total_count: 1,
        });
      if (
        url.pathname.endsWith("/invitations") ||
        url.pathname.endsWith("/membership_requests") ||
        url.pathname.endsWith("/organization_suggestions")
      )
        return response({ data: [], total_count: 0 });
    },
  });
  try {
    const results = {};
    const call = async (target, operation, args = []) => {
      const result = await f.invoke(target, operation, args);
      if (result.failure)
        throw new Error(
          JSON.stringify({ variant, operation, failure: result.failure }),
        );
      results[operation] = result.result;
    };
    await call(f.group("clerk", "environment"), "EnvironmentResource.reload");
    if (variant !== "signedOut") {
      await call(f.state.roots.user, "User.getSessions");
      const orgRef = f.resource(f.state.roots.user).organizationMemberships[0]
        .$ref;
      const org = f.resource(orgRef).organization.$ref;
      await call(org, "Organization.getDomains", [
        { initialPage: 1, pageSize: 20 },
      ]);
      await call(org, "Organization.getRoles", [
        { initialPage: 1, pageSize: 20 },
      ]);
      await call(org, "Organization.getMemberships", [
        { initialPage: 1, pageSize: 20 },
      ]);
      await call(org, "Organization.getInvitations", [
        { initialPage: 1, pageSize: 20 },
      ]);
      await call(org, "Organization.getMembershipRequests", [
        { initialPage: 1, pageSize: 20 },
      ]);
    }
    const record = { manifest: f.ready.manifest, state: f.state, results };
    await fs.writeFile(
      path.join(directory, `${variant}.json`),
      JSON.stringify(record) + "\n",
    );
  } finally {
    f.dispose();
  }
}
console.log(
  "Generated SwiftUI preview fixtures through the packaged TypeScript core.",
);
