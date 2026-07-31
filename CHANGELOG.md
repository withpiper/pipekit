# Changelog

All notable Pipekit releases. Versioning follows semver-ish — minor bumps for new capability, patch for fixes/docs only.

Pin to a specific version: `./scripts/sync-method.sh v1.8.2`.

---

## Release Checklist

Every `chore(release): vX.Y.Z` PR must complete the following before merging to `main`:

- [ ] Bump `PK_VERSION` in `bin/pk`.
- [ ] Add a new `## vX.Y.Z — YYYY-MM-DD` section to `CHANGELOG.md` (this file).
- [ ] **Stamp every doc you actually edited in this release.** Don't bump stamps on untouched docs — the version gap between an older stamp and the current release is the drift signal we keep them for. The stamped doc set lives in the table below. If you add a new top-level doc or SOP, stamp it and add it to that table.
- [ ] Bump `method.md` / `RUNBOOK.md` / `GUIDE.md` stamps to `vX.Y.Z` with today's date **unconditionally** — these three are the "constitutional" docs: they describe current behavior and must always carry the latest version, edited or not. If one wasn't edited, bumping its stamp is your assertion that you re-checked it against this release and it's still accurate. (The drift-signal convention applies only to the non-constitutional docs below; v3.0.0-rc3 shipping with a `GUIDE.md` that still claimed `/work` spawns `vbw-lead` is what this rule prevents.)
- [ ] Update `RUNBOOK.md` line 14 (`./scripts/sync-method.sh vX.Y.Z` example) to the new tag.
- [ ] PR title contains `vX.Y.Z` so the `auto-tag-release` workflow can tag the merge commit (see `.github/workflows/auto-tag-release.yml`).
- [ ] Skip-check: leave historical `vX.Y.Z` references in prose alone (e.g., "as of v2.3.0" describes when a behavior shipped — that's intentional, not drift).

### Stamped docs (maintained list)

Every doc below carries a `**vX.Y.Z** — Last updated: YYYY-MM-DD  *(blurb)*` line right after its H1. The stamp's `vX.Y.Z` is the release **the doc is calibrated to**, not the release we last touched typography in. When a release modifies a doc, bump its stamp to the new version + today's date. Otherwise, leave it alone so the gap surfaces drift.

| Doc | Role |
|-----|------|
| `method.md` | Constitutional — deep methodology |
| `RUNBOOK.md` | Constitutional — one-page daily flow |
| `GUIDE.md` | Constitutional — full instruction manual |
| `README.md` | Public-facing repo intro |
| `CLAUDE.md` | Guidance for Claude Code sessions in this repo |
| `STARTUP.md` | Project bootstrap reference |
| `method.config.template.md` | Project-config template |
| `sop/Code_Quality.md` | SOP — coding conventions |
| `sop/Database_SOP.md` | SOP — schema-change artifact rule, Migration Plan contract |
| `sop/Production_Readiness_SOP.md` | SOP — production-readiness gate (`/prod-ready`), the six operational checks |
| `sop/Security_Gate_SOP.md` | SOP — feature-scoped security gate (`/security-gate`), the six sensitive categories |
| `sop/Git_and_Deployment.md` | SOP — branches, merges, release flow |
| `sop/Hooks_SOP.md` | SOP — Claude Code hooks |
| `sop/Linear_SOP.md` | SOP — Linear model, states, labels |
| `sop/Session_Management_SOP.md` | SOP — Claude Code session hygiene |
| `sop/Skills_SOP.md` | SOP — skill anatomy, sync, overrides |
| `sop/Completion_Claims_SOP.md` | SOP — the completion-claims loop (CLAIM → DOUBT → RECONCILE → STOP) |
| `sop/Cmux_Orchestration_SOP.md` | SOP — orchestrating other Claude sessions in cmux worker panes |

Format (copy verbatim): `**vX.Y.Z** — Last updated: YYYY-MM-DD  *(one-line release blurb)*`. The three constitutional docs additionally carry an `HH:MM` suffix on the date to disambiguate same-day patch releases (e.g., `2026-05-13 21:04`).

Why this list exists: v2.4.0 through v2.4.3.1 all shipped with stale `v2.3.0` header stamps because release PRs edited prose at specific line numbers without touching the "Last updated" line. The header tells humans and AI sessions which version the doc describes — when it lies, every reader after that ships against the wrong contract.

---

## v4.26.0 — 2026-07-31

> **The split gate: a data-layer change and a rewrite of the client that consumes it are two issues, not one.** Upstreamed from SiteLine PIPER-486/487, where two CRITICAL security fixes, a 1,816-line migration across 23 schema objects, and a rewrite of an admin tab inside an 8,000-line vanilla-JS page shipped on one branch and took **eight `/verify` rounds over two days**, at roughly three opus reviewers per round. The distribution is the argument: rounds 1–5 each found a High *inside the previous round's fix commit*; round 6 — the only clean round, zero Critical / zero High under three independent reviewers — was the one that reviewed a **reduction**; round 7's additions produced 22 findings. The migration reviewed clean from round 6 onward and stayed clean, and essentially every defect across all eight rounds lived in the client half. The branch was cut at round 7 and shipped at round 8. Split at spec time, plausibly a three-round issue. **The mechanism is a property of the work, not the team:** data-layer review *converges* — policies, grants and predicates are a finite, statically reviewable surface, falsifiable by mutation, so a clean pass carries real information and stays true. Client-behaviour review does *not* — stale in-memory snapshots, transaction boundaries between separate writes, zero-row writes the API reports as success, ordering, scope-resolved-at-load-versus-at-use surface one at a time, and each fix moves code the previous round already cleared. Bundled, every round must hold both, so the converged half is dragged back through review each time the other moves. Three changes. (1) **`/01-light-spec` Phase 3.75** runs only when Phase 3.7 already detected a schema change — reusing that predicate rather than re-deriving it — and asks whether the spec also rewrites the consuming client. If so it drafts two issues with an explicit dependency and presents both in Phase 4. **The split is not 50/50, and getting the line wrong is the failure mode of adopting this carelessly:** client changes the migration *forces* (an RPC call a narrowed policy makes mandatory, a call site for a dropped function) travel **with** the migration, because reverting them ships a broken UI — on PIPER-486 a naive "revert the client" would have left `main` calling a function the migration drops. Only the hardening and UX work layered on top moves to the second issue. (2) **Spec Review Agent v5.5** gains a Bundling Rule so the heuristic is gated, not merely advisory: schema change + consuming-client rewrite at `High`/`Very High`/`Critical` Complexity is **Blocking** with a named split; below heavy tier it is **Non-blocking** with a proposal. Two explicit anti-false-positive clauses — an ordinary feature adding a column and the form field to populate it is not a finding, and a split that leaves the migration shipping against a client that cannot work with it must never be proposed. Tier-scoping is deliberate: nearly every feature spec touches schema and client, so an unconditional block would make the agent noise and get routed around. (3) **`/verify` gains cross-round scope-drift signals.** Its "Doubt theater check" had explicitly deferred multi-cycle escalation to "a future multi-cycle iteration-loop skill" — so `pipekit-discipline.md`'s "escalate after three" governed cycles *within* one run and nothing at all governed the same issue re-verified round after round. That is the axis PIPER-486 ran away on, and it reached five before anyone named it. Three signals now sit at that hole: **a fix commit containing a new High** (once is noise, twice means the unit is too large to review as one — the specific trigger, not "another round happened"), **object-count drift** (spec named 3 schema objects, work touched 23 — compare mid-flight), and **reductions reviewing clean while additions do not** (cut, don't patch). Two or more firing means cut the branch, not run another round. Honest about its own instrumentation: `VERIFY_DIR` is one directory per issue *per day* and re-runs overwrite, so `ls -d Logs/Verify/*/$ISSUE` counts **days in verification, not rounds** — no round counter is claimed. Also upstreamed, and beyond the original handoff's scope: `pipekit-tooling.md` § "The Verification Method Must Be Able to See the Failure" — line-based `grep` cannot match a claim that wraps a line, which let two facts survive multiple "fixed everywhere" commits on PIPER-486, and a regression measured against your own half-finished worktree rather than the integration branch reads as a no-op and never gets flagged. Without it, deleting SiteLine's local stopgap rule (`.claude/rules/discipline.md`, which the handoff instructs be removed once this lands) would have silently dropped that lesson. No `bin/pk` behavior change — smoke 145.

## v4.25.0 — 2026-07-29

> **Two false-claim fixes in `bin/pk` — both cases of the tool asserting something it never checked.** (1) **`pk ready` / `pk ship` named reviewers that don't exist.** Both printed a hardcoded `Outside reviewers (Semgrep, claude-review) will now fire` with no probe of the repo. But `templates/ci/semgrep.yml` and `claude-review.yml` are **opt-in copy-ins** — `sync-method.sh` lands them under `templates/`, never in `.github/workflows/` — so a consumer that installed one, or neither, was told a review ran that structurally cannot. Surfaced on SiteLine 2026-07-29: no Semgrep workflow, no `.semgrep/` dir, and no commit on any branch that ever added either; `pk ready` named it anyway. New `pk_ready_for_review_workflows` lists `.github/workflows/`, keeps the files whose uncommented lines carry the `ready_for_review` trigger, and names each by its `name:` field (filename stem as fallback). With none installed, `pk ready` now says so explicitly and points at the templates instead of implying a review happened. This is `pipekit-tooling.md` § "Enumerate the Surface Before Claiming Behavior" applied to `pk` itself — the rule already said list the workflow dir before claiming what fires; `pk` was the thing not doing it. Docs carrying the same unqualified pair (`README.md` step 8a, `RUNBOOK.md` ship box, `GUIDE.md` § pk ready) now say "whichever reviewer workflows the repo installed." (2) **`pk spec-cycle` destroyed spec review history, by instruction.** Its trigger prompt closed with *"update the issue description by replacing the existing `## Agent Review` section with the new review"* — so pass 2 wiped pass 1's rationale and pass 3 wiped both, on every project running the skill. Two things were being lost: the earlier passes' blocking-issue reasoning, which `/02-light-spec-revise` reads to tell a resolved blocker from a re-raised one, and any human commentary in that section — including the stalemate-override note `/02` § Phase 6 option 3 writes there, the one record `/02`'s own hard constraints say must never be deleted (`skills/02-light-spec-revise/SKILL.md:216`). `pk_spec_cycle_trigger_body` now takes the pass number and instructs an **append**: a new `### Review N — <date> — <verdict>` block at the end of the section, with an explicit prohibition on editing, condensing, or deleting prior blocks or human notes. The Linear-side agent skill template (`templates/spec_review_skill.md`) never carried a description-write instruction, so the trigger prompt was the sole source — this is the complete fix. Already-flattened descriptions are not recoverable from `pk`; the per-pass verdict **comments** on the issue were never touched, so the individual verdicts survive even where the consolidated section doesn't. Smoke 133 → **145** (7 reviewer-probe cases including the SiteLine class and a commented-out trigger, 5 trigger-body cases asserting the string never regresses to a replace). The probe's first cut also had a latent `set -euo pipefail` abort on any workflow lacking a top-level `name:` — caught by the new tests, fixed before ship.

## v4.24.0 — 2026-07-28

> **Context rightsizing, phase 2 (rules-trim batch): 8.9kB moved off the always-on canonical rules.** Executes the redirect designed in `resources/item-c-premise-check.md` — the v4.23.0 probe proved the `.claude/rules/pipekit-*` block is injected into **every subagent spawn** and re-billed on every one of its turns, so each rule kB is the most-multiplied content in the system. Three moves, all move-don't-delete (a consumer main session on any model can still demand-load everything): (1) **`pipekit-cmux.md` −4.0kB** — § Orchestrating other Claude sessions (menu numeric-mapping trap, repaint waits, stale-ref fallback, turn-END detection, plus its four anti-pattern rows) → new **`sop/Cmux_Orchestration_SOP.md`**; the rule keeps a trigger pointer. Orchestration is a session *mode*, not an every-turn constraint — and non-cmux projects already have `Skip rules`. (2) **`pipekit-migrations.md` −4.2kB** — the three silent-failure narratives and the WIT-514 MCP-stamp forensic walkthrough → `sop/Database_SOP.md`; the rule keeps the three invariants + audit greps (table→bullets so grep pipes survive markdown) and 2-line incident anchors. Frozen-file core untouched. (3) **`pipekit-tooling.md` −0.7kB** — the cmux-rpc worst-class case study was told in full in *two* always-on files; deduped to anchor + pointer (full anatomy stays in `pipekit-cmux.md`), WIT-461 enumerate-surface case study compressed to anchor form; the list-command table (the enforceable core) stays. `pipekit-discipline.md` and `pipekit-security.md` untouched — the audited trim candidates there didn't clear the overhead bar. This closes the rightsizing program's planned phases; remaining always-on weight is either enforceable constraint or incident anchor, exactly the doctrine's "keep" categories. No `bin/pk` behavior change (version bump only); smoke 133.

## v4.23.0 — 2026-07-28

> **Context rightsizing, phase 2 (design batch): specs-as-code-references ship; tier-aware rule delivery refuted by probe.** Two outcomes. (1) **Specs reference code — pastes are contracts-only.** Pasted code blocks assert a stale reality the moment the file changes, and Linear bills them twice (`createIssue`/`updateIssue` echo the body; every later `getIssueById` re-drags it). `/light-spec` Phase 3 gains a code-reference discipline: cite `path` + symbol/heading, line numbers only as a secondary qualifier — line numbers rot fastest, and `/spec-preflight` can *verify* a reference but only *trust* a paste. Pasting stays right where the paste IS the contract: an exact expected diff, a small type signature the implementation must match, content that doesn't exist yet. Judgment-form, not a ban. Spec Review Agent bumps to v5.4: ambiguous references ("the helper in utils") are Blocking, demanding pasted code as a fix is prohibited, and referencing-instead-of-pasting is never a finding; `/02-light-spec-revise` never resolves a blocker by pasting. `/spec-preflight` Step 3b resolves symbol/heading citations empirically — declaration-shaped grep in the cited file, repo-wide `moved_to` fallback mirroring 3a's `renamed_to`, symbol-over-line precedence (`⚠ drifted`, not `✗`, when the symbol resolves at a different line). (2) **Item C (tier-aware rule delivery) is dropped; its economics survive.** Three no-tool probe agents — general-purpose on the session model, `scout`, and a haiku-pinned general-purpose — all inherited the complete claudeMd injection at spawn (global + project CLAUDE.md, every `.claude/rules/*` file, MEMORY.md). The spawn-prompt guard-rail-block design would duplicate content subagents already receive; meanwhile the cost thesis got *worse* — the always-on block is re-billed on every subagent turn, not just the main session's. The surviving fix (trim/demand-load ~10–11kB of canonical rules, move-don't-delete) is designed in `resources/item-c-premise-check.md` and deferred to the next batch. No `bin/pk` behavior change (version bump only); smoke 133.

## v4.22.0 — 2026-07-28

> **Context rightsizing, phase 2 (mechanical batch) + skill-file case fix.** Four changes. (1) **`skills/*/skill.md` → `SKILL.md`** across all 35 skills — Claude Code's canonical skill filename is uppercase; lowercase worked only on case-insensitive filesystems and drops skills from the model-facing listing (surfaced by SiteLine's 2026-07-28 `/doctor` pass). `sync-method.sh` gains an explicit case-migration step — `git mv` when the consumer's copy is tracked, plain `mv` otherwise, because a plain copy can't apply a case-only rename and git with `core.ignorecase` misses disk-level renames — plus basename normalization so legacy lowercase `.claude/overrides/skills/<name>/skill.md` files keep applying. (2) **CLAUDE.md Key Skills tables compressed** to current-behavior one-liners; version-history prose lives here, not in the always-loaded hub. Also corrects a stale escape claim: plain `--force` stopped waiving the security gate in v4.20.0 (`--force-secgate`). (3) **Completion Claims loop demand-loaded** — the ~58-line CLAIM/EXTRACT/DOUBT/RECONCILE/STOP machinery moves from always-on `pipekit-discipline.md` to new `sop/Completion_Claims_SOP.md`; the rule keeps a 9-line trigger + shape + pointer. (4) **10 oversized skill descriptions compressed** (701/682-char worst cases → 181–265) — description frontmatter is what every consumer session pays in the skill listing, measured at ~2.5× its routing budget in SiteLine. Batch 2 (tier-aware rule delivery, specs-as-code-references in `/light-spec`) is deferred to a follow-up release. No `bin/pk` behavior change (version bump + one comment); smoke 133.

## v4.21.2 — 2026-07-28

> **CI template hardening: `actions/checkout` pinned to a full commit SHA.** `templates/ci/migration-drift.yml` used `actions/checkout@v6` — a mutable tag reference the action owner can silently repoint (the trivy-action / kics-github-action compromise class). Piper's Semgrep policy (`github-actions-mutable-action-tag`, blocking) caught it on the v4.21.1 sync PR — the second time a consumer's security gate has reviewed this template upstream (v4.20.0's `${{ github.base_ref }}` script-injection fix was the first). Now `actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803  # v6`. Consumers who already copied the template into `.github/workflows/` must re-apply the pin locally — sync never rewrites workflow files. No `bin/pk` change (version bump only); smoke 133.

## v4.21.1 — 2026-07-28

> **`/linear-hygiene` parent-ticket matching de-hardcoded — the highest-confidence orphan-homing signal was dead in every non-POC workspace.** The Phase 3 rule matched parent references (`follow-up to/from`, `Source:`, `Related:`, `Split from`) against a hardcoded `POC-N` pattern: SiteLine-specific leakage into a portable skill, violating the no-hardcoded-values rule. In Piper (`WIT-N`) the signal never fired — bodies citing a parent fell silently through to the weaker keyword-match path. Surfaced when the v4.21.0 SiteLine sync clobbered SiteLine's in-place `(PIPER|POC)-N` fix (2026-07-26 prefix migration), promoted to a `.claude/overrides/` entry in SiteLine PR #731 — this release retires the need for that override: the rule now matches any Linear identifier (`[A-Z]+-N`), covering every workspace prefix and prefix migrations with zero config. The example-output block keeps its illustrative `POC-*` rows. No `bin/pk` behavior change (version bump only); smoke 133.

## v4.21.0 — 2026-07-28

> **Context rightsizing, phase 1.** Anthropic's Claude 5 context-engineering guidance (2026-07-24: ~80% of Claude Code's system prompt removed for Claude 5 models with no eval loss; keep always-loaded files to repo purpose + incident-anchored gotchas, move rigid rules to judgment form) audited against Pipekit's always-on prose layer. Three changes land; the deterministic enforcement layer (`bin/pk` sentinel gates, hooks, CI) is untouched — the guidance validates that split.

- **Version stamps return to their spec'd one-line form.** `CLAUDE.md`'s stamp had grown to a ~15.7k-character release-history preamble — auto-loaded into every session turn in this repo, and pure duplication of this file (whose own format spec says "one-line release blurb"). `CLAUDE.md`, `method.md`, `RUNBOOK.md`, `GUIDE.md`, and `method.config.template.md` now carry single-release stamps; history lives here only. `CLAUDE.md` shrank ~54%.
- **`pipekit-discipline.md § Comments and documentation` moves to judgment form.** The four prescriptive bullets ("Default to no comments… Never write multi-paragraph docstrings") were near-verbatim the *obsolete* example in the Claude 5 guidance — and the judgment-form replacement now ships inside Claude Code's own system prompt, making the old bullets redundant and stale at once. Now: match the surrounding code's comment density, naming, and idiom; comment only to state a constraint the code can't show; task/fix/PR context belongs in the commit message. `GUIDE.md`'s catalog line updated to match. The rest of the rules corpus keeps its incident-anchored content — exactly the guidance's "keep" category (v4.16.0's real-incident anchor rule was already this position).
- **`Skip rules` — config-gated canonical-rule opt-out in `sync-method.sh`.** Two canonical rules self-declare "informational if the project doesn't use X" (`pipekit-cmux.md`, `pipekit-migrations.md`) yet auto-load into every session turn anyway. A `Skip rules` key in `method.config.md` (both config forms, e.g. `Skip rules: pipekit-cmux, pipekit-migrations`) stops the listed rules from syncing and **removes** previously-synced copies; clearing the key restores them on next sync. Absent key = all five sync — zero behavior change. `README.md` isn't skippable; unknown names warn, so a typo can't silently keep a rule the consumer meant to drop. New `config_value()` helper mirrors `pk_config`'s two-form parsing. The template ships the row commented out **and indented** — the parser anchors on column-0 `| **Key**` rows, so a verbatim template copy is inert (caught in pre-release testing: an unindented commented row would have armed the skip, deleting two rules on every verbatim copy).
- **Rider:** pipekit's own `.claude/rules/` copies refreshed to canonical `templates/rules/` (local `pipekit-migrations.md` and `README.md` had drifted).
- **Rider (`/doctor` pass):** `CLAUDE.md` also drops its `## Repo Structure` section — fully derivable from `ls` + file headers, same rightsizing thesis.

Deferred to later phases (assessment 2026-07-28): tier-aware rule delivery (guard-rail content for smaller Model Policy tiers moves into subagent spawn prompts instead of the main session), demand-loading the Completion Claims loop, specs-as-code-references in `/light-spec`, `/doctor` audit of consumers.

No `bin/pk` behavior change (version bump only); smoke 133.

## v4.20.0 — 2026-07-20

> **`pk ship --force` no longer waives the security gate — split into `--force` (verify) and `--force-secgate` (security).** A SiteLine review of the v4.19.1 sync flagged that `cmd_ship` reused one `--force` variable to bypass **both** sentinel gates: the v2.7 `verify-complete.md` gate and the v4.17.0 `secgate-complete.md` gate. So the routine `pk ship --force` — muscle-memory for routing around a stale or midnight-rolled-over *verify* sentinel — silently also waived an armed `/security-gate` review in the same keystroke, on any project with a `Security categories` file (SiteLine included).

- **The flag is now split.** `--force` waives **only** the verify gate. A new **`--force-secgate`** is the separate, explicit waiver for the security gate (still posts the Linear audit comment). To waive both, pass both.
- **The safer default falls out.** A plain `pk ship --force` on a security-gated project with no HEAD-matching secgate sentinel now **blocks** — it no longer ships past an un-run security review. This mirrors the env layer, which was already decoupled (`PK_VERIFY_BYPASS` / `PK_SECGATE_BYPASS`), and honors `pipekit-security.md`'s "flag granularity should match blast radius."
- **Twin gate checked, unchanged.** `pk promote --force` (prod-ready) is already single-duty — the UAT-state check has its own `--confirmed` — so no change was needed there.

> **CI rider — script-injection hardening in the migration-drift workflow template.** `templates/ci/migration-drift.yml` interpolated `${{ github.base_ref }}` directly into a `run:` block (the GitHub Actions script-injection anti-pattern). It now binds `base_ref` via `env: BASE_REF` and references `"$BASE_REF"`. Consumers who copied the template into `.github/workflows/` must re-apply the edit locally — `sync-method.sh` doesn't rewrite workflow files.

`bin/pk`: `+--force-secgate` parse + the secgate block reads `force_secgate`, not `force`; block/bypass messages and `pk ship` help updated. Docs: `Security_Gate_SOP.md` and `skills/security-gate/skill.md` escape-hatch prose corrected (v4.17.0 changelog lines left as history). Smoke **131→133** — two new assertions: `--force` does NOT waive an armed secgate (the regression guard for this fix) and `--force-secgate` does.

---

## v4.19.1 — 2026-07-20

> **`sync-method.sh` Config-drift check: compare key presence, not whole rows.** The Sync Changelog's `## Config` section (written into each consumer's `pipekit/.sync-changelog.md`) diffed full `| **Key** | value |` table rows between `method.config.template.md` and the project's `method.config.md`. That garbled the section two ways, both surfaced on RS-Vault (2026-07-20):

- **Filled-in values flagged as new.** The template ships placeholder values; a real project's values differ, so every customized field showed up as a "new field in template."
- **Code-block configs dumped the whole template.** A `method.config.md` in code-block form (`Key: value` — a form `pk config` supports) matched *zero* `| **Key** |` rows, so the diff reported every template row as new — raw template lines, not a diff.

The check now extracts the template's declared keys (its bolded table-row keys) and treats each as present if the project names it in **either** form — `**Key**` (table) or `Key:` (code-block). An aligned config reports "No new config fields — method.config.md already has every template key"; only genuinely-absent template keys are listed. Erring toward "present" under-reports rather than dumps. Validated against both bug shapes + a true-positive (missing key) + no self-dump on the real 46-key template; RS-Vault's proper reconcile independently confirmed 0 real drift. No `bin/pk` change (smoke 131). Unblocks clean SiteLine/Piper syncs.

---

## v4.19.0 — 2026-07-20

> **MCP result payloads are sticky — keep them out of the main thread.** An MCP tool result is not a one-time cost: every payload it returns stays in the conversation context and is re-sent as input tokens on *every subsequent turn*, so cost scales with (payload size × remaining turns), not with the call. A routine SiteLine day (2026-07-20) — create an initiative + a handful of projects + a dozen issues, then draft and agent-review a Light Spec, ~40 Linear MCP calls all inline — was observed leaving the `linear-server` MCP holding **~17%** of the session budget, matching the documented ~18% `supabase` pattern. The work was correct; the cost was the payloads persisting. A project spoke can't fix this — the offending calls come from pipekit-synced skills and the canonical rule lives here — so the fix is framework-level and server-agnostic (Linear, Supabase, Sentry, GitKraken share the economics).

**R1 — new canonical rule section `pipekit-tooling.md § MCP Result Payloads Are Sticky`.** States the sticky/re-billed mechanism and the three acute shapes to avoid:
- **State reads that drag the whole record** — `linear_getIssueById` returns the full description **plus the entire comment thread**; called only to learn an issue's state/merge/PR status it can spend several percent of the budget and stay resident for the rest of the session. Use `pk next`/`pk status`/`pk portfolio` (compact, width-controlled text), filtered `linear_searchIssues` (no bodies), or `git`/`gh` instead.
- **Writes that echo their input** — `linear_createIssue`/`linear_updateIssue` return the full description in their result, so a spec-length body is paid for twice (sent + echoed) and the echo persists.
- **Doing either inline in the main thread** — where a payload costs the most (it rides every remaining turn); an MCP-heavy batch belongs in a subagent that returns a distilled summary.

The fix is explicitly **behavioral — keep fat payloads out of the main thread — not a hard output-size cap** (truncation silently drops needed data; declined for SiteLine).

**R2 — `pipekit-discipline.md § Parallel work patterns` gains one line:** MCP-heavy read/write batches belong in a subagent so the fat payloads stay out of the main thread. Generalizes the already-proven "Payload watch-out" pattern in `/linear-hygiene` and `/00-roadmap-review`.

**R3 — `sop/Linear_SOP.md`** gains a caveat under the MCP tool table: `getIssueById` is a full-content read, not for state-only reads.

**R2 nudges** — `/01-light-spec` (Phase 1 fetch) and `/work` (Step 2 fetch) now say "read once, carry the fields, don't re-fetch for state." `/pk-bug` was deliberately **not** nudged — it makes no direct Linear MCP calls (it wraps `/work` + `pk ship`), so a nudge there would be performative; it inherits the rule and `/work`'s nudge.

Canonical source is `templates/rules/`; consumers inherit R1/R2 on their next `sync-method.sh`. Rider: cleared pre-existing `VBW`→`/work` drift between this repo's gitignored `.claude/rules/pipekit-discipline.md` copy and its `templates/rules/` source.

**R5 — `pk issue show`, the lean structured read (shipped, not deferred).** A new `bin/pk` verb: `pk issue show <ID> [--fields a,b,c] [--comments] [--json]` reads an issue over the daily-loop GraphQL path (`LINEAR_API_KEY`), **not** MCP `getIssueById` — so the fat fields never enter the session. Default fields `id,title,state,labels`; **the two fat fields are fetched only on demand** — `description` via `--fields description`, `comments` via `--comments` *or* `--fields …,comments` (symmetric, so a field request never renders a false "(0)"). Compact aligned text by default, `--json` for skills; unknown/trailing `--fields` entries are surfaced or skipped, never a silent-empty read; no key → a clear "set `LINEAR_API_KEY`" error (reads are unguarded, so a cross-workspace read still works). `pipekit-tooling.md § MCP Result Payloads Are Sticky` and `sop/Linear_SOP.md` now name `pk issue show` the **first-class state read**, ahead of `searchIssues`/`git`/`gh`. `bin/pk` gains `cmd_issue` + two pure helpers (`pk_linear_issue_full` fetch, `pk_issue_show_render` renderer — the renderer unit-tested); **smoke 121→131** (10 new cases: render/field-selection/edge cases + query-economics asserting the fat fields stay out unless asked). Live-verified against SiteLine `POC-426` — the exact closed-bug-with-11-comments the origin handoff cited as the worst offender, now a four-line ~200-byte read.

This is the only piece touching the CI-gated `bin/pk`; it was scoped as a fast-follow and folded into this release once tested green. Spec/history in `resources/mcp-payload-hygiene-followup.md`.

---

## v4.18.0 — 2026-07-16

> **Migration safety Tiers 2+3 — gap #1 completes.** Tier 1 (the artifact rule: every schema change is a tracked migration with a Migration Plan, v4.0.0-rc5) constrained how migrations are born. This release ships the two explicitly-deferred tiers that catch what survives it — the drift classes where every *local* check passes and the failure only surfaces on merge or deploy. Both anchor to real incidents that motivated the original gap analysis ("migrations is the biggest single win").

**Tier 2 — `scripts/check-migration-drift.sh` (synced to consumers).** Three checks, each with the house opt-in pattern (no `Migration dir` configured → clean skip; unresolvable base ref → warn, never false-block):
- **A. Branch collision** — a migration added on this branch that is **not strictly later** than the base branch's migration tail. The Piper WIT-550 class (2026-06-02): a same-day migration merged to `dev` mid-session; the collision was invisible in the worktree because local validation and `/verify` only ever see one branch's tree. The fix window is pre-merge — the script says so and points at `pipekit-migrations.md § Parallel Branch Coordination`.
- **B. Duplicate / malformed versions on disk** — two branches picked the same timestamp, or a hand-named file the tool will mis-order.
- **C. Remote-history drift (`--remote`, best-effort)** — delegates to `supabase db push --dry-run`, whose refusal *is* the authoritative check for "Remote migration versions not found in local migrations directory" (the MCP wall-clock-stamp incident, 2026-05-27, ~5h deploy lockup). Requires the CLI + a linked project; skipped with a note otherwise — checks A+B still run.

**Tier 3 — `templates/ci/migration-drift.yml`.** Runs the git-only checks (A+B, credential-free) on any PR touching `Migration dir`, with the PR base as the collision baseline — the merge moment is the only point where both branches' trees are comparable, i.e. the only point the WIT-550 class is *visible*. Consumers copy it to `.github/workflows/` and adjust the `paths:` filter; setup in `templates/ci/README.md`.

**Rider — `check-no-self-references.sh` now actually syncs.** The script is invoked by `pk verify` (the `Self-reference check` config key) and `Skills_SOP` says it "lives in pipekit and gets synced" — but it was never in `sync-method.sh`'s script list, so a consumer enabling the key got a silent skip. Found while wiring the drift script into the same list; both now sync with `chmod +x`.

**Docs.** `Database_SOP § How this is enforced` grows from three enforcement points to five (spec / verify / review + drift-detection / merge-time CI); `templates/ci/README.md` documents the fourth template; the `Migration dir` template row lists its new consumers. No `bin/pk` logic change (`PK_VERSION` bump only); smoke **116 → 121** (skip path, clean path, WIT-550 collision, duplicate versions, unresolvable-base never-false-block).

---

## v4.17.0 — 2026-07-16

> **The sentinel gates go hard — `/security-gate` and `/prod-ready` stop being advisory.** Both gates shipped advisory (v4.4.0 / v4.3.0) with the hard gate as a documented fast-follow, each carrying its own § Future design. This release builds exactly that design, on the mechanics `/verify`'s `verify-complete.md` gate proved in production: **a PASS writes a sha-matched sentinel; the `pk` verb refuses without one; a FAIL writes nothing — the missing sentinel is the block.** An advisory gate everyone learns to ignore is worse than no gate; this is the enforcement thesis paying off on the two gates that bracket the feature lifecycle (entering UAT, entering production).

**The `pk ship` gate (security).** `/security-gate` — standalone or embedded in `/verify` Flag check F — writes `Logs/SecurityGate/<date>/<issue>/secgate-complete.md` on **every PASS**, including the no-category-matched instant PASS: `pk ship` can't classify a diff itself, so the sentinel is how it knows the classifier ran clean *at this HEAD*. `pk ship` refuses to push / open the PR when the project's `Security categories` file exists and no sentinel matches HEAD. The Flag-check-F integration is load-bearing — without it, the `/work → /verify → pk ship` auto-rollover would block right after its own embedded gate passed.

**The `pk promote` gate (prod-readiness).** `/prod-ready` writes `Logs/ProdReady/<date>/prodready-complete.md` stamped with the audited **source-branch head** (not issue-scoped — a promote bundles WITs). `pk promote` refuses the **final `Ship environments` hop only** when the project's `Prod-ready checks` file exists and no sentinel matches the source head — so a feature merged into the source branch *after* the audit correctly invalidates the sentinel (the batch changed; re-gate). Intermediate hops untouched. **Known limitation:** 1-tier projects (`Promote to main: false`) merge to `main` without `pk promote` — no seam to gate, prod-ready stays advisory there.

**Escapes, all audited.** `pk ship --force` (Linear audit comment) · new `pk promote --force` (bypass.log) · `PK_SECGATE_BYPASS=1` / `PK_PRODREADY_BYPASS=1` (bypass.log). **Backward compatibility:** each gate is armed by the same file that arms its skill (`resources/security-categories.md` / `resources/prod-readiness-checks.md`) — projects without the file see zero behavior change, and opting in is one file.

**Implementation.** Two new matchers (`pk_secgate_sentinel_for_head`, `pk_prodready_sentinel_for_sha`) mirroring the verify matcher, plus one **shared pure decision helper** `pk_gate_verdict` (the `pk_linear_guard_verdict` house pattern — both gates have the same table: bypass-env > skip > ok > bypass-force > block). Skills updated to write sentinels on PASS only; SOP § Enforcement roadmaps flipped to shipped; docs-wide advisory→hard sweep (CLAUDE.md, RUNBOOK flowchart [4a]/[8a], GUIDE, method.md pipeline rows). Smoke **98 → 116** (verdict units, matcher units, ship-gate E2E incl. the unarmed zero-change guarantee, promote-gate E2E on a bare remote).

**Scoped + deferred to v4.18.0:** Migration safety Tier 2 (disk-vs-remote-history drift-detection script) + Tier 3 (CI template) — a second full release's blast radius; kept out of this PR deliberately.

---

## v4.16.0 — 2026-07-16

