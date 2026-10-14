# iOS Control Plane Adapter v1

This pilot observes the existing GitHub-hosted macOS / Swift / Xcode / iOS Simulator CI without changing its build or test behavior.

## Existing workflows remain authoritative executors

The adapter observes, but does not modify or rerun:

- `iOS Device Build`
- `iOS Simulator E2E`
- `Build18-M Final Regression`

The adapter is deliberately **observe-only**. Automatic Simulator recreation, workflow rerun, or recovery is a later safety gate.

## Durable authority

The observer writes only to the dedicated `control-plane-state` branch:

```text
control-plane/state/shogi-ai-coach.json
```

The state branch is not an application candidate branch and must not be merged into `main`.

Authority is updated only when the required CI set for an exact `main` SHA can be resolved. A still-running expected workflow causes a defer rather than a transient durable state update.

If an expected workflow run is absent after a short grace period, the adapter writes a fail-closed `BLOCKED` authority instead of silently dropping that gate or waiting forever.

## Security boundary

`workflow_run` can receive repository write permissions. Therefore automatic observation is accepted only when all of the following are true:

- source branch is exactly `main`;
- source event is exactly `push`;
- source repository is this repository;
- observer code is checked out from trusted `main`, not from the triggering branch.

No source PR code is executed with the observer's write permission.

## Failure classification

The first adapter version is intentionally conservative:

- known setup/tool/cache failures -> `INFRA_FAIL`;
- build/test/application assertions -> `CODE_FAIL`;
- artifact/evidence validation -> `VALIDATION_FAIL`;
- missing expected workflow -> `BLOCKED`;
- ambiguous cases -> `UNKNOWN`.

No failure class triggers an automatic rerun in v1.

## Two-failure rule

The adapter records `methodKey=ios-main-ci-set`. The same failure signature on a new candidate may be attempted at most twice. A second same-method failure moves the durable state to `BLOCKED` and recommends changing method rather than repeating the same workflow.

Duplicate observer events for the same candidate do not increment the attempt count.

## Common contract

The schema and semantic validator under `control-plane/` are vendored from:

```text
inari-1234/Excel-Tests@b11e775d51d7cdff179184e2d7313fce18d77444
```

This avoids a runtime dependency from this public repository on a private repository.

## Pilot gates

The initial required gates are:

1. `device-build`
2. `simulator-e2e`
3. `final-regression`

A PASS authority requires all three workflows to complete successfully for the same exact `main` SHA.

## Next safety gate

Only after the observer produces stable evidence should an iOS recovery layer be considered. Any future recovery layer must distinguish infrastructure failure from code/test failure and must not recreate a Simulator or rerun CI merely to turn a deterministic red run green.
