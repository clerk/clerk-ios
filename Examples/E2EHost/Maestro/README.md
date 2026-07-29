# E2EHost Maestro tests

Maestro provides the release-gating E2E coverage for four E2EHost journeys:

- `auth-email`
- `auth-phone`
- `user-profile`
- `session-task-setup-mfa`

## Run locally

Install [`maestro-runner`](https://open.devicelab.dev/maestro-runner), configure `.keys.json`, and select a flow:

```sh
E2E_MAESTRO_FLOW_NAME=auth-email make test-e2e
E2E_MAESTRO_FLOW_NAME=auth-phone make test-e2e
E2E_MAESTRO_FLOW_NAME=user-profile make test-e2e
E2E_MAESTRO_FLOW_NAME=session-task-setup-mfa make test-e2e
```

Reports are written under `build/reports/maestro-<flow>`, with screenshots and other artifacts retained when a flow fails.

## Release CI

The Release SDK workflow runs the four flows as parallel, required jobs on Blacksmith macOS runners. CI installs the pinned `maestro-runner` version and caches the runner together with its compiled WebDriverAgent.
