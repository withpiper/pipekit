# Source — Pipekit: Linear state lags merged PRs (recurring; root cause + fix status)

**A living reference, not a handoff.** Tracks a recurring Pipekit issue — its mechanism, the evidence, what's been fixed, and what's left. Update it as fixes land; cite it from CHANGELOG entries and skill comments that touch the transition path.

**First observed:** 2026-05-31 (WIT-434 strategy-sync run B caught a merged-but-UAT WIT)
**Last updated:** 2026-05-31 (v2.7.0-rc3 — #3 + #4 landed; see Status)
**Severity:** Medium — no data loss, but it silently under-reports shipped work to `/strategy-sync`, `/roadmap-review`, and any skill that trusts Linear state as "what shipped."
**Status:** Partially fixed in **v2.7.0-rc3** — `pk done` now fails loud (#3) and the canonical `/strategy-sync` carries the merged-PR cross-check (#4). The root cause (transitions are command-driven, not merge-driven) is still open: #1, #2-for-`pk done`, #5 remain.

---

## TL;DR

Linear issue state routinely lags the git/PR reality: a WIT's PR merges to the integration branch (and sometimes onward), but the issue stays in **UAT** / **In `<Env>`**. Any skill that asks Linear "what is `Done`?" to decide "what shipped?" therefore **under-returns**, and doc-sync silently skips real work. This bit three consecutive syncs. The durable fix belongs upstream: drive the Linear transition off the **PR-merge event**, not off a human remembering to run `pk done` / `pk promote --finish`.

---

## The mechanism

Per `method.config.md` § V2 keys, the intended transitions are (env names below are Piper's — `dev`/`beta`/`main` — yours come from `ship_environments`):

| Command | Transition | Trigger |
|---|---|---|
| `pk ship` | → **UAT** | PR opened as Draft on preview |
| `pk done` (after merge to integration) | → **In `<FirstEnv>`** | run manually post-merge |
| `pk promote <env> --finish` | → **In `<Env>`** | run manually after promote PR merges |
| `pk promote <final> --finish` | → **Done** | run manually after promote PR merges |

Every transition after `pk ship` is **command-driven and manual**. If a PR is merged via the GitHub UI (the common path), or `pk done` / `--finish` is skipped, the issue never advances — even though the code is on the integration branch. There is no merge-triggered reconciliation.

---

## Evidence — three occurrences

| Date | Sync | What Linear `Done` returned | Reality | How it was caught |
|---|---|---|---|---|
| 2026-05-26 | periodic | **missed 6 WITs** (419/512/513/521/522/514) — query returned zero of them | all merged to `dev` 05-26→05-27 | **user-flagged**; required a retroactive 2026-05-27 sync |
| 2026-05-31 | run A | under-returned (WITs showed **In Beta**/Done, not uniformly Done) | 462/416/534/520/516 merged to `dev`, promoted to `beta` | merged-PR cross-check (newly mandatory) |
| 2026-05-31 | run B | WIT-434 showed **UAT** | PR #414 (`feature/WIT-434-finance-configuration-forms`) merged to `dev` 15:27 UTC | merged-PR cross-check **only** |

WIT-434 is the cleanest signal: the branch is named for exactly one WIT (no bundling excuse), the PR merged to `dev`, and the issue still sat two states back in **UAT**. `pk done`'s UAT→In Dev transition simply never fired for it.

---

## Recommended fixes (in leverage order)

1. ✅ **Merge-driven Linear transition (the real fix). — SHIPPED v2.7.1, live-validated.** `templates/ci/linear-transition.yml`: a GitHub Action on `pull_request: closed` + `merged == true` against the integration branch that extracts every `<PREFIX>-NNN` from the branch name + PR title + body and transitions each to the configured `TARGET_STATE` (`In <FirstEnv>` multi-tier, `Done` single-tier) via the Linear GraphQL API — same auth + `workflowStates`/`issueUpdate` shapes as `bin/pk`. Idempotent (skips a WIT already at target — harmless alongside `pk done`) and forward-only (a `PRE_MERGE_STATES` allowlist prevents pulling a promoted/Done WIT backward and prevents leap-frogging an Approved WIT that bypassed UAT). **Live-validated on SiteLine 2026-06-05:** a real POC WIT in UAT, merged via a real PR, transitioned `UAT → Done` by the workflow in CI; idempotent skip confirmed on a second pass. **Key finding from that test — Linear's native GitHub integration overlaps this.** SiteLine's workspace had native on; it moved the WIT `UAT → In Progress` (backward!) on PR-open then → Done on merge, *before* our workflow ran (our workflow then correctly skipped). Native can't respect the Pipekit ladder (it jumps multi-tier dev-merges straight to Done and pulls UAT backward), so the recommended posture is: single-tier may leave native on (our workflow is then a harmless net); **multi-tier should turn native off and use this workflow per hop** — which is exactly the original lag scenario (Piper is multi-tier). Documented in `templates/ci/README.md` § "Relationship with Linear's native GitHub integration." **Follow-ups (not blockers):** (a) commit messages not yet parsed for IDs — only branch + title + body (would catch squash-merged bundles whose extra IDs live only in commit subjects); (b) one workflow watches one hop — downstream promote hops need a sibling file or stay on `pk promote --finish`.
2. 🟡 **`pk done` / `pk promote --finish` must transition every bundled `<PREFIX>-NNN`**, not just the branch-named one. — **`pk promote --finish` already does this** (it loops the full `issue_ids` set, `bin/pk:1676`). `pk done` is still single-issue (`bin/pk:1314`) — parse commit messages + PR body for the issue prefix and transition the set.
3. ✅ **Fail loud, not silent.** — **Done in v2.7.0-rc3.** `pk done`'s transition no longer swallows failures with `|| true`; it warns loudly that the issue is stranded but continues cleanup (the merge already succeeded). `pk promote --finish` already failed loud with a non-zero return (`bin/pk:1678-1690`).
4. ✅ **Fold the cross-check into the canonical skill.** — **Done in v2.7.0-rc3.** `/strategy-sync` Phase 1 §4b now diffs merged PRs on the integration branch against the Linear `Done` set and treats any merged-but-not-Done issue as shipped — portably (reads integration branch + issue prefix from config). Every consuming project inherits it on next sync, not just Piper.
5. ⬜ **Optional: `pk doctor` drift check.** A read-only command that reports issues whose latest merged PR is ahead of their Linear state. Lets a human reconcile on demand instead of discovering drift at sync time.

---

## Pointers

- `bin/pk:1454-1461` — `pk done`'s UAT→In `<Env>` transition (the rc3 fail-loud fix).
- `bin/pk:1676-1691` — `pk promote --finish`'s bundled + fail-loud transition (already correct; the model for #2's `pk done` fix).
- `skills/10-strategy-sync/skill.md` Phase 1 §4 + §4b — the Done query and the rc3 merged-PR cross-check that masks the bug.
- `method.config.md` § V2 keys / `## Ship environments` — the intended transition map.
- Piper-side origin receipts: `Strategy/Doc4_Changelog.md` (the three sync entries), `engineering/Handoff-Pipekit-Recovery.md` ~line 60 (prior "branch-named WIT only" finding, #2's origin).
