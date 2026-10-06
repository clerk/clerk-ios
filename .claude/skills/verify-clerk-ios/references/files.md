# Files the CLI keeps

## In the skill directory

Everything is under `.verify/`, which git ignores.

| Path | What it holds |
| --- | --- |
| `.verify/runs/<run-id>/` | The evidence of one run. `down` never deletes it |
| `.verify/builds/<build key>/` | The E2EHost build for one build key |
| `.verify/leases/ios.json` | The lease this worktree holds: the lane name, the simulator UDID as `deviceId`, and the installed build |
| `.verify/instances/` | The keys of this worktree's Clerk application and the settings recorded for it. Never print these files |
| `.verify/agent-device/` | The state of this worktree's agent-device daemon. `daemon.json` holds the daemon's auth token |
| `.verify/scratch/`, `.verify/locks/`, `.verify/context.json` | The working files of a run in progress, the locks between commands in this worktree, and the context that e2e reads |

## In the home directory

| Path | What it holds |
| --- | --- |
| `~/.verify/ledgers/<id>.jsonl` | This worktree's ledger. `<id>` is a hash of the worktree path, and `<id>.owner` beside it holds that path on its first line and the path of the skill directory on its second |
| `~/.verify/claims/` | One claim per lane, for the whole machine |
| `~/.verify/clerk-platform-key-reference` | Optional. Its one line is the 1Password secret reference of the Platform API key |

The ledger has a line for each thing the worktree created that needs cleanup: a lease, an application, a test identity, or a process. Each line is a JSON object with an `id` and a `kind`, which is `lease-intent`, `lease-held`, `application`, `identity`, `user`, or `process`. An `application` line has the application's `name`. A later line of kind `done` names an `id` in `ref` and marks that entry done. `down` works from the open entries, so it can finish after a crash. To find the ledger of the current worktree, run `grep -lxF "$(git rev-parse --show-toplevel)" ~/.verify/ledgers/*.owner`.

A lane changes hands only by compare-and-swap on its claim, so two worktrees never hold the same lane.

When a worktree is removed without `down`, its `.owner` file names a path that no longer exists. The next `up` or `run` in any worktree on the machine finishes that ledger, marks every open entry done, and leaves the ledger files on disk.
