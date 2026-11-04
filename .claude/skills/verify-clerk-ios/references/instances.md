# Test instances

Each worktree has one Clerk application of its own. `up` creates it through Clerk's Platform API, specs run on its development instance, and `down` deletes it. Nothing is shared with another worktree or another repository, so a spec never meets users or settings that it did not make.

The application serves one run at a time, because the tests of a run change its settings. While one `run` drives, a second `run` in the same worktree waits for the device for as long as its `--wait` allows, and then fails with `DEVICE_BUSY`.

## The standard settings

`src/core/instances/base.json` of `@clerk/internal-mobile-e2e` defines the settings every new application gets. It has two parts.

- `config` is the whole body of the Platform API request that puts an instance on the standard settings. Everything that can coexist is switched on except the email link: email code, phone code, password, username, authenticator app, backup codes, and organizations. The email link is off so that an email sign-in opens on the code screen.
- `environment` lists the settings of the instance's public `/v1/environment` that a spec cannot run without.

After the CLI configures a new application, it reads that public environment. A difference in one of those settings fails with `INSTANCE_MISCONFIGURED` and names the setting. Run `down`, then `up` once more. If it fails again, Clerk changed what a setting does. Say so in your report.

## Change settings in a test

Every test starts on the standard settings. A test that needs another setting calls `host.useSettings` with the Platform API config leaves to change, each by its full dotted name:

```ts
await host.useSettings({ config: { 'auth_multi_factor.required_for_sign_up': true } });
```

The CLI reads the value that each leaf has now, changes it, and waits until the instance's public `/v1/environment` shows the change. Turning a feature off is the same call with the other value:

```ts
await host.useSettings({ config: { 'auth_multi_factor.authenticator_app.enabled': false } });
```

`environment` is optional. Without it, the CLI waits until any leaf of the public environment changes, up to 15 seconds, and records the leaves that changed. A setting that moves no public leaf goes on after the 15 seconds, and the CLI prints a `settings` line that says so. When you know the leaf that shows the change, name it. The wait then checks exactly that leaf, and a wrong expectation fails the call:

```ts
await host.useSettings({
  config: { 'organization_settings.force_organization_selection': true },
  environment: { 'organization_settings.force_organization_selection': true },
});
```

Call `host.useSettings` anywhere in a test, as many times as it needs. A call changes the settings from that point on. Clerk's servers apply the change at once. On iOS the SDK's screens showed it at once too: a sign-up started after the authenticator app was turned off met a setup-MFA task that offered only SMS, with no relaunch. The Android SDK keeps showing the settings it read at launch until the app launches again, so call `host.launch()` after `host.useSettings` unless the test is about an app that is already running. `session-tasks/setup-mfa-sms-only` does this.

Any leaf of the instance config works, not only the leaves in `base.json`. Clerk checks the request with a dry run before anything changes. A leaf that does not exist fails the call and lists the leaves beside it. A value Clerk refuses, or would store differently, also fails the call, and nothing changes. The Platform API cannot turn off reverification, the development-mode banner, test mode, or PII protection.

## Require a minimum app version

A minimum app version isn't a leaf that `host.useSettings` can name, because the bundle ID in its path holds dots and the app must be registered first. A test calls this instead:

```ts
await host.useMinimumAppVersion({ minimumVersion: '2.0', updateUrl: 'https://apps.apple.com/app/id000000000' });
```

The CLI registers the app under test with the application, which a later call finds already done, and sets the minimum through the Platform API config key `native_app_minimum_versions`. It then waits until `native_app_settings.minimum_supported_version` in the public `/v1/environment` shows it. Call it again in the same test to change the minimum. Clerk's `native_app_force_update` flag must be on for the instance.

## Restore

When a test ends, pass or fail, the CLI puts back every leaf that the test changed, to the value it read before the first change. A leaf changed twice goes back to its value before the first change. It deletes any minimum app version the test set and leaves the app registered. The next test starts on the standard settings again.

The restore runs in three places, so a crash does not leave the application changed:

- The test fixture restores when the test ends.
- `run` restores after e2e exits, in case e2e was stopped before the fixture could.
- The next `run` or `up` restores what a crashed CLI left. The CLI writes the old values to the worktree's state file before it changes anything, so it can always put them back.

`run.json` has one `settings` entry per call: `at` is the spec line that called `host.useSettings` or `host.useMinimumAppVersion`, `changed` lists each leaf with `from` and `to`, `shown` lists the environment leaves that showed the change, and `restored` says the leaves went back. `attach` refuses a run with an entry that was not restored.

## See the settings

