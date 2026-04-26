# Contract Freeze Wave 1

## Purpose

Freeze the highest-risk integration contracts during the current stabilization window so implementation work can proceed without interface churn.

## Freeze Baseline

- Repository: `zeroclaw`
- Baseline commit: `371313ee`
- Freeze date: `2026-03-26`
- Scope: Wave 1 stabilization

## Frozen Contract Surfaces

The following files are Wave 1 contract surfaces and require explicit review before signature/shape changes:

- `src/runtime/traits.rs`
- `src/providers/traits.rs`
- `src/channels/traits.rs`
- `src/tools/traits.rs`
- `src/config/schema.rs`
- `src/gateway/api.rs`

## Change Policy During Freeze

A change to any frozen surface requires all of the following:

1. Linked issue explaining why the freeze break is required.
2. Compatibility note in PR summary (what clients/adapters are impacted).
3. Explicit rollback plan for reverting contract change.
4. Evidence showing downstream adapters still build or fail with actionable messages.

## Validation Gate for Contract Changes

Minimum command set for PRs touching frozen surfaces:

```bash
cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
cargo test --no-fail-fast
```

If any command is skipped, the PR must include a justification and follow-up issue.

## Verified vs Assumed Snapshot

Verified:
- All six frozen file paths exist at freeze baseline.
- Baseline commit recorded.

Assumed:
- Existing CI coverage is sufficient to catch all contract consumers.

Unknown:
- Full downstream impact to external/private adapters not present in this workspace.

## Exit Criteria for Wave 1 Freeze

Freeze can be lifted only after:

1. Wave 1 implementation tasks complete.
2. No open P0 regressions against frozen surfaces.
3. Compatibility notes are merged for all freeze-break PRs.
