# E2EHost Maestro burn-in

The Maestro suite mirrors the four required E2EHost XCUITest smoke-test shards:

- `auth-email`
- `auth-phone`
- `user-profile`
- `session-task-setup-mfa`

The existing XCUITest jobs remain the required gate. Maestro runs as a non-blocking burn-in during integration CI.

## Run locally

Install `maestro-runner`, configure `.keys.json`, and select a flow:

```sh
E2E_MAESTRO_FLOW_NAME=auth-email make test-e2e-maestro
E2E_MAESTRO_FLOW_NAME=auth-phone make test-e2e-maestro
E2E_MAESTRO_FLOW_NAME=user-profile make test-e2e-maestro
E2E_MAESTRO_FLOW_NAME=session-task-setup-mfa make test-e2e-maestro
```

Reports and `metrics.json` are written under `build/reports/maestro-<flow>`.

## Collect CI samples

The manually dispatchable `Maestro E2EHost Burn-in` workflow runs all four Maestro flows and, by default, the matching four XCUITest baselines:

```sh
gh workflow run maestro-burn-in.yml \
  --ref main \
  -f include_xcuitest_baseline=true
```

After 10–20 completed workflow runs, summarize the retained metrics:

```sh
MAESTRO_BURN_IN_RUNS=20 make summarize-maestro-burn-in
```

Set `MAESTRO_BURN_IN_BRANCH` to restrict the summary to one branch.

## Gate-replacement criteria

Do not replace the required XCUITest gate until:

- every Maestro flow has at least 10 CI samples;
- Maestro reliability is no worse than the matching XCUITest shard;
- failures do not show a recurring runner, WDA, cleanup, or credential-isolation problem;
- median and P95 total durations justify the additional third-party runner dependency; and
- failure reports contain enough information to diagnose the corresponding product state.

Promoting Maestro to a required gate should be a separate change after reviewing the burn-in summary.