`settings` prints the live config of this worktree's application, one leaf per line, with its exact dotted name and value. Each line pastes into `config`. Name a prefix to see part of it:

```console
$ e2e-tests/bin/control-clerk-ios settings auth_multi_factor
settings  app_… (verify-throwaway-…)  no change a test made is pending
"auth_multi_factor.authenticator_app.enabled": true,
"auth_multi_factor.backup_code.enabled": true,
"auth_multi_factor.required_for_sign_in": false,
"auth_multi_factor.required_for_sign_up": false,
```

`settings` reads Clerk's Platform API and never the device, so it works the same with a local and a remote device. It needs the application that `up` creates. When a crash left changes in place, its first line says how many leaves the next `run` or `up` restores.

## Settings that tests often change

| Setting | Config leaf | Example |
| --- | --- | --- |
| MFA required at sign-up | `auth_multi_factor.required_for_sign_up` | `{ 'auth_multi_factor.required_for_sign_up': true }` |
| MFA required at sign-in | `auth_multi_factor.required_for_sign_in` | `{ 'auth_multi_factor.required_for_sign_in': true }` |
| Authenticator app | `auth_multi_factor.authenticator_app.enabled` | `{ 'auth_multi_factor.authenticator_app.enabled': false }` |
| Backup codes | `auth_multi_factor.backup_code.enabled` | `{ 'auth_multi_factor.backup_code.enabled': false }` |
| Email link | `auth_email.sign_in_strategies`, `auth_email.verification_strategies` | `{ 'auth_email.sign_in_strategies': ['email_code', 'email_link'], 'auth_email.verification_strategies': ['email_code', 'email_link'] }` |
| Password | `auth_password.enabled`, `auth_password.required` | `{ 'auth_password.required': false }` |
| Username | `auth_username.used_for_sign_in`, `auth_username.required_for_sign_up` | `{ 'auth_username.required_for_sign_up': true }` |
| Organizations | `organization_settings.enabled` | `{ 'organization_settings.enabled': false }` |
| Force organization selection | `organization_settings.force_organization_selection` | `{ 'organization_settings.force_organization_selection': true }` |

Set an array leaf whole, with every value it keeps. The standard values are in `config` of `base.json`, and `settings` prints the live ones.

## The credential

One team key creates, changes, and deletes the application, and reads its secret key. The key needs four scopes: `applications:read`, `applications:manage`, `applications:delete`, and `application_secret_keys:read`. The CLI reads `MOBILE_VERIFICATION_PLATFORM_API_KEY` first, then the file that `MOBILE_VERIFICATION_PLATFORM_API_KEY_FILE` names. A variable that is set and does not work is an error. With neither variable set, the CLI reads the key's 1Password secret reference from `MOBILE_VERIFICATION_PLATFORM_API_KEY_REFERENCE` and asks the 1Password CLI for the key. The 1Password app then asks a person to approve, and a refused or unanswered request is an error.

Before it asks 1Password, the CLI sends one request with no key. In a cloud environment that holds the key as an API credential for `api.clerk.com`, the environment adds the key after the request leaves the machine, so that request succeeds and no key is ever in the session. [Remote devices](remote.md) has the setup.

`doctor`, `up`, and `run` use the credential every time, and `down` and `settings` use it when the worktree holds an application. `screen` and `attach` never use it. With 1Password each of those commands asks once.

With no credential, `doctor` fails `instances` and prints how to supply one. `up` and `run` fail with `KEYS_MISSING` before they lease a device. `down` releases the device first and then fails the same way, and `down` with the credential deletes the application later.

The key reaches only the team's verification workspace, which holds nothing but these applications. The CLI refuses a key of any other workspace. It also refuses to create or delete anything while that workspace holds an application whose name does not start with `verify-throwaway-`.

## Lifetime and limits

An application's name carries a deadline: `verify-throwaway-until-<utc>-<hex>`. The deadline is six hours after the application was created, and `VERIFY_THROWAWAY_HOURS` sets it to a whole number from 2 to 72. `down` deletes this worktree's application at once.

If a session ends without `down`, a later command on any machine deletes the application after its deadline and prints a `reap` line. Nothing is deleted before its own deadline, so no session can remove another session's live application.

`up` and `run` replace this worktree's application before they use it in two cases. The first is an application within an hour of its deadline. The second is an application that holds 60 or more users, because a Clerk development instance allows 100. Users seeded in the replaced application are gone.

Clerk allows the workspace 100 Platform API requests a minute, shared by every session. On a 429 the CLI prints a `wait` line, waits as long as Clerk asks, up to a minute, and retries up to six times. If the limit does not lift, the verb fails with `RATE_LIMITED`, which is retryable.
