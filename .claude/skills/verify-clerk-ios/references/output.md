# CLI output

## Text output

A verb prints progress lines to stderr while it works and its result to stdout when it ends. An error goes to stderr as two lines: `error`, the error code, and the message, then `fix:` and what to do.

## JSON output

Every verb takes `--json`. The verb then prints no progress lines, and prints one JSON object to stdout.

On success the object is `{ "ok": true, "verb": "<verb>", ... }`. The remaining keys depend on the verb. `src/core/types.ts` defines them as `DoctorReport`, `UpResult`, `RunResult`, `ScreenResult`, `AttachResult`, and `DownResult`.

On failure the object is `{ "ok": false, "error": { "code", "message", "fix", "retryable" } }`.

Each check of `doctor --json` has `id`, `ok`, `detail`, and a `fix` when there is one. A warning has `ok: true` and `state: "warning"`. A check that did not run has `ok: true` and `state: "not-run"`.

`attach --json` prints one of two shapes. With `via: "gh"`, this machine edited the description, and the keys are `prUrl`, `posted`, and `alreadyPosted`. With `via: "runner"`, the evidence was handed to the session's runner, and the keys are `pr`, `handedOff`, `because`, `sessionRun`, and `sessionRunUrl`.

`down --json` and `down --dry-run --json` print different keys. A dry run prints `dryRun: true`, `wouldRelease`, `wouldDelete`, `wouldStop`, and `keptRuns`. A real `down` prints `dryRun: false`, `released`, `deletedApplications`, `stoppedProcesses`, and `keptRuns`. Each entry of `wouldDelete` is `{ "kind": "application", "name" }`, and each entry of `deletedApplications` is `{ "name" }`. Neither lists users or organizations.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | The verb succeeded. For `run`, no spec failed. A spec that passed on a retry is `flaky` and does not fail the run |
| 1 | `run` finished and at least one spec failed or was interrupted |
| 2 | The error code is `USAGE` |
| 3 | Any other error, or `doctor` has a failing check |

## Error codes

`retryable` is true for `POOL_FULL`, `DEVICE_BUSY`, `LEASE_LOST`, and `RATE_LIMITED`. For those, the same command can succeed later with no other change.

| Code | Meaning |
| --- | --- |
| `USAGE` | The command line, a spec's declaration, or an environment variable is malformed |
| `NOT_READY` | A precondition is missing. The fix names it |
| `POOL_FULL` | All four `verify-ios-<n>` simulators on this Mac are in use |
| `DEVICE_BUSY` | Another command in this worktree is driving the device |
| `LEASE_LOST` | The leased device is gone |
| `BUILD_FAILED` | The E2EHost build failed. The message has the last lines of the build output. With the remote backend, also that the app sources have uncommitted changes or that GitHub does not have HEAD |
| `KEYS_MISSING` | No Platform API credential works on this machine, or `AI_GATEWAY_API_KEY_FILE` names a file that is missing, empty, or readable by other users |
| `INSTANCE_MISCONFIGURED` | The Clerk instance does not show the settings a spec needs |
| `NOT_TEST_IDENTITY` | A spec used an email, phone number, or user that the run did not create |
| `NO_SPECS` | The selection matched no spec, or no selected spec ran |
| `E2E_CRASHED` | e2e exited without a readable report. Read `e2e.log` in the run directory |
| `EVIDENCE_UNSAFE` | The run cannot be attached, or a path is not safe to delete |
| `UNSUPPORTED` | This machine cannot do what the command asked |
| `RATE_LIMITED` | Clerk's Platform API kept answering 429 |
