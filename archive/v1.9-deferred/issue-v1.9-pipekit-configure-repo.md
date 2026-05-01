## Summary

`scripts/pipekit-configure-repo.sh` (introduced v1.8.0.6) has three latent issues that together make re-running the script riskier than its "Safe to re-run" header advertises. Surfaced in v1.8 code review (2026-04-30).

## Issues

### 1. Rulesets PUT silently nukes UI-added bypass actors

`pipekit-configure-repo.sh:112-117` PUTs `RULESET_BODY` for both create and update paths. GitHub's Rulesets API on PUT replaces the entire ruleset — any fields not in the body (e.g., `bypass_actors` added manually in the UI for emergency-override situations) are removed.

Re-running the script silently destroys out-of-band bypass configuration.

**Fix options:**
- Before PUT, fetch existing ruleset and merge `bypass_actors` (and any other locally-managed fields) into `RULESET_BODY`
- Or PATCH only the `rules` array
- Or document the destructive behavior and require `--force` to overwrite

### 2. No `gh auth status` / admin-permission precheck

`pipekit-configure-repo.sh:30-36` auto-detects the repo via `gh repo view` but never checks (a) auth status, (b) that the user has admin permission. Rulesets require admin. On insufficient scope:

- Step 1 (PATCH repo settings) may partial-succeed
- Step 2 (Rulesets) errors midway
- Repo left in half-configured state

`set -euo pipefail` halts on first failure but only AFTER the merge-method PATCH already mutated state.

**Fix:** add upfront `gh auth status` check + admin probe (`gh api "repos/$REPO" --jq .permissions.admin`) before any mutation.

### 3. `EXISTING_ID` jq parse swallows real errors

`pipekit-configure-repo.sh:82`:

```bash
EXISTING_ID=$(gh api "repos/$REPO/rulesets" --jq "..." 2>/dev/null || echo "")
```

The `|| echo ""` is meant to handle "ruleset doesn't exist yet" but also swallows auth/permission failures silently. Script then takes the "create new ruleset" branch and fails there with a less-clear error.

**Fix:** drop the `|| echo ""` or distinguish empty-result from API-failure.

## Acceptance criteria

- [ ] Re-running script does not destroy UI-added bypass actors
- [ ] Script aborts with clear message if `gh` not authenticated or user lacks admin
- [ ] Real `gh api` failures surface as errors, not "ruleset doesn't exist"
- [ ] No regression on greenfield (no-existing-ruleset) path
- [ ] Updated header comment reflects actual safety guarantees

## Priority

P2 — script works for greenfield repos and well-behaved re-runs; biting cases require unusual configurations or auth states.
