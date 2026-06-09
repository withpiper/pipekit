# SHIP RUNCARD — POC-57 real ship (native finishes the UI)

**This is the real ship, not an experiment arm.** Branch `feature/POC-57-mvp-client-approve`
(off real `main`, Linear → In Progress). Worktree: `~/Projects/SiteLine/.worktrees/POC-57-mvp-client-approve`.

## Already in place — DO NOT REDO

The **DB layer is cherry-picked and QA-verified** (from the VBW-full pilot arm, 192/192):
- `supabase/migrations/...20260608120000_add_approval_fields_to_budget_snapshots.sql` — 3 approval fields + `snapshots_approval_update` RLS policy (plain RLS, **no SECURITY DEFINER**, one-time invariant `approved_at IS NULL`).
- `supabase/migrations/...20260608120100_harden_snapshot_approval_write.sql` — `SECURITY INVOKER` BEFORE-UPDATE trigger: column-immutability + approver-binding (closes the HIGH escalation/forgery finding the pilot caught).
- `tests/rls/snapshot-approval.rls.test.js` — the authz suite that *proves* the above.

**Read those two migrations first** — they define the write contract (a plain `UPDATE` of the 3 approval columns; the trigger binds the approver to `auth.uid()` and rejects any other column change / re-approval).

## Native's job — finish the consuming UI only (Phases 2 + 3)

Start a fresh session:
```bash
cd ~/Projects/SiteLine/.worktrees/POC-57-mvp-client-approve && claude --dangerously-skip-permissions
```
Then run `/work` **scoped to the delta** (tell it up front: *"the DB layer + RLS test are already present and verified — plan and execute ONLY the client UI below"*):

- `src/app/js/database/snapshots.js` — `approveSnapshot(snapshotId, note)` doing the plain RLS-guarded `UPDATE`; add the 3 approval columns to the snapshot selects.
- `src/app/project_detail.html` — gated Approve button (authenticated contact w/ access · `is_snapshot` · `approved_at == null`); on click → `approveSnapshot` → optimistic re-render to approved state (no full reload).
- `src/app/js/utils/versions.js` `formatVersionLabel()` + `src/app/js/pages/budget-edit-main.js` — "Approved (date)" stamp sourced from `approved_at` (never `description`).

## Non-negotiable discipline (the pilot's lessons, enforced manually)

1. **Author tests for the new UI/data-layer behavior** — at minimum a unit test that `formatVersionLabel` renders the stamp from `approved_at` (and not when null), and the `approveSnapshot` call shape. Don't lean only on the existing suite. (This is the exact gap that cost native the blind panel.)
2. **`/verify`** — full gate including `npm run test:rls` (DB/RLS touched).
3. **`/pr-security-review`** — MANDATORY. This feature has a proven escalation footgun; an adversarial pass is required before ship, not optional.
4. **`pk ship`** — open the PR (Draft), Linear → UAT.

## Notes

- The cherry-picked migrations are dated `20260608` (one day ahead of today). Functionally fine — strictly later than main's tail `20260607170000`, never applied to a shared env. Optional tidy: rename to today's date before merge; re-confirm tail vs `origin/main` right before merge regardless (parallel-branch rule).
- Don't `supabase db push` to shared envs; migrations deploy via the normal CI path on merge.