> **High-stakes skill guardrails — the five gate skills now carry the SOP's own required sections, and the convention grows teeth.** `Skills_SOP § Body Conventions` has required `When NOT to use` + `Common Rationalizations` on ship/merge-gating skills since the convention was written — using `/verify` as its worked example. An audit (prompted by an external 9-point skill-format rubric) found the standard was itself under-applied: only `/pr-security-review` had `When NOT to use`, and **none** of the five had `Common Rationalizations` — including `/verify`, the SOP's own example. Near-equivalents turned out not to be equivalents: `What this skill does NOT do` is a *scope fence* (what the skill won't write), not the redirect anti-criteria of `When NOT to use`; `/work`'s `Anti-rationalization guard` guards against *Claude* defending broken visible state (RS-64), not against the *user* rationalizing skipping the skill.

**Compliance sweep.** `/verify`, `/work`, `/pr-fix` gain both sections; `/pr-security-review` and `/pk-bug` gain `Common Rationalizations` (`/pk-bug`'s embedded "Do NOT use for" list and `Failure modes to avoid` already satisfied the other two). Each rationalization is a two-column skip-excuse → rebuttal table, and each rebuttal cites the documented incident or rule that earned it: the false-ship pattern and "Done overstating reality" (v2.7.0-rc5 log-mining) for `/verify`; WIT-451's auto-`pk done` mid-UAT and the no-guesswork stage principle for `/work`; the RS-64 handoff miss and the INVESTIGATE quadrant for `/pr-fix`; the frozen-file invariant for `/pr-security-review`; guess-fix regressions for `/pk-bug`.

**The convention is extended to three required sections + one situational.** New third requirement: **Never-do guardrails** (house names `Drifts to Avoid` / `Failure modes to avoid`) — **every line must be a mistake that was actually made and corrected, with its anchor** (issue ID, date, or CHANGELOG version). A Never-do without a real incident behind it is a guess dressed as a rule — leave it out until the mistake happens; the sections stay short because they grow one corrected mistake at a time. Situational fourth: **output-producing skills** (specs, verdicts, gate reports, changelogs) should show one **good/weak example pair** with the difference named — one pair, not a gallery. (Adopted from the external rubric's two strongest items; the rest of that rubric was deliberately *not* adopted wholesale — uniform 9-section skills would bloat the low-stakes ones, which the SOP already warns against.)

**No `bin/pk` behavior change** — `PK_VERSION` bump only; smoke unchanged. Five skills + `Skills_SOP` + release stamps.

---

## v4.15.1 — 2026-07-15

> **Docs backfill — the instructional docs catch up to v4.14.0/v4.15.0.** The two prior releases bumped the constitutional-doc *stamps* but left some of the bodies stale (the exact drift the stamp discipline exists to catch — surfaced by an audit). This patch reconciles them. No `bin/pk`, skill, or methodology change; smoke suite unchanged.

- **`GUIDE.md`** — the "Ongoing health checks" list under *Stage 0 Gate: Roadmap Review* enumerates what `/roadmap-review` actually does, and was missing **both** new phases. Added **Roadmap progress** (Phase 2.5, checkbox ↔ `Done`) and **Phase-label layer** (Phase 3.5), each marked optional / no-op-when-inapplicable.
- **`sop/Linear_SOP.md`** — § Standard Labels documented every label family (Type/Flag/Tier) but not the phase-label layer's. Added a *Roadmap (optional)* subsection for the `Roadmap: Phase *` / `Order: Any` labels, pointing to `method.config.md § Phase Label Layer` and the `/linear-hygiene` guardrail. (This SOP syncs to consumers, so the tag carries it to rs-vault/Piper/SiteLine.)
- **`RUNBOOK.md`** — new **Maintenance** section. The runbook was only the two per-issue loops; the periodic Linear housekeeping had no home. Added a cadence table for `/linear-hygiene`, `/brainstorm-review`, `/roadmap-review`, `/phase-plan`, plus a phase-label-layer upkeep note (bootstrap on first run → drift-check thereafter → the one manual Manual-sort toggle).

**Verified as *correctly* left alone:** `README.md` (high-level intro — the layer is below its altitude), `STARTUP.md` / `Skills_SOP.md` (bootstrap-chain / catalog altitude; `STARTUP`'s stamp staying at v4.11.0 is the drift-signal convention working, not an oversight).

---

## v4.15.0 — 2026-07-14

> **Roadmap Progress Reconciliation — the roadmap's checkboxes vs Linear `Done`.** A roadmap file with `- [ ]`/`- [x]` progress checkboxes and the Linear board are edited by different hands at different times, so they drift: a box gets ticked before the issue actually ships, or an issue lands `Done` and the roadmap is never updated. New **Phase 2.5** in `/roadmap-review` reconciles the two. This is the one check SiteLine's hand-rolled phase-label drift-check had that v4.14.0's Phase 3.5 didn't cover — now portable and upstream (surfaced while porting v4.14.0 to SiteLine).

**The check (both directions, against the states already fetched in Phase 1):**
- **Checked but not `Done`** — the roadmap shows `- [x]` for an issue whose Linear state isn't `Done` (reopened, still in flight, or ticked prematurely) → flag; a checked box asserts "shipped."
- **`Done` but unchecked** — an issue is `Done` in Linear but the roadmap still shows `- [ ]` → flag; the roadmap is stale.

**Report-only, and it never writes the roadmap.** `ROADMAP.md` is human-owned (`method.md § Initiative Surface Ownership` — skills never write it), and a mismatch is ambiguous about which side is right (a `[x]`-but-not-`Done` may mean the issue *reopened*, not that the box is wrong). So Phase 2.5 surfaces both lists and lets the human resolve — tick the box, reopen the issue, or fix the state. It never edits the roadmap file and never flips a Linear state from a checkbox.

**Gating.** Reads the roadmap source (`Roadmap source` key, default `ROADMAP.md`); **no-op** if that file has no checkboxes. Deliberately **independent of the phase-label layer** — a project can keep a checkboxed roadmap without opting into `### Phase Label Layer`, so the check is *not* gated behind that config. A new Phase 8 report block surfaces the mismatches.

**No `bin/pk` behavior change** — `PK_VERSION` bump only; smoke suite unchanged. One skill (`/roadmap-review`) + the release stamps.

---

## v4.14.0 — 2026-07-14

> **Roadmap Phase-Label Layer — render `ROADMAP.md`'s build order onto the Linear board.** The `i{N}.`/`I{N}.P{N}.` initiative surface answers *"what's the current initiative/sub-phase?"* — but a solo dev looking at N issues in a project still can't see *"what order do I run these in, and which are safe in parallel?"* A roadmap **phase** routinely spans multiple `I{N}.P{N}.` projects, so no single Linear container *is* a phase, and a plain project filter can't render "this phase, in order." This release makes a **label-based visualization mirror** of `ROADMAP.md` a first-class, config-gated, portable part of `/roadmap-review` — proven live on SiteLine's `piper-poc` across 24+ issues / 4 labels before being brought upstream.

**The layer.** A **label** (not a project) carries phase/pool membership, because phases cross project boundaries: `Roadmap: Phase A/B/C` (sequenced) + `Roadmap: Continuous` (the standing pool). One ungrouped, Manual-sorted saved view per label renders the order in Linear's UI; `sortOrder` mirrors `ROADMAP.md`'s top-to-bottom order (stepped, so inserts don't force a renumber); an `Order: Any` label marks parallel-safe issues and real `blockedBy` relations (never description prose) carry sequential dependencies. It **owns no state `ROADMAP.md` doesn't already assert** — it's a mirror, additive to the two surfaces beside it, not a replacement.

**`/roadmap-review` — new Phase 3.5 (config-gated).** No-op unless the `### Phase Label Layer` section is *filled in* (the template ships it commented out — gate on active values, not the bare heading), so it's fully portable. When configured, it reads the label/view convention from config (**hardcodes no phase names** — reads them from the project's own roadmap source file, the `Roadmap source` key, default `ROADMAP.md`) and drift-checks: membership adds/removes vs the roadmap's per-phase issue lists, `sortOrder` monotonicity (**flag-only**, reordering is a human-intent call), one-phase-label-per-issue exclusivity, and `Order: Any` ⊥ `blockedBy` contradictions. Drift fixes fold into the skill's existing "want me to fix any of these?" prompt (propose-then-apply); a new Phase 8 report block surfaces the state.

**Retrofit path — the layer materializes onto an *existing* board.** Phase 3.5 opens with a **materialization check**: if the layer is configured but its labels/views don't exist yet (an established project adopting the layer — the rs-vault / Piper rollout case), it offers a one-time **bootstrap** with its own confirm — create the team labels + one saved view per label, seed `sortOrder` from the roadmap order, apply membership, and create the intra-phase `blockedBy` relations — then falls through to drift-checking. This closes the gap the file-sync can't: `/pipekit-update` carries the *skills* but never touches Linear, and view/label creation previously lived only in `/roadmap-create`'s initial-authoring scaffold. A `sortOrder` **seed** (of an unset value) applies on the bootstrap confirm; a **reorder** of an already-set order stays flag-only. The one step no API can do — toggling each view to Manual sort — is reported as a pending human step.

**Two live bugs, fixed in the skills — not just documented.**
- **Bug 1 (`/linear-hygiene`):** re-parenting an orphan into a phase-arc project silently implied phase membership — SiteLine POC-382 picked up a stray `Roadmap: Phase A` label from a placement pass, but `ROADMAP.md` places it under Continuous. **Project membership ≠ phase-label membership.** New hard **Drifts-to-Avoid** rule: the placement janitor mutates `projectId`/`priority`/`stateId`/relations and must **never** touch `Roadmap: *` labels — phase-label placement is owned by `/roadmap-review`'s Phase 3.5.
- **Bug 2 (portability):** the drift-check logic had nowhere portable to live, so it was hand-authored into SiteLine's `method.config.md` prose. Now it's skill-native, parameterized by `method.config.md` the way Team ID / Workflow State IDs already are — every Pipekit project gets the same tooling instead of reinventing the prose.

**`/roadmap-create`** gains an optional, config-gated **Phase 3.5** to *scaffold* the labels + saved views at initial authoring time (labels, membership, stepped `sortOrder`, one view per label) so new projects get the layer from the start, not only as a retrofit. **`method.config.template.md`** gains a **commented-out `### Phase Label Layer`** block under `## Initiative Surface` — a project opts in by uncommenting and filling label/view names from its own roadmap; skills no-op without an active section, so un-opted projects see zero behavior change.

**Rider: `/01-light-spec` label-mutation note corrected.** Phase 5 claimed `linear_updateIssue` "doesn't support add/remove deltas" — stale: `@tacticlaunch/mcp-linear` does expose `linear_addIssueLabel`/`linear_removeIssueLabel` (which this release's new edits use), and the surfaced contradiction is fixed. The claim is re-stated accurately: `updateIssue`'s `labels` param is a wholesale *set* (not a delta), which is why Phase 5 pulls-and-merges the full label list; the delta tools exist but a single wholesale set is cleaner when reconciling the whole list at once. Mechanism unchanged.

**No `bin/pk` behavior change** — `PK_VERSION` bump only (no code path reads these labels); smoke suite unchanged. Docs/skills/template only.

---

## v4.13.0 — 2026-07-12

> **Model Policy — skills reference model roles, not model names.** Portable skills used to hardcode `model: opus` / `model: sonnet` at every subagent spawn site (~10 call sites), which meant every model generation forced a docs-wide sweep — and the sweep never fully happened: four skills still reasoned about "Opus 4.7 defaults" two generations later. This release applies Pipekit's own no-hardcoded-values rule to the time-varying axis: skills now cite a **role**, and the role → model + effort mapping lives in one place.

**The roles.** A new optional `method.config.md § Model Policy` section maps four agent roles to a model + effort tier:

| Role | Default model | Default effort |
|------|---------------|----------------|
| Grounding / lookup | `haiku` | `low` |
| Execution | `sonnet` | `medium` |
| Verification | `sonnet` | `high` |
| Plan review / adversarial | `opus` | `xhigh` |

Skills cite the role **with its default inline** ("execution tier per `method.config.md § Model Policy`, default `sonnet`"), so a project whose config predates the section sees zero behavior change, and re-pointing a tier at the next model generation is a one-row config edit. `sop/Skills_SOP.md § Pinning models on subagents` is the canonical reference; the section is documented in `method.config.template.md`.

**Pin sweep.** Inline `model:` pins replaced with role references in `/review-plan` (plan-reviewer spawn), `/verify` (QA subagent, antagonistic reviewer, migration reviewer, embedded security-gate spawn), `/security-gate` (classifier + per-category reviewers), `/prod-ready` (check subagents), plus the `method.md` and `GUIDE.md` plan-reviewer references. Model defaults are unchanged from the previous hardcoded values; effort defaults are newly explicit, sourced from current Anthropic guidance.

**`/work` now implements the policy — all four spawn sites pinned.** Previously `/work` passed no `model:` at any spawn site, so its subagents silently inherited the session model — on a frontier-model (Fable-class) session, every atomic task agent ran at frontier cost. Now: Workflow **task agents** → execution tier (default `sonnet`/`medium`, passed explicitly in every `agent()` call and every fallback Task dispatch, with a "surface, don't self-escalate" rule); `--deep` **codebase explorer** → grounding tier (default `haiku`/`low`); `--deep` **spec validator** and the Step 6 **security review** → plan-review/adversarial tier (default `opus`/`xhigh`). This closes the one divergence between the Model Policy table and actual behavior — the session model now governs only the session's own cognition (planning, synthesis, verdicts), never spawned lanes.

**De-staling.** Model-version-anchored prose made model-agnostic where the behavior persists across generations: the design-default probes in `/strategy-create` + `/startup` (the cream/serif/terracotta house style — now framed as "current Claude models", with the counter-it-concretely guidance), the Explore-subagent mandate in `/01-light-spec`, and the parallel-spawn mandate in `/06-linear-todo-runner`. `sop/Session_Management_SOP.md`'s effort section is re-anchored: session default `high` with `xhigh` reserved for the most capability-sensitive steps, and an explicit "sweep *downward* on upgrade" note — newer generations deliver more per effort level (current-frontier `low` often exceeds previous-generation `xhigh`), so porting old effort settings forward over-provisions.

**Considered + deferred** (surfaced by a review of the pilotfish repo, which independently arrived at role-indirected model routing): **escalate-on-failure** (start a task on the cheapest plausible role, re-run one tier up after two verify failures) — a natural fit for the native executor's verify-before-integrate loop, deferred until the Model Policy section has real-world mileage. (Pinning `/work`'s grounding agents to haiku was initially deferred too, then folded in pre-merge as part of the `/work` spawn-site sweep above.)

**Rider: commit hook — two more false-positive shapes closed.** (1) `git commit -m "$(cat <<'EOF' … EOF)"` — the canonical multi-paragraph commit shape — misfired the advisory nudge: the `-m` value has no closing quote on its line, so the extractor validated the truncated literal `$(cat <<'EOF'` while the real subject sat unread on heredoc line 1. A sibling of the v4.3.1 heredoc-body fix (that release handled `git commit` *inside* a body; this handles a heredoc *feeding* `-m` via command substitution). The extractor now routes that shape into the existing first-body-line capture used by bare `-F- <<EOF` commits. (2) Markdown inline code in a `--body` string — `` `git commit -m ...` `` — counted as a *real* invocation because backtick was in the operator-boundary class (legacy `` `cmd` `` substitution); with a `<<EOF` elsewhere in the prose, the hook then "validated" the next body line. Backtick is dropped from the boundary class: markdown backticks are ubiquitous in Claude-authored PR comments, archaic backtick cmd-subst commits are essentially unused. Both shapes surfaced live during this release's own session. `templates/hooks/validate-commit.sh` + dogfood copy; 3 new smoke tests.

**Rider: `pk done` hints are merge-aware — `--merge` is the exception, not the suggestion.** Sessions kept telling the user to run `pk done <ID> --merge` for PRs that were already merged (e.g. the POC-343 session log: branch merged as #615, log still prescribed `--merge`). `bin/pk` itself was already correct (`pk next` says "review/merge the PR, then `pk done X`" when OPEN, plain `pk done X` when MERGED; `--merge` only offered in the not-merged error path) — the parroting came from prose. Fixed at the two sources sessions actually read: `/pk-exit`'s log template now requires checking `gh pr view --json state` before writing the cleanup step (merged → plain `pk done <ID>`; open → "merge once green, then `pk done <ID>`" or `--merge`), and the consuming-project CLAUDE.md pipeline line now reads `[PR review + preview UAT → merge] → pk done` with an explicit "never suggest `--merge` for an already-merged PR" note. Syntax references (`pk done <ID> [--merge]` in tables) are unchanged — the flag is real; only the prompting was wrong.

**No `bin/pk` behavior change** — `PK_VERSION` bump only; smoke 95→98 (three hook false-positive tests).

---

## v4.12.0 — 2026-06-27

> **Guarded Linear writes — `pk` won't land an issue on the wrong board.** Before any Linear *mutation*, `bin/pk` now proves the resolved API token actually belongs to this project's workspace, and refuses the write on a confirmed mismatch. A stale or cross-project token — wrong direnv env, wrong 1Password vault, a global `pk` symlinked into another repo — can no longer quietly transition issues or post comments on someone else's board.

**How it pins.** The check runs at the single `pk_linear_gql` chokepoint, fired only when the query is a `mutation` (reads are never guarded — a wrong-board read is harmless, and the guard itself reads). It pins on **Team ID** (a globally-unique UUID; resolving under the token proves same-workspace) or, when Team ID is unset, **Workspace slug** vs the token's org `urlKey`. Verified once per invocation, then cached.

**Fail-closed, but only on a *confirmed* mismatch.** Adapted from [KyaniteHQ/linctl](https://github.com/KyaniteHQ/linctl)'s target-pinned guarded writes — with one deliberate softening for a daily driver: pipekit fails *open* (warns + allows) when it simply can't reach Linear to verify, so a transient network hiccup never false-blocks the loop. A genuinely bad token still makes the mutation itself fail loudly. Projects with neither pin set get a one-time warning and proceed (backward-compatible).

**Implementation.** New pure `pk_linear_guard_verdict` (a 5-arg decision, fully unit-tested) split from the I/O wrapper `pk_linear_guard`; the two writers (`pk_linear_set_state`, `pk_linear_comment`) hardened so a blocked mutation never prints a misleading success line. No methodology change, no change to any read command. Smoke **89 → 95** (six verdict-branch tests). Live-verified against a production Linear workspace: a legitimate token → `ok` (no false-block), a foreign team UUID → `Entity not found` (the fail path is real).

**Config.** `Team ID` / `Workspace slug` in `method.config.md` now do double duty as the write-guard pins — documented in `method.config.template.md`.

## v4.11.0 — 2026-06-26

> **The docs speak Linear now.** v4.10.0 aligned what `pk` *prints* (phase → initiative) but deliberately deferred the documentation. This release finishes the job: the methodology docs, skills, and SOPs say **initiative** wherever they mean a Linear Initiative, and the **Phase Surface** concept is now the **Initiative Surface** — so a reader never has to translate between Pipekit's words and Linear's.

**The sweep.** ~280 in-place edits across 27 files — a perfectly balanced diff (every change is a word swap; zero structural change). Roadmap-phase prose → *initiative* (`current/next/future phase`, roadmap "Phase N", `phase-aware` → `initiative-aware`, "The Phase Model" → "The Initiative Model", every state/order/hierarchy line); the architectural concept **Phase Surface → Initiative Surface** everywhere in active docs, including the `§ Phase Surface` cross-references in five skills + `sop/Linear_SOP.md` and the `## Phase Surface` section heading in `method.config.template.md`.

**Deliberately kept** (each verified, not missed):
- The `/phase-plan` **skill name** and the `phase-detect` / `phase-slug` **identifiers** — renaming a command is a breaking change for every consumer; out of scope.
- **`Future Phases`** — a literal **Linear workflow state name**, not prose. Renaming it would mean reconfiguring every consumer's board + state-ID map.
- **`sub-phase`** — the Project level. It maps to a Linear **Project**, *not* a nonexistent "sub-initiative" (an over-eager agent coined that in four spots; reverted).
- spec-preflight **"Phase 3.6"** probe numbers, **generic skill-process** "phases" (`/linear` "5 phases", `pk-bug` "the phase below"), the `pk promote` **"two-phase model"**, and the legacy `.vbw-planning/phases/` dir.
- All **dated history** — `CHANGELOG.md`, `Logs/`, `resources/vbw-retirement-plan.md` keep "phase surface" as written.

**No behavior change.** `bin/pk` and `tests/` were untouched; apart from `pk version`, command output is identical to v4.10.0. Smoke **89/89**.

**How it was built.** A fan-out of 11 low-cost (haiku) subagents over disjoint file-sets applied a single locked decision map, **deferring** every ambiguous occurrence back for human reconciliation rather than guessing — followed by two grep audits (KEEP-list integrity + grammar) and the smoke gate. A partition miss (`STARTUP.md`) and a half-completed concept rename were caught and finished in reconciliation.

**Consumer note.** Existing projects carry `## Phase Surface` in their project-owned `method.config.md`; after they sync these skills (which now reference `§ Initiative Surface`), that pointer is a cosmetic mismatch until they rename the heading — self-heals on a one-line edit. SiteLine's is updated in the same sync as this release.

## v4.10.0 — 2026-06-26

> **`pk portfolio` — a new top-altitude view for project-managing yourself.** `pk next` answers "what's the next keystroke," `pk status` shows the current board — but neither tells you *where you are in the whole plan* or *what's gone cold while you were heads-down*. `pk portfolio` is the zoom-out above both.

**The command.** `pk portfolio` (new `cmd_portfolio` + pure helper `pk_runway_render` in `bin/pk`) prints two things, read live from Linear:

1. **Initiatives map** — every `i{N}.` initiative with its Linear status, the Active ones marked `← active`, and its current `I{N}.P{N}.` project.
2. **Runway** — actionable issues (In Progress / UAT / Approved / Needs Spec) across **all Active-status initiatives** (you work several at once — "active" = Linear initiative status `active`, naturally multi-select; falls back to the single derived current initiative if none are Active), grouped by `I{N}.P{N}.` project and ordered initiative → sub-phase. Project-scoped queries per project × state — avoids the team-wide `first:25` truncation that would starve a phase's issues when other phases were touched more recently.

**Runway ordering** is priority-first, *not* lifecycle-first, and blocked issues are **not** sunk: instead each blocker is lifted to rank just above the most urgent issue it blocks (`erank = min(own_rank, blocked_rank − 0.5)`, one level, only when the blocker is in the list — otherwise the `⛔` tag + reference suffices). Columns are width-aligned (titles clip at 60); each project header shows an **active count** and a **`⚠ Nd idle`** momentum flag computed from the newest issue's Linear `updatedAt` vs the new `Portfolio staleness days` config key (default 14). Smoke 80 → 89; new pure-render coverage (grouping, blocker-lift order, cross-initiative order, idle flag, alignment) + a dispatch case.

**Terminology — `pk` output now speaks Linear.** `pk next` and `pk portfolio` user-facing strings say **Initiative** where they used to say "Phase" (Project and Issue already matched). The `i{N}.`/`I{N}.P{N}.` naming convention, internal variable/function names, and the methodology docs ("phase surface" in `method.md`/`GUIDE.md`/`CLAUDE.md`/SOPs — ~1,100 "phase" mentions, many of them *not* initiative-sense, e.g. the `/phase-plan` skill name and the "Phase Surface" concept) are **deliberately not swept here** — that's a larger, semantically-careful migration planned as its own release. This release aligns only what the daily-loop user reads on screen.

**`pk status` unchanged** — kept as the full-board view by design.

## v4.9.0 — 2026-06-26

> **`pk next` and `pk status` see structure now.** v4.8.0 made them order by *priority*; v4.9.0 makes them aware of *project* and *dependencies*. Two changes, both `bin/pk`.

**`pk status`: grouped by project, with the Needs Spec queue.** It listed each state flat and didn't even fetch the project, so a multi-project board was a wall of identifiers; and the `Needs Spec` queue (pre-Approved) wasn't shown at all. Now each state is **grouped by project** — project groups ordered by their highest-priority issue (most-important project first), issues priority-sorted within each, orphans (`(no project)`) always last even if one holds an Urgent (an orphan is an anomaly to home via `/linear-hygiene`, not normal work). `Needs Spec` is shown as its own bucket beside `Approved`. The old `head -10` truncation is gone — `pk status` is the "show me the board" view, and hiding rows (especially the Needs Spec queue) worked against it.

**`pk next`: dependency-aware — blocked work sinks, the suggestion stays startable.** `pk next` surfaced Approved issues by priority and suggested `.[0]` as the next `pk branch` with zero awareness of blocked-by — so a high-priority Approved issue blocked by an unfinished one sorted to the top and got recommended even though it can't be started (sharper since v4.8.0's priority sort). Now the two state queries fetch Linear `inverseRelations`, and:
- An issue is **blocked** iff a relation of type `blocks` points at it (`inverseRelations`, the `.issue` side is the blocker) and that blocker is **not yet `Done`/`Canceled`**. Direction verified against Linear's published schema + recipes (a `blocks` relation is `issue` blocks `relatedIssue`).
- Within each group, blocked issues **sink below ready work** and are tagged **`⛔ blocked by POC-X`** (nothing is hidden).
- The `Run:` suggestion targets the **top *startable* issue** (`pk_first_ready_id`), not a blocked `.[0]`. When *every* Approved is blocked, it says so (`All Approved issues are blocked — clear POC-X first`) instead of recommending an unstartable one.
- `pk status` flags blocked issues inside the project groups too.
- **Fail-safe:** missing or unrecognized relations → the issue is treated as ready (never falsely blocked) and never crashes the pick.

This is the daily-loop counterpart to the dependency gating that already lived in `/phase-plan` (composition) and `/06-linear-todo-runner` (batch scheduling). Direct blockers only (one level, matching the batch runner); cross-phase blockers count.

Four new pure, smoke-tested helpers: `pk_issues_group_render`, `pk_issues_annotate_blocked`, `pk_issues_flat_render`, `pk_first_ready_id`. Suite **70 → 80**.

> **Verify on first use:** the blocked-by direction was confirmed against Linear's docs/schema (pipekit-the-repo has no Linear to introspect live); when a consumer first runs `pk next`/`pk status` against a known blocked pair, confirm the `⛔ blocked by` tag names the actual blocker.

---

## v4.8.0 — 2026-06-26

> **Priority-aware surfacing — organise Linear so `pk next` shows the most important work.** Two coupled changes that share one goal: an important follow-up should be *visible* in `pk next` and *on top* of what it lists. One controls what enters `pk next`'s view; the other controls what sits at the top.

**`/linear-hygiene` routes Triage state by priority, not difficulty.** The old rule sent Triage → `Backlog` by default and → `Needs Spec` only for `tier:standard`/`tier:heavy` items. But tier is a *size* estimate, not an *importance* signal — so an important-but-unsized follow-up got buried in `Backlog`, where `pk next` can't see it (`pk next` surfaces `In Progress` / `Approved` / `Needs Spec`, not `Backlog`/`Triage`). The new rule routes by the **resolved priority**:
- `Normal (3)` or higher → **`Needs Spec`** (important enough to slate for speccing, so `pk next` surfaces it).
- `Low (4)` → **`Backlog`** (homed and prioritized, not yet on the spec lane).
- **Priority catch-all floor flips `none → Low`** (was `Normal`). This is what makes the cut behave: an item with no importance signal is *Low until proven otherwise*, so it doesn't get slated for speccing just for existing. `Normal+` now means "a signal said this matters" (`Client Request` → High, `Bug` → Normal, blocks-something → ≥Normal).
- **Exception — bundles:** a multi-ask item (raw feedback often packs several: "grid lines + header parity + column-hide + logo") routes to `Backlog` + a `/brainstorm-review` flag *regardless of priority* — `Needs Spec` is for one spec-able thing, not a pile. This keeps the change from re-creating premature-spec for important items.

This nudges `/linear-hygiene` slightly further into disposition (it now decides "slate this to spec"), but it stays placement, not verdict: it never renders Now/Later/Kill, never Parks, never Cancels — that's still `/brainstorm-review`.

**`pk next` / `pk status` order each state group most-important-first.** The state-query helpers fetched with `orderBy: updatedAt`, so even with important items in `Needs Spec`, the *most* important wasn't on top — and `.[0]`, the suggested next action (`pk branch` / `/light-spec`), pointed at the most recently *touched*, not the most important. New pure helper `pk_issues_priority_sort` ranks a fetched issue array Urgent → High → Normal → Low → None (priority `0`/None sorts **last**, not first as a naive numeric sort would); both helpers route through it. Linear's `orderBy` enum has no priority field, so the ranking is client-side over a fetched `priority`. Net: the listing leads with the top item and the "Run:" suggestion targets it.

3 new smoke tests pin the sort (ordering, absent-priority → last, empty input); suite **67 → 70**.

---

## v4.7.1 — 2026-06-26

> **`pk done` no longer destroys the session that runs it from inside the worktree.** A `bin/pk` safety fix; rides into every consumer on the next `sync-method.sh v4.7.1`. No methodology change, no new skills.

`pk done` removes the feature worktree, so it must run from the parent repo. A guard existed to refuse a run-from-inside-the-worktree, but it was structurally defeated: it only fired when `root != wt_path`, and `root` came from `pk_repo_root()` → `git rev-parse --show-toplevel`, which **from inside a linked worktree returns the worktree itself**. So `root == wt_path`, the guard's outer condition was always false, and `pk done` fell straight through to `git worktree remove --force` — tearing down the directory the calling session lived in. With `--merge`, the PR was merged *first* (the `gh pr merge` block sat above the guard), so the failure mode was: merge the PR, then destroy the session — no `/pk-exit`, no deploy, dead session. Surfaced repeatedly on SiteLine, because the `pk next` hint kept suggesting bare `pk done` with no worktree caveat, luring the run.

The fix, three parts:
- **Un-gate the guard.** Drop the `&& [ "$root" != "$wt_path" ]` condition; the inner `pwd`-inside-`wt_real` check (`pwd -P` on both sides, so a session in a worktree *subdir* still matches) is the real signal — the `root` compare was noise that defeated it.
- **Move the guard above `--merge`** so a run-from-worktree mistake refuses *before* merging anything. The refusal now points at the actual parent repo (the first `git worktree list` entry) and tells you to run `/pk-exit` first — the old message pointed `cd $root`, which was the worktree you needed to *leave*.
- **Worktree-aware `pk next` hint.** New `pk_in_linked_worktree` helper (compares `--git-dir` to `--git-common-dir`); when the next-step hint is read from inside a worktree it now spells out the `/pk-exit` → leave → `pk done <ID>` sequence and names the issue, instead of bare `pk done`.

4 new smoke tests pin the guard (helper distinguishes worktree vs main; refuses from inside before merging; worktree intact after refusal; parent-repo run not falsely blocked); suite **63 → 67**.

---

## v4.7.0 — 2026-06-24

> **VBW fully retired.** This release completes the retirement begun in v4.0.0 (executor removed), v4.1.0 (Linear-native phase surface), and v4.2.0 (plugin decoupled). VBW is no longer part of any Pipekit workflow, doc, or dependency.

**Debrand across the active surface (~250 mentions, 32 files).** Docs (`method.md`, `GUIDE.md`, `README.md`, `RUNBOOK.md`, `STARTUP.md`, `CLAUDE.md`, `method.config.template.md`), skills (`/work`, `/review-plan`, `/spec-preflight`, `/roadmap-create`, `/sync-linear`, `/startup`, `/pipekit-help`, `01-light-spec`, `00-roadmap-review`, `10-strategy-sync`, and more), SOPs (`Linear_SOP`, `Skills_SOP`, `Session_Management_SOP`, `Hooks_SOP`), `agents/plan-reviewer.md`, and templates were debranded: no `/vbw:*` commands, no `vbw` backend / `--backend=` selection, no "Pipekit wraps VBW" / VBW-ownership-boundary framing. Pipekit owns the whole Linear-native phase surface; `/work` is the only executor entry point. The `## VBW / Pipekit Ownership` section is now `## Phase Surface Ownership`.

**`bin/pk`.** `pk_vbw_*` helpers renamed `pk_legacy_*`; comments/strings debranded. The legacy `.vbw-planning/PHASES.md`/`linear-map.json` + `PLAN.md` finalize remain as a **read-only fallback for un-migrated projects** — never the normal path. Smoke **63/63**.

**Removed.** The dead `scripts/pipekit-post-archive.sh` hook (fired on `/vbw:vibe --archive`, which no longer exists) and its sync registration; the `/vbw:vibe` matcher in `pipekit-next-step-nudge.sh`.

**Machine.** The VBW plugin is uninstalled from `~/.claude` (cache + marketplace clone removed, `settings.json` enable-flag + vbw statusline removed, plugin registry + telemetry cleaned). History is preserved as written — `archive/`, `experiments/`, `Logs/`, `CHANGELOG.md`, and `resources/vbw-retirement-plan.md` are untouched.

**Deferred (Scope B).** `bin/pk-init/detect_vbw.sh` and the greenfield-bootstrap VBW detection stay — they belong to the deferred new-project bootstrap redesign, not this debrand.

---

## v4.6.0 — 2026-06-23

> **New: `pk deploy [<env>]` — a first-class front door for script-deploy projects.** Projects that ship by running a deploy script (FTP, rsync, a custom uploader) rather than by branch promotion had no `pk` verb for the deploy itself — `pk done` only *reminded* you to run the configured `Deploy command` ("merged ≠ deployed"), leaving the last, outward-facing step as out-of-band copy-paste. `pk deploy` closes that gap: it resolves `<env>` to the project's configured deploy command in `method.config.md` and runs it.

**Positional env, thin delegation.** `pk deploy` (or `pk deploy prod`) runs the bare `Deploy command`; `pk deploy dev` runs the per-env `Deploy command dev` (the per-env key is **space-suffixed** — `pk_config` splits each config line on its first colon, so a colon in the key would be unparseable); `pk deploy prod` falls back to the bare key when no `Deploy command prod` is set. Anything after `--` passes through to the script verbatim (`pk deploy prod -- budget-edit.html`, `pk deploy -- --all`). The command `exec`s the deploy script so it owns the tty — its own confirmation prompts, secrets-manager wrapping (`op run`), and progress output are untouched. **pk reimplements none of the deploy safety** (file resolution, cache-busting, main-only extraction, the confirm gate); those stay in the project's script, the single source of truth.

**Backward-compatible + promote-aware.** The long-standing single `Deploy command` key keeps working unchanged (it's what `pk deploy` / `pk deploy prod` read), so existing configs need no edits. Branch-promotion projects (no `Deploy command`, `Promote to main: true`) are pointed at `pk promote` instead of erroring. `pk done`'s post-merge reminder now points at `pk deploy` (still showing the underlying command). Two optional config keys documented (`Deploy command`, per-env `Deploy command <env>`) plus a new script-deploy template example. 7 new smoke tests (delegation + passthrough, prod→bare fallback, per-env key, unknown-env / unknown-flag / extra-positional errors, promote redirect); suite **56 → 63**. No change to any existing command's behavior.

---

## v4.5.0 — 2026-06-22

> **Phase surface: projects carry their initiative number.** A Linear project under initiative `i1.` is now named **`I1.P2. label`** (initiative number + project number), not bare `P2.`. Initiatives sit *above* projects in Linear and get buried in the UI; projects are the unit you actually navigate — so putting the initiative number in the project name makes the phase legible at the level you work at.

**Backward-compatible parser.** `bin/pk`'s phase derivation (`pk_native_phase_context` / `pk_native_roadmap_summary`) widened its project-name match from `^P[0-9]+\.` to `^([iI][0-9]+\.)?[pP][0-9]+\.` — it now accepts **both** `I{N}.P{N}.` and legacy bare `P{N}.`. The `P{N}` number still sets sub-phase order either way, so a workspace can be renamed gradually without breaking `pk next` / `pk status`. 2 new smoke tests prove an `I{N}.P{N}.` fixture derives correctly and coexists with bare `P{N}.`; suite **54 → 56**.

**Authoring + docs updated to the new form.** `/roadmap-create` authors projects as `I{N}.P{N}. label`; `/phase-plan` displays and advances them; the drift-detectors `/sync-linear` and `/00-roadmap-review` treat `I{N}.P{N}.` as the correct form and a bare `P{N}.` as a rename candidate (not an error). The contract (`method.config.md § Phase Surface`) and every doc that states the naming (method.md, CLAUDE.md, GUIDE.md, RUNBOOK.md, STARTUP.md, `sop/Linear_SOP.md`) now show `I{N}.P{N}.`.

This is a convention + tooling change only — no change to how phases are *derived* (lowest non-complete initiative → lowest non-complete project, by numeric prefix) and no `bin/pk` command behavior change beyond the widened regex.

---

## v4.4.0 — 2026-06-22

> **New: `/security-gate` — the feature-scoped security gate (gap #3).** Pipekit has had `/security-review` (whole-repo audit) and `/pr-security-review` (PR-scoped, antagonistic) for a while, but both are **opt-in** — a human decides to run them. The gap that left: a security-sensitive feature can sail Building → UAT → production without anyone *deciding* it needed a look. `/security-gate` closes that — it runs automatically at the Building → UAT seam (in the v2 loop, the `pk ship` transition), beside `/verify`. This is the third of the five production-readiness gaps (gap #1 migrations in v4.0.0-rc5, gap #2 `/prod-ready` in v4.3.0).

**Classify first, review only on a match.** The gate's first stage is a read-only classifier sub-agent that maps the **feature diff** to six sensitive categories — **auth, payments, user-input, external-APIs, file-storage, PII** — using the project's category signals. If none match, the gate is an **instant PASS**: most features touch nothing sensitive, and that path is meant to be cheap. If a category matches, a per-category checklist runs against the diff (parallel read-only sub-agents), every finding is **adversarially refutation-tested** (mirroring `/security-review`'s verification pass), and the gate emits a PASS/FAIL report. Classify from opened files, never a filename alone; when genuinely ambiguous, match (a false match costs one checklist run, a false miss ships an unreviewed sensitive change).

**Where it sits.** After `/verify` (code is correct), before `pk ship` (transitions to UAT). Two per-feature gates now bracket the lifecycle: `/security-gate` at the *entry* to UAT (is this safe to expose to testers?) and `/prod-ready` at the *exit* to production (can the env absorb it?). Distinct from `/verify` (per-task, fast, category-blind) — don't fold them.

**Portable framework, project-owned signals** — mirrors `/prod-ready` and `/financial-review`. The discipline + classifier + report shape live in `skills/security-gate/skill.md`; the substance (which paths/keywords mean each category in *this* repo, the project's auth primitive, which tables hold PII) lives in `resources/security-categories.md`, scaffolded from `templates/security-categories.template.md`. New SOP `sop/Security_Gate_SOP.md` carries the six per-category checklists + project-type variants (Next.js/Supabase, PHP, Python) + the rate-limiting overlap with `/prod-ready`. Two new `method.config.md` keys: `Security categories`, `Security gate report path`. No-op on a project without a categories file (scaffolds the template and stops).

**Advisory in this release.** `/security-gate` produces a PASS/FAIL report (`Reports/Security_Gate_<ID>_<date>.md`) and posts a best-effort Linear comment; it does **not** transition state or block `pk ship`. A hard sentinel gate on `pk ship` (refusing a category-matched feature without a fresh PASS sentinel, mirroring `/verify`'s `verify-complete.md`) is a documented fast-follow, deferred to keep this first cut out of the CI-gated `bin/pk` logic. No `bin/pk` behavior changed.

---

## v4.3.1 — 2026-06-22

> **`fix(hooks)`: the commit-format hook is now heredoc-aware.** The v4.3.0 fix closed the "`git commit` as a search pattern / echo / JSON literal" false-positive class, but one path remained open — and it bit immediately: **`git commit` inside a heredoc *body*.** When you document commit conventions inside a heredoc that feeds another command (the classic being `gh pr comment --body "$(cat <<EOF … git commit -m "feat: x" … EOF)"`), the awk read the line-initial `git commit` as a real invocation and fired a spurious nudge. The PR #441 review surfaced it the hard way: *posting the review comment tripped the hook.*

**Two paths, one fix.** (1) The awk now runs **line-by-line tracking heredoc open/close**, so a `git commit` occurrence inside a heredoc body is data, never an invocation. (2) The fragile `cat <<` *fallback* (which grabbed the first heredoc line as a "subject" whenever no `-m` was found — and so *also* misfired on prose heredocs) is **deleted**; the one legitimate case it served, a heredoc-authored commit (`git commit -F- <<EOF`), is now handled inside the same state machine — the first non-blank body line of a *bare* `git commit … <<DELIM` is its subject. Here-strings (`<<<`) and `<<-` tab-stripped closers are handled.

Hook-only change — `validate-commit.sh` + its dogfood copy, no `bin/pk` or methodology change. 4 new smoke tests cover both misfire paths and the legit `-F-` extraction (good + bad subject); suite **50 → 54**.

---

## v4.3.0 — 2026-06-22

> **New: `/prod-ready` — the production-readiness gate (gap #2).** Pipekit's pre-deploy gate (`/verify`) proves the code is correct in isolation; it never proved the *system* could absorb the code safely in production. `/prod-ready` is the second gate: it runs **once per feature**, at the production boundary, and verifies the operational preconditions `/verify` deliberately skips. This is the second of the five production-readiness gaps to close (gap #1, the migration artifact rule, shipped in v4.0.0-rc5).

**The split.** `/verify` runs every task at Building → ship (fast: types/lint/tests/AC). `/prod-ready` runs once at the production boundary — before `pk promote <last-env>` on multi-env projects, or before the merge to `main` on 1-tier. Two gates, never merged: different cadence, different failure modes (a `/verify` fail is a lint error fixable in minutes; a `/prod-ready` fail is infra work).

**The six checks**, each tagged automatable / agent-verifiable / manual-confirm: (1) error monitoring wired for the feature path, (2) no secrets in the **built** client bundle (greps the build output, not source — Critical on any match), (3) rate limiting on new public endpoints, (4) backups active on the target env, (5) feature flag / kill switch on risky paths, (6) a monitoring dashboard chart. Severity rubric Critical→Low; any Critical or unaddressed High → FAIL (hold the promote).

**Portable framework, project-owned checks** — mirrors `/financial-review`. The discipline + report shape live in `skills/prod-ready/skill.md`; the concrete substance (build command, secret prefixes, monitoring tool, rate-limit middleware, backup provider, flag system, dashboard URL) lives in a project checks file (`resources/prod-readiness-checks.md`, scaffolded from `templates/prod-readiness-checks.template.md`). New SOP `sop/Production_Readiness_SOP.md` carries the full methodology + project-type variants (Next.js/Vercel/Supabase, Python/Railway, generic). Two new `method.config.md` keys: `Prod-ready checks`, `Prod-ready report path`.

**Advisory in this release.** `/prod-ready` produces a PASS/FAIL report (`Reports/Production_Readiness_<ID>_<date>.md`) and posts a best-effort Linear comment; it does **not** transition state or block `pk promote`. A hard sentinel gate on `pk promote <prod-env>` (mirroring `/verify`'s `verify-complete.md`) is a documented fast-follow, deferred to keep this first cut out of the CI-gated `bin/pk` logic. No `bin/pk` behavior changed.

**Also — `fix(hooks)`: the commit-format hook no longer false-positives on "git commit" as data.** The re-homed advisory hook (`validate-commit.sh`, shipped v4.2.0) matched the string `git commit` *anywhere* in a Bash command, so `grep -rn "git commit"`, an echoed reminder, or a JSON literal containing a commit example would fire a spurious format nudge (and extract garbage, e.g. `Got: 1`). It now treats `git commit` as an invocation **only** when command-initial or preceded by a shell operator (`; & | ( ) { } \`` or newline) — real commits (including `&&`-chained, subshell, and newline-preceded) still validate; commit-text-as-data is ignored. 4 new smoke tests guard both directions; suite **46 → 50**.

---

## v4.2.1 — 2026-06-21

> **Sync now force-tracks the re-homed commit hook.** v4.2.0 shipped the Pipekit-owned commit-format hook to `.claude/hooks/validate-commit.sh` and registered it in the committed `.claude/settings.json`. But many projects gitignore `.claude/hooks/` (the older "hooks are per-machine" convention), which left the hook **uncommitted** while its registration was committed — "wired but not really" for anyone who pulled without running sync.

`scripts/sync-method.sh` now detects when `.claude/hooks/<hook>` is gitignored and **force-tracks it** (`git add -f`) so the committed registration always points at a committed script. Non-fatal, dry-run-safe, and a no-op outside a git repo or when the path isn't ignored. Surfaced as a `FORCE-TRACKED …` line in sync output (falls back to a `git add -f` instruction if the add can't run). Found while rolling v4.2.0 into SiteLine, whose `.gitignore` ignores `.claude/hooks/`.

---

## v4.2.0 — 2026-06-21

> **VBW plugin decoupled — no longer required.** Pipekit no longer depends on the VBW plugin runtime. The plugin's one functional dependency — the advisory commit-format hook — is re-homed as a Pipekit-owned hook, so the `{type}({scope}): {desc}` nudge survives without VBW installed. The dead executor references are retired and the docs are debranded. The VBW *executor* was already removed in v4.0.0; what remains is a **legacy `.vbw-planning/` planning layer** that no Pipekit skill depends on — left intact, slated for a separate, later retirement.

**Re-homed commit-format hook (the one functional must-do).** Ported the plugin's `validate-commit.sh` to a Pipekit-owned source at `templates/hooks/validate-commit.sh` (dropping the VBW-internal version-sync block). `scripts/sync-method.sh` ships it to a consumer's `.claude/hooks/` and idempotently registers it in `.claude/settings.json` (jq merge — preserves existing settings, no-ops if already wired, falls back to a printed snippet when jq is unavailable). The hook stays advisory/non-blocking (always exits 0). 7 new smoke tests cover it; the suite is **46/46**.

**Debrand (framing only).** Dropped the "Pipekit wraps VBW" positioning across `method.md`, `GUIDE.md`, `README.md`, `CLAUDE.md`, `RUNBOOK.md`, `STARTUP.md`, `templates/CLAUDE.md.template`, `sop/Linear_SOP.md`, and `sop/Skills_SOP.md`; removed `/vbw:init` from the Stage 0 / bootstrap chains; reframed the legacy planning layer as optional and slated for retirement (not gone). Also fixed a stale executor claim in `GUIDE.md` ("native and vbw both plan here" → native only) and a long-broken `#vbw-integration` TOC anchor.

**Retirements.** `VBW_COMMANDS.md` and `sop/VBW_Help.md` (pure `/vbw:*` plugin command references) moved to `archive/`. Dropped the vestigial `Backend:` row from `method.config.template.md` — native has been the sole executor since v4.0.0.

**Deliberately deferred (separate, later retirement):** the functional identifiers `.vbw-planning/`, `pk_vbw_*`, and `/vbw:*` are left intact — they belong to the kept legacy planning layer; renaming/removing them is the separate planning-layer retirement. The machine-side plugin uninstall is a local op, not a repo change.

---

## v4.1.0 — 2026-06-21

> **Linear-native phase surface.** The roadmap's phase order moves out of committed files and into Linear itself. An Initiative named `i{N}. label` is an ordered roadmap **phase**; a Project named `P{N}. label` is an ordered **sub-phase** that holds the issues; ordering is the integer in the name prefix, parsed numerically (`P2` before `P10`). `pk next` / `pk status` derive the current phase live; `/roadmap-create` authors the hierarchy; `/phase-plan` advances it. `.vbw-planning/PHASES.md` + `linear-map.json` are **retired** to a read-only fallback, and `/vbw:init` is dropped from the Stage 0 contract. Validated live against a production Linear workspace before shipping.

**Why the name prefix, not Linear `sortOrder`:** the live probe showed `sortOrder` is an internal drag-rank that does **not** track phase sequence (it ordered one initiative's projects `P11, P8, P4, P3, P1, …`). The `i{N}.`/`P{N}.` name prefix is the only reliable order, and it doubles as the roadmap opt-in — unprefixed initiatives (strategic themes) are ignored by `pk next`. No config list of "which initiatives are phases" is needed.

**`bin/pk`:**
- New `pk_linear_initiatives_json` (one GraphQL query for initiatives + their projects) and `pk_native_phase_context` — derive `<current phase>\t<current project-id>` from the lowest non-`Completed` `i{N}.` initiative and its lowest non-`completed`/`canceled` `P{N}.` project, by numeric name prefix.
- `pk_phase_context` dispatcher: native (Linear) wins; falls back to the legacy `.vbw-planning/` files (renamed `pk_file_current_phase_*`) so un-migrated projects keep working — no flag-day. `cmd_next` shows `Phase: X (Linear)` when native.
- `pk status` gains a **Roadmap** section: the ordered `i{N}.` → current-`P{N}.` walk (silent until a project is migrated).
- Issue grouping (`pk_linear_issues_in_state_project`) is reused unchanged.
- 4 new sourced-mode smoke unit-tests guard the derivation jq (derivation, empty-input, no-prefix fallback, roadmap walk). **Suite 39/39, zero network.**

**Skills:**
- **`/roadmap-create`** rewritten to author the Linear `i{N}.`/`P{N}.` hierarchy directly (Initiatives → Projects → Issues). No `.vbw-planning/ROADMAP.md` merge dependency, no `linear-map.json`, no `/vbw:init` prerequisite. ROADMAP.md survives only as an optional human-readable narrative.
- **`/phase-plan`** pivoted from "compose a batch into `PHASES.md`" to "derive the current phase from Linear, promote its issues to Needs Spec, and advance the pointer by flipping initiative/project state." No file writes.
- **`/sync-linear`** reframed: reconciles strategy/requirement drift against the Linear board's `i{N}.`/`P{N}.` hierarchy; no `PHASES.md`/`linear-map.json` to sync.
- **`/00-roadmap-review`** validates the Linear-native surface (prefix naming, ordering, issue placement, lifecycle sanity) instead of the retired files.
- **`/startup`, `/01-light-spec`, `/review-plan`, `/pk-exit`** repointed: phase context is derived live from Linear; `/vbw:init` dropped from the Stage 0 orchestration.

**Config + docs:** `method.config.template.md` gains **§ Phase Surface** — the `i{N}.`/`P{N}.` naming contract. `method.md`, `RUNBOOK.md`, `GUIDE.md` (constitutional, re-stamped `v4.1.0`), plus `CLAUDE.md`, `README.md`, `STARTUP.md`, `sop/Linear_SOP.md`, `sop/Skills_SOP.md` migrated to the Linear-native model. README flags that the phase surface needs a Linear MCP with **initiative** support (`@tacticlaunch/mcp-linear`), which the first-party `mcp.linear.app` remote lacks.

**Deliberately deferred (separate, later retirement):** the broader VBW *planning layer* — `.vbw-planning/phases/*/PLAN.md`, `SUMMARY.md`, `.execution-state.json`, the `pk done` SUMMARY/PLAN lifecycle, and `/vbw:init`'s greenfield codebase analysis — is untouched. v4.1.0 migrates the **phase surface** only.

---

## v4.0.0 — 2026-06-20

> **Final cut of the v4.0.0 line.** Promotes `v4.0.0-rc5` to stable — no code change from rc5, only the release label, the consolidated changelog, and doc-stamp normalization (every `v4.0.0-rc*` stamp → `v4.0.0`). The five release candidates (rc1–rc5) below carry the full detail; this is the one-stop summary of what v3.2.0 → v4.0.0 delivers.

**Headline: the VBW *executor* is gone — native-on-Workflow is the sole executor.** The pluggable `vbw` backend, the `--backend=` flag, and the `vbw-dev`/`vbw-scout` dispatch in `/work` were removed (the `auto` router went in v3.2.0). A stale `Backend: vbw`/`auto` or `--backend=vbw` now **refuses** with a migration message rather than silently routing. Evidence-driven: 0/30 recent production PRs used vbw; native matched-or-beat VBW-the-full-system on first-pass correctness (POC-48), with the gate layer — not the executor — catching the one defect. **The VBW *planning* layer is deliberately untouched** (`.vbw-planning/`, `/vbw:init` roadmap scaffold, `/roadmap-create` phase merge, `/phase-plan`, `/review-plan`, `pk_vbw_*` helpers) — retiring it is a separate, later effort.

What the rc train added on top of the executor removal:

- **rc1** — VBW executor removal (the headline above).
- **rc2** — de-stale + debrand pass over the docs (executor-removal language; the brand stays load-bearing only in the plugin-owned planning layer).
- **rc3** — **Linear MCP tool-name migration.** All 19 interactive Linear skills now call `@tacticlaunch/mcp-linear`'s camelCase `linear_*` tools; the old snake_case house names matched no installed server (the daily-loop `pk ship`/`pk done` REST path was always unaffected, which is why the break stayed latent). Plus the `/linear-hygiene` placement janitor.
- **rc4** — **`pk ship` verify gate is sha-matched and date-independent** (matches a `verify-complete.md` whose `sha:` == HEAD under any date dir instead of re-deriving tier + today's date — killed two false-abort modes; `/verify` now writes the sentinel on PASS for every tier). **`pk promote` auto-picks the next ready hop** on a 3+ env chain instead of refusing (never skips ahead).
- **rc5** — **gap #1 artifact rule.** New `sop/Database_SOP.md`: every schema change lands as a tracked, reversible migration file (the AI still does all the DDL; only the artifact is constrained). `/light-spec` Phase 3.7 requires a six-field **Migration Plan** on schema-touching specs; the Spec Review Agent (§ Migration Rule) blocks one that lacks it. Companion to the *immutability* rule in `.claude/rules/pipekit-migrations.md`.

**Migration:** consumers re-sync (`./scripts/sync-method.sh v4.0.0`). After syncing, verify `method.config.md` has `Backend: native` (or no Backend row) — the sync never touches `method.config.md`, and a stale `auto`/`vbw` makes `/work` refuse. Smoke suite: 35 green.

---

## v4.0.0-rc5 — 2026-06-20

> **gap #1 artifact rule — schema changes land as migration files.** Closes the last open piece of the highest-priority production-readiness gap. The *immutability* rule (once a migration is applied anywhere, the file is frozen) shipped earlier as `.claude/rules/pipekit-migrations.md`. This release adds the *artifact* rule upstream of it: every schema change is born as a tracked, reversible migration — never an ad-hoc `ALTER` or a hand-edited schema dump — and schema-touching specs must plan that migration before they reach planning. **The AI still does all the database work; only the artifact is constrained.** No `bin/pk` change; docs/SOP/skill/template only.

- **New `sop/Database_SOP.md`** — the schema-change methodology. The One Rule (every schema change = a migration file), an explicit "the AI still does all the work" clause (the rule changes the artifact, not the workload), the six-field **Migration Plan** spec contract, a per-tool interface table (Supabase / Prisma / Drizzle / Knex / Alembic / Rails), and the three enforcement points (spec / verify / review). References `pipekit-migrations.md` for immutability and `pipekit-security.md` for the default-deny authorization rule — no duplication of the frozen-file invariant.
- **`/light-spec` Phase 3.7 — Migration Plan gate.** On a schema-touching spec, the new `### Migration Plan` template section is mandatory and must answer six questions (schema objects; migration tool + dir from `method.config.md § Migration dir`; forward intent; rollback intent; data backfill; authorization). Non-schema specs delete the section — it's conditional, so non-DB work is unaffected. Catching it here saves a Spec Review round-trip.
- **Spec Review Agent § Migration Rule (Critical)** (`templates/spec_review_skill.md`, bumped to v5.3) — mirrors the existing Authority Rule. A schema-touching spec with no concrete Migration Plan is a **Blocking** issue; so is an empty rollback intent (no reasoned undo, not explicitly "irreversible") or a new table/column with no stated RLS policy / GRANT.
- **`templates/light_spec_template.md`** gains the conditional `### Migration Plan` section under Technical Context.
- **Migration:** none for the API. Consumers re-sync (`./scripts/sync-method.sh v4.0.0-rc5`) to pick up the new SOP, template section, light-spec phase, and reviewer rule. Deferred (explicitly out of scope, per the gap's tiering): the Tier 2 drift-detection script and Tier 3 CI template.

---

## v4.0.0-rc4 — 2026-06-20

> **`pk ship` gate + `pk promote` hardening.** Two self-contained correctness/usability fixes from the standing backlog, both about a command re-deriving state it shouldn't.

- **`pk ship` verify gate is now sha-matched and date-independent.** The gate re-derived state `/verify` had already computed, giving two false-abort modes: (1) it re-derived tier via `pk_linear_tier`, which defaults to `standard` when Linear is unreachable — so a transient Linear flake at ship time demanded a sentinel that a `tier:quick` issue correctly never wrote; (2) `/verify` wrote `verify-complete.md` under `Logs/Verify/<verify-date>/` but ship looked under `<ship-date>/`, so a verify at 23:55 / ship at 00:05 missed it. Now `/verify` writes `verify-complete.md` on PASS for **every** tier (quick gets a minimal virtual sentinel recording the HEAD `sha`), and ship accepts a sentinel under **any** date dir whose `sha:` matches `git rev-parse HEAD` (new helper `pk_verify_sentinel_for_head`). The sha match also closes the converse hole — a PASS from an earlier commit can no longer vouch for the code being shipped. **Behavior changes:** `tier:quick` now requires a verify run (or `--force`) before ship (closing the old "ship an unverified quick issue" hole), and a new commit after `/verify` requires a re-verify. `--force` / `PK_VERIFY_BYPASS=1` unchanged. Touches `bin/pk`, `skills/verify/skill.md`, `skills/01-light-spec/skill.md`.
- **`pk promote` auto-picks the next ready hop.** On a 3+ env `Ship environments` chain, `pk promote` with no arg used to refuse (`Specify target`). It now walks the chain frontier and promotes the earliest hop whose source branch is ahead of its target (new helper `pk_promote_next_target`) — still one hop, still two-phase, never skipping ahead. A level chain is a no-op (exit 0); an explicit target still overrides; 2-env auto-pick unchanged.
- **Tests:** +13 smoke cases in `tests/pk-smoke.sh` — 6 unit + 3 E2E for the ship gate, 3 frontier-walk + 1 updated guard-rail for promote. Suite now 35 green.
- **Migration:** none for the API; consumers re-sync (`./scripts/sync-method.sh v4.0.0-rc4`) to pick up the gate + promote behavior. Note the two `pk ship` tightenings above when re-syncing.

---

## v4.0.0-rc3 — 2026-06-20

> **Linear MCP tool-name migration.** Every interactive Linear skill called Linear via a snake_case house convention (`mcp__linear-server__{list_issues, get_issue, save_issue, save_comment, list_projects, …}`) that matched **no** installed MCP server. Both consuming projects (SiteLine, Piper) register their Linear MCP as `linear-server` running **`@tacticlaunch/mcp-linear`**, which exposes **camelCase** tools (`linear_searchIssues`, `linear_getIssueById`, `linear_createIssue`/`linear_updateIssue`, …). The mismatch silently broke every interactive Linear call. The high-frequency daily-loop transitions (`pk ship`, `pk done`) were unaffected because they go through `bin/pk`'s direct Linear REST API, not MCP — which is why the break stayed latent until `/linear-hygiene` exercised MCP live (SiteLine, 2026-06-19). This release also promotes the previously-Unreleased `/linear-hygiene` + `/pk-exit` hygiene check into a tagged version.

- **Tool-name migration across 19 interactive Linear skills** (`sync-linear`, `06-linear-todo-runner`, `linear-hygiene`, `02-light-spec-revise`, `spec-preflight`, `00-roadmap-review`, `roadmap-create`, `linear`, `brainstorm-review`, `task-processor`, `startup`, `phase-plan`, `brainstorm`, `01-light-spec`, `work`, `verify`, `review-plan`, `pr-fix`, `10-strategy-sync`). Rename map: `get_issue`→`linear_getIssueById`; `list_issues`→`linear_searchIssues` (filtered) / `linear_getIssues` (connectivity test); `save_issue`→`linear_createIssue` **or** `linear_updateIssue` (split by create-vs-update intent per call site); `save_comment`→`linear_createComment`; `list_projects`→`linear_getProjects`; `get_project`→`linear_getProjectById`; `get_initiative`→`linear_getInitiativeById`; `save_project`/`save_initiative`→`linear_create*`/`linear_update*`; `create_issue_label`→`linear_createTeamLabel`; `list_teams`→`linear_getTeams`; `list_issue_statuses`→`linear_getWorkflowStates`; and `roadmap-create`'s `save_issue`-for-relations → the dedicated `linear_createIssueRelation`. `bin/pk`'s REST path and the `mcp__linear-server__*` wildcard in `Skills_SOP` are untouched; `archive/` and historical CHANGELOG prose left frozen.
- **`sop/Linear_SOP.md`** gains a "Linear MCP Server" section documenting the `@tacticlaunch/mcp-linear` coupling and the snake_case-remote caveat — the portable contract for a project on a different Linear MCP server.
- **New skill `/linear-hygiene`** — a fast, frequent Linear *placement* janitor. Scans all open states for issues that drift in during the daily loop (🏚️ orphaned / no project, 🔶 stuck in Triage, ⚪ unprioritized) and batch-homes them: parent-project inference → keyword match → human pick for ambiguous; importance-aware priority floors (never lowers an existing priority); Triage → Backlog / Needs-Spec mirroring `/brainstorm-review`'s tier routing. Propose-then-apply (one manifest, single `go`). Modes: `default` and `--check` (read-only). Placement only — "where does it belong?", distinct from `/brainstorm-review` (disposition: Now/Later/Kill) and `/roadmap-review` (plan-vs-requirements audit). Payload-safe (minimal fields board-wide, bodies only for the drift subset). VBW-free (does not read `.vbw-planning/`). Live-validated on SiteLine, 2026-06-19.
- **`/pk-exit` hygiene check** — new non-mutating step runs `/linear-hygiene --check` at session close and surfaces drift under "Outstanding / next session" while context is warm. Degrades silently if the skill/Linear MCP is unavailable; preserves pk-exit's no-Linear-writes guarantee (no hook, manual model unchanged).
- **Deferred to a `/linear-hygiene` v2:** 🔗 isolated→relation linking (`linear_createIssueRelation`) and 🧹 stale-label stripping (`linear_removeIssueLabel`) — both tools now **confirmed present** on `@tacticlaunch/mcp-linear`, deferred only to keep this pass scoped to tool-name correctness — plus a `--session` mode (only this session's follow-ups).
- **Migration:** no behavior change; consumers re-sync (`./scripts/sync-method.sh v4.0.0-rc3`) to pick up the corrected tool names. A project on a Linear MCP server other than `@tacticlaunch/mcp-linear` must remap the tool names (see `sop/Linear_SOP.md`).

---

## v4.0.0-rc2 — 2026-06-16

> **De-stale + debrand follow-up to rc1.** rc1 removed the VBW *executor* but left stale references that still routed users to it, plus cosmetic "VBW" branding that no longer matches reality. This pass fixes the wrong-routing bugs and debrands prose where the name isn't load-bearing. **No behavior change to the planning layer** — `.vbw-planning/`, `/vbw:init`, `/roadmap-create`, `/phase-plan`, `/review-plan`, `pk_vbw_*`, and the vbw plugin are all untouched. The brand necessarily persists in the plugin-owned `.vbw-planning/` directory and the `/vbw:*` commands until a separate planning-layer retirement.

- **Executor-stale bug fixes (were misrouting users to removed infra):**
  - `skills/verify/skill.md`: QA + adversarial subagents now use `subagent_type: "general-purpose"` directly (dropped the `Backend`-keyed `vbw:vbw-qa` selection and the `Backend` config read); fallback row no longer names `vbw:vbw-qa`.
  - `skills/pk-bug/skill.md`: dropped the `Backend (vbw or native)` config read and the `vbw-debugger` agent suggestion (now a `general-purpose` debugging subagent).
  - `skills/review-plan/skill.md`: reframed native-first — all 14 `/vbw:vibe --plan/--execute` references now point at `/work`'s inline planning (`.pk-work/<ID>-PLAN.md`) and native execution; legacy `.vbw-planning/phases/` layout still reviewed.
  - `templates/tier-standard.md`, `templates/tier-heavy.md`: execution rows say native `/work` (planning still required; `PLAN.md` at `.pk-work/<ID>-PLAN.md`).
  - `sop/Linear_SOP.md`: `Building` state now correctly attributes execution + QA to native `/work` + `/verify`, not "VBW execution / VBW QA agent". Planning-layer ownership model preserved.
  - `method.md`: "VBW agents read CLAUDE.md / VBW agents execute plans" → "the executor".
- **Debrand (cosmetic):** "VBW SUMMARY" → "planning SUMMARY" (`GUIDE.md`, `sop/Git_and_Deployment.md`); `01-light-spec` "VBW-ingestible" → "plan-ready"; `templates/CLAUDE.md.template` dropped the stale "planning and execution engine" claim (execution is native).
- **Deliberately not touched:** the `## VBW Integration` / `Step 0.5: VBW Init` section headings (named after the real `/vbw:init` command, TOC-anchored, kept in rc1) and `VBW_COMMANDS.md` / `sop/VBW_Help.md` (real planning-command references). Fully removing "VBW" from these requires the deferred planning-layer retirement.
- **Migration:** none. Consumers re-sync (`./scripts/sync-method.sh v4.0.0-rc2`) to pick up the corrected guidance.

---

## v4.0.0-rc1 — 2026-06-15

> **VBW executor removed.** v3.2.0 deprecated the optional `vbw` `/work` executor on production evidence (0/30 recent SiteLine PRs used it); v4.0.0 makes good on the removal. Native-on-Workflow is now the **sole** executor — there is no pluggable backend, no `--backend=` flag, and no `vbw-dev`/`vbw-scout` dispatch in `/work`. This is the breaking change that justifies the major bump: a stale `Backend: vbw`/`auto` in `method.config.md` or a `--backend=vbw` flag now **refuses with a migration message** rather than silently routing. **The VBW *planning* layer is untouched** — `.vbw-planning/`, `/vbw:init`'s roadmap scaffold, `/roadmap-create`'s phase merge, `/phase-plan`, `/review-plan`, and the `pk_vbw_*` roadmap helpers all stay. Retiring the planning layer (and rewriting Stage 0 onto Linear + a native phase surface) is a separate, later effort, deliberately not bundled here.

- **`vbw` executor deleted from `/work`.** `skills/work/skill.md`: removed the Step 5 `vbw backend` dispatch block (the `vbw:vbw-dev` Task), the Step 3 `vbw:vbw-scout` deep-grounding branch (deep now spawns two grounding agents, not three), and the Step 1 backend-resolution logic. Native is the only execution path. `--backend=` with any value, or `Backend: vbw`/`auto` in config, now refuses with a migration message pointing to native. Frontmatter, triggers, tier table, failure model, and the v1-comparison table updated accordingly.
- **`bin/pk`:** `pk doctor`'s Backend default flipped `vbw` → `native`; `Backend` dropped from `pk init`'s required-keys list (vestigial now); the `pk_config` doc-comment example no longer shows the removed `auto`. **Kept:** `pk_vbw_find_plan` / `pk_vbw_finalize_plan` and the `.vbw-planning/` phase/SUMMARY reads in `pk done` — those are Pipekit's roadmap layer, not the executor.
- **`method.config.template.md`:** the `Backend` row is now vestigial (`native` only) — omit it; the rs-vault and Piper examples drop the row.
- **Doc sweep (constitutional + supporting):** `method.md`, `RUNBOOK.md`, `GUIDE.md` (all re-stamped `v4.0.0-rc1`), plus `CLAUDE.md`, `README.md`, `VBW_COMMANDS.md`, `agents/plan-reviewer.md`, and `templates/` (`spec_review_skill.md`, `linear_guidance.md`, `CLAUDE.md.template`) reworded from "vbw-or-native backend" to native-as-sole-executor. GUIDE's "VBW Integration" section reframed as the **roadmap scaffold**; the ownership model's VBW-steering surface drops the executor-dispatch point. Planning-layer references (ROADMAP/PLAN ownership, `/vbw:init`, direct-VBW use) preserved.
- **Migration:** projects on `Backend: native` (or with no Backend row) need no change. Projects still on `Backend: vbw`/`auto` must set `Backend: native` or delete the row — `/work` refuses until they do. VBW stays installed for `/vbw:init`'s roadmap scaffold.

---

## v3.2.0 — 2026-06-13

> **VBW backend deprecated.** The optional `vbw` executor and its complexity-based `auto` router were the last load-bearing remnant of "Pipekit wraps VBW." Production evidence retired both: across the last **30 merged SiteLine PRs, zero used `vbw`** (last `vbw-dev` dispatch was 2026-06-06, before 3.0 made native the default), and the Opus-authored native set shipped **12/13 clean first-pass** with the gate layer — not the executor — catching the one real defect. This corroborates POC-48 round-two (native matched-or-beat VBW-the-full-system on first-pass correctness at ~1/5 wall-clock) and the POC-57 split verdict (native's architecture sound; its only recurring weakness, execution discipline, is exactly what the gate layer backstops). So `vbw` becomes a deprecated legacy opt-in and the `auto` router — which never fired in production — is removed.

- **VBW execution backend deprecated; `auto` router removed.** `/work` is now native-default with `vbw` reachable only via an explicit `Backend: vbw` / `--backend=vbw` (legacy, **removal targeted for v4.0.0**). The complexity-based `auto` backend (`≤3 files + no migration → native, else → vbw`) is **gone** — `--backend=auto` now refuses with a pointer to native/vbw, and `/work`'s Step 3c routing block is deleted. What stays: the `vbw-dev` executor path, the `vbw-scout` deep-grounding (when `vbw` is explicitly chosen), all `agents/vbw-*` files, and the `.vbw-planning/` roadmap scaffold (Pipekit owns the roadmap there regardless of backend) — only the router and default-eligibility are removed. Surface touched: `skills/work/skill.md` (description, `--backend` list, resolution order, refuse list, Step 3c deletion, vbw-dispatch legacy note), `method.config.template.md` + `RUNBOOK.md` (Backend row — the latter also **fixed a stale `vbw` default that should have read `native` since 3.0**), `STARTUP.md`, `method.md`, `GUIDE.md`, `README.md`, `CLAUDE.md`, `VBW_COMMANDS.md` (deprecation banner), and the two `/brainstorm` skills (corrected a stale "Heavy tier → full VBW planning" prescription — heavy now plans inline with forced `--deep` on native). The `auto`-router design spec was archived to `archive/spec-work-auto-backend.md` (superseded).
- **`pk branch` secrets hygiene — 1Password pattern round-trip.** Closes the "promote into Pipekit" item from the SiteLine (POC-85/86) and Piper (WIT-559) 1Password rollouts. `pk_link_env_files` no longer links `.env.prod` into worktrees (root or nested) — prod credentials have no business in a feature worktree; deploys render prod values from the vault. Env linking is no longer silent: `pk branch` now announces every plaintext symlink it creates and names `.env.prod` files it skipped. New `pipekit-security.md` § Secrets Managers and Worktrees codifies the portable contract: committed `op://` reference files travel via git checkout (no linking needed), a reference is not a credential, the op-recipe `.envrc` is config (still linked + direnv-allowed), plaintext symlinking is the legacy fallback, and loaded ≠ valid for write-only secret migrations. Regression coverage added to `scripts/test-pk-env-links.sh`.

---

## v3.1.0 — 2026-06-10

> **Distribution-layer hardening.** A top-to-bottom system review (pipekit ↔ Piper ↔ SiteLine, 2026-06-10) found the method itself healthy but the distribution layer under-protected: `bin/pk` had zero test coverage and its bugs were being found by consumers in production; the sync flagged every project-local skill as "possibly removed" on every run; a consumer could fall releases behind with no signal anywhere; and doctrine still ordered the deletion of a curated roadmap file consumers demonstrably want. This release closes all four.

- **`bin/pk` smoke suite + CI gate** (`tests/pk-smoke.sh`, `.github/workflows/pk-smoke.yml`) — 23 zero-dependency tests (bash 3.2+, git, jq; no bats). CLI tests run pk in a throwaway git repo with a `gh` shim on PATH that logs every invocation, so tests can assert pk *never reached for GitHub*. Covers: config parsing (code-block + legacy table + precedence), dispatch, the per-subcommand `--help` regression, promote guard rails (target resolution/rejection, single-tier no-op), ship preflight, doctor staleness. Out of smoke scope (deliberate): migration-drift heuristic, Linear API paths, worktree lifecycle.
- **fix(pk): `-h`/`--help` after any subcommand prints usage instead of executing.** Subcommand arg loops swallowed unknown flags, so `pk ship --help` actually shipped and `pk next --help` queried Linear (SiteLine, 2026-06-04). A global dispatcher guard intercepts exact `-h`/`--help` args before dispatch; quoted free-text args containing "--help" (e.g. `pk delegate`) don't trip it. Test-first: the 7 regression tests failed before the fix.
- **`pipekit/.local-skills` manifest** — the sync flagged every project-local skill "Possibly Removed/Renamed" on every run (the old check's `grep -qv` against the multi-line skill list was always true, and its `.sync-changelog.md` history fallback became transient when v2.8.0-rc1 gitignored that file). Projects now declare local-by-design skills in a committed manifest (one name per line, `#` comments); declared skills report under "Project-local", undeclared ones flag "Not in upstream (undeclared)" with the exact declare command. Documented in `Skills_SOP.md`. Both consumers seeded (SiteLine #284 — 8 skills; Piper #449 — 9 skills, with the retired-v1 `/end-session` deliberately left undeclared so it keeps flagging).
- **`pk doctor` upstream-staleness check** — compares the synced `PK_VERSION` against the method repo's latest `vX.Y.Z` tag (`git ls-remote`; `Method repo` config key / `METHOD_REPO` env overridable). Behind → warning with the exact update command; unreachable repo → info line only (doctor works offline); rc tags don't count as "latest". Motivation: a consumer checkout sat a full release behind through the 2.8/3.0 cycle with no signal.
- **Curated visual roadmap re-legitimized** (`method.md` header note + ownership table, `pk init` message, `Skills_SOP.md`). v2's NEXT.md retirement over-rotated: it correctly killed the v1 machine-readable mirror but also ordered deletion of the hand-curated visual roadmap consumers actually keep (SiteLine maintains one against doctrine). The two are different artifacts. Doctrine now: a committed human-owned `NEXT.md`/`ROADMAP.md` (phases, themes, standing backlogs) is a first-class *optional* artifact under two rules — skills/agents never write it and never read it as operational state; "what's next?" is always `pk next`. `pk init`'s warning prints the distinction instead of recommending `git rm`.
- **Release-checklist note:** the v3.0.0 unconditional constitutional-stamp rule applied here — `method.md`/`RUNBOOK.md`/`GUIDE.md` all re-checked and stamped v3.1.0.

---

## v3.0.0 — 2026-06-10

**Pipekit 3.0 — native-on-Workflow is the default executor; VBW is an optional backend.** Final cut of the rc1–rc3 cycle. The rc tree ships as-is; final adds only the last documentation carry-overs. The 3.0 arc, by rc (detailed sections below):

- **rc1** — `/work` defaults `Backend:` to `native`; backend dispatch corrected (`/work` plans inline in every backend; `vbw` dispatches only `vbw-dev` — no `vbw-lead`/`vbw-qa`); justified by the POC-48 round-two head-to-head (native matched-or-beat VBW-the-full-system on tier:heavy financial parity at ~1/5 wall-clock and a fraction of the tokens).
- **rc2** — `/pk-bug` branches early (Phases 3+ in the worktree, off the shared integration checkout); Linear review layer backend-agnostic (`templates/linear_guidance.md` + `templates/spec_review_skill.md` v5.2 review for "the planner," upstream of backend dispatch).
- **rc3** — ownership-model `vbw-lead` scrub in `method.md` + `/review-plan`; POC-57 blind A/B verdict committed (split result; reinforces gate-layer-as-safety-net rather than crowning a backend).

### What changed since rc3

- **`GUIDE.md` — completed the `vbw-lead` dispatch scrub** rc3 applied to `method.md` and `/review-plan`. The Stage 2 backend table claimed `Backend: vbw` "spawns `vbw-lead` to generate PLAN.md"; the Plan Review section framed `/review-plan` as running "between `vbw-lead`'s plan generation and `vbw-dev`'s execution" and routing failed plans "back to vbw-lead" — contradicting GUIDE's own (rc2-corrected) VBW Integration section. Corrected to the 3.0 dispatch model, including *why* `/review-plan` matters most on the `vbw` backend (whole plan handed to `vbw-dev` wholesale, no per-task gate) vs `native` (per-task verify-before-integrate is its own plan-safety net).
- **`agents/plan-reviewer.md` — same scrub.** The agent's frontmatter description and Context section framed the pipeline as `VBW Lead → reviewer → VBW Dev` unconditionally. Corrected to the `/review-plan` skill's rc3 provenance framing: the plan comes from `/work`'s inline planning on the `vbw` backend, or VBW's own planner in direct VBW use. Review rubric unchanged.
- **Release-checklist hardening** — the constitutional-doc stamp rule is now unconditional: `method.md` / `RUNBOOK.md` / `GUIDE.md` get stamped every release, edited or not (an unedited bump asserts the doc was re-checked against the release). rc3 shipping while `GUIDE.md` still carried the `vbw-lead` dispatch claim is the failure this closes — the "intended drift signal" reading of a stale constitutional stamp made real drift indistinguishable from convention.
- `PK_VERSION` → `3.0.0`; stamps: `method.md`, `RUNBOOK.md`, `GUIDE.md`, `CLAUDE.md`, `README.md` → v3.0.0; `RUNBOOK.md` sync example → `v3.0.0`.

---

## v3.0.0-rc3 — 2026-06-09

Doc-accuracy follow-up + experiment evidence. **No behavior change** — closes the doc-drift rc1 explicitly deferred, folds the same fix into `/review-plan`, and lands the POC-57 verdict. Carries v3.0.0-rc1/rc2.

- **`method.md` ownership model — scrubbed the last stale `/work`-spawns-`vbw-lead` references** rc1 named as a known follow-up. The Ownership table (PLAN.md-writer + Strategy-docs-reader rows), Rule 5, the VBW-steering-surface list, and the `/review-plan` tooling row still phrased `/work` as dispatching `vbw-lead`. Corrected to match 3.0's dispatch model (already-correct in the Stage 2 text): `/work` plans **inline** in every backend; the `vbw` backend dispatches **only** `vbw-dev`; `vbw-lead` appears only in direct VBW use.
- **`/review-plan` skill — same scrub.** The skill claimed `/work` (vbw backend) "spawns `vbw-lead` to produce `PLAN.md`." Corrected the provenance framing (the plan is `/work`'s inline output on the vbw backend, or VBW's planner in direct VBW use) and clarified *why* the skill is most relevant on the `vbw` backend (the whole plan is handed to `vbw-dev` wholesale, no per-task gate) while `native` needs it less (per-task verify-before-integrate is its own plan-safety gate). Mechanics (file paths, `/vbw:vibe` next-steps) unchanged — the skill is legitimately VBW-oriented.
- **POC-57 native-vs-vbw blind verdict committed** (`experiments/poc-57-backend-ab/`). A blind-judged, reality-grounded A/B on a tier:standard SiteLine feature (client Approve action). Result is a **split** (single pilot rep): native got the architecture right (plain RLS, no SECDEF — matched what shipped) but under-tested it and shipped a forgeable timestamp; vbw was tested + server-bound but violated a DEFINED no-SECDEF decision. **Reinforces the gate-layer-as-safety-net thesis rather than crowning a backend** — and flags native's recurring test-authoring gap, which the gates (run by both backends) exist to backstop. Directional, not co-equal with the POC-48 round-two justification.

---

## v3.0.0-rc2 — 2026-06-09

Bug-workflow and review-layer fixes surfaced by rc1 production runs (SiteLine POC family). Carries v3.0.0-rc1 (native-on-Workflow as the default executor; VBW optional).

- **`/pk-bug` branches early — Phases 3+ run in the worktree, off the shared integration checkout.** Previously Phases 1–4 were *main-anchored*: intake → reproduce → diagnose → the failing test were authored uncommitted on the integration checkout, then a Phase-4 "worktree handoff" did `pk branch` + `git stash`-apply to move the test into the worktree. That occupied the shared `main` working tree through test-authoring and collided with other agents working there. Now: **Phase 2 cuts the worktree the moment the bug reproduces** (`pk branch` off `origin/<integration>`), and diagnosis + the failing test + the fix all run inside it — the test is committed test-first in the worktree (Phase 4), so the fragile stash-handoff and orphaned-on-`main` risk are gone. Reproduce stays on the integration checkout (read-mostly) so an unreproducible bug never spends a worktree. Restructured: Preflight guard (now "don't nest worktrees" instead of "must stay on main"), resume-routing table + heuristics (worktree/test-commit detected earlier), Phases 2–4, and the Invariants table. (Surfaced 2026-06-08: `/pk-bug` on `main` blocked concurrent SiteLine agents.)
- **Linear Agent Guidance → backend-agnostic (v5.2).** `templates/linear_guidance.md` (injected ahead of the Spec Review Agent) no longer names VBW as the execution engine. "VBW is the execution engine" → "Claude Code (`/work`) is the planning + execution engine, native default / vbw optional"; pipeline `… → VBW Plan → Execution` → `… → Plan → Execution` with an inline-planning note; "If VBW would guess → Revise" → "If the planner would guess → Revise". Review philosophy and gates unchanged.
- **Spec Review Agent → backend-agnostic (v5.2).** `templates/spec_review_skill.md` no longer names VBW as the planning engine. The reviewer sits **upstream of backend dispatch** — the spec is reviewed before `/work` runs, and `/work` plans inline regardless of executor (`native` default, `vbw` optional) — so the executor is irrelevant to the review. Replaced every "VBW will/would …" with "the planner …" and added an explicit upstream-of-dispatch note. Gate logic (Problem/Scope/AC, Authority Rule, Decomposition Readiness) unchanged; native's task-DAG + atomic-commit-per-task model only sharpens the existing decomposition/testable-AC bar.

---

## v3.0.0-rc1 — 2026-06-08

**Pipekit 3.0 — native-on-Workflow becomes the default executor; VBW is now an optional backend.**

- **`/work` defaults `Backend:` to `native`** when the config row is unset (was `vbw`). Native executes the inline plan on the Workflow primitive (task DAG in `.pk-work/<ID>-PLAN.md`, atomic commit per task, verify-before-integrate). Set `Backend: vbw` to opt into the VBW executor; `auto` still routes per plan complexity.
- **Doc-drift fix:** corrected the long-standing claim that `Backend: vbw` runs the "full vbw-lead/dev/qa pipeline." It does **not** — `/work` plans inline in *every* backend and the `vbw` backend dispatches only the `vbw-dev` subagent (no `vbw-lead`/`vbw-qa`). The sole difference between backends is the executor. Fixed in `CLAUDE.md`, `method.md`, `method.config.template.md`, `skills/work/skill.md`.
- **VBW reframed as optional, not removed.** Retained as a selectable backend; no deletion. `/work`, `/review-plan`, and the dispatch logic still support it.
- **Justification:** the round-2 head-to-head on POC-48 (tier:heavy financial-parity, JS↔SQL to the cent) — the improved native executor (`feat/native-workflow-executor`: test-first + sequential-default) matched-or-beat VBW-the-full-system on first-pass correctness (native held parity both sides + tested non-zero in-cost; VBW's dev tried to loosen the parity AC and missed the IN-side fold) at **~1/5 wall-clock and a fraction of the tokens** — VBW exhausted ~a weekly token budget on one issue. The deep-analysis safety net is the gate layer (`/financial-review`, `/pr-security-review`), which **both backends run**. Framework + verdict: `experiments/poc-48-roundtwo/`.
- **Known follow-up:** a few lower-traffic `method.md` references (ownership-model lines ~362/377/381, the §208 output note) still phrase `/work` as spawning `vbw-lead` — a deeper doc-accuracy pass tracked for a later rc.

---

## v2.8.0-rc3 — 2026-06-07

> **`/security-review` finding-stage discipline.** Folds review-quality guidance — proven in a downstream project's override — into the portable upstream skill so every project gets it. Skill-only; continues the rc cycle.

- **`/security-review` gains finding-stage coverage + an adversarial verification pass.** Three additions, all stack-agnostic: (1) a "Running this review" preamble (high reasoning effort; dynamic-workflow/`ultracode` fit; **grounded reads** — cite `file:line`, never infer a vuln or an all-clear from a filename); (2) a **finding-stage coverage** rule in the audit step (surface every finding tagged with confidence + severity, do not self-filter — capable models otherwise investigate deeply but under-report); (3) an **adversarial verification pass** after the agents report (try to *refute* each candidate against real auth/RLS/call-sites; mark confirmed/refuted/needs-info; only confirmed + needs-info feed the score). Plus Key Principle #5 (coverage before filtering). Generalized from SiteLine's project-specific override, which is being retired in favor of this upstream version (no more override drift).

> **Reviewer-trigger hardening + `/pk-bug` branch guard.** CI review templates now re-run on every push (self-healing) and carry a loud warning about the workflow-validation 401 that masquerades as a secrets failure; `/pk-bug` refuses to run its main-anchored phases from the wrong checkout. All fixes/docs — no new capability. Continues the rc cycle.

- **`claude-review.yml` + `semgrep.yml` now trigger on `synchronize`** (every push to a Ready PR) in addition to `opened` + `ready_for_review`. A failed review — transient, or the workflow-validation 401 below — now self-heals on the next push instead of forcing a Draft → Ready re-flip to re-trigger. Per-push cost on `claude-review.yml` stays bounded: Draft PRs are exempt (the `triage` job's `draft == false` guard) and the **skip-on-trivial `triage` job** filters doc-only / <5-LOC pushes before the paid review runs. Semgrep is free (Community Rules), so it re-runs unconditionally on non-Draft pushes. Reverses the original `synchronize` omission (Piper WIT-463, 23-commit branch) now that the triage guard absorbs the cheap-push noise — and without it, a one-line workflow-file mistake (SiteLine POC-87) had no automatic recovery path.
- **`claude-review.yml` hardened against the app-token-exchange 401.** `anthropics/claude-code-action` requires the workflow file on a PR to be byte-identical to the version on the default branch — a deliberate guard so a PR can't alter the reviewer that runs with the OAuth secret. Editing the file on a feature branch (even deleting a comment) fails the exchange with `401 Unauthorized - Workflow validation failed`. Added a prominent warning to the template header **and** `templates/ci/README.md`, including the load-bearing detail that `ANTHROPIC_API_KEY: empty` in the log is **normal under OAuth auth and not the cause** — scan for the 401 — plus the one-line restore fix (`git checkout origin/<default-branch> -- .github/workflows/<file>`). Anchor: SiteLine POC-87, 2026-06-07 (first misdiagnosed as a 1Password secret-load failure; the OAuth token had loaded fine).
- **`/pk-bug` checkout guard.** Phases 1–4 are main-anchored: intake → reproduce → diagnose → the *failing regression test* are authored on the integration checkout, uncommitted, before Phase 4's `pk branch` cuts the worktree (off `origin/<integration>`). A test written on any other branch is orphaned by that handoff. Added a preflight guard that **STOPs with a redirect** when the skill is invoked from a feature branch or an existing worktree, with the escape hatch that resuming a past-Phase-4 bug by `<ISSUE-ID>` skips the guard. Phases 5–8 (post-worktree) are unaffected.

---

## v2.8.0-rc1 — 2026-06-06

> **New capability: portable `/financial-review`.** A finance/calculation-accuracy review skill, generalized from SiteLine's project-specific version so any finance project (Piper, SiteLine, other users) gets it via the framework + checks-file split. Plus a sync-noise self-heal. Minor bump for the new skill; cut as a release candidate.

- **New portable skill `/financial-review`** — periodic financial-accuracy review for finance/calculation-heavy projects: cross-layer parity audit (DB view ↔ server/client calc ↔ UI footer; delta > tolerance = finding), baseline tests, parallel sub-agent audit, regression scan, severity-ranked report, and a recurring-WIT Linear lifecycle (In Progress → In Review → Done, transitions by **state name** via `pk` — no hardcoded UUIDs). Generalized from SiteLine's project-specific version using the **framework + checks-file** split: the skill ships the discipline + report shape; each project supplies its concrete checks (test cmd, calc files, DB-integrity SQL, parity formulas) in `resources/financial-review-checks.md`, scaffolded from `templates/financial-review-checks.template.md`. No-op on projects without a checks file. New `method.config.md` keys: `Financial review WIT` (blank disables the Linear lifecycle) + `Financial review checks` (path). Indexed in `Skills_SOP.md`.
- **`sync-method.sh` now gitignores `pipekit/.sync-changelog.md`** (idempotent self-heal). The sync changelog is regenerated on every run, so committing it was pure history noise — it had been landing in consuming-project sync commits. The sync now appends the ignore line to `.gitignore` if missing; the method content itself stays committed (worktrees check out tracked files only, so skills/rules/templates must be tracked — only this transient artifact is ignored).

---

## v2.7.1 — 2026-06-05

> **Merge-driven Linear transition — the real fix for the state-lag gap.** Closes `resources/linear-state-lag.md` item #1, the highest-leverage open item after v2.7.0.

- **`templates/ci/linear-transition.yml`** — a GitHub Action on `pull_request: closed` + `merged` against the integration branch extracts every `<PREFIX>-NNN` from the branch name + PR title + body and advances each issue to the configured `TARGET_STATE` (`In <FirstEnv>` multi-tier, `Done` single-tier) via the Linear GraphQL API — same auth + `workflowStates`/`issueUpdate` shapes as `bin/pk`. Removes the dependency on a human running `pk done` after a GitHub-UI merge, which silently stranded issues in their pre-merge state and made `/strategy-sync` under-report shipped work (bit three consecutive runs). Idempotent (skips a WIT already at target — harmless alongside `pk done`) and forward-only (a configurable `PRE_MERGE_STATES` allowlist means it never pulls a promoted/`Done` WIT backward and never leap-frogs an Approved WIT that bypassed UAT). PR-supplied text is passed via `env`, never interpolated into the shell (injection-safe); portable to bash 3.2+.
- **Live-validated on SiteLine (2026-06-05):** a real `POC-NNN` WIT in `UAT`, merged via a real PR, transitioned to `Done` by the workflow in CI, with the idempotent skip confirmed on a second pass.
- **Documented the relationship with Linear's native GitHub integration** (`templates/ci/README.md`). The native integration overlaps but can't respect Pipekit's state ladder — the SiteLine test caught it pulling a WIT `UAT → In Progress` (backward) on PR-open. Recommended posture: single-tier projects may leave native on (this workflow is then a harmless idempotent net); multi-tier projects should turn native **off** and use this workflow per hop (it's ladder-aware and forward-only). The original lag was on a multi-tier project — native's exact blind spot.
- Known limitations (tracked in the source doc): commit messages are not yet parsed for IDs (only branch + title + body); one workflow watches one hop (downstream promote hops need a sibling file or stay on `pk promote --finish`).

---

## v2.7.0 — 2026-06-05

> **The enforcement-substrate release, stabilized.** v2.7.0 hardened the gates that protect a ship — `/verify` and `/pr-fix` stop punting judgment back to the human and instead carry a verdict — and added `/pk-express`, an idea→Draft-PR autopilot for simple WITs. This final tag is the rc6 tree with no new behavior: the last gate before cutting was re-validating the portable `/pr-fix --engine=builtin` fallback (the engine every consuming project without the `pr-review-toolkit` plugin lands on), which passed end-to-end including the rc3 historical finders (git-history + prior-pr-comments) firing in the builtin path.

The 2.7.0 arc, by release (detailed sections below):

- **rc1** — discipline substrate, source-authority hierarchy, evidence-gated `/verify`, `pk ship` hard-fail on missing `verify-complete.md`.
- **rc2** — pluggable-engine `/pr-fix` (pr-review-toolkit agents by default, built-in fallback) + two-axis severity×confidence triage; Opus 4.8 framing audit (Fresh-Chat → stage-isolation).
- **rc3** — `/pr-fix` dependency-free historical finders (git-blame regression + prior-PR-comment reapplication); `/pipekit-update` Phase P (pr-review-toolkit as a managed dependency); first Linear-state-lag fixes.
- **rc4** — `/verify` migration flag self-reviews via subagent (Hold/Approve verdict, not a raw `git show`); `pk branch` auto-discovers and symlinks nested per-app env files into worktrees.
- **rc5** — `pk doctor` false-ship cross-check; completed `pk done` finish (parent-branch reset, stack advisory, script-deploy `Deploy command` reminder); migration pre-merge re-check; discipline lines.
- **rc6** — `/pk-express` idea→Draft-PR autopilot (tier-guarded; quick/standard only), validated live on SiteLine POC-14; load-bearing `/light-spec` fix (publish to configured `Spec ready state`, not hardcoded `Specced`); `pipekit-cmux` turn-end-detection lesson.

### What changed since rc6

- `PK_VERSION` → `2.7.0`; CHANGELOG `Unreleased` finalized into this section; `CLAUDE.md` + `RUNBOOK.md` stamps and the `sync-method.sh` example bumped to `v2.7.0`.
- Re-validated `/pr-fix --engine=builtin` (the rc2 restructure + rc3 historical-finder widening) — PASS. No code change; the gate that was blocking the final tag is cleared.
- **Documentation content pass** — brought the constitutional + reference docs current with the whole rc3→rc6 feature set (they had lagged at rc2/older): `GUIDE.md` and `method.md` (→ v2.7.0) now document `/pk-express`, the `/pr-fix` pluggable engine + historical finders, `/verify` migration self-review verdict, `pk branch` nested env symlinks, `pk doctor` false-ship check, `pk done` rc5 finish, `/pipekit-update` Phase P, and `/light-spec`'s configured `Spec ready state`; `sop/Skills_SOP.md`, `sop/Linear_SOP.md` (tier labels), `STARTUP.md` (V2 config-key reference), and `README.md` updated to match. `method.md`/`GUIDE.md` stamps move rc2 → v2.7.0; `method.config.template.md` left unstamped (content already complete — the version gap is the intended drift signal).
- **Full-release drift sweep** — ran `drift-check.sh` + five parallel deep audits across every template, SOP, skill, CI/config template, and a cross-cutting consistency pass. Fixes: `agents/plan-reviewer.md` referenced the retired v1 `/launch` as its invoker (→ `/review-plan`); `skills/06-linear-todo-runner/skill.md` hardcoded the `Specced` overflow-fetch state (→ configured `Spec ready state` — the same two-state-board bug the rc6 `/light-spec` fix closed); `skills/verify/skill.md` dropped a phantom `/pk-compound` forward-ref; `templates/strategy/design-direction.md` de-pinned two `Opus 4.7` model references to be model-agnostic; `sop/Session_Management_SOP.md` stamp rc2 → v2.7.0 (content was already final). The remaining drift-check hits are illustrative example paths and correctly-labelled v1-historical mentions, left as-is.
- **Positioning** — `README.md` gains a "Why Enforcement, Not Memory" section making the enforcement-over-persistence thesis legible: Pipekit bets on independent-judgment gates, not context persistence, because confident-wrong output scales with model capability while a larger window does not make an agent able to review its own work.

---

## v2.7.0-rc6 — 2026-06-03

> **`/pk-express` — an idea→Draft-PR autopilot for *simple* WITs.** Takes an existing brainstormed WIT (or a raw idea) and drives it through the four stages that already self-drive — `/brainstorm` → `/light-spec` (auto-cycle to Approved) → `pk branch` → `/work` (auto verify + ship) — advancing on each stage's success signal and stopping only at genuine attention gates. Quick/Standard tier only; refuses heavy work. Validated end-to-end on a live SiteLine WIT (POC-14): it correctly split off the heavy half as a follow-up, drove the simple half to a merged PR, and stopped at the tier guard the first time around.

### What changed

**`/pk-express` idea→PR autopilot** (`skills/pk-express/skill.md`, indexed in `Skills_SOP.md` + `CLAUDE.md`)
- New orchestrator skill. `/pk-express <ISSUE-ID>` (primary) takes a brainstormed WIT to a Draft PR; `/pk-express "<idea>"` prepends brainstorm. Resume routing reads the issue's Linear state and joins at the right stage.
- **Auto-advances** on success signals (brainstorm Now, spec Approved, branch ok, verify Pass+0-flags) and **stops + notifies** at exactly five gates: brainstorm not-Now, **`tier:heavy` (refuses heavy)**, spec stalemate, `/verify` flags, and the Draft-PR/UAT handoff. Never runs `pk ready`/`pk done`/`pk promote`.
- Express mode collapses only the low-judgment friction (between-stage typing, the Now/Later/Kill prompt, spec passes 2–3); the `/verify` gate and human PR/merge gates stay intact.
- Handles the **Quick→Approved spec-skip path** (a Quick item brainstorm sends straight to Approved skips the spec stage).

**`/light-spec` publishes to the configured `Spec ready state`, not hardcoded `Specced`** (`skills/01-light-spec/skill.md`)
- `/light-spec` hardcoded moving the issue to `Specced`, but `pk spec-cycle`'s entry precondition is config-driven (`Spec ready state`) — two halves of one interlock, only one read config. On a board without a `Specced` state (e.g. SiteLine's Piper-poc: `Needs Spec → Approved`), `/light-spec` tried to set a nonexistent state and broke the cycle. Now it publishes to the configured ready state (default `Specced` — no change for canonical boards), so the interlock holds on any workflow. The skill's own line 239 already stated this intent; the implementation now matches.

**`pipekit-cmux`: watch worker turn-end, not narration keywords** (`templates/rules/pipekit-cmux.md`)
- New orchestration subsection + anti-pattern: when master control watches a worker Claude via `read-screen`, detecting gates/completion by grepping for keywords false-fires on the worker *narrating its own plan*. Detect the **turn ending** (live present-tense spinner gone across 2 polls — never the past-tense completion marker) or wire `Stop`/`Notification` hooks to `cmux notify`. Earned watching the `/pk-express` validation run.

---

## v2.7.0-rc5 — 2026-06-03

> **Log-mining release: ten fixes surfaced by Piper + SiteLine session logs.** The dominant signal across both projects was *"Done" overstating reality* — issues marked built/shipped that git never built, and merges that never deployed. rc5 adds a `pk doctor` integrity check for the false-ship case, completes `pk done`'s finish (process/branch teardown + a deploy reminder for script-deploy projects), hardens migration pre-merge coordination, and adds four discipline lines. (The SHA-aware `verify-complete.md` gate was scoped out — it's a behavior change, deferred to its own cut.)

### What changed

**`pk doctor` flags false-ships via Linear↔git cross-check** (`bin/pk`, `scripts/test-pk-doctor-integrity.sh`)
- New testable helper `pk_git_build_evidence` (`built | docs-only | none`) plus a `pk doctor` section: for WITs the board calls UAT/Done, confirm git history on the integration branch actually contains implementation referencing the id. No commits — or only docs commits — flags a likely false-ship. The leading-direction mirror of `/strategy-sync` 4b (which catches merged-but-not-Done). Advisory + heuristic (assumes commits reference the WIT id); surfaces candidates, never hard-fails.

**`pk done` finish completed** (`bin/pk`, `method.config.template.md`)
- **Deploy reminder** (new optional `Deploy command` config): for script-deploy projects where `pk promote` is disabled, `pk done` surfaces the deploy command after merge so "merged ≠ deployed" can't pass silently. Advisory — never auto-runs a deploy.
- **Parent-branch reset:** when the parent repo is sitting on the just-merged feature branch, `pk done` returns it to the integration branch (clean-tree guarded) before deleting — you can't delete the branch you're on, and parking there was recurring friction.
- **Stack advisory:** notes that a worktree's local Supabase stack / dev server keeps running after teardown (`pk done` won't stop it — may be shared).
- **Softened migration check:** the post-merge "not on remote" check is now an explicit advisory that notes a collision-rename can cause a false mismatch (ground truth: `supabase migration list` / the live DB), instead of a bare scary warning.

**Discipline rules — four log-mined additions** (`templates/rules/`)
- `pipekit-migrations`: re-check migration timestamps against the base-branch tail right *before merge*, not only at creation (long-lived branches get overtaken; the collision is invisible in the worktree).
- `pipekit-cmux`: when a worker surface ref goes stale, treat git/Linear/`gh` as ground truth instead of polling a dead pane.
- `pipekit-discipline`: red flag — a vendor-UI affirmative state (green check, "disabled") is a claim to verify, not evidence of effect.
- `pipekit-tooling`: project-critical MCP servers must live in committed `.mcp.json`, or they're invisible inside `pk branch` worktrees.

---

## v2.7.0-rc4 — 2026-06-02

> **Two gates stop punting work back to the human.** `/verify`'s migration flag used to hand the user a raw `git show` to review themselves — it now runs the migration rubric in a subagent and carries a Hold/Approve **verdict** the user approves. And `pk branch` only ever symlinked root-level env files, so monorepo worktrees came up reading the `*.example` placeholder with no real backend — it now auto-discovers and links nested per-app env files too. Carries forward the rc3 `/pr-fix` historical finders and `pr-review-toolkit` managed dependency.

### What changed

**`/verify` migration flag now carries a verdict, not a bare pointer** (`skills/verify/skill.md`)
- Step 6 Flag check A previously detected migration files in the diff and surfaced a bare `FLAG: … review for irreversibility, RLS, search_path` — handing the user a raw `git show` to review themselves, the exact analysis the skill exists to perform. It now spawns a review subagent (`pr-review-toolkit:code-reviewer`, fallback `general-purpose`) that applies `/pr-security-review`'s migration rubric (M1–M8, plus the RLS / SECURITY DEFINER / GRANT rubrics when the diff body contains those patterns), writes `migration-review.md`, and the flag carries the resulting **Hold/Approve verdict**. `reality-check.md` gained a `## Migration review` section that inlines it.
- Runs on **every tier** (migrations are high-stakes regardless of tier) and is complementary to Step 5's generic antagonistic pass — that lens finds "what's wrong"; this one returns a structured verdict against named rubric IDs.
- A `Hold` verdict pauses auto-ship via the flag but does **not** auto-downgrade `/verify` status to NEEDS WORK — consistent with how antagonistic findings and every other flag behave; classification stays the user's RECONCILE step. The human gate is unchanged in spirit (migrations always pause for a human eye), changed in substance: the user now approves `Hold: M3 missing backfill` or `Approve — no findings` instead of a `git show` they were never positioned to act on.

**`pk branch` now symlinks nested per-app env files into the worktree** (`bin/pk`, `scripts/test-pk-env-links.sh`)
- `pk branch` symlinked only a hardcoded **root-level** env list (`.env .env.local .envrc …`). In a monorepo, the browser client reads `apps/web/.env.local` — which is gitignored, so a fresh worktree never had it and fell back to the `*.example` placeholder (`NEXT_PUBLIC_SUPABASE_URL=your-project.supabase.co`), leaving the app with no real backend to talk to.
- Extracted the linking into a testable `pk_link_env_files` helper and added pass (2): auto-discover every real nested env file (`.env` / `.env.local` / `.env.dev` / `.env.prod`) in the parent and symlink it at the same relative path. Exact-name match (never `*.example`), pruning `node_modules` / `.git` / `.worktrees`. Idempotent; never clobbers a real file already in the worktree.
- **Auto-discover, not config:** a `method.config.md` env-link list was considered and rejected — the failure was that the need was *implicit* and nobody enumerated it; a config list reintroduces the same "forgot to configure it" footgun. Discovery mirrors parent reality with zero setup, so new monorepo apps are picked up automatically.
- **Recovery for existing worktrees:** the worktree-exists path in `pk branch` falls through to the symlink step, so re-running `pk branch <ID>` (idempotent) backfills the missing links into a worktree created before this fix.
- New `scripts/test-pk-env-links.sh` exercises the real helper (sources `bin/pk`): real-value link, `.example` exclusion, nested depth, `node_modules` prune, idempotency, no-clobber.

**`/strategy-sync` fresh-chat → stage-isolation framing** (`skills/10-strategy-sync/skill.md`)
- Aligned the fresh-chat requirement with v2.7.0-rc2's `method.md` stage-isolation reframe: clarified it's *deliberate isolation* (an agent that watched the build can't independently diff shipped-reality vs. the docs), **not** a context-window workaround — a 1M window doesn't relax it because the risk is contaminated judgment, not lost memory. Wording only, no behavior change. Surfaced by the Opus 4.8 rollout review.

---

## v2.7.0-rc3 — 2026-05-31

> **`/pr-fix` gains temporal signal; `pr-review-toolkit` becomes a managed dependency.** rc2 made `/pr-fix`'s native engine the `pr-review-toolkit` specialists — but those agents only ever see the diff. rc3 adds two dependency-free **historical finders** that read *how the code got here* and *what reviewers already said*, running alongside the specialists in the same parallel wave. Separately, the plugin dependency rc2 introduced was being borrowed from a project-local install on an unrelated repo; rc3 promotes it to a user-scope managed dependency and teaches `/pipekit-update` to keep it current.

### What changed

**Historical finders in `/pr-fix`** (`skills/pr-fix/skill.md`)
- Two new dependency-free finders (`git` + `gh` only) join the native fan-out (§3.1), **alongside** the toolkit specialists — peers, not a pre-pass:
  - **git-history** — `git blame`/`git log` on modified+deleted line ranges. Flags (a) changes that regress a recent deliberate bugfix (cites the prior commit sha), (b) removed guards whose blame points to a fix/incident commit, (c) high-churn fragile regions needing extra test coverage.
  - **prior-pr-comments** — pulls review comments from recently-merged PRs that touched the same files and flags any that **reapply** to the current diff (confidence ≈70 — past feedback is a lead, not proof).
- Because they need no plugin, they also run in the `--engine=builtin` path (§3.2).
- New dedup rule §4.1.5 **Historical corroboration**: a historical finder matching a specialist *raises* that finding's confidence (+10, cap 99) instead of being dropped — recurrence-is-a-reality-signal applied across finders, not just across `--runs`.
- Ordering rationale recorded: running the finders *first* to prime the specialists was considered and rejected for this cut — it serializes the wave for marginal gain, and the corroboration rule already captures most of the benefit.

**`pr-review-toolkit` as a managed dependency** (`skills/pipekit-update/skill.md`)
- New **Phase P — Ensure Plugin Dependencies**, routed through *both* upstream (Pipekit repo) and downstream (consuming project) modes. It installs/updates `pr-review-toolkit@claude-plugins-official` at **user scope** via the `claude plugin` CLI. Plugins are not files `sync-method.sh` can copy — they live in `~/.claude/plugins/` — so Phase P calls the CLI directly; it touches harness config, never project files.
- If the `claude` CLI is absent (e.g. a CI runner), Phase P skips with a printed note — `/pr-fix --engine=builtin` remains the dependency-free fallback. Project-scope documented as the alternative for teams wanting the dependency to travel reproducibly with a repo.

**Linear-state-lag fixes** (`bin/pk`, `skills/10-strategy-sync/skill.md`)
- Surfaced by a Piper handoff (`resources/handoffs/Handoff-Pipekit-Linear-State-Lag.md`): post-`pk ship` Linear transitions are command-driven, not merge-driven, so a merged PR can leave its issue stranded in UAT — under-reporting shipped work to `/strategy-sync`. Verified against the code: `pk promote --finish` already transitions every bundled WIT and fails loud, but `pk done` transitioned a single issue and swallowed the failure with `|| true`.
- `pk done` now **fails loud** on a failed UAT→In <Env> transition — it warns that the issue is stranded but continues worktree cleanup (the merge already succeeded; hard-failing post-merge would strand the worktree, which is worse).
- `/strategy-sync` Phase 1 gains a **mandatory merged-PR cross-check** (§4b): diff merged PRs on the integration branch against the Linear `Done` set and treat any merged-but-not-Done issue as shipped. Ports the guard Piper carried locally into the canonical skill so every project inherits it. The deeper root-cause fixes (a merge-driven transition Action; bundled-WIT parsing in `pk done`) remain a scoped follow-up.

> **Release note:** stamped `CLAUDE.md` + `RUNBOOK.md` to `v2.7.0-rc3` (RUNBOOK has no daily-flow change — only the sync example + stamp); `method.md` / `GUIDE.md` left at their prior stamps (untouched this cut — the gap is the intended drift signal). Bumped `PK_VERSION` and the RUNBOOK sync example. **Operational note for this machine:** `pr-review-toolkit` was re-homed from a `local` install on the SiteLine project to a `user`-scope global install, so Pipekit (and every other project) no longer borrows another repo's plugin registration. The synced skill changes are portable; the plugin re-home is environment state, not shipped content.

---

## v2.7.0-rc2 — 2026-05-31

> **Opus 4.8 framing audit — docs reframed, one handoff slimmed, nothing lost.** An impact audit of Pipekit's artifacts against Opus 4.8 (1M context window + harness-persistent memory) found that the persistence layer those capabilities would obsolete was *already pruned in the 4.7 cycle* (`NEXT.md` retired v2.1.0, bash Stop hook retired, `Session_Management_SOP.md` already 1M-aware). No artifact was REDUNDANT-delete. The real finding was framing rot: a few docs still justified discipline as a small-window workaround. These edits correct the *why* without changing the rule, refresh the external prompt-engineering snapshot to 4.8, codify a durable-vs-ephemeral split for handoff docs (git history holds any removed runbook), and harden `pr-fix` against 4.8 recall loss (the one enforcement skill that suppressed findings at the find stage).

### What changed

**Stage isolation decoupled from context scarcity** (`method.md` § Fresh-Chat Discipline)
- Reframed the section's core: the load-bearing principle is **stage isolation** (an agent can't independently review work it helped produce), not "start fresh because the model forgets." Added an explicit paragraph that this is *not* a context-window workaround — the 1M window + harness memory do not relax it, because the risk is **contaminated judgment, not lost memory**. Named the two mechanisms (hands-on fresh chat / by-construction subagent spawning) as interchangeable deliveries of the same isolation. Header name kept to preserve ~10 live `§ Fresh-Chat Discipline` cross-references (GUIDE.md + 5 skills).

**Session boundaries reframed as cognitive-load hygiene** (`sop/Session_Management_SOP.md`)
- Added explicit "session boundaries exist for cognitive load, not token scarcity" framing, distinguishing these *optional* hygiene boundaries from the *mandatory* stage-isolation gates in `method.md`. De-versioned two unverifiable behavioral claims (subagent-default rate; effort-tier defaults) — kept the durable guidance, flagged the effort table as "calibrated on 4.7, re-validate." Bumped the source attribution 4.7 → 4.8.

**Scope-guidance de-versioned** (`sop/Skills_SOP.md`)
- Generalized the "Writing Skill Prompts for Opus 4.7" subsection to be model-agnostic — literal-instruction-following guidance is durable prompt hygiene, not a 4.7-specific trait. Model-pinning section left unchanged (a cost/capability tradeoff independent of context size).

**Anthropic prompt-engineering snapshot refreshed to 4.8** (`sop/Anthropic - Prompting best practices.md`)
- Re-fetched the live published doc (snapshot date → `2026.05.31`); upstream had been restructured to lead with a `Prompting Claude Opus 4.8` section plus updated model strings. This is a verbatim external snapshot (not a Pipekit-stamped doc), so it was refreshed by re-fetch — never hand-edited. Surfaced two Pipekit-relevant facts: (a) `xhigh` remains Anthropic's recommended default for coding/agentic on 4.8; (b) a new "Code review harnesses" caveat — 4.8 obeys "only report high-severity" instructions more faithfully, lowering *measured* recall unless review prompts say "report everything, filter downstream."

**Handoff & session-log content discipline codified** (`sop/Session_Management_SOP.md`, `resources/nebula-piper-pipekit-v2.5.0.1-handoff.md`)
- New section splitting handoff/log content into **durable** (decisions, caveats, lessons, gaps — keep) vs **ephemeral** (step-by-step state recaps — now carried by Linear + harness memory). Retrofitted the v2.5.0.1 Piper migration handoff as the worked example: a ~430-line Step 0–7 runbook slimmed to a one-page durable record (F-caveats + the `Withpiper` team-name footgun + gaps), with the procedural body preserved in git history.

**Enforcement-layer recall audit + `pr-fix` fix** (`skills/pr-fix/skill.md`)
- Audited the four enforcement surfaces (`pr-fix`, `security-review`, `verify`, the DOUBT loop) against the refreshed Anthropic doc's new "Code review harnesses" guidance — 4.8 obeys "be conservative / only report high-severity" instructions more faithfully, investigating as deeply but converting *fewer* investigations into reported findings. Result: the DOUBT loop (`pipekit-discipline.md`), `security-review`, and `verify` already follow the "coverage at finding, filter downstream" pattern — no change needed. `pr-fix` was the outlier: it discarded sub-80-confidence findings *at the finding stage* (§3.3) with "silence is better than noise," which on 4.8 biases the self-assigned confidence score downward and silently drops real bugs.
- Fix: decoupled finding from display. §3.3 now mandates coverage-first honest scoring with no self-censoring; the `>= 80` threshold became a Phase-4 **display** filter; sub-80 findings are retained in a collapsed "below threshold" coverage list instead of discarded. The clean-by-default precision UX (only `>= 80` shown up front) is unchanged. Reframed the §8 intro and Calibration rule 1 from "precision over recall / zero noise" to "coverage when finding, precision when displaying."

**`/pr-fix` review engine made pluggable + two-axis triage** (`skills/pr-fix/skill.md`)
- Born from the audit's `/pr-fix` vs `pr-review-toolkit:review-pr` comparison on Piper PR #408: a properly-configured native toolkit run matched or beat `/pr-fix`'s built-in review on depth, but `/pr-fix` owns the parts review-pr lacks (intent + cross-spec handoff scan, dedup, interactive fix, Linear/pipeline integration). Rather than retire either, `/pr-fix` Phase 3 is now **engine-pluggable** (mirrors `/work`'s backend model): default `native` fans out the `pr-review-toolkit` specialist agents (code-reviewer, silent-failure-hunter, pr-test-analyzer, …) as read-only subagents; `--engine=builtin` runs the original reference-file dimensions with zero plugin dependency. **Fail-loud** if the plugin is absent (no silent downgrade) — `--engine=builtin` is the escape hatch. One invocation, native engine, /pr-fix's remediation.
- **Two-axis triage replaces the single confidence threshold.** Severity (impact) and confidence (likelihood) are now kept independent — `severity=Critical, confidence=20` is valid and surfaces. New **INVESTIGATE** quadrant (high severity, low confidence): surfaced up top, never auto-fixed. Surfacing rule = `confidence ≥ 80 OR severity ≥ High`; ordering = severity-dominant priority (`0.7·severity + 0.3·confidence`); below-threshold collapsed list = low-severity *and* low-confidence only. Fixes the morning's edit's blind spot — the PR #408 fail-open guard (Critical/78) now surfaces instead of sitting below an 80 line. `--quick` auto-fixes the FIX quadrant only.
- New flags: `--engine=native|builtin`, `--runs=N` (recurrence across runs raises confidence). `--from-review` now explicitly composes as a merge source — including ingesting a `pr-review-toolkit` run that already posted.

> **Release note:** stamped `method.md` / `GUIDE.md` / `CLAUDE.md` / `RUNBOOK.md` (constitutional, +`HH:MM`) and `sop/Session_Management_SOP.md` / `sop/Skills_SOP.md` to `v2.7.0-rc2`; bumped `PK_VERSION` and the RUNBOOK sync example. **Native `/pr-fix` engine adds a `pr-review-toolkit` plugin dependency** (Anthropic first-party, Apache-2.0, actively maintained — repo pushed 2026-05-31, plugin last touched 2026-04-28). Not carried by `sync-method.sh`; consuming projects must install the plugin for `--engine=native`, and `--engine=builtin` is the dependency-free path. The `/pr-fix --engine=native` flow was smoke-tested end-to-end against Piper PR #408 this cycle.

---

## v2.7.0-rc1 — 2026-05-25

> **Release candidate: discipline substrate + evidence-gated `/verify` + `pk ship` hard-fail.** Week 1 lays the rules substrate that the rest of v2.7 leans on (Completion Claims doctrine, two-tier Plan Gate, source-authority hierarchy, trigger-phrased skill descriptions). Week 2-3 rewrites `/verify` to write a per-issue evidence layer (`evidence.txt` with per-command anchors, `reality-check.md`, `verify-complete.md`) and wires `pk ship` to hard-fail on missing `verify-complete.md` for `tier:standard | tier:heavy`. Antagonistic review is mandatory for `tier:heavy` and opt-in via `--review` for `tier:standard`, using the verbatim DOUBT prompt from `pipekit-discipline.md`. RC because Week 4 (`/pr-fix` full subagent dispatch + cross-persona promotion) is still ahead; ship to consumers when Week 2-3 validation completes on Pipekit-the-repo.

### What changed

**Discipline substrate** (`templates/rules/pipekit-discipline.md`, `templates/rules/pipekit-tooling.md`, `sop/Skills_SOP.md`, `templates/CLAUDE.md.template`)
- **Completion Claims doctrine.** New H2 section in `pipekit-discipline.md`: CLAIM → EXTRACT → DOUBT → RECONCILE → STOP loop with verbatim adversarial subagent prompt. RECONCILE precedence: AC misread → Valid actionable → Valid trade-off → Noise. Doubt-theater red flag at 2+ cycles with substantive findings but zero actionable.
- **Plan Gate two-tier.** Inline form (`PLAN: 1. … 2. … 3. … → Executing unless you redirect.`) for small/single-module changes; Expanded 5-bullet form for cross-module/new-surface/multi-file. Replaces the prior single 5-bullet ad-hoc gate.
- **Source Authority Hierarchy.** New subsections in `pipekit-tooling.md`: Tier 1 official docs + installed source under `node_modules/<pkg>/` is ground truth; Tiers 2-4 vendor changelogs / web standards / runtime tables are authoritative for their scope; StackOverflow / third-party blogs / AI-generated examples / training data are leads not facts. UNVERIFIED flag pattern when no Tier 1-4 source available.
- **Enumerate the Surface Before Claiming Behavior** (`pipekit-tooling.md`). Sibling rule to source authority: before claiming what CI/infra does, `ls` the full surface (workflows, migrations, env files, scripts) — never reason from a single known file. Case study from 2026-05-25: a session knew about `supabase-production.yml` (beta-merge trigger) and confidently advised the user that dev-merge wouldn't auto-apply a migration, missing that `supabase-dev.yml` existed and DID fire on dev-merge. The advisory cost ~5 min of manual verification that was already done by CI. Six concrete enumeration commands documented per claim category (workflows / migrations / env vars / scripts / rules / skills).
- **Skill frontmatter conventions** in `sop/Skills_SOP.md`: trigger-phrased descriptions (pack `Use when X. Use when Y.` into the `description:` field — this is the surface Claude scans for auto-invocation) + `disable-model-invocation: true` for prompt-only skills (`/pk-exit`, `/concept`, `/define`).
- **`resources/solutions/` routing pointer** in `templates/CLAUDE.md.template` — placeholder for Phase 2's `/pk-compound` bug-track corpus.
- **30 skill descriptions** updated to trigger-phrase format. Verification: `grep -E '^description:' .claude/skills/*/skill.md | grep -v 'Use when'` returns only intentional exemptions (`/pk-exit`, `/pk-bug`).

**`/verify` full rewrite** (`skills/verify/skill.md`)
- **Tier-aware dispatch.** Step 0.5 one-screen contract: `quick` is virtual (stdout only, no file writes); `standard` writes the evidence layer; `heavy` adds mandatory antagonistic review.
- **Evidence artifact layer.** For `TIER != quick`, every run produces three files under `Logs/Verify/<YYYYMMDD>/<ISSUE>/`:
  - `evidence.txt` — per-command `==> $ <cmd>` header, tee'd stdout/stderr, `exit:` + `duration:` trailers. Flag-enumeration appends `FLAG: ...` lines. Per-command structure enables anchor cites as `evidence.txt:L<line>`.
  - `reality-check.md` — gate-results table with anchors, inlined `qa-verdict.md` (Step 4) + `adversarial.md` (Step 5), flags surfaced, status reasoning, next actions.
  - `verify-complete.md` — minimal sentinel (issue, stamp, tier, status, sha) written **only on PASS**. Stale sentinels are explicitly removed on NEEDS WORK so `pk ship`'s gate cannot trust a stale file.
- **QA verdict via Write tool.** Subagent is configured with `allowed-tools: Read, Bash, Write` and writes its verdict block to `$VERIFY_DIR/qa-verdict.md` directly. Returns a one-line confirmation. Removes parent-side parsing. Anchor-emit discipline: cite sources as `<file>:<line>`, gate output as `evidence.txt:L<line>`.
- **Step 5 antagonistic review.** New subagent dispatch using the **verbatim** DOUBT prompt from `pipekit-discipline.md`. Mandatory for `tier:heavy`. For `tier:standard`: auto-fires on **sensitive-path diffs** (paths matching `supabase/migrations/`, `/auth/`, `/middleware\.`, `/rls\.`, `/policies\.` or diff content matching `SECURITY DEFINER` / `GRANT EXECUTE` / `REVOKE EXECUTE` / `CREATE POLICY` / `ALTER POLICY`); otherwise opt-in via `--review`. Skipped for `tier:quick`. Patterns mirror Week 4's `/pr-fix` design. Writes findings to `$VERIFY_DIR/adversarial.md`. Findings do NOT auto-downgrade status — classification (AC misread / actionable / trade-off / noise) is the user's RECONCILE call, not the subagent's.
- **Flag check E** added to Step 6 enumeration: antagonistic findings count surface as flags, pausing auto-ship per the load-bearing F6 rule. Existing Step 3.5 (now Step 6) flag logic and Step 4 (now Step 9) auto-ship behavior preserved verbatim.

**`pk ship` verify-complete.md gate** (`bin/pk`)
- New `pk_linear_tier` helper queries the issue's Linear labels for `tier:(quick|standard|heavy)`, defaults to `standard` on miss/error so the gate stays operative when Linear is unreachable.
- After issue extraction (~line 1090 of `cmd_ship`), before `git push`: read `Logs/Verify/<YYYYMMDD>/<ISSUE>/verify-complete.md`. Missing file → `return 1` with the expected path printed.
- Three escape hatches: `--force` (parsed in `cmd_ship`; bypass + Linear comment audit trail via `pk_linear_comment`); `PK_VERIFY_BYPASS=1` env var (emergency bypass + `Logs/Verify/bypass.log` entry); `tier:quick` (warn + proceed, virtual gate by design).
- Shipped in two atomic commits (warn-only then hard-fail flip) for bisect-clean rollback.

**`/light-spec` tier auto-derive** (`skills/01-light-spec/skill.md`)
- New Phase 3.6 parses the spec body's `**Complexity:**` field and maps it to a `tier:*` Linear label: `Trivial | Low → tier:quick`, `Medium → tier:standard`, `High | Very High | Critical → tier:heavy`. Hour-range fallback when no named token present (`≤4h → quick`, `5-11h → standard`, `≥12h → heavy`).
- Phase 5's Linear save merges existing labels (stripping any stale `tier:*`) with `spec` + the Phase 3.6-derived tier. Custom human-applied labels (`Feature`, `Finance`, domain tags) survive the publish.
- Closes the spec-author-classified-as-Heavy-but-the-label-says-otherwise gap surfaced by WIT-419 (spec body said `Complexity: High (~16-22h)` but the Linear label was `Heavy`, not `tier:heavy` — `pk_linear_tier` defaulted to `standard` instead of recognizing the intent).

**`PK_VERSION`** 2.6.0.1 → 2.7.0-rc1.

### Why

The catalog audit (multi-day external review of `shanraisshan/claude-code-best-practice`, deep-dives into `addyosmani/agent-skills`, `msitarzewski/agency-agents` Testing division, and `EveryInc/compound-engineering-plugin`) surfaced one convergent gap: **artifact-gated review that the model cannot persuade its way through**. Pipekit's prior `/verify` was persuasion-based prose — the LLM decided whether to comply. v2.7's evidence layer turns review into an artifact chain with explicit stop conditions (the `verify-complete.md` sentinel) and default-deny posture (`pk ship` aborts on missing file).

The DOUBT prompt format borrows from doubt-driven-development (addyosmani) and adapts the "Contract misread" classification to Pipekit's Linear AC list. The Plan Gate two-tier reformulation absorbed feedback that the prior single 5-bullet gate was over-applied to trivial edits — inline mode now handles bug fixes and small refactors without ceremony.

### Migration

- **Pin to v2.7.0-rc1.** Run `./scripts/sync-method.sh v2.7.0-rc1` from inside your consuming project. RC sync recommended for one cycle of dogfooding before bumping to v2.7.0 stable.
- **`tier:*` labels.** Add the `tier:(quick|standard|heavy)` Linear labels to your team if not already present (per v2.6.0 reinstatement). Issues without a tier label default to `standard` — gate behaves as if the issue is opted in to the artifact pipeline.
- **`.gitignore` recommendation.** Add `.pk-work/` only (transient `/work` marker files). `Logs/Verify/` is **intentionally committed** as the per-PR audit trail — the `verify-complete.md` sentinel travels with the merge as evidence that the pre-deploy gate passed at the verified SHA. Retention is the consumer's call (periodic `git rm -r Logs/Verify/<old-date>/` commits work fine).
- **Linear API key required for `pk_linear_tier`.** The gate falls back to `standard` if Linear is unreachable, but the artifact layer requires you to actually call `/verify` to produce `verify-complete.md`. Projects without a Linear key still gate on file presence — they just can't differentiate tiers.
- **`--force` audit trail.** Bypassing the gate via `pk ship --force` posts a Linear comment to the issue: `Shipped without verify-complete.md (--force at <ISO-timestamp>)`. Use sparingly — `pk_linear_comment` is best-effort so an outage won't block the ship.
- **`PK_VERIFY_BYPASS=1`** is the emergency escape, not the daily-driver escape. It bypasses Linear comment writing and only appends to `Logs/Verify/bypass.log`. Reserve for production incident recovery when Linear is also down.

### What's deferred to v2.7.0 stable

- **Week 4: `/pr-fix` full subagent dispatch.** Diff-aware persona dispatch (always-on quartet + conditional security/migration/performance/adversarial), cross-persona promotion (3-line bucket match-key + 25→50→75→100 confidence ladder), severity × autofix matrix with `--quick` remap. `--legacy-flat` escape hatch preserves v2.6 behavior.
- **Project-configurable sensitive-path patterns for `/verify`** — currently hardcoded; future `[verify.sensitive_paths]` block in `method.config.md` would let consumers override the defaults. Deferred to v2.7.1+ along with the analogous `[pr-fix.sensitive_paths]` block.
- **`/02-light-spec-revise` tier re-derive** — currently only `/01-light-spec` runs Phase 3.6. If a revise cycle changes the Complexity field, the `tier:*` label doesn't auto-refresh. v2.7.1 candidate.
- **Phase 2: `/pk-compound` + `resources/solutions/`.** Bug-track first, knowledge-track reassess at month 3.

---

## v2.6.0.1 — 2026-05-24

> **Patch: `pk branch` auto-allows direnv on the worktree.** v2.6.0 #14 added `.envrc` to the symlink loop in `cmd_branch`, but direnv treats the worktree path as a new `.envrc` and blocks it until manually allowed. Symptom: MCP servers and other direnv-loaded tooling still fail to auth at Claude Code launch in fresh worktrees — the exact failure mode #14 was meant to fix. v2.6.0.1 closes the half-broken state by running `direnv allow` on the worktree after the symlink lands.

### What changed

- **`bin/pk` `cmd_branch`** — after the `.envrc` symlink, run `direnv allow "$wt_path"` if `direnv` is on `$PATH`. Fails soft (suppressed via `|| true`) when direnv is missing. The symlink target is the parent's `.envrc` which the user has already `direnv allow`-ed (otherwise direnv wouldn't have loaded in the parent), so the auto-allow doesn't bypass the user's trust decision — it propagates it.

**`PK_VERSION`** 2.6.0 → 2.6.0.1.

### Why

v2.6.0 #14 shipped the `.envrc` symlink to fix MCP auth failures in fresh worktrees launched via `pk branch`. In testing 2026-05-24, the symlink lands correctly but direnv refuses to load it with `error /<worktree>/.envrc is blocked. Run \`direnv allow\` to approve its content`. Net effect: same MCP auth failure mode, one extra manual step (`direnv allow`) to recover. The fix delivered half its value.

The justification for auto-allow: direnv's allow-gate exists to prevent malicious `.envrc` files from being added to a repo without the user's knowledge. The worktree's `.envrc` is not new content — it's a symlink to the parent's `.envrc` which the user has already explicitly allowed. Auto-allowing on the symlink target propagates an existing trust decision rather than bypassing the security model.

### Migration

- **Pin to v2.6.0.1.** Run `./scripts/sync-method.sh v2.6.0.1` from inside your consuming project.
- **Existing fresh worktrees** still need a one-time manual `direnv allow $WT_PATH` to recover (v2.6.0.1's auto-allow only fires on new `pk branch` invocations).
- **direnv not installed?** No-op — `command -v direnv` check skips the auto-allow silently.

---

## v2.6.0 — 2026-05-23

> **Minor: tier system restored + Path 3 reviewer pipeline + two-phase promote + worktree-setup polish.** Twelve candidates landed in one release — the v2.5.0 / v2.5.0.1 cycle's findings plus the 2026-05-17 cmux parallel-native batch (5 WITs / 75 min / 1.5-1.8× speedup) and the 2026-05-18 reviewer-strategy work. Three headline groups: (1) **tier inference** is back in `/work` via Linear `tier:*` labels — closing the config↔code mismatch since v2.0.0; (2) **Path 3 reviewer pipeline** ships — Semgrep + Claude templates, `/pr-fix --from-review` + `--second-opinion=gemini` flags, `pk ship --draft` default + new `pk ready <ID>` command, and the F2 two-phase promote that stops `pk promote` from writing Linear state ~5 minutes ahead of reality; (3) **VBW plan-state finalization** in `pk done` unblocks fresh-worktree batch flows. Plus six smaller items: `.envrc` symlink, `pk branch` auto-install + `--no-install`, `pk done` auto-pull, `pk_promote` silent-exit fix, `sync_file` idempotent, cmux numeric-menu rule.

### What changed

**Tier system reinstatement** (`skills/work/skill.md`)
- **Step 2.6 (new)**: infer tier from Linear `tier:*` labels (defaults to Standard). Surface a Quick → `/06-linear-todo-runner` batch alternative and a Heavy `/strategy-sync`-required warning.
- **Step 3 (Plan)**: Quick forces inline planning (no spec-validator / Explore / vbw-scout subagents even with `--deep`). Heavy forces parallel grounding regardless of `--deep`. Standard unchanged.
- **Step 4 (Verdict)**: Quick uses a single y/N gate — no revision loop. Standard / Heavy keep the 3-revision verdict.
- **Step 6 (Security)**: Quick skips review even with `--deep`. Heavy forces it regardless of `--deep`.
- **Step 7 (Hand-off)**: Heavy appends a `/strategy-sync` reminder before close.
- Semantics match the existing per-tier templates at `templates/tier-{quick,standard,heavy}.md`. The `method.config.template.md` Tiers section was already accurate; the code side now honors it.

**`pk done` writes VBW SUMMARY + flips PLAN status** (`bin/pk`)
- After a confirmed merge, flips `.vbw-planning/phases/<phase>/<phase>-<id>-PLAN.md` frontmatter `status: ready` → `status: complete` (frontmatter-scoped via awk).
- Writes `<phase>-<id>-SUMMARY.md` alongside with PR URL, merge SHA, commits-shipped count, diffstat, close date.
- Prints a commit hint so the user can land the changes when ready.
- Idempotent (re-runs preserve existing SUMMARY; status flip is no-op if already complete). Skips silently when there's no `.vbw-planning/` or no matching PLAN.md.
- Unblocks fresh-worktree edits for batch flows — VBW's file-guard otherwise treats every `status: ready` PLAN.md as in-progress.

**`pk done` auto-pulls integration branch post-merge** (`bin/pk`)
- After confirmed merge, fast-forwards local `dev`/`main` if HEAD is on it; otherwise fetches so the next checkout is current. Divergence warns rather than fails.

**`pk branch` auto-runs lockfile-matched install + `--no-install` opt-out** (`bin/pk`)
- Replaces the F8 fresh-worktree hint (added v2.4.3.3 / 2026-05-14) with the action it suggested. Detects `pnpm` / `yarn` / `npm` from the lockfile, runs install in foreground.
- New `--no-install` flag for cached-deps or spec-only worktrees. Flag surfaces in the "To enter:" output after an install runs so it's discoverable for next time.
- Install failure warns loudly but doesn't return 1 — the worktree, env symlinks, and Linear state are already set up.

**`pk branch` symlinks `.envrc` alongside `.env`** (`bin/pk`)
- Adds `.envrc` to the env-symlink loop in `cmd_branch`. Without it, direnv stays inert in fresh worktrees and MCP servers / other direnv-loaded tooling fail to auth at Claude Code session launch. Existing `-f` guard means non-direnv projects are unaffected.

**`pk promote` no longer silent-exits on commit ranges with no WIT matches** (`bin/pk`)
- The two `git log | grep -oE PREFIX-N` pipelines in `cmd_promote` exited 1 under `set -euo pipefail` when commit ranges contained no issue-prefix matches — killing the script before the `if [ -n "$bundled_ids" ]` check could skip safely. Fixed with `{ grep ... || true; }` scoped to grep, matching the precedent at `bin/pk:528-529`.

**`sync_file` is idempotent on unchanged files** (`scripts/sync-method.sh`)
- Skip `cp` when `diff -q` reports no content change. Prevents the F3 "bin/pk drift in worktrees" symptom and reduces git-status noise on no-op syncs. Side effect: faster sync (no cp for unchanged files).

**cmux numeric-menu discipline** (`.claude/rules/pipekit-cmux.md`)
- Codified pre-v2.6.0 in the canonical rule file (`Never send <digit>\n to a Claude interactive menu` + `Wait 2-3s between send-key enter and the next read-screen`). Listed here for v2.6.0 traceability.

**F2 — `pk promote` two-phase Linear transition** (`bin/pk`)
- Replaces the optimistic-at-PR-open behavior (v2.3.0–v2.5.0) where Linear advanced to `In <Env>` ~5 minutes before the merge landed. Aborted promotes required manual Linear revert.
- **Phase 1**: `pk promote <env>` opens the promote PR. Bundled WITs stay in source-env state. The PR body embeds a `<!-- pipekit-promote-tracking: source=<s> target=<t> wits=<W1,W2,...> -->` marker (stateless, cross-machine — no local state file required).
- **Phase 2**: `pk promote <env> --finish` finds the most recent merged promote PR, parses the marker, transitions each bundled WIT to the target state. Falls back to deriving WITs from PR commits when no marker exists (older PRs).
- Phase 1 prints the exact `--finish` command at the end so the two-step flow is discoverable without docs.

**CI workflow templates** (`templates/ci/`)
- `templates/ci/semgrep.yml` — deterministic outside reviewer (`semgrep ci --config=auto`, free Community Rules, no token required). Triggers on `[opened, ready_for_review]` only — matches Pipekit's Draft-PR lifecycle.
- `templates/ci/claude-review.yml` — semantic outside reviewer via `anthropics/claude-code-action@v1`. Includes a `triage` job (Option B path-filtering per v2.6.0 #5) that skips doc-only PRs (`.md`/`.txt`/`.rst`) and trivial PRs (<5 LOC). Path filtering is intentionally absent — PR #331 evidence showed claude-review caught bugs in non-high-leverage paths that any allowlist would miss.
- `templates/ci/semgrep-rules/uuid-route-params.yml` — starter custom rule flagging dynamic route params flowing into Supabase queries without UUID validation. Deterministic backup for the Piper PR #341 miss (claude-review caught the pattern on PR #331 but missed it on #341).
- `templates/ci/README.md` — documents the Draft-PR lifecycle, `branches:` configuration per tier, custom-rule adoption, and the `/pr-fix` flags below.

**`/pr-fix` — `--from-review` + `--second-opinion=gemini` flags** (`skills/pr-fix/skill.md`)
- `--from-review` — skip Phase 3's fresh review and ingest existing PR review comments (typically from `claude-review.yml` GHA) instead. Maps each comment to a structured finding (file:line + body → severity inference). Default confidence = 85.
- `--second-opinion=gemini` — after Phase 4, invoke `gemini-flash-latest` for a parallel review. Surfaces findings as a separate section, NOT merged into Phase 4 (the point of a second opinion is comparison). Requires `GEMINI_API_KEY`; refuses cleanly without. Documents the thinking-tokens gotcha (`maxOutputTokens=65536`, `thinkingBudget=-1`).
- Flags compose: `/pr-fix --review --from-review --second-opinion=gemini` is valid (reviews-only + ingest GHA + parallel Gemini).

**`pk ship` opens Draft by default + new `pk ready` command** (`bin/pk`)
- `pk ship` now passes `--draft` to `gh pr create` unless `--ready` is set. Outside reviewers (Semgrep + claude-review templates) trigger on `[opened, ready_for_review]` — opening Draft means no review fires during iteration.
- New `pk ready [<ID>]` flips the feature PR from Draft to Ready (`gh pr ready <#>`). No Linear state change. Closes the dead-code gap from Piper PR #330 (`ready_for_review` trigger was wired but nothing in Pipekit fired it).
- `pk ship --ready` opens Ready immediately for one-shot tiny WITs where iteration won't happen.
- `pk_gh_pr_create` helper gained a `--draft` flag (REST `-F draft=true`, gh CLI `--draft`).

**`PK_VERSION`** 2.5.0.1 → 2.6.0.

### Why

This release stacks four motivations:

1. **Tier reinstatement is the headliner.** Empirical anchor: 2026-05-17 cmux parallel-native batch shipped 5 WITs in 75 min wall-clock vs 90-135 min serial (1.5-1.8× speedup), 5/5 clean. WIT-478 PR 1 took 3 hours for one ADR doc under the full gate stack (would be <30 min on Quick). WIT-474 (Production Fee float drift) sat unworked for 2 days as "Quick Win, can slot any time" because no fast lane existed. v2.6.0 closes the config↔code gap and restores the Quick fast lane.
2. **Path 3 reviewer pipeline closes the "no real outside reviewer" gap.** Pre-v2.6.0 consumers ran two Claude reviewers in parallel (GHA + local `/pr-fix`) — convergent perspective, shared blind spots, double credit cost. v2.6.0 ships Semgrep (deterministic, no LLM, free) + Claude (semantic, the empirically-strongest LLM reviewer on Piper PR #331) + opt-in Gemini second-opinion. OpenAI/Microsoft stack disqualified on the IP-absorption pattern (`resources/v2.6.0-candidates.md` § "Why OpenAI/Microsoft are disqualified"), not on quality.
3. **F2 fixes the "Linear ahead of reality" semantic bug.** Pre-v2.6.0 `pk promote` wrote `In <Env>` at PR-open, ~5 minutes before the merge landed. Two-phase (`pk promote` opens; `pk promote --finish` transitions post-merge) trades one extra command for accurate Linear state.
4. **`bin/pk` worktree-setup paper cuts.** `.envrc` symlink (Piper handoff 2026-05-23) and auto-install (v2.4.3.3 F8 follow-through) make fresh worktrees ready-to-use without the human typing the lockfile-install command. `pk done` SUMMARY + PLAN flip unblocks batch flows that were hitting VBW's file-guard wall on every fresh worktree. `pk_promote` silent-exit on RS-Vault 2026-05-15 was a trivial fix with high signal-restoration value.

### Migration

- **Pin to v2.6.0.** Run `./scripts/sync-method.sh v2.6.0` from inside your consuming project.
- **Tier labels in Linear.** To use the new tier behavior, add a `tier:quick`, `tier:standard`, or `tier:heavy` label to your Linear issues. Issues without a `tier:*` label default to **Standard** (current behavior). No action needed for projects that don't want to adopt tiers yet.
- **CI workflow adoption.** Copy `pipekit/templates/ci/semgrep.yml` and `pipekit/templates/ci/claude-review.yml` into `.github/workflows/` and edit the `branches:` list to match your `Ship environments`. `claude-review.yml` requires the `CLAUDE_CODE_OAUTH_TOKEN` repo secret. See `pipekit/templates/ci/README.md` for the full lifecycle doc.
- **Draft-PR flow.** `pk ship` now opens Draft by default. Iterate freely, then `pk ready <WIT-ID>` to fire the outside reviewers at the merge moment. Use `pk ship --ready` if you want the old behavior on a one-shot tiny WIT.
- **Two-phase promote.** `pk promote <env>` opens the PR but no longer writes Linear state. After merge, run `pk promote <env> --finish` to transition WITs to the target state. Phase 1 prints the exact `--finish` command at the end — no docs lookup needed.
- **`pk branch --no-install`.** If your workflow doesn't need a fresh `pnpm install` on every worktree (cached deps, spec-only worktrees), pass `--no-install`. The flag surfaces in the "To enter:" output after the first install runs so it's discoverable.
- **VBW SUMMARY / PLAN-flip commits.** `pk done` now leaves `.vbw-planning/` files modified (SUMMARY written, PLAN status flipped). Commit them with `git add .vbw-planning/ && git commit` to propagate the status to future worktrees. Without the commit, batch workers may still hit the stale-PLAN file-guard wall.

### Knock-on followups (not in this release)

Held for v2.6.x+:

- **#10 — `pk_promote` strict ownership match.** Closing-keyword + commit-title prefix verification. ~3h, defense-in-depth — cuts leap-frog noise.
- **#11 — `/light-spec` two-step placeholder workaround.** Investigate root cause first; may already be moot if upstream fixed it.

Full backlog: `resources/v2.6.0-candidates.md`.

---

## v2.5.0.1 — 2026-05-15

> **Patch: `sync-method.sh` wrong-target bug.** RS-Vault's v2.5.0 migration (Finding #1 in `resources/rs-vault-v2.5.0-migration-followup.md`) surfaced that the sync script resolved its target from the script's own location instead of the consuming project's working directory. Result: invoking `bash ~/Projects/pipekit/scripts/sync-method.sh v2.5.0` from outside the pipekit repo silently synced INTO the pipekit repo itself, leaving the consuming project unchanged and dirtying pipekit's working tree with ~20 file rewrites. Recoverable but invisible until you noticed `pk version` still printed the old number.

### What changed

- **`scripts/sync-method.sh`** — `PROJECT_ROOT` now defaults to `${PWD:-$(pwd)}` instead of `$(dirname "$0")/..`. This matches the `cd <project> && bash <pipekit>/scripts/sync-method.sh` invocation pattern documented everywhere. Adds a safety check that compares the target's git origin URL against `METHOD_REPO` and refuses with a clear error message if they match (i.e. the user is about to sync Pipekit into itself). Error message explains both the likely cause (forgot to `cd`) and the recovery paths. Adds a `--target=<path>` flag for explicit override.
- **Constitutional doc stamps (`method.md`, `RUNBOOK.md`, `GUIDE.md`)** — bumped to v2.5.0.1 per the v2.4.3.2 Release Checklist exception.
- **`RUNBOOK.md` sync-example** — `v2.5.0` → `v2.5.0.1`.

**`PK_VERSION`** 2.5.0 → 2.5.0.1.

### Why

Two things this patch achieves:

1. **The documented invocation now works.** Every Pipekit handoff, README, RUNBOOK, and STARTUP example says some variant of `cd ~/Projects/<project> && bash ~/Projects/pipekit/scripts/sync-method.sh v<tag>`. Pre-v2.5.0.1, the `cd` was effectively ignored — `PROJECT_ROOT` was script-relative. v2.5.0.1 honors `$PWD` so the `cd` actually controls where the sync lands.
2. **Self-sync is no longer silent.** If the user *does* forget to `cd` (or invokes from a session that lost its cwd), the script now refuses with `exit 1` and a helpful error rather than chewing through pipekit's own working tree. Detection is structural (git origin URL comparison), not heuristic.

The handoff template (`resources/nebula-rs-vault-pipekit-v2.5.0-handoff.md`) still says `bash ~/Projects/pipekit/scripts/sync-method.sh v2.5.0` because that pattern now works correctly post-patch. Older handoffs that say the same thing will Just Work after the consuming project syncs to v2.5.0.1 (their local copy of sync-method.sh updates via the self-update guard on first sync).

### Migration

- **Pin to v2.5.0.1.** Run `./scripts/sync-method.sh v2.5.0.1` from inside your consuming project to pick up the patched script. The self-update guard re-execs with the new logic mid-sync.
- **If you already synced v2.5.0 successfully**, you're fine — the v2.5.0 sync touched the same target files; v2.5.0.1 only changes the *invocation safety*. No re-sync needed unless you want the new safety check locally.
- **If your v2.5.0 sync went into pipekit itself**, recover by: (a) `git status` in pipekit shows the spurious changes, (b) `git checkout .` discards them, (c) cd into your actual consuming project, (d) re-run with v2.5.0.1.

### Knock-on followups (not in this patch)

The RS-Vault migration surfaced four other findings beyond this one. Tracked separately:

- **F2: `pk promote` optimistic Linear write.** Writes terminal state at PR-open, not merge. Documented behavior since v2.3.0 but semantically louder in v2.5.0's env-as-status model. Resolution path TBD — likely either a two-phase transition (`pk promote` opens PR + sets `In <NextEnv>`, then a `--finish` flag or post-merge hook writes terminal) or a `--wait` flag.
- **F3: `bin/pk` drift in fresh worktrees.** `pk install` or sync rewrites `bin/pk` on disk in a way that shows as modified in worktrees pinned to older commits. Cosmetic; workaround is `git checkout -- bin/pk`. Likely fix: only update the user-PATH copy, not the in-tree file.
- **F4: protected-branch consumer projects can't `git push` direct.** Handoff template says `git push` but Piper / RS-Vault / etc. require PR + status checks. Fix: handoff Step 6 should route through a sync PR. Not a code change — handoff template only.
- **F5: extra started-type Linear states unflagged in pre-flight.** rs-vault has `In Progress` + `Building` + `In Dev`; canonical pair assumed. Fix: handoff Step 0c should list all started-type states. Not a code change.

Full RS-Vault findings: `resources/rs-vault-v2.5.0-migration-followup.md`.

---

## v2.5.0 — 2026-05-15

> **Env-as-status.** Linear state names now derive from `Ship environments` chain position: `UAT` (PR open on preview, pre-merge) → `In <FirstEnv>` (e.g. `In Dev` — merged to first env) → `In <Env>` per intermediate hop → `Done` (final env). `Released` retired. `pk done` regains state-transition responsibility (UAT → `In <FirstEnv>`) with optional `--merge` flag to run `gh pr merge` for you. Resolves "tested but still UAT" status headache on multi-tier projects.

### What changed

**`bin/pk`:**

- **`pk_state_rank`** — refactored to compute "In `<env>`" ranks from `Ship environments` chain position (rank 11 + idx). Pre-deploy ranks (Triage through UAT) stay hardcoded; Done = 50 (fixed high). Unknown "In `<x>`" envs return 0 to fall through the leap-frog gate. Replaces v2.3.0's fixed `UAT < Released < Done` ladder which couldn't generalize past 3-tier.
- **`pk_first_env_state_name`** (new helper) — returns `"In <FirstEnv-Capitalized>"` (n-tier) or `"Done"` (1-tier).
- **`pk_env_state_name <env>`** (new helper) — returns `"In <Env-Capitalized>"` for intermediate hops, `"Done"` for the final env, empty string for envs not in the chain.
- **`pk_capitalize`** (new helper) — first-letter capitalization for env names → state names.
- **`cmd_done`** — adds Linear state transition (UAT → `In <FirstEnv>`, or → Done for 1-tier) after the PR-merge check passes. **Drops** the v2.4.3 UAT-state refusal — `pk done` IS the legitimate UAT-out transition now; the PR-merge check is the load-bearing gate. **Adds `--merge` flag** (M3 opt-in) — runs `gh pr merge "$current" --merge` before the merge-verification step, so one command handles the full hand-off. `--confirmed` is still parsed (backward compat) but is a no-op.
- **`cmd_promote`** — target-state mapping now goes through `pk_env_state_name "$target"` instead of position-based `Released` / `Done` binary. Intermediate hops set `In <Env>` (e.g. `In Beta`, `In Staging`); final hop still sets `Done`. UAT-refusal gate retained — still refuses if any bundled issue is in `UAT` (PR not yet merged); `--confirmed` bypasses after env-UAT signoff.
- **`pk_linear_set_state` leap-frog check** — threshold changed from `pk_state_rank Released` (== 11 in v2.4.x, == 0 in v2.5.0 since Released is gone) to a literal `11` (any "In `<env>`" or Done state). Comment updated.
- **`cmd_status`** — now iterates `Ship environments` and shows one bucket per non-final env (`In Dev`, `In Beta`, etc.) alongside the existing `In Progress` / `Building` / `UAT` / `Approved` buckets. Final env (Done) excluded from in-flight view.
- **`cmd_help`** — `pk done`/`pk ship`/`pk promote` descriptions updated; `--merge` flag documented; `--confirmed` deprecation note for `pk done`.

**Docs (rename + flow updates):**

- **`method.md`** — Stage 3+4 narratives rewritten: UAT semantics narrowed to "PR open on preview"; `In <FirstEnv>` introduced; pk done's state transition documented; pk promote rows updated (Released → `In <Env>`); quick-reference tables refreshed.
- **`RUNBOOK.md`** — `[5e]` interactive-UAT box rewritten to reference the two-phase UAT (`UAT` pre-merge, `In Dev` post-merge); `[8]` pk done box updated with state transition + `--merge` flag; `[9]` pk promote box updated (Released → `In <Env>`); cheat-sheet rows refreshed.
- **`README.md`** — Stage 10 pk done description and Stage 11 pk promote description updated.
- **`STARTUP.md`** — header stamp v2.3.0 → v2.5.0; transition-quick-table updated.
- **`GUIDE.md`** — pipeline overview, two-tier/three-tier release flows, status ladder, and command tables updated. PROJ-6 example status changed from UAT to In Dev.
- **`CLAUDE.md`** — header stamp v2.4.3.2 → v2.5.0; v2 daily loop sequence shows the new chain; pk done / pk promote table rows updated.
- **`sop/Linear_SOP.md`** — header stamp v2.4.3.2 → v2.5.0; pipeline diagram + state-meaning table + transitions table + fast-track paths all rewritten for env-as-status.
- **`sop/Git_and_Deployment.md`** — 2-tier and 3-tier transition blocks updated; v2.5.0 UAT-gate note replaces v2.4.3 description.
- **`sop/Skills_SOP.md`** — pk ship / pk done / pk promote rows updated.
- **`skills/linear/skill.md`**, **`skills/startup/skill.md`**, **`skills/pk-exit/skill.md`** — state-name references refreshed; `/startup` now prompts to create `In <FirstEnv>` + `In <Env>` workflow states; `/pk-exit` discipline note explains pk done's new state-transition role.
- **`method.config.template.md`** — 2-tier and 3-tier example Linear-transition blocks rewritten with explicit UAT → `In Dev` → (`In Beta` →) `Done` paths.

**Tests:**

- **`scripts/test-pk-promote.sh`** — pk_state_rank assertions updated for env-derived ranks. Stubs `pk_config` to return `dev,beta,main` so In Dev=11, In Beta=12, Done=50 are deterministic. Pairwise checks now reference `In Dev` and `In Beta` instead of `Released`. 27/27 passing.
- **`scripts/test-pk-v2.4.3.sh`** — Finding 1 (cmd_done UAT-refusal) inverted: now asserts that cmd_done with state==UAT does NOT refuse (proceeds to PR-merge check) and that `--confirmed` is accepted as a no-op. 9/9 passing.

**`PK_VERSION`** 2.4.3.3 → 2.5.0. (v2.4.3.3 landed on origin during the v2.5.0 design session — see v2.4.3.3 section below for its scope.)

### Why

Multi-tier projects (Piper: dev → beta → main) accumulated a UX headache through v2.3.0–v2.4.x: an issue could be tested + signed off in dev but Linear still showed `UAT`, because the only thing that flipped state was `pk promote`. "UAT" reads as "actively being tested" — confusing when testing is complete and the issue is just parked awaiting the next hop.

The fix isn't a deeper state machine; it's matching state names to the physical question "which env is this on?". v2.3.0 already had the state-maps-to-env intuition (CHANGELOG: *"With state mapped 1:1 to environment (UAT = on dev, Released = on beta, Done = on main), Linear's state always reflects reality"*), but `Released` as a single label collapsed every non-final env into one bucket and didn't generalize past 3-tier. v2.5.0 derives per-env state names directly from `Ship environments`, so the status column on a Linear board literally tells you "this is on beta" or "this is on staging" — no ambiguity, no per-project naming guessing.

The split of UAT into two phases (`UAT` = on preview branch pre-merge; `In <FirstEnv>` = on dev post-merge) honestly maps to the two distinct activities that previously shared one label: PR review on the preview URL, vs interactive UAT on the deploy env. `pk done` becomes the legitimate transition between them (it verifies the merge happened, so the In `<FirstEnv>` claim isn't a lie).

### Breaking changes (consumer migration required)

- **Linear workspace states.** Consuming projects must:
  1. Rename existing `Released` state → `In <SecondEnv>` (e.g. `In Beta`). Linear's UUIDs persist across renames so existing issues stay attached.
  2. Add new `In <FirstEnv>` state (e.g. `In Dev`), type `started`, positioned between `UAT` and the renamed-Released.
  3. (Optional) Reclassify currently-`UAT` issues whose PR is already merged → `In <FirstEnv>`.
  4. Pull updated Pipekit via `./scripts/sync-method.sh v2.5.0`.

- **`method.config.md` "Workflow State IDs" table.** Add rows for the new per-env states + capture their UUIDs.

- **`pk done` flag semantics.** `--confirmed` is now a no-op (was: bypass UAT-state refusal). `--merge` is new (opt-in: runs `gh pr merge` before state transition + cleanup). Scripts/skills that passed `--confirmed` to `pk done` will continue to work; the flag is silently accepted.

### Migration runbook (Piper-specific)

Piper is the lead consumer. Steps already partially executed during the v2.5.0 design session (states renamed/added in Linear before this code shipped):

1. ✅ Done (already executed manually): Rename `Released` → `In Beta` in Linear workflow.
2. ✅ Done (already executed manually): Add `In Dev` (type: started) between `UAT` and `In Beta`.
3. **TODO**: Reclassify currently-`UAT` issues whose PR is already merged → `In Dev`. WIT-414 is the known case (PR #279 merged 2026-05-14). Eyeball any other `UAT` issues for PR-merge state.
4. **TODO**: Sync Piper to v2.5.0: `cd ~/Projects/piper && bash ~/Projects/pipekit/scripts/sync-method.sh v2.5.0` (or `./scripts/sync-method.sh` for HEAD).
5. **TODO**: Spot-check Piper's `method.config.md` Workflow State IDs table — add UUIDs for `In Dev` and verify `In Beta` UUID matches the renamed state.
6. **TODO**: Smoke test on a sandbox WIT — full chain (`pk branch` → `pk ship` → merge → `pk done` → `pk promote beta` → `pk promote main`).

If steps 1+2 hadn't been done before code shipped: `pk promote beta` would have written to the non-existent `Released` state and gotten "state not found" errors. Recoverable (manual state flip in Linear UI) but messy.

### Conceptual reversal

v2.3.0 deliberately stripped `pk done` of state-transition responsibility ("a worktree closing does not mean the issue is shipped"). v2.5.0 reverses that: pk done sets `In <FirstEnv>`, not `Done`. The v2.3.0 objection doesn't apply — pk done is no longer claiming the issue is shipped, just that it's now on the first deploy env (which is accurate, since pk done verified the merge). State movement is still owned by pk ship + pk done + pk promote collectively; pk done now sits between pk ship (sets UAT) and pk promote (sets per-env / Done).

---

## v2.4.3.3 — 2026-05-14

> **Canary-driven release.** One load-bearing skill behavior change (F6 — `/verify` pauses auto-ship when human-decision flags surface) plus a five-finding doc-polish bundle. All six items surfaced by a live v2.4.3.2 canary against Piper WIT-456 the same day. The canary itself validated v2.4.3.2's headline UAT-gate feature end-to-end (P1, P12, P13) and v2.3.3's skip-backward-transition guard in production (P15). Twelve passing signals total. Full canary log: `Logs/Sessions/2026-05-14_0838.md`.

### What changed

**`/verify` auto-ship now gates on `Pass AND zero flags AND --auto-ship` (F6 — load-bearing).** New Step 3.5 enumerates human-decision flags before the rollover decision:
- Migration files in diff (always pause regardless of QA — migrations are high-stakes and warrant a human eye for irreversibility, RLS, `search_path` review).
- QA verdict Pass with non-"none" Omissions / Scope-creep / Bugs-noticed sub-sections (the subagent classified the work as shippable in aggregate but still flagged items worth surfacing — treat each as a flag).
- User invoked `/verify --qa` (forcing QA signals "I want eyes on it"; auto-ship would contradict the explicit flag).
- `/work` advisory marker file (`.pk-work/<ID>.flags`) present (cross-skill signal — see below).

When `FLAG_COUNT > 0`, auto-ship is forbidden even with `--auto-ship`. The skill surfaces the flag list + three resolution paths (address, accept-and-amend, `/work --resume`), then stops. The auto-chain itself stays — it is a feature when nothing is surfaced. F6 anchor: 2026-05-14 canary verbatim feedback from the user: *"the F6 — /work → /verify → pk ship auto-chain is a feature. The programming should pause on verify if there is ANY Flag for human decision making."*

**`/work` Step 6.5 writes `.pk-work/<ISSUE-ID>.flags` when advisories surface (F6 cross-skill signal).** Triggers: self-reference grep #1/#2/#3 returns a match outside the file just edited, behavioral self-check finds a gap and the work ships anyway with the gap documented, or a documented Risk-fallback was invoked during execution. Marker file is one line per flag, gitignored at `.pk-work/`, consumed by `/verify` Step 3.5, cleaned up automatically when `pk done` removes the worktree. Re-runs of `/work --resume` overwrite the marker rather than appending. Empty markers are forbidden — file existence is the signal.

**`bin/pk pk_config` → `pk config` in `/work` skill (F1).** Replaced 6 invocations in `skills/work/skill.md` (lines 65, 68-71, 79, 504). `pk_config` is an internal shell function inside `bin/pk` reachable only when the binary is *sourced*; the subcommand exposed for skill bodies is `pk config <key> [default]`. The skill body's wrong form crashed the first config read of every `/work` invocation; workers self-recovered by retrying with the correct form, but each crash + retry burned a Bash tool call + LLM cycles. Doc-only fix; no binary change needed.

**`/work` Step 5 gains a "Test command discipline" preamble (F7).** One paragraph instructing executors to use the AC-stated test command verbatim before improvising. Surfaced by 3 retries on WIT-456: `pnpm --filter=@piper/web vitest run <abs-path>` (no such script) → `cd apps/web && pnpm test <abs-path>` (wrong relative path) → finally the AC's literal `pnpm turbo run test --filter=@piper/web`. Each ad-hoc invocation costs ~30s of retry; the AC string is pre-tested.

**`pk branch` emits a fresh-worktree dependency-install hint (F8).** When the new worktree has `package.json` but no `node_modules/`, `pk branch` now ends with:
```
⚠️  Fresh worktree — install deps before first test:
     (cd <wt-path> && <pkg-manager> install)
```
Lockfile detection picks `pnpm install` / `yarn install` / `npm install`. Worktrees inherit tracked files but not gitignored ones; the first test invocation otherwise triggered a multi-minute `pnpm install` while the worker session tried to figure out what was wrong. Surfaced on canary WIT-456 worker session.

**`/pr-fix` Phase 6.6 pre-documents the expected external-action security warning (F10).** Posting a Linear comment from inside `/pr-fix` triggers a generic "external action" security warning because Linear is an external write. The action is sanctioned by the skill (Phase 6.6 is an explicit step), but the harness can't know that — so workers improvised transparency notes per-run. The new preamble in `skills/pr-fix/skill.md` § 6.6 gives the worker the exact line to surface, removing the need to improvise.

**`pk done` + `/pk-exit` ordering hints (F11).** Two non-load-bearing additions:
- `bin/pk done --help` row now appends *"Run from parent repo (not worktree); run /pk-exit inside the worktree session first."*
- `skills/pk-exit/skill.md` frontmatter description now appends *"For worker sessions in a worktree, run /pk-exit before pk done (pk done cleans up the worktree this session lives in, so the log must be written first)."*

The canonical sequence was already documented in RUNBOOK step [7]→[8] and the refuse-table line 435 (`pk done` from worktree → refuses with hint). But experienced users still paused mid-canary to ask "do I run /pk-exit first?" — the join between the two skills was implicit in the flowchart. These hints surface the dependency at each command's own help text.

**`PK_VERSION`** 2.4.3.2 → 2.4.3.3. **`RUNBOOK.md`** sync-example line bumped to `v2.4.3.3`.

### Why

The 2026-05-14 canary against Piper WIT-456 ran the full v2 daily loop end-to-end against the v2.4.3.2 release and validated the headline UAT-gate features in production (PR #276 shipped, `pk done --confirmed` honored UAT bypass, `pk promote beta` refused without `--confirmed` then ran clean with it). In the process, six findings surfaced. F6 is the only behavior change — it was an explicit user methodology decision to keep the auto-chain but make `/verify` itself smarter about pausing. F1/F7/F8/F10/F11 are doc-tier polish that the v2.4.3.2 stamped-docs inventory and drift-check.sh wouldn't have caught (they check stamps and removed-skill references, not command examples vs `bin/pk`'s actual subcommand surface, and not user-friction patterns that show up only mid-loop).

The canary pattern paid off: zero methodology rework, six fixes ready the same day, all anchored to concrete observed behavior rather than speculative cleanup. The canary log is the substantive artifact — read `Logs/Sessions/2026-05-14_0838.md` for the structured P/F findings tally + the moment-by-moment observations.

### Migration

None for consumers already on v2.4.3.2 — F1/F7/F8/F10/F11 are doc-only or hint-only. F6 changes `/verify`'s auto-ship gate: it is strictly *more conservative* (paused chains are easier to recover than over-eager shipping), and the new pause path is the documented expected behavior when a flag is present. Re-run `/pipekit-update v2.4.3.3` or `./scripts/sync-method.sh v2.4.3.3` in consumer projects.

If your project already uses `.pk-work/` for something else, the F6 marker scheme will collide — but `.pk-work/` is a new directory in Pipekit's vocabulary and is unlikely to be in use already. (Pipekit's own `.gitignore` adds the entry.)

---

## v2.4.3.2 — 2026-05-14

> **Doc-polish release.** No code behavior changes. Brings every constitutional doc + SOP into alignment with the v2.4.3 code gate, establishes a stamped-docs inventory + release checklist, and closes drift that accumulated across v2.4.0 through v2.4.3.1.

### What changed

**Stamped-docs inventory (new).** Every top-level doc and SOP now carries a `**vX.Y.Z** — Last updated: YYYY-MM-DD  *(blurb)*` line right after its H1. The version on each stamp is the release the doc is **calibrated to** — when a release modifies a doc, bump its stamp; otherwise leave it alone so the gap between stamped version and current release surfaces drift. 14 docs are covered; the maintained list lives in the Release Checklist section above.

**Release Checklist (new).** Top of `CHANGELOG.md` now carries a checklist that every `chore(release): vX.Y.Z` PR must complete before merging — bump `PK_VERSION`, add CHANGELOG entry, stamp edited docs, update RUNBOOK sync example, ensure PR title carries `vX.Y.Z` for the auto-tag workflow. The root cause this closes: v2.4.0 through v2.4.3.1 all shipped with stale `v2.3.0` header stamps because release PRs edited prose at specific lines without touching the "Last updated" line.

**Content polish across 10 docs.**

- **`method.md`, `RUNBOOK.md`, `GUIDE.md`** — `--confirmed` flag now appears on every `pk done` / `pk promote` row in the daily-loop tables and cheat sheets. `Backend: auto` listed alongside `vbw` / `native` in the config table. Three-layer enforcement model (CLAUDE.md / CI+hooks / skills) called out in method.md Overview. `/strategy-from-code` deferral reworded — was "deferred to v1.4.0" (a version that already shipped 2026-04-27 without the skill); now "deferred; originally promised for v1.4.0 but never built."
- **`CLAUDE.md`** — daily-loop sequence shows the full v2.4.3 chain with `[--confirmed]` modifiers and `pk promote`; `/pk-exit` flagged as manual-invocation-only (never auto-chained from another skill); `Backend: auto` listed; `sop/` list expanded to include all seven SOPs.
- **`README.md`** — `pk done` / `pk promote` rows updated; `/pk-exit` per-session emphasis; versioning example refreshed from `v1.0` to `v2.4.3.2`.
- **`sop/Code_Quality.md`** — stack-agnostic note (was implicitly TypeScript-only); `/verify` named as canonical pre-deploy gate runner.
- **`sop/Git_and_Deployment.md`** — Release Flow now explicitly describes optimistic state transitions at PR-open, the merge as source-of-truth anchor, and the v2.4.3 `--confirmed` gate semantics.
- **`sop/Linear_SOP.md`** — UAT row + transitions reference `--confirmed`; 2-tier clarification that Released state is unused.
- **`sop/Session_Management_SOP.md`** — `/pk-exit` added as explicit session bookend in the session pattern table.
- **`sop/Skills_SOP.md`** — skill-author guidance now says "Dispatch heavy work through `/work`" (which routes to vbw/native/auto backends) rather than "Use VBW agents directly"; `/pipekit-help` usage hint added.

**`PK_VERSION`** 2.4.3.1 → 2.4.3.2.

### Why

The methodology is correct; the docs were lagging. Stamping every doc with its calibration version makes drift legible (you can see a doc is "v2 minor releases behind current" at a glance), and the checklist forces future releases to keep the stamps honest. Cutting v2.4.3.2 instead of leaving the polish on main without a tag lets Piper and other consumers `./scripts/sync-method.sh v2.4.3.2` to pin a known-good doc set.

### Migration

None. Re-run `/pipekit-update` or `./scripts/sync-method.sh v2.4.3.2` in consumer projects. Consumers already on v2.4.3 / v2.4.3.1 see only doc changes (no behavior changes).

---

## v2.4.3.1 — 2026-05-13

> Patch: doc reconciliation for v2.4.3. The v2.4.3 code shipped with `method.md` and `RUNBOOK.md` still describing only the v2.4.2 *prose* UAT gate — neither mentioned that the binary now refuses with `exit 1`. Closes the doc lag.

### What changed

- **`method.md` Stage 3 (line 219)** — Interactive UAT paragraph appended: "v2.4.3 added code-level enforcement as a belt-and-braces backstop: `pk done` and `pk promote` now refuse with `exit 1` when Linear state is `UAT` (or any bundled issue is in `UAT` for `pk promote`). Pass `--confirmed` once UAT is signed off to bypass."
- **`method.md` Stage 4 (lines 236-237)** — `pk done <ID>` and `pk promote <env>` step descriptions updated with the `[--confirmed]` flag and the UAT-refusal clause.
- **`method.md` Tooling table (lines 435-436)** — `pk done <ID> [--confirmed]` and `pk promote <env> [--confirmed]` rows updated.
- **`RUNBOOK.md` `[5e]` box** — extra line: "v2.4.3+ enforces this in code: pk done / pk promote refuse with exit 1 when Linear state is UAT. Pass --confirmed once UAT is signed off to bypass."
- **`PK_VERSION`** 2.4.3 → 2.4.3.1.

### Why

v2.4.3's code-level UAT refusal is the load-bearing change of the day, but the prose docs still implied "this is a discipline rule, not enforced." Users (and AI sessions) reading `method.md` would think the gate is advisory when it now exits 1. Doc rot starts within hours of the code shipping; closing it the same night while the context is fresh.

### Migration

None. Re-run `/pipekit-update v2.4.3.1` in consumer projects (or in the Pipekit clone itself — same command, auto-detects mode).

---

## v2.4.3 — 2026-05-13

> Patch: code-level enforcement of the v2.4.2 UAT-gate doc, plus a `pk install` lag fix surfaced when the v2.3.3 state-ladder gate failed to fire because the user's installed `pk` was at v2.3.2. Five fixes, one bundled PR.

### What changed

- **`bin/pk cmd_done`** — refuses with `exit 1` when the issue is in Linear state `UAT` unless `--confirmed` is passed. v2.4.2's doc gate told future sessions not to chain `pk done` past UAT; this is the belt-and-braces. Doc gates rely on the model reading prose; code gates rely on `exit 1` and don't lie. Anchor: WIT-451 worker session 2026-05-13, where auto-merge → auto `pk done` wiped the worktree mid-UAT.
- **`bin/pk cmd_promote`** — same shape, narrower trigger: refuses when any bundled issue (scanned from `git log <target>..<source>`) is in `UAT`. Released / Done bundles still pass through (re-promote is fine). Approved-or-earlier is already caught by the v2.3.3 ladder leap-frog refusal in `pk_linear_set_state`, so no double-emit. `--confirmed` opt-out.
- **`bin/pk pk_linear_get_state`** — new helper: fetches the current workflow-state name for a Linear issue by identifier. Returns empty string on lookup failure so callers can treat absence as "don't know" rather than aborting. Used by both UAT refusals above.
- **`bin/pk cmd_install`** — `--force` now always re-links, even when the existing target already points at `$src`. Previously the `existing == src` short-circuit returned 0 before `--force` was evaluated, so `pk install --force` was a silent no-op against valid symlinks (anchor: Pendragon 2026-05-13). Reports `Re-linked: …` instead of `Installed: …` when the re-link was forced. Adjacent design question — should `pk install` default to symlinking the global `~/Projects/pipekit/bin/pk` clone instead of the calling project's `bin/pk`? — left for a future cycle; not in scope for v2.4.3.
- **`scripts/sync-method.sh`** — after each sync, compares the synced `bin/pk` content against `~/.local/bin/pk` and `/usr/local/bin/pk` via `cmp -s` (follows symlinks). If they differ, warns with the `pk install --force` remediation. New `--auto-install` flag invokes `pk install --force` automatically post-sync for unattended sync paths (CI, batch scripts). Closes the lag-bug anchor: PR #270 ran the v2.3.3 state-ladder gate code path… except it didn't, because `~/.local/bin/pk` was at `pk 2.3.2` while the synced `bin/pk` was 2.4.2. WIT-275 got falsely transitioned Approved → Done and had to be reverted manually.
- **`sop/Git_and_Deployment.md` § Hotfix Procedure**  — new sub-section "When the explicit beta cherry-pick is needed (three-tier)". The standard three-tier hotfix flow files three branches (`hotfix/*-main`, `*-cherrypick-dev`, `*-cherrypick-beta`), but the explicit beta cherry-pick is redundant when a `dev → beta` promote is imminent — the dev cherry-pick sweeps to beta via the next promote. Filing it anyway leaves an orphan branch. Anchor: WIT-455, 2026-05-13 — `hotfix/margin-cherrypick-beta` orphaned because the dev cherry-pick swept to beta via PR #268 the same day.
- **`scripts/test-pk-v2.4.3.sh`** — new test harness covering: `pk install --force` re-links a valid symlink, `pk_linear_get_state` helper presence, `cmd_done` / `cmd_promote` `--confirmed` arg parsing, and end-to-end UAT-refusal trigger + bypass via a stubbed `pk_linear_get_state`. 9 assertions, network-free (Linear lookups stubbed inside subshells).
- **`bin/pk cmd_help`** — adds `--confirmed` to the `pk done` and `pk promote` synopsis lines.
- **`skills/pipekit-update/skill.md`** — new Phase 0 auto-detects upstream vs downstream mode by `git remote get-url origin` + sentinel files (`method.md` + `CHANGELOG.md` + `bin/pk`). Upstream mode (running inside the Pipekit repo itself) does `git fetch --tags && git checkout <tag>` + `pk install --force`; downstream mode keeps the existing `sync-method.sh` flow. Same `/pipekit-update v2.4.3` command works on both: a machine where `~/.local/bin/pk` symlinks to a consumer project's `bin/pk` AND a machine where it symlinks to the Pipekit clone itself. `--push` refuses in upstream mode (incoherent). Closes the multi-machine update divergence — every machine runs the same incantation.
- **`PK_VERSION`** 2.4.2 → 2.4.3.

### Why

The v2.4.2 doc gate (Stage 3 + RUNBOOK [5e] + `/work`/`pk-exit` "does NOT do") is the right gate for normal use, but the empirical failure mode is an LLM session auto-chaining past prose. Doc gates rely on the model reading and respecting natural language; code gates rely on `exit 1`. Belt-and-braces. The same week the v2.4.2 doc gate landed, the v2.3.3 state-ladder gate (a code gate that DID exist) silently bypassed itself because the user's installed `pk` was old — surfacing the lag-bug that `sync-method.sh` now warns on. Both classes of failure now have explicit code-level guards.

### Migration

None for consumers. Re-run `./scripts/sync-method.sh v2.4.3` in consumer projects. After sync:

- `pk version` returns `2.4.3`
- `pk done <ID>` refuses with a clear message when the issue is in UAT — pass `--confirmed` once UAT is signed off
- `pk promote <env>` refuses when any bundled issue is in UAT — pass `--confirmed` to override
- `pk install --force` always re-links, even on valid symlinks (no more silent no-op)
- `./scripts/sync-method.sh` warns when `~/.local/bin/pk` differs from the synced `bin/pk`; add `--auto-install` for unattended sync

### What this fixes (anchor incidents from 2026-05-13)

- **WIT-451 worker auto-firing `pk done` mid-UAT** → `cmd_done` UAT refusal
- **Same root, narrower** → `cmd_promote` UAT refusal on bundled issues
- **PR #270 / WIT-275 false transition: state-ladder gate didn't fire because installed `pk` was v2.3.2** → `sync-method.sh` install-lag warning + `--auto-install`
- **Pendragon `pk install --force` silent no-op** → `cmd_install` force/symlink fix
- **WIT-455 orphaned `hotfix/margin-cherrypick-beta` branch** → `sop/Git_and_Deployment.md` hotfix nuance

### Tests

```
bash scripts/test-pk-promote.sh   # 25 assertions (v2.3.3 ladder + missing-target guard)
bash scripts/test-pk-config.sh    # 14 assertions (pk_config parsing)
bash scripts/test-pk-v2.4.3.sh    #  9 assertions (v2.4.3 additions)
```

---

## v2.4.2 — 2026-05-13

> Patch: daily-loop discipline polish. Five doc-only fixes from the WIT-451 canary that ran today against Piper. Closes the "implicit UAT gate" and "auto-cascade past UAT" failure modes, plus two `/spec-preflight` Phase 3.6 false-positive reductions and a `/work` rule that auto-files follow-up WITs when a documented Risk-fallback is invoked.

### What changed

- **`method.md` Stage 3 + Stage 4** — Stage 3 renamed "Verify + Ship + UAT" so the UAT step is named, not implied. Adds the gate-clause: `pk done` and `pk promote` MUST NOT run until UAT signs off AND the PR merges. Stage 4 reframes both as "Deliberate human step — must NOT be auto-invoked by `/work`, `/verify`, `/pk-exit`, or any session-automation skill." Both anchor on the WIT-451 canary 2026-05-13 ("the worker session auto-fired `pk done` mid-test and wiped the worktree").
- **`RUNBOOK.md` flowchart** — new explicit `[5e] Interactive UAT` box between PR review and merge, with the no-auto-chain rule inline so future readers don't need to re-derive it from `method.md`.
- **`skills/work/skill.md` "What this skill does NOT do"** — adds two explicit bullets: "No `pk done` invocation, ever" and "No `pk promote` invocation, ever." Names the WIT-451 canary as the anchor incident. Tightens what the worker session is allowed to do at completion.
- **`skills/pk-exit/skill.md`** — new "What this skill does NOT do" section with the same two bullets + "No Linear state writes." Closes the secondary path the worker session could have used to chain past UAT.
- **`skills/work/skill.md` Step 6.5 Risk-fallback follow-up filing** — MANDATORY clause when a documented `R<N>: Mitigation` clause was invoked during implementation. Worker now must (1) identify the deferred scope, (2) `mcp__claude_ai_Linear__save_issue` to file the follow-up WIT in Approved state, (3) reference the new WIT-ID in the hand-off, (4) update parent spec's AC to mark as "partial per R<N>; tracked in <NEW-WIT-ID>". Closes WIT-451's R4 follow-up-rot pattern (dual-field inline NOTE editor only got filed in triage, not at ship time).
- **`skills/spec-preflight/skill.md` Step 3a explicit-NEW marker** — file-paths probe now recognizes `**NEW**`, `(NEW)`, `, NEW`, `(new file)`, "Files to create" section heading, `NEW: <path>` prefix. NEW-marked paths record as `🆕 expected-new` instead of `✗ missing`. Verdict category treats them as `✓`. Eliminates the over-statement false positive on every WIT that legitimately introduces files (WIT-348, WIT-451 each hit this 2-3 times).
- **`skills/spec-preflight/skill.md` Probe 3.6a Strategy-citation downgrade** — Canonical-doc cross-check now scans for inline Strategy citations (`Strategy/Doc<N>`, `Strategy/Doc<N> §<section>`, or an "Authority hierarchy" table naming a Strategy file). If ≥1 inline citation, downgrades `⚠ Cross-check Strategy` → `✓ Canonical docs: cross-check performed in-spec`. Probe still emits `⚠` when POC is mentioned but no inline Strategy citation exists. WIT-451's revised spec was the canonical example that motivated this — fully cited, still drew `⚠`.
- **`PK_VERSION`** 2.4.1 → 2.4.2.

### Why

The WIT-451 canary 2026-05-13 against Piper ran the full v2 daily loop end-to-end and surfaced three procedural gaps. Listed from highest impact down:

1. **No interactive UAT gate.** Stage 3's "Human performs UAT" line was prose-only. The worker session shipped PR #265, auto-merged on green CI, then auto-fired `pk done` and `pk promote beta` in the same ~60-second window while the user was still in the middle of UAT on `dev.withpiper.ai`. The worktree got wiped mid-test. Stage 3 now names UAT as the gate, names `pk done` and `pk promote` as deliberate human steps, and explicitly forbids `/work` and `/pk-exit` from chaining past them.
2. **Worker sessions auto-firing `pk done` / `pk promote`.** Symptom of (1). Both skills now carry explicit "no pk done, ever / no pk promote, ever" bullets that name the anchor incident.
3. **Risk-fallback follow-up rot.** WIT-451's spec documented R4 ("if the dual-field inline cell editor proves brittle, fall back to NOTE-via-modal-only"). The worker correctly invoked the fallback but only filed 2 follow-up WITs, missing the dual-field editor — that one got caught later in triage and became WIT-454. Step 6.5 of `/work` now makes the follow-up filing mandatory when an `R<N>: Mitigation` clause is invoked.

Two adjacent Phase 3.6 probe-polish items also surfaced:

4. **NEW-file false positives.** WIT-348 (3 NEW files) and WIT-451 (3 NEW files) each drew `⚠ File paths: N/M exist (missing: ...)` warnings on paths the spec explicitly marked NEW. Verdict noise that erodes signal.
5. **Strategy-citation false positives on Probe 3.6a.** WIT-451's revised spec cited Strategy/Doc6 §2.1, §3.3, and Doc2 §3.3.1 throughout, with an explicit Authority hierarchy table — and the probe still emitted `⚠ Cross-check spec claims against Strategy` because the trigger fired blindly. Downgrade closes the false positive.

All five are docs-only, low-blast-radius. A deeper code-level guard for (1) and (2) — `pk done` refuses when Linear state is `UAT` and a `--confirmed` flag isn't passed — is deliberately deferred to v2.4.3, after the doc gate has run in practice.

### Migration

None. Re-run `./scripts/sync-method.sh v2.4.2` in consumer projects. After sync:

- `pk version` returns `2.4.2`
- `method.md` Stage 3 / Stage 4 + `RUNBOOK.md` flowchart reflect the named UAT gate
- `/work` and `/pk-exit` carry explicit "no pk done / no pk promote" bullets
- `/spec-preflight` Phase 1 + Probe 3.6a emit fewer false positives on real specs

### What this fixes (canary findings)

- **WIT-451 canary finding "implicit UAT gate"** → method.md Stage 3 + Stage 4 + RUNBOOK.md [5e]
- **WIT-451 canary finding "worker session auto-fired pk done / pk promote"** → /work + /pk-exit "does NOT do" sections
- **WIT-451 canary finding "R-fallback follow-up filed only at triage time"** → /work Step 6.5 mandatory clause
- **WIT-451 + WIT-348 finding "NEW-file false positives"** → /spec-preflight Step 3a
- **WIT-451 finding "Strategy cited inline but probe still warned"** → /spec-preflight Probe 3.6a downgrade

### Deferred to v2.4.3

- Code-level guard in `bin/pk cmd_done`: refuse when Linear state is `UAT` unless `--confirmed` flag passed. Belt-and-suspenders with the v2.4.2 doc gate.
- Same for `cmd_promote` when source-branch issues are still in UAT.

---

## v2.4.1 — 2026-05-13

> Patch: `/linear-todo-runner` creates real worktrees explicitly. Closes the empirically-observed "Agent isolation:`worktree` parameter is a no-op" failure mode where 4 parallel agents collapsed into one shared checkout and trampled each other's uncommitted work via branch switches.

### What changed

- **`skills/06-linear-todo-runner/skill.md` Phase 3 worktree creation** — the orchestrator now runs `git worktree add <path> -b <branch> <BASE>` before each Agent spawn. Worktree path is interpolated into the worker prompt as a concrete value (the Agent tool exposes no `cwd` parameter).
- **Worker first-action verification** — the spawned worker must `cd <WORKTREE_PATH>` then run a 4-way check (`pwd`, `git rev-parse --show-toplevel`, `git rev-parse --abbrev-ref HEAD`, `git worktree list`). Any mismatch halts the worker before any edits and reports the actual output — prompt-level `cd` + verification is now the actual containment mechanism, not optional.
- **Preflight against path/branch collision** — refuses to start a worker if `WORKTREE_PATH` or `BRANCH_NAME` already exist; logs the collision in a Linear comment, moves the issue back to Approved, continues with the next queue item. Eliminates the "blended diff" failure mode where re-runs trampled prior partial work.
- **Phase 4 cleanup asymmetry** — on success, `git worktree remove <path>` clears the worktree (with `--force` documented for cases where the worker leaves untracked files); the branch stays for PR creation. On failure, both the worktree and the branch are preserved for forensic inspection; the user cleans up after triage.
- **Worker prompt template** — outer fence now uses 4 backticks so the inner `` ```bash `` verification block nests cleanly. Worktree path and branch name passed as concrete values, not placeholders.
- **Prerequisites + Related Skills sections updated** — explicitly document that `isolation: "worktree"` is a no-op on current harnesses; runner uses sibling `../<repo>-<id>` worktree paths, distinct from `pk branch`'s in-repo `.worktrees/<ID>-<slug>/` pattern, so the two coexist without fighting over paths.
- **`PK_VERSION`** 2.4.0 → 2.4.1.

### Why

Empirically observed on 2026-05-13 while running `/linear-todo-runner` against rs-vault: 4 parallel agents spawned with `isolation: "worktree"` collapsed into one shared checkout. Sibling branch switches inside that shared checkout silently discarded each other's uncommitted work — the workers produced a "blended diff" where each agent's final state contained fragments of every sibling's work overlaid by the last branch switch.

Root cause: the Agent tool's `isolation: "worktree"` parameter is accepted but does not honor on current harnesses — there's no actual worktree provisioned, just the shared parent cwd that the workers race over. The Agent tool also exposes no `cwd` parameter, so neither path of "containment" the original skill assumed actually exists. The fix moves containment to the orchestrator's pre-spawn `git worktree add` plus a worker prompt that fails loudly when verification doesn't match.

### Migration

None. Re-run `./scripts/sync-method.sh v2.4.1` in consumer projects. After sync:

- `pk version` returns `2.4.1`
- `/linear-todo-runner` creates real worktrees via `git worktree add` before each agent spawn
- Workers refuse to proceed if the 4-way first-action verification doesn't match — preventing the silent-corruption failure mode
- Failed worker runs preserve both the worktree and the branch for forensic inspection (`git worktree remove <path>` and `git branch -D <branch>` are the manual cleanup once triaged); successful runs clean up the worktree but keep the branch for PR creation
- Preflight collision refusal protects against re-running the same queue across leftover worktrees from prior failed runs

### What this fixes (empirical findings)

- **2026-05-13 rs-vault 4-agent collapse** — Agent tool `isolation: "worktree"` parameter is a no-op → orchestrator now creates real worktrees explicitly and the worker verifies before any edits. Memory entry "Agent isolation:'worktree' broken" anchors this in cross-session context.

### Related notes

If you cannot run `git worktree add` from the orchestrator (e.g., the orchestrator's repo state is non-trivial), the skill now documents `--max-agents 1` (sequential) as the safe fallback. Sequential is slower but immune to the parallel-collapse failure mode.

---

## v2.4.0 — 2026-05-13

> Minor: `/spec-preflight` Phase 3.6 — project signal probing. Closes the "environmental blindness" class of bug surfaced by the WIT-348 Gate 3 canary. Four new probes: canonical-doc cross-check, platform capability, tooling availability, migration data shape.

### What changed

- **`skills/spec-preflight/skill.md`** — new Step 3.6 ("Project signal probes") between Steps 3 and 4. Steps 1–3 verify claims the spec explicitly makes; Step 3.6 probes claims the spec implies by referencing a tool, proposing a platform-specific mechanism, drafting a migration, or anchoring to a non-canonical source. Four probes:
  - **3.6a — Canonical-doc cross-check (#21)** — when the spec body references POC and `Strategy docs path` resolves to an existing dir, surfaces Strategy docs + section hints for cross-check. `⚠` warning (ambiguous; human decides).
  - **3.6b — Platform capability (#20)** — detects GUC patterns (`ALTER DATABASE`, `current_setting`, `app.X`). Hard-fails on managed-supabase (the postgres role lacks `SET DATABASE` privilege even as DB owner). Reads new `Platform` V2 key.
  - **3.6c — Tooling availability (#22)** — detects test runner / quality tool names in ACs (Playwright, Cypress, Jest, Vitest, Storybook, Lighthouse, ESLint, Prettier, MSW, Testing Library). Greps repo-root + workspace `package.json` files for the corresponding package names. Hard-fails when AC requires a tool that isn't in `dependencies` or `devDependencies`. Auto-downgrades to warning when the same AC text acknowledges the gap ("to be added", "follow-up", "next phase").
  - **3.6d — Migration data shape (#24)** — scans cited migration SQL for new `CHECK`, `NOT NULL`, type-narrowing, and column renames. Builds inverse-predicate `SELECT COUNT(*)` queries. Executes against the parent project via any bound `mcp__supabase-*__execute_sql` tool (read-only); otherwise surfaces the query templates. `⚠` warning with the violator counts (or templates).
- **`skills/spec-preflight/skill.md` `--accept` flag** — downgrade Phase 3.6 hard-fails (`✗`) to warnings (`⚠`) for accepted-risk cases. Findings still appear; only the blocking verdict softens. Phase 1–3 hard-fails remain blocking (`--accept` does not bypass empirical claim divergence).
- **`skills/spec-preflight/skill.md` verdict block** — now sectioned: "Empirical claims (Phase 1–3)" and "Project signal probes (Phase 3.6)". New output examples include the WIT-348 canary pattern (Strategy cross-check + Playwright tooling miss + migration data-shape probes firing simultaneously).
- **`method.config.template.md`** — new `Platform` V2 key (values: `managed-supabase`, `self-hosted-postgres`, `none`; default `none`). `Migration dir` "Used by" column extended to call out `/spec-preflight` Probe 3.6d.
- **`PK_VERSION`** 2.3.3 → 2.4.0.

### Why

The v2.3.x recovery established that Pipekit had two distinct classes of "trust but never verify" bug. v2.3.2 fixed parser blindness (`pk_config` returned defaults silently); v2.3.3 fixed promote-chain blindness (target branch and Linear ladder). v2.4.0 fixes the remaining class: environmental blindness — the spec is internally coherent and passes the Spec Review Agent, but it references tooling that isn't installed, a platform mechanism the deployment doesn't support, or a column model that contradicts the project's canonical Strategy docs. Every downstream gate (plan-reviewer, `/verify`, QA subagent) reads the spec body as ground truth; none of them re-check spec-vs-reality at the surroundings layer. The Gate 3 canary surfaced all four probe gaps in a single WIT (WIT-348):

- **#21 (Strategy cross-check)** — spec claimed 5 lifecycle date fields with "parity with POC" framing. Strategy/Doc1 §3.1 + Strategy/Doc2 §3.2.3 define **6** fields with engagement-default scoping. Without the canonical-doc probe, `/light-spec` and every downstream gate would have shipped the wrong column set.
- **#22 (Tooling)** — an AC required Playwright; `@playwright/test` was not in `package.json`. The AC was unsatisfiable as written; the `/work` agent had to invent a Vitest substitution mid-execution.
- **#20 (Platform)** — WIT-450's prod-safety mechanism used `ALTER DATABASE postgres SET app.is_prod`; managed Supabase blocked the write with `42501: permission denied` at deploy-time, forcing a redesign to a sentinel-table pattern. The capability mismatch was knowable from the platform fact alone.
- **#24 (Migration data shape)** — per-PR branch DBs run with `with_data: false`, so the migration's chronological `CHECK` constraint passed CI three times. At apply-time against populated piper-dev, 1 row violated `show_end_date <= onsite_end_date` because `end_date → show_end_date` and `wrap_date → onsite_end_date` reversed the natural project-closure ordering.

All four are "the project has the answer; the toolchain didn't apply it." Phase 3.6 puts the probes at the earliest gate (`/spec-preflight`) so the spec author resolves divergence once, before downstream agents lock in.

### Migration

Optional. Re-run `./scripts/sync-method.sh v2.4.0` in consumer projects to pick up the updated `spec-preflight` skill and template. After sync:

- `pk version` returns `2.4.0`
- `/spec-preflight PROJ-XXX` emits a Phase 3.6 section in the verdict block. Probes that don't match the spec content render as `n/a` — projects with no GUC patterns / no Strategy dir / no migrations see the same flow they had pre-v2.4.0 plus four `n/a` lines.
- Optional `Platform: managed-supabase` (or `self-hosted-postgres`) in `method.config.md` enables hard-fails on platform-incompatible GUC designs. Leave blank for projects without DB or with non-Postgres backends.
- `/spec-preflight PROJ-XXX --accept` downgrades Phase 3.6 hard-fails to warnings (for tooling intentionally absent / to be bootstrapped later). Phase 1–3 hard-fails remain blocking.

### What this fixes (loop-notes references)

- **#20** Managed-Supabase blocks GUC parameter writes → Probe 3.6b refuses GUC-based prod-safety designs at spec time (reads `Platform` config key)
- **#21** `/spec-preflight` doesn't cross-check `Strategy/*` canonical docs → Probe 3.6a surfaces Strategy docs + section hints when spec references POC
- **#22** `/spec-preflight` doesn't probe test-runner / tooling availability → Probe 3.6c grep `package.json` for every tool mentioned in an AC; hard-fails when absent
- **#24** Per-PR branch DBs lack production data; migrations pass CI then fail at apply-time → Probe 3.6d scans migration SQL for CHECK/NOT NULL/rename/narrowing, builds inverse-predicate SELECT COUNT(*) queries, runs them via Supabase MCP when bound

### Deferred to future patches

Piper-side infra items (#23 dev migration CI, #26 branch protection, #27 SessionStart `gh auth` hook) are tracked downstream in the Piper repo — they are project-specific operational hardening, not Pipekit upstream changes.

---

## v2.3.3 — 2026-05-13

> Patch: `pk promote` correctness. Refuses when the target branch is missing on origin instead of exiting 128 silently; respects the Linear workflow ladder instead of force-transitioning every bundled WIT to the env's mapped state.

### What changed

- **`bin/pk` `cmd_promote` missing-target guard** — runs `git ls-remote --exit-code origin refs/heads/$target` after target validation. On miss, refuses with an actionable error containing the exact `gh api -X POST repos/<owner>/<repo>/git/refs` recovery command (owner/repo derived from the origin URL). New `--bootstrap` flag auto-recreates the branch at `origin/<source>` tip via `gh api`.
- **`bin/pk` `pk_state_rank`** (new helper) — ranks Linear workflow states along the canonical ladder (`Triage` < `Ideas` < `Future Phases` < `On Deck` < `Needs Spec` < `Specced` < `Approved` < `Building` < `In Progress` < `UAT` < `Released` < `Done`). Unknown states return 0 (preserves current behavior for projects with custom workflows); `Canceled` / `Duplicate` outrank `Done` (never promote forward).
- **`bin/pk` `pk_linear_set_state` ladder gate** — opt-in `mode="advance"` argument. When set, refuses backward transitions (logs "already at <state> (skip backward transition)") and refuses Approved-or-earlier → Released/Done leap-frogs (logs a loud warning to stderr; commits made it into a promote bundle without UAT verification).
- **`bin/pk` `cmd_promote` issue-loop** — passes `"advance"` mode to `pk_linear_set_state`. Bundled WITs only move forward along the ladder; the audit trail stays monotonic across cycles.
- **`scripts/test-pk-promote.sh`** (new) — fixture-based bash harness. Asserts pairwise ladder ordering, unknown-state fallback, terminal-off-ladder behavior, `git ls-remote --exit-code` semantics, and owner/repo extraction from both https and ssh origin URLs. 25 assertions; run with `bash scripts/test-pk-promote.sh`.
- **`PK_VERSION`** 2.3.2 → 2.3.3.

### Why

The v2.3.1 recovery Gate 3 canary (WIT-348, closed 2026-05-13) surfaced 8 new findings. Two were direct regressions of the promote chain that v2.3.2 was supposed to stabilize:

- **#25** — `pk promote beta` exited 128 with zero diagnostic output when `origin/beta` was missing. Root cause: `git fetch origin beta --quiet || true` swallowed the "couldn't find remote ref" message and masked the non-zero exit; the downstream `git log origin/beta..origin/dev` then exited 128 on the unknown revision. Without `bash -x`, the failure mode is essentially undebuggable. (The branch went missing because GitHub's repo-level auto-delete-on-merge removed it when a previous beta→main PR merged — handoff finding #26, fixed Piper-side via branch protection.)
- **#28** — `pk promote beta` force-transitioned every WIT mentioned in commit messages to the env's mapped state, regardless of current Linear state. In the canary, this pulled 3 already-Done WITs backward to Released and leap-frogged 1 Approved WIT straight to Released, skipping Building/In Progress/UAT entirely. Audit-trail integrity loss compounds per cycle — the next `pk promote main` would have force-moved the Released WITs back to Done, producing a "shipped → unreleased → shipped" lifecycle on three issues that never actually un-shipped.

Both regressions fired on the first real canary use. v2.3.2 happened to have `origin/beta` bootstrapped, so #25 (a direct regression of canary 3's loop-note #16) was deprioritized as parallel-track; v2.3.3 folds it in.

### Migration

None. Re-run `./scripts/sync-method.sh v2.3.3` in consumer projects. After sync:

- `pk version` returns `2.3.3`
- `pk promote <env>` refuses loudly when the target branch is missing on origin (instead of exiting 128 silently)
- `pk promote <env> --bootstrap` recreates the missing target branch at the source tip via `gh api`
- `pk promote <env>` only transitions Linear issues forward along the workflow ladder; backward and leap-frog attempts log and skip without mutating Linear state
- `bash scripts/test-pk-promote.sh` exits 0 (25 assertions)

### What this fixes (loop-notes references)

- **#25** `pk promote` silent exit 128 on missing target branch → fixed (`git ls-remote` guard + `--bootstrap` flag)
- **#28** `pk promote` force-transitions bundled WITs ignoring Linear state → fixed (ladder gate in `pk_linear_set_state` via opt-in `mode="advance"`)

### Deferred to a future patch

The Gate 3 canary also flagged `/spec-preflight` capability gaps (#20 managed-Supabase GUC probe, #21 canonical `Strategy/` cross-check, #22 test-runner/tooling availability, #24 migration data-shape probe) and three Piper-side infra items (#23 dev migration CI, #26 branch protection, #27 SessionStart `gh auth` hook). The `/spec-preflight` Phase 3.6 capability-probing extension lands in a separate Pipekit PR; the Piper-side items are tracked downstream.

---

## v2.3.2 — 2026-05-12

> Patch: closes the v2.3.1 canary cascade. `pk_config` reads the actual code-block config format; `pk config` subcommand exposed; `/verify` skill stops self-terminating; `pk done` no longer destroys its own CWD.

### What changed

- **`bin/pk` `pk_config` parser** — accepts plain `Key: Value` inside fenced code blocks (the format every consumer actually uses, per `method.config.template.md` lines 162-180) in addition to the legacy markdown-table form. Code-block matched first; table is the fallback. Restores correct values for `Backend`, `Integration branch`, `Ship environments`, `Require QA review`, and every other V2 key.
- **`bin/pk config <key>` subcommand** — added. Plain-value output for `$(pk config K)` substitution. No-arg form dumps all known V2 keys + resolved values. `pk cfg` is an alias. Skills now have one place to read config.
- **`bin/pk` sourceability** — bottom-of-file `main "$@"` guarded with `[ "${BASH_SOURCE[0]}" = "${0}" ]` so test harnesses can `source bin/pk` to exercise helpers directly.
- **`scripts/test-pk-config.sh`** (new) — fixture-based bash harness. Asserts `pk_config` against code-block style (Piper, rs-vault), legacy markdown-table, missing-key + default, and malformed blank-value. 14 assertions; run with `bash scripts/test-pk-config.sh`.
- **`skills/verify/skill.md`** — Step 0 + Step 3b replace the markdown-table `grep` for Integration branch with `pk config "Integration branch"` (one source of truth). Step 2's awk gate-extractor no longer self-terminates: the start regex uses `next` so the end pattern only evaluates on subsequent lines, restoring the bash block extraction that v2.3.1 silently broke.
- **`bin/pk` `cmd_done` worktree refusal** — prefix-matches CWD against the worktree path via `pwd -P`, refusing for *any* nesting level (subdirs included), and runs before posting Linear comments or computing diffs so refused runs leave no side effects.
- **`PK_VERSION`** 2.3.1 → 2.3.2.

### Why

The v2.3.1 canary (WIT-280 in Piper, closed 2026-05-12) surfaced 19 findings. One root cause — `pk_config` matched only markdown-table rows, never the `Key: Value` code-block format documented in `method.config.template.md` — silently returned defaults for every V2 key in every consumer project. `pk promote beta` refused with "not a valid target" because `Ship environments` read as the default `dev,main` instead of Piper's `dev,beta,main`. `Backend: auto` read as `vbw`. `Require QA review: true` read as `false`. `pk ship` and `pk branch` accidentally kept working because `pk_integration_branch` had a separate fallback chain.

Three downstream findings rode the same parser blind spot: `/verify` Step 0's Integration-branch grep (#3) and Step 2's awk gate-extractor (#4) — the awk used `/^## Pre-Deploy Gate/,/^## /` which self-terminated on its own start line, emitting an empty gate. And `pk done`'s late, exact-match CWD check (#13/#14) destroyed the running Claude session's working directory when called from inside the worktree's subdirectories.

This patch closes the cascade plus adds a test harness so the silent-default class of bug cannot recur unnoticed.

### Migration

None. Re-run `./scripts/sync-method.sh v2.3.2` in consumer projects. After sync:

- `pk version` returns `2.3.2`
- `pk config Backend` returns the actual configured value (e.g. `auto`) in projects that use the code-block V2-key format
- `pk promote <env>` works for any project with a multi-env `Ship environments` chain
- `pk done` from inside the worktree (or any subdirectory of it) refuses with a clear error instead of destroying the CWD

### What this fixes (loop-notes references)

- **#15** `pk_config` parser blind to code-block format → fixed
- **#2** No `pk config` subcommand → added (with `cfg` alias)
- **#3** `/verify` Step 0 Integration-branch parser → routed through `pk config`
- **#4** `/verify` Step 2 awk self-terminates on start line → corrected (`next` after start match)
- **#13** `pk done` exact-match CWD check skipped subdirs → prefix-match via `pwd -P`
- **#14** `pk done` side-effect ordering destroyed CWD partway through cleanup → refusal moved above side effects

---

## v2.3.1 — 2026-05-09

> Patch: `RUNBOOK.md` is now synced into consumer projects.

### What changed

- **`scripts/sync-method.sh`** — adds `RUNBOOK.md` to the synced doc set alongside `method.md`, `GUIDE.md`, and `STARTUP.md`. Three edits: header comment listing what syncs, `sync_file` invocation, and the post-sync changelog comparison loop. Consumer projects now get `pipekit/RUNBOOK.md` populated and kept up-to-date on each sync.
- **`PK_VERSION`** 2.3.0 → 2.3.1.

### Why

`RUNBOOK.md` exists in pipekit's main repo as the one-page operational doc — the canonical daily-loop flowchart. Until v2.3.1 it was never synced, so consumer projects had `pipekit/method.md` (deep methodology, ~700 lines) and `pipekit/GUIDE.md` (full manual, ~1200 lines) but no one-pager for daily reference. Surfaced during Piper's v2.3.0 sync canary (PR #242 on piper).

`method.md` line 5 self-describes the relationship: "RUNBOOK is the canonical one-page operational doc; this document is the deeper methodology." Both have distinct, non-overlapping roles. Adding RUNBOOK to the sync gives consumers the daily-use surface.

### Migration

None. Re-run `./scripts/sync-method.sh v2.3.1` and `pipekit/RUNBOOK.md` lands in your project's `pipekit/` folder.

---

## v2.3.0 — 2026-05-09

> State machine maps 1:1 to environment. New `Released` Linear state for 3-tier projects. `pk promote` walks `Ship environments` one hop per call. `pk done` is cleanup-only.

### What changed

- **`bin/pk` cmd_promote rewritten** (PR #76) — `pk promote <env>` walks `Ship environments` one hop per invocation. Validates target against the chain, derives source from chain position, opens source→target PR, transitions matching issues optimistically at PR-open time. Position-based state mapping: last env in chain → **Done**, any non-final → **Released**. 2-tier backwards-compat: `pk promote` with no arg auto-picks the only hop. Preserves `--stash` / `--take-remote` conflict handling.
- **`bin/pk` cmd_done strip-down** (PR #76) — removed the `pk_linear_set_state ... "Done"` call. `pk done` is now **pure cleanup**: removes worktree, deletes branch, posts commits + diffstat to Linear. State movement is owned entirely by `pk ship` (→ UAT) and `pk promote` (→ Released / → Done). A worktree closing does not mean the issue is shipped.
- **`bin/pk` v2.2.2 fixes folded in** (PR #75) — `pk verify` parser rewrite (awk section-extractor; removes gate-must-be-last constraint and the silent 10-command truncation cap); `pk doctor` Linear error surfacing (parses `userPresentableMessage` / `.message` from GraphQL responses; falls through to truncated body snippet; distinct "no response" branch for network failures); `pk branch` honors `Worktree prefix` from `method.config.md` (defaults to `${root}/.worktrees/`; trailing char in prefix value controls join style).
- **Help text + headers** — `bin/pk` header comment block, `cmd_help` table, and inline `pk` echo strings all updated to reflect new transitions and the `pk promote <env>` target-arg form.
- **`method.config.template.md`** — Released row added to Workflow State IDs table. Two-tier and three-tier release-flow sections rewritten with new transition semantics. (PR #76 + #78.)
- **`sop/Linear_SOP.md`** — pipeline diagrams (Planned + Ad-hoc), state-meaning table, key transitions, and fast-track paths updated to include Released. Explicit note: `pk done` is cleanup-only and does NOT transition state. (PR #76.)
- **`sop/Git_and_Deployment.md`** — Step 5/6 docs use `pk promote <env>` (primary). Linear-transitions lines for both 2-tier and 3-tier rewritten. Pre-deploy gate sub-section updated. (PR #78.)
- **`sop/Skills_SOP.md`** — `pk done` and `pk promote` rows updated. (PR #77.)
- **Constitutional docs aligned** — `method.md`, `RUNBOOK.md`, `GUIDE.md`, `STARTUP.md`: version stamps bumped from v2.1.2 → v2.3.0; pipeline tables, flowcharts, and walkthroughs reflect Released state and the new pk done / pk promote semantics. (PRs #77, #78, #79.)
- **Templates** (`templates/tier-{quick,standard,heavy}.md`) — close-path lines rewritten to reflect cleanup-only `pk done` and target-arg `pk promote <env>`. (PR #78.)
- **Skills updated** — `skills/linear/skill.md` (Phase 4 step 3 documents 2-tier vs 3-tier transitions); `skills/sync-linear/skill.md` (workflow status ladder includes Released); `skills/task-processor/skill.md` (adds Released as a state option); `skills/pr-fix/skill.md` (visibility-gap description includes Released). (PR #78.)
- **`PK_VERSION` 2.1.3 → 2.2.2 → 2.3.0** — caught a pre-existing version drift (PR #75) and bumped through to current.

### Why

The v1 → v2 daily loop validated end-to-end on Piper (May 2026 migration), but two structural problems surfaced during the canary:

1. **`pk done` was 3-tier-blind** — it transitioned issues to Done unconditionally on merge to the integration branch (e.g. `dev`). For 3-tier projects (Piper, any team-with-QA project), this lied about issue status: the code was still on `dev`, awaiting beta and main promotions. Workaround was a manual revert to UAT after every `pk done`. Filed as Loop-Notes finding #6.
2. **`pk promote` was hardcoded single-hop** — opened `--base main --head $integration` directly, skipping any intermediate environments. For 3-tier projects, `pk promote` was effectively a no-op for `dev → beta` and a misuse risk for `dev → main`. Filed as Loop-Notes finding #8.

Both problems share a root cause: the v2 design hadn't fully committed to "state tracks WHERE in the pipeline." With state mapped 1:1 to environment (UAT = on dev, Released = on beta, Done = on main), Linear's state always reflects reality. No more "Done then revert" pingpong on intermediate hops. `pk done`'s pre-v2.3.0 state-transition responsibility evaporates — state movement belongs entirely to `pk ship` (the one transition into the deploy chain) and `pk promote` (each subsequent hop).

This is the load-bearing simplification: `cmd_done` shrinks, `cmd_promote` carries all promotion-state logic, and the contract becomes legible — "the command's invocation is the trigger; state moves at PR-open optimistically; `pk done` is just cleanup."

### What this fixes

- **3-tier `pk done` lying about status** — gone. State stays UAT through any number of intermediate hops; `pk promote main` is the only command that can mark Done.
- **3-tier `pk promote` skipping environments** — gone. `pk promote <env>` walks one hop, validates against `Ship environments`, refuses skip-ahead.
- **State-machine ambiguity** — Linear's state and the deploy reality now diverge only when a promote PR is closed without merging (rare, recoverable by manual state revert).
- **Project portability** — position-based state mapping (last hop → Done, else → Released) means projects can use any env names, not just `dev,beta,main`. `develop,staging,production` works identically.

### What this breaks

**Backwards-compat preserved for 2-tier projects.** `pk promote` with no arg still works there — auto-picks the only hop in `Ship environments`, transitions directly to Done. Released is unused on 2-tier.

**3-tier projects must:**
1. Add a **Released** Linear state (type: `started`) between UAT and Done. Capture the state UUID.
2. Add the UUID to `method.config.md` Workflow State IDs.
3. Switch from `pk promote` (no arg) to explicit `pk promote <env>` invocations.

If a 3-tier project syncs v2.3.0 before adding Released, intermediate `pk promote <env>` calls fail-soft per issue: "Released state not configured — add it via Linear UI + method.config.md, then re-run." Final-hop promotes (`pk promote main` → Done) continue working unchanged.

### Migration

Per consuming project:
1. Add `Released` state via Linear UI (type `started`, position between UAT and Done). Capture state UUID.
2. Update `method.config.md` Workflow State IDs table — add `| Released | <uuid> |` row.
3. Run `./scripts/sync-method.sh v2.3.0`.
4. (3-tier only) Update consumer-side SOPs that reference `/g-promote-*` or single-hop `pk promote` to use `pk promote <env>` form.
5. First canary: `pk promote beta` on the next real Linear issue.

### Cross-references

- PR #75: v2.2.2 — `pk verify` / `pk doctor` / `pk branch` fixes
- PR #76: v2.3.0 — `cmd_promote` rewrite + `cmd_done` strip + Released state
- PR #77: docs alignment pass 1 (constitutional docs + Skills_SOP)
- PR #78: docs alignment pass 2 (Git_and_Deployment + templates + skills)
- PR #79: RUNBOOK final-mile alignment

---

## v2.2.1 — 2026-05-09

> Patch: stop wiping project-local agents on sync.

### What changed

- **`scripts/sync-method.sh` agents sync** — replaced `sync_dir --delete` with per-file `sync_file` over upstream agent files. Project-local agents in `.claude/agents/` (e.g., `code-reviewer.md`, `supabase-reviewer.md`, `{library}-pitfalls.md`) now persist across syncs.

### Why

Surfaced during Piper's v2 canary (PR #235): `rsync --delete` on `.claude/agents/` would have deleted 8 Piper-local agents because upstream pipekit ships only `plan-reviewer.md`. Patched manually in PR #235 by restoring from HEAD; this is the permanent fix. Mirrors the canonical-rules pattern (`README.md`, `pipekit-*.md`), which uses `sync_file` for the same reason — consumers extend `.claude/rules/` and `.claude/agents/` with project-specific files that must survive sync.

### Migration

None. Re-run `./scripts/sync-method.sh v2.2.1` and project-local agents are preserved.

---

## v2.2.0 — 2026-05-09

> Two paired changes: **synced-folder rename** (`method/` → `pipekit/`) and **squash retirement** (merge-commit-only on `main`, squash disabled repo-wide). Breaking changes for consumers — see Migration section.

### What changed — folder rename

- **Sync target folder renamed `method/` → `pipekit/`.** All consumer-side synced content (`sop/`, `templates/`, `method.md`, `GUIDE.md`, `STARTUP.md`, `.sync-changelog.md`) now lands under `pipekit/` instead of `method/`. This Pipekit source repo's layout is unchanged — only the destination path on the consumer side moves.
- **Updated:** `scripts/sync-method.sh` (sync targets, snapshot path, override target paths), `scripts/drift-check.sh` (path filter regex), and all skill docs and templates that reference consumer-side paths (`pipekit-update`, `00-roadmap-review`, `01-light-spec`, `startup`, `templates/overrides-manifest.template.md`, `templates/rules/README.md`, `GUIDE.md`, `README.md`, `method.config.template.md`, `method.md`).
- **Unchanged:** `method.config.md` filename (still at consumer repo root), Pipekit source layout (`sop/`, `templates/`, `method.md` at root of this repo), all override paths under `.claude/overrides/`, `bin/pk`, all skills and agents.

### What changed — merge strategy

- **`scripts/pipekit-configure-repo.sh` rewritten** — repo-level `allow_squash_merge=false`; new `pipekit-main-merge-only` ruleset enforces `allowed_merge_methods=["merge"]` on PRs targeting main. The legacy `pipekit-main-squash-only` ruleset is auto-deleted on re-run.
- **`sop/Git_and_Deployment.md` § Merge Strategy by Hop** — table rewritten. Squash row removed; merge-commit is the enforced strategy for dev → main. Rebase or merge-commit are both fine for feature → dev.
- **`bin/pk` reminders updated** — `pk ship` no longer tells you to squash on main; `pk promote` PR body and prompt updated to "Create a merge commit."
- **`RUNBOOK.md`, `method.md`, `STARTUP.md`, `GUIDE.md`** — all "squash" references updated to reflect the new policy.

### Why — folder rename

`method/` was generic and confusing — both Pipekit and consumer projects used "method" interchangeably, with no signal about ownership. Renaming the synced folder to `pipekit/` makes ownership immediately legible: `pipekit/` is upstream content (don't hand-edit; gets overwritten on sync). Pairs cleanly with whatever the consumer chooses to name its own engineering workspace folder (e.g., `engineering/` for piper, `local/` for rs-vault).

The rename also eliminates a long-standing collision risk for consumers with a pre-existing `method/` folder (notably Piper, which had Piper-flavored v1 method docs there from the era when Pipekit was extracted from Piper). Sync now writes to a fresh `pipekit/` and leaves any pre-existing `method/` alone for manual dissolution.

### Why — merge strategy

v1.7.0 banned merge-commits everywhere. v1.8.0.6 reversed: rebase/merge for feature → dev, squash for dev → main. **Both schemes hit phantom conflicts in production.** Piper's `nebula-piper-migration-handoff.md:282` documents the v1.8.0.6 failure ("GitHub squash ruleset breaks parent linking. Every promote re-conflicts on files added on both sides"); rs-vault hit the identical trap on PR #173 / #175 in May 2026.

The misdiagnosis: prior versions believed "merge-commits on main cause phantom conflicts." Squash on main causes them — by collapsing N atomic dev commits into one orphan commit on main, the next promote's merge-base finds two divergent histories that both modified the same files relative to the common ancestor. Merge-commits prevent the divergence: dev's atomic commits flow onto main with stable SHAs.

The cleanup-via-squash use case (collapse messy WIP commits) doesn't apply: Pipekit's discipline rules already enforce "one atomic change per commit," and vbw-dev makes atomic commits per task. Squash was throwing away useful bisect/blame information for an aesthetic linear-history preference. `git log main --first-parent` gives the squash-equivalent view (one entry per merged PR) without the cost.

### What this fixes

- **Phantom conflicts on `pk promote`** — gone. Same SHAs flow feature → dev → main.
- **`git bisect` and `git blame` on main** — newly useful. Today main is a series of squash-mega-commits attributed to whoever clicked the merge button.
- **`git branch -d` after `pk done`** — would now succeed (latent improvement; `pk done` still uses `-D` for safety).

### Migration (consuming projects)

After `./scripts/sync-method.sh v2.2.0`:

```bash
# 1. Folder rename — sync creates pipekit/ alongside any existing method/.
#    - Verify pipekit/ has the canonical content (sop/, templates/, method.md, etc.).
#    - Move any project-specific content out of method/ to its appropriate home
#      (engineering/, .claude/overrides/, Strategy/_decisions/, etc.).
#    - Re-point references in CLAUDE.md, skills, and docs from method/* to pipekit/*.
#    - rm -rf method/ once empty.
#    - method.config.md filename unchanged — no action needed there.

# 2. Merge strategy — re-run the configure script. It will:
#    - Set allow_squash_merge=false at the repo level
#    - Delete the legacy pipekit-main-squash-only ruleset
#    - Create the new pipekit-main-merge-only ruleset
bash scripts/pipekit-configure-repo.sh
```

If you have an open dev → main PR that's hitting a phantom conflict from the prior squash policy, resolve it once with a merge-commit (or close + reopen as a no-ff merge); subsequent promotes will be clean.

For consumers with extensive `method/` customization, see Piper's worked example at `engineering/Pipekit-Migration-Plan.md` for a phased dissolution approach.

---

## v2.1.2 — 2026-05-03

> Session-log redesign: bash Stop hook retired, narrative `/pk-exit` skill restored.

### What changed

- **`/pk-exit` skill (new)** — writes a narrative session log to `Logs/Sessions/<YYYY-MM-DD>_<HHMM>.md` before `/exit`. Captures summary, commits shipped, decisions/findings, outstanding work, optional QA trail. Restores the v1 `/end-session` artifact shape without the v1 baggage. User runs as the last command of every Claude Code session; no auto-trigger (forget = no log, accepted tradeoff).
- **Bash Stop hook retired (`scripts/pipekit-journal-hook.sh` deleted)** — fired on every assistant turn, dumped duplicate commit-list entries to `.pipekit/journal/<branch>.md`, couldn't write narrative anyway. The per-branch journal cache it produced is no longer used.
- **`pk done` reads commits directly from `git log`** for its Linear close comment (was: read from `.pipekit/journal/<branch>.md`). Same Linear output, simpler source of truth, no cache to drift.
- **`pk log` repointed** at `Logs/Sessions/` — shows the latest session log instead of the per-branch journal cat.
- **`pk init` / `pk doctor`** create/verify `Logs/Sessions/` and flag stale Stop-hook artifacts (`scripts/pipekit-journal-hook.sh`, Stop block in `.claude/settings.json`, `.pipekit/journal/`) so consuming projects can clean up post-upgrade.
- **`templates/v2/settings-snippet.json` deleted** — no Stop hook to wire anymore. `pk init` setup steps reduced from 7 to 6.
- **`method.config.template.md`** drops the `Journal in repo` config key (no longer used).
- **`RUNBOOK.md`** updated end-to-end: setup step removed, flowchart shows `/pk-exit → /exit` as the close-of-session sequence, recovery row covers "forgot to run /pk-exit", v1↔v2 table maps `/end-session → /pk-exit`.

### Why

The v2.0 bash Stop hook was structurally wrong on three axes: (1) Stop fires on *every* assistant turn, producing 4-10 duplicate entries per session with the same commit list — see `chore-v2.0.0-cleanup.md` from 2026-05-02 with identical commit blocks 4 times; (2) bash can't write narrative, so the entry was just `git log -5` repeated, missing the decisions/lessons/QA-trail content that made v1 session logs actually useful; (3) the per-branch journal it wrote was a cache of git log, and `pk done` was the only consumer — repointing at `git log` directly removed the entire cache without losing anything.

The v1 `/end-session` skill's session-log shape (compare `rs-vault/Logs/Sessions/2026-04-26_1555.md` vs `.pipekit/journal/chore-v2.0.0-cleanup.md`) was strictly better as a human archive. `/pk-exit` restores that artifact while keeping the v2 simplifications (no NEXT.md write, no branch-status orchestration — `pk next` and `pk done` own those).

### Migration (consuming projects)

After `./scripts/sync-method.sh v2.1.2`:

```
# Remove the Stop hook block from .claude/settings.json (pk doctor will flag it).
# Delete the retired hook script:
rm scripts/pipekit-journal-hook.sh
# Existing .pipekit/journal/ is gitignored and harmless — dies with branches on `pk done`.
# Run pk doctor to confirm Logs/Sessions/ exists; pk init creates it if not.
```

End every Claude session with `/pk-exit` → `/exit`.

---

## v2.1.1 — 2026-05-02

> Notepad convention: replaces retired v1 NEXT.md.

### What changed

- **`pk init` seeds a gitignored `notepad.md`** if one doesn't already exist, and ensures `.gitignore` excludes it. Free-form personal scratch space; never committed.
- **`.gitignore` (pipekit's own)** adds `notepad.md` for pipekit-side development.
- **`method.md` documents the convention** — NEXT.md is officially retired; consuming projects should delete any committed NEXT.md and rely on `pk next` for canonical "what's next?".
- **`pk init` flags stale NEXT.md** if found, suggesting the cleanup command (does not auto-delete — user's call).

### Why

v1's `NEXT.md` was machine-readable state. v2's `pk next` (phase-aware as of v2.1.0) replaces that role. Consuming projects kept editing `NEXT.md` manually as a personal notepad, which created git-status churn + drift from any auto-source. `notepad.md` (gitignored) is the right shape for that use case.

---

## v2.1.0 — 2026-05-02

> Three improvements surfaced during rs-vault Phase 2.5 execution. Same-day v2.0.0 → v2.1.0.

### What changed

- **`/pr-security-review` skill** (new) — security-focused antagonistic PR review for migrations, RLS policies, SECURITY DEFINER functions, GRANT/REVOKE, auth code, and Server Actions on privileged tables. 30+ rubric items across 6 surface categories. Different from `/security-review` (periodic repo audit) and `/pr-fix` (broad PR review). Surfaced by RS-74 (rs-vault saved_searches migration) where neither existing skill fit the security-focused PR-diff need.
- **Phase-aware `pk next`** — reads `## Current Phase:` from `.vbw-planning/PHASES.md`, matches to `linear-map.json` project entry via `Phase X.Y` prefix (handles em-dash vs colon separator drift), groups Linear results by status: In Progress / Approved / Needs Spec, with per-group next-action hints. Surfaces "Other phases: N Approved outside" footer. Falls back to legacy global behaviour when no phase context is available. Surfaced by Phase 2.5 having 6 Needs Spec issues + RS-63 In Progress while old `pk next` reported nothing.
- **Mid-loop Linear visibility for `pk ship --review` + `/pr-fix`** — `pk ship --review` now posts a Linear comment flagging the review-in-flight; `/pr-fix` Phase 6.6 posts a triage-complete summary with fixed/rejected/deferred counts. Closes the gap where Linear sees `In Progress → UAT → Done` but no record of the review/fix cycle's findings.

### v2.1 backlog still open (deferred to v2.1.x or v2.2)

- `resources/` vs `temp/` portable convention + `pk branch` worktree resource sync
- Cross-spec handoff verification at flowchart level (skill prose already shipped in v2.0; flowchart promotion deferred)
- Visual + functional verification step in flowchart (Playwright + diff infra — too big for same-day cut)
- "Defended status quo" guardrail at flowchart level (already in `/work` prose; flowchart promotion deferred)
- `/ship` skill auto-dispatch (subagent boundary — see `temp/ship-skill-spec.md`)

---

## v2.0.0 — 2026-05-02

> Cut to v2 after RS-63 proved the v2 ↔ VBW handshake on a Heavy spike (rs-vault). v1 daily-loop skills retired to `archive/v1-skills/`. v2 is now the canonical Pipekit.

### What changed at the cut

- **`bin/pk` is the dispatcher.** All daily-loop work goes through `pk next / pk branch / pk ship / pk done / pk promote`. Idempotent against Linear+git ground truth.
- **`/work` + `/verify`** replace the v1 launch chain. `/work --backend=vbw|native` chooses execution backend per-invocation.
- **`RUNBOOK.md`** is now the v2 one-page flowchart (was `V2_RUNBOOK.md`). Old runbooks archived.
- **`method.md`** carries a v2 transition banner; full rewrite queued for v2.0.1.

### v1 retirement (skills moved to `archive/v1-skills/`)

`/branch`, `/launch`, `/launch-native`, `/start-session`, `/end-session`, `/linear-status`, `/g-promote-dev`. All replaced by `pk` subcommands or the Stop hook (journal). Stage 0 skills (`/concept`, `/define`, `/strategy-create`, `/startup`, `/roadmap-create`, `/phase-plan`) and orthogonal skills (`/light-spec`, `/brainstorm`, `/pr-fix`, `/sync-linear`, etc.) are unchanged — v2 only retires the daily loop.

### Validation

- rs-vault Phase 1 closeout (RS-25, RS-30, RS-60, RS-61, RS-62) shipped on the v2 loop
- RS-63 (Phase 2.5 Foundation + Search redesign) — Heavy spike, vbw backend, antagonistic review, /pr-fix triage all worked end-to-end
- DB migration auto-apply workflow (`db-migrate.yml` + `db-pr-check.yml`) shipped, secrets verified via dry-run

### Known gaps (v2.0.1)

- `method.md` still references v1 paths (banner added, rewrite queued)
- `sync-method.sh` may copy v1 skill paths — needs audit
- See `RUNBOOK.md § Backlog` for alpha.15-style improvements that didn't land at the cut: phase-aware `pk next`, `resources/` vs `temp/` portable convention, `/ship` skill auto-dispatch

---

## v2.0.0-alpha — 2026-05-01 → 2026-05-02

> Pre-cut development. 14 alphas across two days. v2/main long-running branch.

### What v2 is

A `pk` shell dispatcher + `/work` and `/verify` skills replace the heavy multi-step v1 launch chain. The daily loop is `pk next → pk branch <ID> → /work <ID> → pk ship → pk done → pk promote`. Idempotent at every step; runs from a worktree.

### Highlights across 13 alphas

- **`bin/pk`** — daily-loop dispatcher (next, status, branch, ship, done, verify, promote, log, doctor, delegate). Idempotent + safe to re-run.
- **`/work`** — plan + execute a Linear issue from inside its worktree. Backend-pluggable (`vbw` | `native`), now overridable per-invocation via `--backend=`.
- **`/verify`** — pre-ship validation skill paired with `pk ship --review` for antagonistic code review.
- **Worktree pk-sync** — `pk branch` copies the parent's `bin/pk` into the worktree so feature work always uses the project's pinned dispatcher version (alpha.12).
- **Stop hook** — `scripts/pipekit-journal-hook.sh` writes a per-feature branch journal on every Claude Code Stop event.
- **Short slugs** — `pk_slug` strips stop words and trims to 3 tokens, keeping worktree paths and status bars sane.
- **REST fallback** — `pk_gh_pr_view` and `pk_gh_pr_create` fall through to GitHub REST when GraphQL is rate-limited (alpha.13). Caught the friction of GraphQL exhaustion silently misreading as "PR not found."
- **Linear robustness** — single-line GraphQL queries, minimal field selections, `.env.local` fallback for the API key, team-name filtering on state transitions.

### Alpha.14 (latest)

- `pk install` global installer — symlinks pk onto `$PATH` (`/usr/local/bin` or `~/.local/bin`); idempotent through the installed symlink
- `pk done` richer Linear comment — commits, diffstat, session count, PR link (replaces raw 50-line journal head dump)
- `pk promote --stash` / `--take-remote` flags — resolve local-edit conflicts with incoming dev (today's friction pattern)

### Alpha.13

- gh REST fallback for `pr view` / `pr create` — initially fallback-only, then **inverted to REST-first** after a session-wide GraphQL exhaustion proved the fallback wasn't enough. REST has its own quota bucket; pk no longer burns GraphQL on normal operation
- `/work --backend=vbw|native` per-invocation override
- Brainstorm skills updated for v2 tier routing (`/brainstorm`, `/brainstorm-review`)
- This consolidated changelog entry

### Carried into beta candidates

- Multi-env `pk ship --env=` for Piper-style multi-environment delivery
- Automated subagent dispatch from `pk ship --review` (currently prints invocation)
- `pk done` richer Linear comments from journal highlights
- `pk install` global installer
- Skills directory reorg: `skills/{loop,stage0,orthogonal}/`
- GitHub Actions `pr-review.yml` (CI-side antagonistic review)

### Notes

- v2 is **not** synced via `sync-method.sh` yet — the script's v2 paths exist but consuming projects pull `bin/pk` and the new skills directly.
- The full v2 design rationale lives in `archive/v2-design-2026-05-01/` (5 design docs from the redesign session).

---

## v1.8.2 — 2026-04-30

### Fixes

Four bugs surfaced in the v1.8 code review (v1.7.0..v1.8.1). All Quick-tier fixes, no behavior changes for the happy path.

- **`/start-session`** — Pre-flight `INTEGRATION` resolver was a literal `$(...)` placeholder. The skill couldn't run end-to-end on a feature worktree. Inlined the same fallback chain `/end-session` Step 0a uses.
- **`/end-session`** — Pre-flight B used a no-op `INTEGRATION="$INTEGRATION"` self-assignment with a forward reference to Step 0a. Inlined the resolver so Pre-flight B is self-contained; Step 0a still refines from `method.config.md` afterward.
- **`/g-promote-dev` Step 3** — Bare `$GATE_CMD` only invoked the first command in an `&&` chain; `&&` became a literal arg. Wrapped in `eval` so the shell parses the chain.
- **`/g-promote-dev` Step 5** — Removed misleading "drop the `-u`" advice. `-u` is idempotent; the actual non-fast-forward case was already documented correctly in the next sentence.

### Filed for v1.9.0

Three issues drafted from the same review, deferred:

- `pipekit-configure-repo.sh` hardening — Rulesets PUT preserves bypass actors, auth/admin precheck, error surfacing
- `/g-promote-dev` Linear-state ownership — three skills now transition the same issue; canonical ownership map needed
- `/launch --auto` refactor — define stalemate overlap precisely, fix Revise default ordering, consider state-machine restructure

Drafts in `temp/issue-v1.9-*.md`.

---

## v1.8.1 — 2026-04-30

### What's New

**`/g-promote-dev` ported from project-local copies into Pipekit.** First skill in the `/g-*` port (v1.8.1–v1.8.5). Eliminates divergence between rs-vault's and piper's project-local copies; bug fixes propagate via `/pipekit-update`.

#### `skills/g-promote-dev/skill.md` (NEW)

Parameterized via `method.config.md`. Reads:

- § Linear → Issue prefix (e.g. `RS`, `PROJ`)
- § Linear → Workflow State IDs → In Progress
- § Git Architecture → Integration branch (`dev`)
- § Pre-Deploy Gate
- § Stack → Hosting (`vercel` | `none`), DB push command (e.g. `supabase db push`), Migration dir, Shared DB across environments

Skips capabilities gracefully when stack values are missing (no Vercel? No DB? Skill still works for the PR-only path).

The migration push step (was hardcoded for rs-vault's shared Supabase) is now config-driven:
- If `DB_PUSH_CMD` empty → skip migration step entirely
- If `SHARED_DB=yes` → warn about forward-mutation, default-no on push prompt
- If `SHARED_DB=no` → default-yes on push prompt (separate dev/prod DBs make this safe)

#### `method.config.template.md` — § Stack section (NEW)

New keys for skill parameterization:

| Key | Used by |
|---|---|
| Hosting (`vercel` \| `none`) | `/g-test-vercel`, `/g-deploy` |
| DB push command | `/g-promote-dev` |
| Migration dir | `/g-promote-dev` |
| Production smoke URL | `/g-deploy` |
| Shared DB across environments (`yes` \| `no`) | `/g-promote-dev` |

### Migration

For rs-vault and other consumers with project-local `/g-promote-dev`:

```bash
./scripts/sync-method.sh v1.8.1
```

Pipekit's parameterized `g-promote-dev` will replace the project-local copy. Before running, verify your `method.config.md` has:
- § Linear → Issue prefix ✓
- § Linear → State IDs → In Progress ✓
- § Pre-Deploy Gate ✓
- § Stack section populated (NEW — copy from `method.config.template.md`)

For rs-vault specifically: Stack section should set `Hosting=vercel`, `DB push command=supabase db push`, `Migration dir=supabase/migrations/`, `Shared DB across environments=yes` to preserve current behavior.

If you need to keep the project-local version (e.g. piper hasn't migrated yet), place it at `.claude/overrides/skills/g-promote-dev/skill.md` — sync-method.sh will preserve the override.

### Open items deferred to v1.8.2 – v1.8.5

- v1.8.2: `/g-promote-main` port
- v1.8.3: `/g-test-vercel` port
- v1.8.4: `/g-deploy` port
- v1.8.5: `/g-promote-beta` port (three-tier flows; piper-relevant)

---

## v1.8.0.6 — 2026-04-30 (patch)

### What changed

**Per-branch merge enforcement via GitHub Rulesets.** Earlier patches (v1.7.0–v1.8.0.5) disallowed merge-commits at the repo level to prevent the phantom-conflict trap on `main`. That's machine-safe but blunt — also bans merge bubbles on `dev`, which some users prefer for feature-branch readability in GitKraken / git-log.

v1.8.0.6 switches to per-branch enforcement:

- **Repo level**: all three merge methods enabled (rebase + squash + merge-commit).
- **`pipekit-main-squash-only` ruleset**: enforces squash-only on `main`. UI dropdown will only show "Squash and merge" for PRs targeting main.
- **Net effect**: feature → dev gets the user's choice (rebase or merge-commit). dev → main is squash, machine-enforced. Mistakes on the dangerous hop are impossible.

`scripts/pipekit-configure-repo.sh` extended to handle both — repo-flag PATCH plus ruleset create-or-update via `POST/PUT /repos/<org>/<repo>/rulesets`. Idempotent. The ruleset name is `pipekit-main-squash-only` so re-runs find and update the existing rule rather than creating duplicates.

### Touched

- `scripts/pipekit-configure-repo.sh` — full rewrite. 2 steps: repo-level flags + ruleset.
- `RUNBOOK.md` § One-time setup — updated table; recommends rulesets-based config.
- `sop/Git_and_Deployment.md` § Merge Strategy by Hop — explains the per-branch model + why the change.

### Migration

`./scripts/sync-method.sh v1.8.0.6` then `bash scripts/pipekit-configure-repo.sh <org>/<repo>`. The script will:
1. Re-enable `allow_merge_commit` at the repo level (was disabled by v1.7.0–v1.8.0.5).
2. Create the `pipekit-main-squash-only` ruleset.

If you want to keep the v1.8.0.5 behavior (merge-commits disallowed globally), just don't run the configure script.

---

## v1.8.0.5 — 2026-04-30 (patch)

### What changed

**`/branch finish` clarified — accepts explicit slug arg, auto-detects merged worktrees.** Live RS-59 observation: RUNBOOK step 13 said "exit + /branch finish" but didn't make clear that /branch finish runs from the parent repo (not from inside the worktree being removed), and the skill itself didn't define how it would identify the right worktree if multiple existed.

This patch:

- **`skills/branch/skill.md`** — Finish subcommand now documents the run-from-parent contract explicitly and adds a 3-tier resolution algorithm: (1) explicit slug arg matches a worktree path; (2) running from inside a worktree errors with a clear "exit and re-run from parent" message; (3) no-arg in parent auto-detects merged-on-origin worktrees, confirms the unambiguous one, or asks user to pick from multiple.
- **`RUNBOOK.md`** — step 13 split into Part A (exit) + Part B (cd to parent, run /branch finish). Notes that squash-merge breaks `git branch -d`'s ancestry check; `-D` is the correct response.

### Migration

`./scripts/sync-method.sh v1.8.0.5`. Pure documentation + skill-prose change; no behavior change unless you were relying on `/branch finish` running from inside the worktree (which fails today regardless).

---

## v1.8.0.4 — 2026-04-30 (patch)

### What changed

**QA-Pass default is now `pause-for-end-session`, not `close-now`.** Live RS-59 observation: /launch --auto's QA-Pass prompt still recommended `close` as the default action, which routes through the v1.7.0 cherry-pick path and defeats v1.8.0's "one PR per issue" model.

The recommended flow on QA Pass is:

1. `pause-for-end-session` (new default) — exit cleanly so the user can run `/end-session` (writes log + NEXT.md to the feature branch), then `/launch --close` (opens the single bundled PR). One PR. No cherry-pick.
2. `close-now` (legacy, preserved) — old v1.7.0 behavior; closes immediately, requires cherry-pick of the session log later.

Touched: `skills/launch/skill.md` auto-chain mode step 6 prose. Fail/Partial defaults unchanged (`pause-here`).

### Migration

`./scripts/sync-method.sh v1.8.0.4`. No breaking changes — `close-now` is still available for users who prefer the v1.7.0 flow.

---

## v1.8.0.3 — 2026-04-30 (patch)

### What changed

**`/launch --auto` no longer auto-advances on Revise.** Live RS-21 observation: plan-reviewer returned Revise, Lead applied the fixes, and `--auto` proceeded straight to Dev — without re-spawning plan-reviewer to validate the revised plan. The user did not approve skipping re-review. The "verdict gate" was effectively a no-op for Revise.

Root cause: skills/launch/skill.md treated Revise as a soft-pass — `proceed on Pass / Revise; abort on Block`. That's wrong. Revise's whole purpose is "fix and re-review."

v1.8.0.3 implements round-2 plan-review on Revise:

1. Round 1 Revise → spawn Lead to apply blocking fixes
2. **Re-spawn plan-reviewer with the revised PLAN.md (NEW)**
3. Round-2 verdict: Pass → Dev; Revise → loop to round 3; Block → abort
4. **Stalemate detection at round 3+**: if round 3's Revise verdict overlaps with round 2's blocking items, pause and surface to user. No auto-loop on round 4.

An explicit override `proceed-without-re-review` exists for the rare case where the user genuinely wants to skip re-review. The override is logged to the pipeline state file (`override: "skip-plan-review-round-2"`).

### Touched

- `skills/launch/skill.md` — auto-chain mode step 3 expanded with round-2 logic; "proceed on Pass / Revise" wording removed in 3 places
- `RUNBOOK.md` — plan-review verdict decision-point table updated with new defaults

### Migration

`./scripts/sync-method.sh v1.8.0.3`. No behavior change in Pass or Block paths. Revise now defaults to `apply-fixes-and-re-review` instead of `proceed`. If you rely on the old soft-pass behavior, use the explicit `proceed-without-re-review` option.

---

## v1.8.0.2 — 2026-04-30 (patch)

### What changed

**Default `/launch` recommendations to `--auto`.** Live test on RS-21 surfaced that /start-session offered "say `/launch RS-21` (or `go` and I'll fire it)" — without `--auto`. The bare form skips the auto-chain orchestration that's the whole point of v1.6.0+. Default should match the canonical Standard-tier path.

Three skill prose updates:

- **`/start-session`** — new step 9 explicitly offers the next command in `--auto` form (Standard tier). Tier handling: Standard → `--auto`, Heavy → plain `/launch` (since `--auto` rejects Heavy), Quick → `/06-linear-todo-runner`.
- **`/end-session`** — NEXT.md recompute writes `/launch RS-XX --auto` instead of bare `/launch RS-XX`. Same tier exceptions.
- **`/launch --close`** — close-time NEXT.md logic emits `/launch {next issue} --auto`. Same tier exceptions.

### Migration

`./scripts/sync-method.sh v1.8.0.2`. No behavior change in the auto-chain itself; only what gets recommended in NEXT.md and what /start-session offers to fire.

---

## v1.8.0.1 — 2026-04-30 (patch)

### What changed

**`/start-session` paired with `/end-session` inside the worktree.** v1.8.0 left an asymmetry: /start-session ran in the parent on dev, /end-session ran in the worktree on the feature branch. They didn't bracket the same scope, and /start-session's NEXT.md view could go stale before the user even got to the worktree.

v1.8.0.1 moves /start-session into the worktree as the kickoff command (after `/branch` and entering the worktree). It now refreshes NEXT.md from `origin/<integration>` tip the same way /end-session does — so both ends of the session see current state.

The parent-on-dev case is preserved: /start-session still works there as a "what should I work on?" view (no refresh, since you're already on integration). The pre-flight only triggers on a feature branch.

### Touched

- `skills/start-session/skill.md` — Pre-flight section added (NEXT.md refresh on feature branch; pass-through on integration)
- `RUNBOOK.md` — loop reordered to 13 steps. Step 0 is now lightweight issue-picking in parent; step 3 is /start-session in worktree (paired with step 9's /end-session). Quick Index TOC updated. Decision tree updated to show the parent/worktree boundary clearly.

### Migration

`./scripts/sync-method.sh v1.8.0.1` pulls the updated /start-session + RUNBOOK. No breaking changes — old order still works, but the new one pairs cleanly.

---

## v1.8.0 — 2026-04-30

### What's New

**One-PR-per-issue release.** Three coupled fixes that close the cherry-pick friction observed during RS-22 work and tighten the per-issue loop. Closes #15, #16, #17.

#### `/end-session` re-orders before `/launch --close` (closes #15)

The biggest day-to-day friction in v1.6.0/v1.7.0: /end-session ran *after* /launch --close, so the session log + NEXT.md update landed on a feature branch *after* PR merge — orphaned unless cherry-picked. The runbook documented a workaround that cost one extra PR (5-min gate-check tax) per issue.

v1.8.0 reverses the order: **/end-session runs first, /launch --close second.** Both inside the worktree, on the feature branch. The session log + NEXT.md update commit to the feature branch *before* the PR opens; /launch --close then bundles everything into the single PR. **One PR per issue. No cherry-pick.**

Two coupled changes inside /end-session:

1. **Integration-branch refusal.** /end-session refuses to run if the current branch is `dev` or `main`. Pre-flight A added; clear error message points to RUNBOOK.md § The loop step 10. Prevents accidental direct-to-integration writes.
2. **NEXT.md base refresh.** Inside the feature worktree, NEXT.md is a snapshot from when `/branch` ran. If a parallel session has shipped to dev since, the snapshot is stale. Pre-flight B fetches `origin/<integration>` and `git checkout`s NEXT.md to the current dev tip *before* recomputing. Race window shrinks from "hours of work in worktree" to "minutes between /end-session and PR merge."

#### Short branch names from `/branch --linear` (closes #16)

`/branch --linear RS-21` used to produce `feature/ethan/rs-21-record-edit-delete-with-change-tracking` (40+ chars, awkward in TUIs and PR titles, derived from Linear's verbose `gitBranchName`).

v1.8.0 derives a short slug from the Linear title: **`feature/RS-21-edit-delete`** (issue ID + 2-3 meaningful words). Algorithm is deterministic — same Linear title always yields the same slug. Stopwords (`with`, `and`, `the`, `for`, `of`, `to`, `in`, `on`, `a`, `an`, `change`, `tracking`, `record`) are stripped before picking the first 2-3 words.

The printed spawn hint also updates: `cd .worktrees/<branch> && claude --dangerously-skip-permissions` — saves a manual flag every time.

#### Recommended merge strategy: rebase feature→dev, squash dev→main (closes #17)

Squash-merging *everything* (v1.7.0's recommendation) flattens atomic per-task commits on dev — unreadable in GitKraken/git-log, useless for `git blame` per task, breaks `git bisect`. Squash-merging dev → main is correct (kills phantom-conflict topology), but feature → dev should preserve atomic commits.

v1.8.0 documents the right combination:

| Hop | Strategy |
|---|---|
| feature/* → dev | **Rebase** (preserves atomic commits as a linear sequence) |
| dev → main | **Squash** (one release commit; kills merge-commit topology) |
| Anything → merge-commit | **Disabled** (creates phantom conflicts on subsequent promotes) |

New `scripts/pipekit-configure-repo.sh` flips all four GitHub repo settings idempotently in one shot:

```bash
bash scripts/pipekit-configure-repo.sh <org>/<repo>
```

Updated: `RUNBOOK.md` § One-time setup, `sop/Git_and_Deployment.md` § Merge Strategy by Hop. The actual flip is per-consumer (Pipekit doesn't enforce repo settings — it recommends).

### Migration

For consuming projects on v1.7.0:

1. `./scripts/sync-method.sh v1.8.0` — pulls updated `/branch`, `/end-session`, `/launch` skills, `Git_and_Deployment.md`, `RUNBOOK.md`, and the new `scripts/pipekit-configure-repo.sh` helper.
2. **Configure your repo's merge strategy:**
   ```bash
   bash scripts/pipekit-configure-repo.sh <org>/<repo>
   ```
3. **New per-issue loop** — see `RUNBOOK.md` § The loop. The order is now: `/end-session` → `/launch --close` → rebase-merge PR → `/branch finish`. The cherry-pick workaround documented in v1.7.0 is removed.
4. No config / template / state-ID changes. Old per-issue flow (`/launch --close` first, /end-session after, cherry-pick log) still works if invoked in that order — but strongly prefer the new order.

### Open items deferred to v1.8.1

- **Port `/g-promote-dev`, `/g-promote-main`, `/g-test-vercel`, `/g-deploy`, `/g-promote-beta`** from rs-vault/piper into Pipekit with parameterization via `method.config.md`. Currently these are project-local copies, diverged between consumers. Folding them into Pipekit closes the per-issue + promotion loop end-to-end.

### Open items deferred to v1.9.0

- `/pipekit-resume` — state-file consumer for cross-session resumption (carried forward).
- Diagnostic gate output (no more bare `REMEDIATION_REQUIRED`).
- Orchestrator-side permission-denial detection (carried since v1.4.0).

---

## v1.7.0 — 2026-04-30

### What's New

**Bug-fix release closing the silent-drop gap left in v1.6.0.** Single observation from rs-vault RS-22 (real-time, 2026-04-29 → 2026-04-30) drove the whole release: the v1.6.0 NEXT.md defer mechanism only worked for non-VBW-scoped writers, exactly the case it was *not* meant to fix.

#### Pipekit machine-local state moved out of repo (closes #13)

v1.6.0 placed the deferred-NEXT.md queue and pipeline-state records inside the repo at `<repo>/.pipekit/`. VBW's file-guard hook blocks any in-repo write that isn't in the active plan's `files_modified` field. The queue file written to dodge the original block hit the same wall — net result: continued silent audit-trail loss, just one level deeper.

The fix: relocate Pipekit's machine-local state to `${XDG_CACHE_HOME:-~/.cache}/pipekit/<repo-basename>/`, resolved consistently by the new `scripts/pipekit-state-dir.sh` helper. VBW's file-guard never inspects paths outside the repo, so writes succeed unconditionally — no more best-effort, no more silent drops.

```bash
# Resolve the path
STATE_DIR=$(bash scripts/pipekit-state-dir.sh)

# Pipekit's directory layout (per consuming project):
#   ${XDG_CACHE_HOME:-~/.cache}/pipekit/<repo-basename>/
#     ├── pending-next-md.json     (NEXT.md defer queue)
#     ├── pending-strategy-sync    (post-archive marker)
#     └── pipeline-state/<issue-id>.json
```

Touched: `sop/Skills_SOP.md`, `method.md`, `VBW_COMMANDS.md`, `templates/tier-heavy.md`, seven skills (`/review-plan`, `/launch`, `/end-session`, `/06-linear-todo-runner`, `/start-session`, `/10-strategy-sync`, `/pipekit-help`), `scripts/pipekit-post-archive.sh` (with inline fallback for mid-upgrade safety), `scripts/verify-next-md-defer.sh` (asserts STATE_DIR is outside repo). The verify script's round-trip dogfood passes against the new path.

#### Sync script reliability fixes

- `--dry-run` now survives the self-update re-exec path (prior shift-based parser silently dropped the flag) — `fix(sync): preserve --dry-run across self-update re-exec` (47e0f9d).
- `diff -rq` exit-1-on-difference no longer kills `--dry-run` under `set -o pipefail` — `fix(sync): tolerate diff -rq exit 1 in --dry-run pipelines` (2b400ef).

These two latent bugs surfaced once `--dry-run` actually started running.

#### Repo URL update

Pipekit moved from `ethan-piper/pipekit` to `withpiper/pipekit`. Updated `METHOD_REPO` default, README/GUIDE/STARTUP install instructions, and `/pipekit-update` + `/startup` curl URLs (417c266). Old URL still redirects, so existing consumers don't break — but pin to v1.7.0+ to pick up the canonical reference.

### Migration

For consuming projects on v1.6.0:

1. `./scripts/sync-method.sh v1.7.0` — pulls updated skills, SOPs, the new `scripts/pipekit-state-dir.sh` helper, and the relocated `verify-next-md-defer.sh`.
2. **One-shot move existing state out of repo** (skip if `.pipekit/` is empty or absent):
   ```bash
   STATE_DIR=$(bash scripts/pipekit-state-dir.sh)
   mkdir -p "$STATE_DIR"
   mv .pipekit/* "$STATE_DIR/" 2>/dev/null
   rmdir .pipekit 2>/dev/null
   ```
   Files are ephemeral; a clean wipe (`rm -rf .pipekit`) is also fine — queue and state files self-recreate on next write.
3. Optionally remove `.pipekit/` from `.gitignore` — Pipekit no longer writes there. Harmless to leave.
4. No config / template / state-ID changes. No breaking API changes.

### Open items deferred to v1.8.0

- `/pipekit-resume` — state-file consumer skill for cross-session resumption (carried forward from v1.6.0/v1.7.0).
- Orchestrator-side permission-denial detection (carried forward from v1.4.0).
- /end-session writes session log onto the merged feature branch (orphan unless cherry-picked) — friction observation from RS-19 + RS-22 closes; right fix is for /end-session to write to integration directly.

---

## v1.6.0 — 2026-04-29

### What's New

**Workflow-friction release.** Two issues closing observations from rs-vault RS-19 (real-time, 2026-04-29). Together they cut per-issue Standard-tier human input count from 6+ down to 3, while fixing a silent audit-trail loss at the Pipekit/VBW boundary. Order matters: #12 ships first because reliable NEXT.md and state-file writes are the substrate #11 builds on.

#### `/launch --auto` auto-chains non-decision pipeline transitions (closes #11)

New `--auto` flag on `/launch` (Standard tier only) orchestrates the full pipeline — `vbw:vbw-lead` → `plan-reviewer` → `vbw:vbw-dev` → `vbw:vbw-qa` → `--close` — pausing only at the two real decision points: the plan-review verdict and the QA verdict. Total human inputs drop from 6+ command re-types (per stage) to 3 (tier confirm + plan-review verdict + QA verdict). The actual cost reduction isn't keystrokes — it's the 5–120 minute resumption tax when the user walks away mid-pipeline and has to context-load on return.

```
/launch RS-19 --auto    # Standard tier
/launch RS-19           # unchanged — manual chaining still supported
```

Each pipeline stage runs as a **fresh Task-spawned subagent**, so the fresh-chat discipline (`method.md` § Fresh-Chat Discipline) is preserved by construction: the orchestrator's conversation context never bleeds into Lead, plan-reviewer, Dev, or QA reasoning. Agents see prior stage output as documents (PLAN.md, REVIEW.md, VERIFICATION.md), not as recalled conversation. This is the load-bearing constraint — no plan-review skip on "trivial" plans, no QA skip on "low-risk" specs. Auto-chain reduces transition friction; it does not lower the gate bar.

Tier handling: Quick → delegates to `/linear-todo-runner` (already auto-chained); Standard → runs the orchestration; Heavy → rejected with a clear message (security review + mandatory `/strategy-sync` gates intentionally human-paced). Permission-denial protocol from v1.4.0 is carried into the spawned Dev task description so hook-driven blocks surface immediately rather than burning turns.

#### NEXT.md write defers under VBW active-plan scope (closes #12)

Real-time observation during rs-vault RS-19's plan-review: VBW's file-guard hook blocked `/review-plan`'s `NEXT.md` write because NEXT.md was not in the active plan's `files_modified` field. The verdict was delivered correctly above the hook error; the audit-trail write was lost silently. Per `method.md` § VBW / Pipekit Ownership Model, NEXT.md is unambiguously Pipekit's — but VBW's hook can't tell that.

The fix (Option A in #12, Pipekit-side, ships in v1.6.0): Pipekit skills that update NEXT.md inside potential VBW-scoped contexts (`/review-plan`, `/launch --close` mid-session, etc.) now run a deferral check. If active-plan scope is detected and NEXT.md is not whitelisted in the plan's `files_modified`, the write is queued to `.pipekit/pending-next-md.json` instead. `/end-session` applies the queue atomically on next session-end, then deletes the queue file (no persistent cruft, per AC).

The inline `➜ Next:` line is **not** deferred — the user still sees their next-command in terminal output of the current skill. Only the file write defers. If/when VBW lands an upstream `always_allow` allowlist for the file-guard hook (Option B in #12, parallel track), the queue mechanism becomes redundant but does not break — both paths coexist gracefully.

A new helper, `scripts/verify-next-md-defer.sh`, dogfoods the round-trip end-to-end against an ephemeral fake project tree. Re-run after any future edit to the deferral mechanism.

#### Pipeline state file (supports `--auto` and future resumption)

Pipeline skills (`/launch` open + `--close`, `/review-plan`, `/linear-todo-runner`) now write a small JSON record to `.pipekit/pipeline-state/<issue-id>.json` at each meaningful state transition: `stage`, `verdict`, `next_command`, `cwd`, `timestamp`. Schema documented in `sop/Skills_SOP.md` § Pipeline state file. Consumed by `/launch --auto` for chain-progress tracking; the state-file writes lay the substrate for `/pipekit-resume` (deferred to v1.7.0) to recover cross-session.

State-file writes that hit a hook block during VBW active-plan scope are best-effort — skip silently rather than failing the skill. The orchestrator reconstructs from VBW state where needed.

### Migration

For consuming projects on v1.5.0:

1. `./scripts/sync-method.sh v1.6.0` — pulls updated `launch`, `review-plan`, `end-session`, `06-linear-todo-runner` skills, plus `Skills_SOP.md`, `method.md`, and the new `scripts/verify-next-md-defer.sh` helper. The new `.pipekit/pipeline-state/` directory is created lazily on first write — no upfront scaffold needed.
2. **Add `.pipekit/` to `.gitignore`** if not already present. The directory holds ephemeral, per-machine state (queue file, pipeline-state records, strategy-sync marker) and must not be committed.
3. No config changes. No template changes. No new state IDs.
4. No breaking changes. Existing `/launch` invocations without `--auto` behave identically to v1.5.0. NEXT.md writes outside VBW active-plan scope behave identically (the deferral check returns `DEFER_NEXT_MD=0` and the direct write proceeds as before).

### Open items deferred to v1.7.0

- **`/pipekit-resume`** — state-file consumer skill that reads `.pipekit/pipeline-state/<issue-id>.json` to resume an interrupted `/launch --auto` chain across Claude Code session boundaries. The state file is written now so the data exists when the consumer ships.
- **Orchestrator-side permission-denial detection** — carried forward from v1.4.0 → v1.5.0 → v1.6.0. The agent-side stop instruction is now in v1.6.0's `--auto` Dev spawn; the orchestrator-side proactive surfacing (without depending on agent compliance) remains open.
- **Option B (VBW-side `always_allow` allowlist)** — upstream coordination required. When it lands, supersedes the v1.6.0 queue mechanism for projects that adopt the VBW config. Both paths coexist safely in the meantime.

---

## v1.5.0 — 2026-04-28

### What's New

**Productivity skills release.** Two new portable skills closing recurring friction observed across the v1.4.x release cycle (rs-vault Phase 1 closeout, four Pipekit releases shipped 2026-04-27). Both are read-only by design and slot cleanly into existing pipeline positions — no behavioral changes to `/launch`, `/light-spec`, or any prior skill. Clean sync from v1.4.1 (no breaking changes, no config migration).

#### `/spec-preflight` automates empirical pre-flight checks on specs (closes #9)

New skill that verifies a Linear issue's spec against reality before `/launch`. Parses file paths, line citations, phase-detect baselines, Linear status, and dependency claims from the spec body and confirms each against the actual project state. Slots between Spec Review Agent (which reviews narrative coherence) and `/launch` (which validates gates).

```
/light-spec → Spec Review Agent → human approval → /spec-preflight → /launch
```

Catches the empirical-drift class of defect agent review structurally cannot see — stale baselines (the recurring failure mode where a spec passed agent review with `phase_count=0` while reality was `1`), renamed files cited in §Technical Context, blockers that re-opened post-approval, etc.

Read-only: never modifies the spec, never transitions Linear status, never writes any project file. Output goes to stdout. Graceful degradation when `phase-detect.sh` or Linear MCP is unavailable — infrastructure flake produces `⚠ unverified` markers, not failures, so a single dropped tool doesn't block the rest of the report. For Quick-tier issues that skip agent review entirely, this is the only automated check before `/launch`.

#### `/release-changelog` generates draft CHANGELOG entry from commits (closes #10)

New skill that parses git commits between two refs, buckets by conventional commit type (`feat` → What's New, `fix` → Fix, `docs` → Documentation, others → Other Changes), and renders a draft CHANGELOG entry mirroring this file's existing format. Output to stdout — human edits the narrative lead and migration sections, then commits. Auto-detects new skill directories in the range to seed the migration bullet.

```
/release-changelog --version v1.6.0
/release-changelog --version v1.6.0 --from v1.5.0
/release-changelog --version v1.6.0 --from v1.5.0 --to HEAD
```

`--version` is required (validated against `vX.Y.Z[-suffix]`); `--from` defaults to the latest tag; `--to` defaults to `HEAD`. Edge cases: no prior tag → error requesting explicit `--from`, empty range → exit 0 with `"no changes since <prev>"`, misformatted commits → bucket gracefully into Other Changes with the full original subject. Read-only on git state and on `CHANGELOG.md`; the human's editing pass is load-bearing and explicitly preserved.

This release dogfooded the skill: the entry above was drafted by hand-running the algorithm on the four commits in the v1.4.1..HEAD range, then expanded with narrative.

### Migration

For consuming projects on v1.4.1:

1. `./scripts/sync-method.sh v1.5.0` — pulls two new skill directories: `skills/spec-preflight/` and `skills/release-changelog/`. Also pulls updated `sop/Skills_SOP.md` and `method.md` skill tables.
2. No config changes required. No template changes. No new state IDs.
3. No breaking changes. Existing pipelines run unchanged. The new skills are additive — projects can adopt `/spec-preflight` selectively (or always) before `/launch`; `/release-changelog` is Pipekit-internal release tooling and consumers may or may not have a use for it depending on their own changelog conventions.

### Open items deferred to v1.6.0

- **Orchestrator-side denial detection** — carried forward from v1.4.0. The "lighter-fix" path landed in v1.4.0 (subagent-side stop instruction); the orchestrator-side detection that surfaces denials proactively without depending on agent compliance remains open.

---

## v1.4.1 — 2026-04-27

### Fix

**`/launch` Step 1.6 resolves `phase-detect.sh` from VBW plugin cache (closes #8).** Hit immediately on first v1.4.0 consumer sync. Step 1.6's lookup checked PATH and `.vbw-planning/scripts/` but didn't know VBW installs `phase-detect.sh` at `~/.claude/plugins/cache/vbw-marketplace/vbw/<VERSION>/scripts/`. Consumers had to write a wrapper script to make Step 1.6 work. Now /launch resolves the canonical install path automatically; if multiple VBW versions are installed, the highest version wins via alphabetic glob expansion.

PATH and project-local lookups still take precedence (preserves override capability). Behavior on no-phase-detect-anywhere is unchanged from v1.4.0 — graceful degradation with non-blocking warning.

### Migration

Patch release. `./scripts/sync-method.sh v1.4.1` — single skill file updated (`launch/skill.md`). No config changes. Consumer wrapper scripts at `.vbw-planning/scripts/phase-detect.sh` continue to work (they take precedence over the plugin-cache fallback).

---

## v1.4.0 — 2026-04-27

### What's New

**Friction-fix release.** Five fixes closing the observations from v1.3.x real-world use (rs-vault Phase 1 closeout, sessions across 2026-04-27). No new capability — all five are behavioral tightenings that close silent-failure modes and cross-system gaps observed in production. Clean sync from v1.3.0 (no breaking changes, no config migration).

#### `/branch` pre-checks Linear status before worktree creation (closes #5)
When `--linear PROJ-XX` is passed, `/branch` now fetches the Linear issue **before** creating the worktree. Done/Canceled/Duplicate prompts confirmation (default abort); In Progress/Building warns and proceeds; other states proceed silently. Linear transition to In Progress still happens after worktree creation (preserves prior behavior). Catches "the work was already shipped" before the user wastes setup time.

#### `/launch --close` is idempotent + comment-on-presence (closes #4)
`--close` no longer silently no-ops when the issue has already moved past UAT (PR-merge automation, label-driven Linear automation, `/linear-todo-runner`, etc.). The status transition and the close-summary comment are now decoupled:
- status `<= Building` → transition to UAT (canonical path)
- status `>= UAT` → status transition is a no-op
- always: scan existing comments for the `**Build complete.**` marker; post the close-summary if absent, skip silently if present

Re-running `--close` is safe: idempotent on the comment, idempotent on the status. Audit trail survives all closeout-style flows.

#### Subagent permission-denial-stop instruction + canonical-file pattern doc (closes #6)
Spawned worker agents in `/linear-todo-runner` (and any future agent spawn from `/launch`) now include an explicit permission-denial protocol in the task description: stop on first `EditPermissionDenied` / `HookFeedbackBlocked`, do not retry, surface denied path + intended change + rationale. Prevents agents from burning turns retrying against hook-protected canonical files. The canonical-file-protection pattern (`.claude/rules/*` as agent-write-locked) is now documented in `sop/Skills_SOP.md` so projects intentionally protect their canonical files.

Orchestrator-side denial detection deferred to v1.5.0 per the issue's lighter-fix path.

#### `/launch` surfaces VBW phase-state warnings (closes #7)
New Step 1.6 reads `phase-detect.sh` (read-only) after the Linear gate-check and surfaces unresolved VBW state — `qa_status=failed`, `qa_status=pending` on shipped phases, `has_unverified_phases`, `next_phase_state=needs_qa_remediation` / `needs_uat_remediation`. User can continue (default), address VBW state first, or abort. `phase-detect.sh` failure is non-blocking. Closes the read-only awareness gap between Pipekit and VBW called out in `method.md` § VBW / Pipekit Ownership Model. Ownership boundary unchanged — Pipekit never writes VBW state.

#### `/launch` handoff routing for closeout-style work (closes #3)
`/launch` now runs a VBW absorption check inside Step 7b before emitting the canonical handoff. If `next_phase_state=all_done` or no matching unbuilt phase exists, the user gets a three-way routing prompt: (1) add a new VBW phase first, (2) skip VBW and author plan manually + `/review-plan <path>`, or (3) abort and escalate. Always confirms; never auto-routes. The manual-plan path explicitly documents that `/review-plan` accepts a path argument (not just a phase slug) so Standard-tier's plan-review gate is satisfied without VBW. Fixes the recurring friction where `/launch` emitted `/vbw:vibe --plan <slug>` against a closed VBW state, producing a broken command for closeout work.

### Migration

For consuming projects on v1.3.0:

1. `./scripts/sync-method.sh v1.4.0` — pulls the updated `branch`, `launch`, `06-linear-todo-runner` skills and `Skills_SOP.md`.
2. No config changes required. No template changes. No new state IDs.
3. If your project has agents that edit canonical files via Pipekit-spawned skills, the new permission-denial protocol will surface hook denials immediately rather than silently — review any prior partial-progress reports against the new behavior.

No breaking changes. The five fixes are all backward-compatible: canonical paths (open VBW phase, in-pipeline issue, fresh `--close` on Building, `/branch` without `--linear`) behave identically to v1.3.0.

---

## v1.3.0 — 2026-04-26

### What's New

**Stage 0 reframed as a contract; entry-mode routing.** Stage 0 is no longer documented as a script you "run once per project" — it's the *contract* (a set of artifacts) that the dev pipeline consumes. Three legitimate entry modes (greenfield, brownfield, inherited) are now first-class, replacing the implicit greenfield-only assumption.

#### Foundation Contract section in `method.md`
A new section enumerates every artifact the dev pipeline (Stages 1-5) requires, with paths and consuming skills. The contract is presence-only — `[TBD]` content is fine; missing files are not. `/roadmap-review` remains the gate that verifies the contract before speccing.

#### Entry-mode tables (parity in `method.md`, `README.md`, `GUIDE.md`)
The greenfield/brownfield/inherited table now appears prominently in all three docs, with `method.md` as the canonical source. Each mode lists who it's for, which skills run, and which are skipped.

#### `/startup --mode={greenfield,brownfield,inherited}` flag
- `--mode=greenfield` — existing 12-step flow, no behavioral change.
- `--mode=brownfield` — skips `/concept` and `/define`, prompts for project metadata, routes through `/strategy-create` with a manual-edit note. Tech-stack and infrastructure steps populate `method.config.md` from the existing project rather than scaffolding.
- `--mode=inherited` — runs the new Foundation Check subroutine (presence audit of every contract artifact) and exits with a next-step recommendation. Does not modify state.

When `--mode=` is absent, `/startup` auto-detects from project state and **always confirms with the user** (mirrors `/launch` Step 1.5 tier resolution — never auto-pick).

#### Foundation Check subroutine in `/startup`
Verifies every foundation-contract artifact, suggests retrofit paths for missing ones, and reports the current phase from `PHASES.md` when the contract is intact. Used internally by `--mode=inherited` and callable standalone whenever you want a foundation audit. No new skill — keeps the skill count steady.

#### Mode-aware Rule #1 in `/pipekit-help`
The single "Stage 0 not complete → run /startup" rule is replaced with four sub-rules:
- Empty project → greenfield → `/startup`
- Code present, no foundation → brownfield → `/startup --mode=brownfield`
- Foundation present, no recent activity → returning/inherited → `/start-session`
- Partial foundation → diagnose via `/startup --mode=inherited`

All other rules are unchanged.

### Migration

For consuming projects on v1.2.0:

1. `./scripts/sync-method.sh v1.3.0` — pulls the updated `method.md`, `/startup` skill, and `/pipekit-help` state rules.
2. No config changes required. Existing greenfield projects continue to behave identically.
3. New contributors joining an existing Pipekit project can now run `/startup --mode=inherited` to verify the foundation contract before picking up work.

No breaking changes.

### Open items deferred to v1.4.0

- **`/strategy-from-code`** — auto-audit skill that would generate strategy docs by inspecting an existing codebase. Brownfield mode currently routes through `/strategy-create` with a banner instructing the user to manually edit the generated docs against reality. Auto-audit is the v1.4.0 follow-up.
- **Brownfield tracker bootstrap from `package.json`** — `/startup --mode=brownfield` currently prompts for project metadata; v1.4.0 will infer name, stack, and deployment from existing project files where possible.

---

## v1.2.0 — 2026-04-26

### What's New

**BMAD-inspired upgrade pack.** Four discrete steals from [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) that strengthen Pipekit without touching the parts that already work — Linear stays the visibility layer, the strategy-sync loop stays the apex, the spec-as-contract principle stays load-bearing. Lands as four sequential commits (P4 → P3 → P1 → P2) that ship value alone if you stop after any of them.

#### Sync-Safe Overrides (`.claude/overrides/`)
Projects can now customize synced skills, SOPs, and `method.md` without forking and without losing upstream improvements. The sync script applies overrides on top of the upstream copy and surfaces a **drift warning** when upstream changes a file you override.

- `.claude/overrides/skills/<name>/skill.md` — full-file replacement
- `.claude/overrides/sop/<file>.md` — full-file replacement
- `.claude/overrides/method.md.patch` — unified diff
- `.claude/overrides/MANIFEST.md` — human-curated index (what + why)

Failed patches dry-run first — they don't half-apply. See `method.md` § Sync-Safe Overrides.

#### First-class scale tiers in `/launch` (Quick / Standard / Heavy)
`/launch` now resolves a **tier** for every issue. Tiers shape *which gates apply*; complexity (Low/Medium/High) shapes *how execution is routed*. The two are orthogonal.

- **Quick** — 1–3 stories, AC-as-plan. Skips spec review, milestone-readiness, plan review, QA agent. Routes to batch runner.
- **Standard** (default) — Existing pipeline.
- **Heavy** — Adds security review + mandatory `/strategy-sync` before close. Always full VBW planning, batch runner disallowed.

Tier inference is **always confirmed with the human** — auto escalation/de-escalation is disallowed by design. Per-tier templates live at `templates/tier-{quick,standard,heavy}.md`. Per-project tier configuration in `method.config.md` § Tiers.

#### `/pipekit-help` skill + opt-in next-step nudge
Push-based replacement for "what skill do I run now?" — replaces pull-based skill discovery in a 12-step pipeline.

- `/pipekit-help` reads project state (branch, recent commits, presence of `PLAN.md` / `REVIEW.md` / `VERIFICATION.md`, `.pipekit/pending-strategy-sync` marker, Linear status) and recommends exactly one next step with a one-line why.
- Rules live in `skills/pipekit-help/state-rules.md` — first match wins; customizable via the override system.
- `scripts/pipekit-next-step-nudge.sh` is an **opt-in** Stop hook that suggests `/pipekit-help` after pipeline-relevant skills finish. Scoped by transcript inspection (silent unless the previous turn invoked a pipeline skill).

#### Fresh-chat discipline (documented enforcement)
The spec-as-contract principle ("no stage may introduce guesswork into the next stage") only holds if downstream agents read prior stage output as documents, not as recalled conversation.

- New `method.md` § Fresh-Chat Discipline section lists which transitions require a new conversation and why.
- Preamble nudges added to skills that cross stage boundaries: `/launch`, `/light-spec-revise`, `/review-plan`, `/strategy-sync`.

### Other Changes Since v1.1.0

This release also bundles the Tier 1 / Tier 2 / Tier 3 `/launch` refactor that landed prior to the BMAD upgrade pack:

- `/launch` split into open + close phases; Pipekit owns Linear status transitions, VBW owns plan/execute/verify
- `/review-plan` standalone skill spawning the `plan-reviewer` agent at `model: opus`
- Post-archive hook (`scripts/pipekit-post-archive.sh`) → `/strategy-sync` nudge via `.pipekit/pending-strategy-sync` marker
- Batch-promote SOP and `/launch --close` messaging
- Canonical `.claude/rules/` hub-and-spoke template (`pipekit-discipline`, `pipekit-tooling`, `pipekit-security`)
- `sync-method.sh` self-update guard + re-exec for single-invocation upgrades

### Deprecations

- `/launch --deep` — no-op since Tier 1; emits a one-line warning. Use `/vbw:vibe --execute --effort=max` instead.

### Migration

For consuming projects on v1.1.0:

1. `./scripts/sync-method.sh v1.2.0` — pulls everything.
2. (Optional) Add `## Tiers` section to `method.config.md` if you want to disable a tier or document tier policy. Default is all three available with **Standard** as fallback.
3. (Optional) Wire the next-step nudge by adding the snippet from `sop/Skills_SOP.md` § Next-Step Nudges to `.claude/settings.local.json`.
4. (Optional) Migrate any pre-v1.2.0 forked skills into `.claude/overrides/skills/<name>/skill.md` so they stop getting clobbered on sync.

No breaking changes. Existing pipelines run unchanged with **Standard** tier as the default.

---

## v1.1.0-opus4.7 — 2026-04-17

Adapted methodology to Claude Opus 4.7 behavioral changes:

- DesignDirection template counters Opus 4.7's default cream/serif/terracotta aesthetic; requires 4 distinct directions before building.
- Literal-scope authoring guidelines added to skills.
- Explicit subagent guidance for Opus 4.7.
- `Session_Management_SOP.md` for Claude Code + Opus 4.7 context handling.

---

## Earlier

See `git log` and `PIPEKIT_IMPROVEMENTS.md` for pre-v1.1.0 history.
