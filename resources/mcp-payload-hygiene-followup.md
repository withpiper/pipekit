# MCP payload hygiene — what shipped (R1–R4) and the deferred code piece (R5)

Origin: `temp/pipekit-handoff-mcp-context-bloat.md` (SiteLine session 2026-07-20). Problem: MCP tool results are **sticky** — every returned payload rides every subsequent turn as input, so cost scales with (payload size × remaining turns). Pipekit's own synced skills call MCP inline in the main thread, so a routine day's Linear work (~40 calls) was observed holding ~17% of the session budget. Fix must be behavioral and framework-level (a project spoke can't reach the synced skills or the canonical `pipekit-*.md`).

## Shipped this pass (docs/skills only — no `bin/pk` change)

- **R1** — new `## MCP Result Payloads Are Sticky` section in `templates/rules/pipekit-tooling.md`. States the sticky/re-billed mechanism, the three acute shapes (state reads that drag the comment thread; writes that echo their body; doing either inline), the state-only-read redirect (R3), the write echo-back note (R4), and the non-goal (behavioral fix, **not** a hard output-size cap — truncation silently drops data).
- **R2** — one line added to `templates/rules/pipekit-discipline.md` § Parallel work patterns (Subagents bullet): MCP-heavy read/write batches belong in a subagent so the fat payloads stay out of the main thread. Generalizes the already-proven "Payload watch-out" pattern in `/linear-hygiene` and `/00-roadmap-review`.
- **R3** — state-read caveat added under the MCP tool table in `sop/Linear_SOP.md`: `getIssueById` is a full-content read; for state/merge/PR status use `pk next`/`pk status`, filtered `linear_searchIssues`, or `git`/`gh`.
- **R2 nudges** — `/01-light-spec` (Phase 1 fetch) and `/work` (Step 2 fetch) now say "read once, carry the fields, don't re-fetch for state." `/pk-bug` was intentionally **not** nudged — it makes no direct Linear MCP calls (it wraps `/work` + `pk ship`), so it inherits the rule and `/work`'s nudge.

Canonical source is `templates/rules/`; consumers inherit R1/R2 on their next `sync-method.sh`. This repo's own `.claude/rules/` copies (gitignored) were mirrored for the current session.

## R5 — deferred: a lean `pk issue show` read wrapper (the only code change)

**Why deferred:** it's the sole recommendation touching `bin/pk` (the CI-gated executor with its own smoke suite, currently 121). R1–R4 remove the *temptation* to reach for the fat MCP read; R5 removes the *need* by giving skills a low-token structured read.

**Spec:**

- New verb `pk issue show <ID>` — hits Linear's REST API directly (the same `LINEAR_API_KEY` path `pk ship`/`pk done`/`pk promote` already use; no MCP, no comment thread).
- Flags:
  - `--no-comments` (default on) — never fetch the comment thread.
  - `--fields title,state,labels,description` — caller picks columns; default to a compact set (`title,state,labels`), add `description` only when asked.
  - `--json` — machine-readable for skills; default is compact width-controlled text like `pk status`.
- Output: a few hundred tokens vs. the multi-KB `getIssueById` payload.
- Once it exists, tighten the R1/R3 guidance from "use `searchIssues`/`git`/`gh` for state" to "use `pk issue show`" as the first-class path, and point `/light-spec` + `/work` fetch steps at it where a full body isn't required.

**Release mechanics when built:** bump `PK_VERSION`, add smoke cases (fields selection, `--no-comments`, missing-key/offline degrade, bad-ID error), expect smoke 121 → ~125, standard `chore(release)` checklist.

## When R1–R4 is released

Fold into the `chore(release)` CHANGELOG entry: R1–R4 as the shipped capability, R5 (`pk issue show`) as the documented fast-follow — same pattern as the v4.4.0/v4.3.0 advisory-gate → v4.17.0 hard-gate deferral.
