# Test instances

Each worktree has one Clerk application of its own. `up` creates it through Clerk's Platform API, specs run on its development instance, and `down` deletes it. Nothing is shared with another worktree or another repository, so a spec never meets users or settings that it did not make.

The application serves one run at a time, because a run changes its settings. While one `run` drives, a second `run` in the same worktree waits for the device for as long as its `--wait` allows, and then fails with `DEVICE_BUSY`.

## The standard settings

`src/core/instances/base.json` defines the settings every new application gets. It has two parts.

- `config` is the whole body of the Platform API request that puts an instance on the standard settings. Everything that can coexist is switched on: email code, email link, phone code, password, username, authenticator app, backup codes, and organizations.
- `environment` lists the settings of the instance's public `/v1/environment` that a spec cannot run without.

After the CLI configures a new application, it reads that public environment. A difference in one of those settings fails with `INSTANCE_MISCONFIGURED` and names the setting. Run `down`, then `up` once more. If it fails again, Clerk changed what a setting does. Say so in your report.

The CLI checks those settings and the settings a settings file declares, and no others. A spec that depends on another setting of the public environment lists it in its settings file.

## Declare other settings

A spec file that runs on the standard settings declares nothing. A spec file that needs other settings has a settings file beside it, with the same name and `.settings.json` in place of `.e2e.ts`. For `specs/golden/session-tasks/choose-organization.e2e.ts`, that file is `specs/golden/session-tasks/choose-organization.settings.json`:

```json
{
  "config": { "organization_settings": { "force_organization_selection": true } },
  "environment": { "organization_settings.force_organization_selection": true }
}
```

`config` is a fragment of Clerk's Platform API instance config. `environment` lists the settings of the public `/v1/environment` that the change moves, each by its full dotted path and with its new value. The declaration applies to every test in the spec file, so tests that need different settings go in different spec files.

The CLI reads the settings file and never runs a spec to learn its settings. It refuses a declaration that breaks one of these rules, with a fix line that says what to write.

- The settings file is one JSON object that holds `config` and `environment` and nothing else. JSON takes no comment and no trailing comma.
- Every JSON file under `specs/` is the settings file of a spec beside it. `run` and `doctor` refuse any other JSON file there, so a misnamed settings file is never left out in silence.
- Every `config` setting has a standard value under `config` in `base.json`, and at least one declared value differs from its standard value.
- An `environment` setting that `base.json` lists differs from its standard value.
- Every setting of `environment` in `base.json` that the change moves is listed. When one is missing, the failure lists the missing settings with their values, ready to paste into `environment`.
- Two settings files that declare the same `config` expect the same value of every setting that both list.

To find the name of a setting, read `environment` in `base.json`. A setting that is not there has the dotted path of its value in the JSON that the instance's public `/v1/environment` returns. The Platform API cannot set reverification, the development-mode banner, test mode, or PII protection off.

## When a declaration fails

`run` groups the spec files it selected by declaration and runs one group after another on the same application.

A declaration that breaks a rule the CLI can check from the files stops `run` before it builds or leases anything.

A declaration that Clerk refuses, or whose `environment` does not match what the instance shows within 15 seconds of the change, fails its own group. Every spec file in that group gets a failed result in `run.json`, and the run goes on to the next group. The error names the spec file, quotes what Clerk said or what the instance shows, and its fix line names the settings file to change.

Any other failure to apply settings stops the run, and the groups that did not run get failed results too.

## The credential

One team key creates, changes, and deletes the application, and reads its secret key. The key needs four scopes: `applications:read`, `applications:manage`, `applications:delete`, and `application_secret_keys:read`. The CLI reads `CLERK_PLATFORM_API_KEY` first, then the file that `CLERK_PLATFORM_API_KEY_FILE` names. A variable that is set and does not work is an error. With neither variable set, the CLI reads the key's 1Password secret reference from `VERIFY_PLATFORM_KEY_REFERENCE` and asks the 1Password CLI for the key. The 1Password app then asks a person to approve, and a refused or unanswered request is an error.

Before it asks 1Password, the CLI sends one request with no key. In a cloud environment that holds the key as an API credential for `api.clerk.com`, the environment adds the key after the request leaves the machine, so that request succeeds and no key is ever in the session. [Remote devices](remote.md) has the setup.

`doctor`, `up`, and `run` use the credential every time, and `down` uses it when the worktree holds an application. `screen` and `attach` never use it. With 1Password each of those commands asks once.

With no credential, `doctor` fails `instances` and prints how to supply one. `up` and `run` fail with `KEYS_MISSING` before they lease a device. `down` releases the device first and then fails the same way, and `down` with the credential deletes the application later.

The key reaches only the team's verification workspace, which holds nothing but these applications. The CLI refuses a key of any other workspace. It also refuses to create or delete anything while that workspace holds an application whose name does not start with `verify-throwaway-`.

## Lifetime and limits

An application's name carries a deadline: `verify-throwaway-until-<utc>-<hex>`. The deadline is six hours after the application was created, and `VERIFY_THROWAWAY_HOURS` sets it to a whole number from 2 to 72. `down` deletes this worktree's application at once.

If a session ends without `down`, a later command on any machine deletes the application after its deadline and prints a `reap` line. Nothing is deleted before its own deadline, so no session can remove another session's live application.

`up` and `run` replace this worktree's application before they use it in two cases. The first is an application within an hour of its deadline. The second is an application that holds 60 or more users, because a Clerk development instance allows 100. Users seeded in the replaced application are gone.

Clerk allows the workspace 100 Platform API requests a minute, shared by every session. On a 429 the CLI prints a `wait` line, waits as long as Clerk asks, up to a minute, and retries up to six times. If the limit does not lift, the verb fails with `RATE_LIMITED`, which is retryable.
