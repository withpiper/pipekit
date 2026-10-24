# Pipekit Runbook

**v5.2.2** — Last updated: 2026-10-24 10:06  *(**v5.2.2 — the migration-drift and self-reference checks find their package from their own location** (SiteLine's nested-package fixes, upstreamed with `scripts/lib/package-root.sh`), and the runbook's security-review trigger names the configured Migration dir.)*

> **North star:** safe and frictionless. Helps, never adds work.

The v2 daily loop on one page. Read top-to-bottom. v1 commands are retired — preserved under `archive/v1-skills/` for reference only.

---

## One-time setup (per consuming project)

```
1. ./scripts/sync-method.sh v5.2.2                (or latest tag)
2. Fill in method.config.md from method.config.template.md (V2 keys: integration_branch, ship_environments, …)
3. Add LINEAR_API_KEY=lin_api_xxx to .env.local    (gitignored, project-local)
4. ./bin/pk init                                   (seeds notepad.md, Logs/Sessions/, checks config)
5. ./bin/pk doctor                                 (deeper diagnostic)
6. ./bin/pk install                                (puts pk on $PATH globally)
```

> v2.1.2 retired the bash Stop hook. Session logs are now written by `/pk-exit` (the last command of each Claude session — see flowchart [End]).

---

## Spec loop (per-issue flowchart — Needs Spec → Approved)

The spec loop produces the input the coding loop consumes. An issue arrives in **Needs Spec** from `/phase-plan` (planned features) or **Triage** (ad-hoc bugs / client requests / `/brainstorm` output). It exits in **Approved**, ready for `pk branch` to pick up.

Run from the parent repo. No worktree needed — specs are Linear-side artifacts, not code changes.

```
┌─────────────────────────────────────────────────────────────────┐
│  PARENT REPO       cwd: ~/Projects/<repo>     branch: dev       │
└─────────────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [S1] Find next spec target                               │
  │     pk next                                              │
  │     • look for the "Needs Spec" group in the output      │
  │     • initiative-aware (Linear i{N}./I{N}.P{N}. surface) │
  │                                                          │
  │     For a brand-new idea:                                │
  │     /brainstorm <idea>                                   │
  │     • creates a Triage-state Linear issue                │
  │     • use /brainstorm-review to batch-triage Triage      │
  │       items into Ideas / Needs Spec / Kill               │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [S2] Generate light spec                                 │
  │     /light-spec <ID>                                     │
  │     • reads issue + codebase + Strategy/ docs            │
  │     • generates the structured AI→AI contract            │
  │     • Phase 6 auto-cycles agent review (max 3 passes):   │
  │         - pk spec-cycle      (polls Spec Review Agent v5)│
  │         - /light-spec-revise (surgical revisions)        │
  │     • stalemate detector breaks runaway loops            │
  │     • Linear: Needs Spec → Specced (on Pass verdict)     │
  │     • Linear: stays Needs Spec (on stalemate; revise     │
  │       standalone via /light-spec-revise <ID>)            │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [S3] Human review   (in the Linear browser, not Claude)  │
  │     you                                                  │
  │     • check scope, decisions, AC against intent          │
  │     • accept → transition Specced → Approved             │
  │     • reject → leave a Linear comment, keep in Specced;  │
  │       re-run /light-spec-revise <ID> with the feedback   │
  │                                                          │
  │     This is the deliberate human gate of the spec loop.  │
  │     Do not auto-chain past it from any skill.            │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [S4] Pre-flight sanity   (recommended, not enforced)     │
  │     /spec-preflight <ID>                                 │
  │     • verifies file paths the spec cites exist           │
  │     • flags stale symbol/line refs (drift since spec)    │
  │     • runs phase-detect baseline                         │
  │     • validates Linear status + dependency chain         │
  │     • read-only — flags issues, doesn't transition state │
  │     • optional but cheap; catches stale specs before     │
  │       /work picks them up and wastes a planning pass     │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
       → Output: issue in Approved.
         Hand off to the coding loop below.
```

> **Batching tip:** run the spec loop ahead of the coding loop. Specs in `Approved` state are the queue the coding loop pulls from; if you're shipping at pace, pre-spec a batch of 3-5 issues so `pk next` always finds work without forcing a context switch into speccing mid-execution.

---

## Coding loop (per-issue flowchart — Approved → Done)

Consumes Approved issues from the spec loop. Each pass produces a merged PR and (for multi-tier projects) walks the issue through `Ship environments` to **Done**.

```
┌─────────────────────────────────────────────────────────────────┐
│  PARENT REPO       cwd: ~/Projects/<repo>     branch: dev       │
└─────────────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [1] Find next issue   (initiative-aware, Linear-native)  │
  │     pk next                                              │
  │     • derives current initiative from Linear initiatives │
  │       (i{N}. initiative → I{N}.P{N}. project, by prefix) │
  │     • groups Linear results by status:                   │
  │         In Progress  (with /work hint)                   │
  │         Approved     (with pk branch hint)               │
  │         Needs Spec   (with /light-spec hint)             │
  │     • surfaces "Other initiatives: N Approved outside" footer │
  │     • falls back to global "next Approved" when no       │
  │       i{N}. initiatives present (PHASES.md fallback)     │
  │     • optional: pk status   (full unscoped board view)   │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [2] Branch + worktree                                    │
  │     pk branch <ID>                                       │
  │     • creates feature/<ID>-<3-word-slug>                 │
  │     • worktree at .worktrees/<ID>-<slug>                 │
  │     • symlinks .env / .env.local / .mcp.json             │
  │       (announced; never .env.prod)                       │
  │     • copies parent's bin/pk into worktree               │
  │     • Linear: Approved → In Progress                     │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
       cd .worktrees/<ID>-<slug>
       claude --dangerously-skip-permissions
       │
┌──────┴──────────────────────────────────────────────────────────┐
│  WORKTREE       cwd: .worktrees/<ID>-<slug>     branch: feature │
└─────────────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [3] Plan + execute                                       │
  │     /work <ID>            (or /work <ID> --deep)         │
  │     • reads spec from Linear                             │
  │     • plans (one-screen)                                 │
  │     • verdict: proceed | revise: <feedback> | abort      │
  │     • executes plan on native-on-Workflow                │
  │     • atomic commits, gate-aware                         │
  │     • --deep adds spec-validator + plan-review +         │
  │       security-review subagents                          │
  │     • on clean exit → auto-invokes [4] /verify           │
  └──────────────────────────────────────────────────────────┘
       │ (auto on /work success; aborts skip the rollover)
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [4] Verify                                               │
  │     /verify         (or pk verify)                       │
  │     • runs § Pre-Deploy Gate from method.config.md       │
  │     • if Require QA review=true: spawns QA subagent      │
  │     • returns Pass / Partial / Fail with per-AC table    │
  │     • on Pass + auto-flow → auto-invokes [5] pk ship     │
  │     • on Partial/Fail → STOP (user fixes and reruns)     │
  └──────────────────────────────────────────────────────────┘
       │ (auto on Pass when invoked by /work; standalone
       │  /verify just prints the hint)
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [4a] Security Gate  (v4.4.0; HARD v4.17.0; projects w/ a │
  │      categories file — skip if absent)                   │
  │      /security-gate [<ID>]  (or embedded in /verify F)   │
  │      • classifies the feature diff into 6 sensitive      │
  │        categories (auth/payments/user-input/external-    │
  │        APIs/file-storage/PII)                            │
  │      • none matched → instant PASS                        │
  │      • a match → category checklist vs the diff →         │
  │        PASS/FAIL report + Linear comment (no state change)│
  │      • PASS writes secgate-complete.md (sha-stamped);     │
  │        pk ship REFUSES without it on armed projects       │
  │        (escape: --force / PK_SECGATE_BYPASS=1)            │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [5] Ship   (still in worktree, still on feature branch)  │
  │     pk ship                 (or --env=<env>)             │
  │     • refuses off-format commit subjects (--force)       │
  │     • push (idempotent)                                  │
  │     • gh pr create as DRAFT against integration branch   │
  │       (v2.6.0+: Draft is default; --ready opens Ready)   │
  │     • Linear → UAT (→ In Review for non-standard envs)   │
  │     • Any reviewer workflow you installed does NOT fire  │
  │       on Draft — flip with pk ready when shipping        │
  │     • on push/gh failure → STOP, surface error, no retry │
  └──────────────────────────────────────────────────────────┘
       │
       ▼ iterate freely on Draft (no review fires)
       │
  ┌──────────────────────────────────────────────────────────┐
  │ [5a] Flip Draft → Ready  (v2.6.0+ — fires reviewers)     │
  │      pk ready [<ID>]                                     │
  │                                                          │
  │      • Runs `gh pr ready <#>` on the feature PR          │
  │      • Fires `ready_for_review` GitHub event             │
  │      • templates/ci/semgrep.yml + claude-review.yml      │
  │        listen for this event — review runs once, at the  │
  │        actual merge moment, not on every push            │
  │      • Linear state unchanged (UAT stays UAT)            │
  │                                                          │
  │      Skip this step if you used `pk ship --ready`        │
  │      (one-shot tiny WITs where iteration won't happen).  │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [5b] Antagonistic PR review  (RECOMMENDED — opt-in)      │
  │      pk ship --review                                    │
  │                                                          │
  │      • Prints reviewer subagent invocation               │
  │      • Posts a Linear comment flagging review-in-flight  │
  │        (v2.1.0 — closes mid-loop visibility gap)         │
  │      • You paste invocation into Claude session;         │
  │        agent reviews + posts findings as PR comment      │
  │      • Severity-ranked: Critical / High / Medium / Low   │
  │                                                          │
  │      Rubric: auth correctness, brand hygiene, test       │
  │      coverage gaps, prod-posture invariants, unspec'd-   │
  │      but-needed cross-cutting concerns. The reviewer     │
  │      plays devil's advocate vs /work + /verify which     │
  │      validate spec adherence.                            │
  │                                                          │
  │      Don't skip on anything auth/security/financial.     │
  │      Status: --review prints the invocation template;    │
  │      auto-dispatch is on the v2.1+ backlog.              │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [5c] /pr-fix triage   (RECOMMENDED — after 5b findings)  │
  │      /pr-fix                                             │
  │                                                          │
  │      • Reads PR review comments + diff                   │
  │      • Cross-spec handoff scan (v2.0.1 skill prose):     │
  │        fetches predecessor specs from Linear, checks     │
  │        every "X will…" promise landed in this PR;        │
  │        unfulfilled handoff = Critical regardless of own  │
  │        AC list                                           │
  │      • Confidence scoring per finding (verify before     │
  │        applying — Critical findings have a verification  │
  │        bar, see Calibration notes below)                 │
  │      • Interactive: user picks which to fix / reject /   │
  │        defer                                             │
  │      • Applies fixes as separate commits, validates      │
  │        gate, force-pushes to PR                          │
  │      • Posts Linear comment with triage summary          │
  │        (fixed N / rejected N / deferred N) — v2.1.0      │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [5d] /pr-security-review  (OPT-IN — security surface)    │
  │      /pr-security-review                                 │
  │                                                          │
  │      Run when the PR touches ANY of:                     │
  │      • method.config's Migration dir, or any *.sql file  │
  │      • SECURITY DEFINER function definitions             │
  │      • CREATE POLICY / ALTER POLICY (RLS)                │
  │      • GRANT / REVOKE statements                         │
  │      • auth code, middleware, session handling           │
  │      • Server Actions on privileged tables (audit_log,   │
  │        profiles, auth.users)                             │
  │                                                          │
  │      Surface-specific rubrics: M1-M8 migrations, R1-R6   │
  │      RLS, S1-S8 SECURITY DEFINER, G1-G3 GRANT/REVOKE,    │
  │      A1-A5 auth, P1-P4 server actions on privileged.    │
  │                                                          │
  │      Different from pk ship --review (broad/generic)     │
  │      and /repo-security-review (whole-repo audit). Run   │
  │      ALONGSIDE 5b for security-sensitive PRs — they      │
  │      cover different surface area.                       │
  │                                                          │
  │      Posts findings to PR + Linear summary comment.      │
  │      v2.1.0 added — surfaced by RS-74 (rs-vault).        │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [5e] Interactive UAT  (THE Stage 3 gate — non-skippable) │
  │                                                          │
  │      Human exercises the feature in the running app:     │
  │      • PR preview URL (pre-merge)    — state: UAT        │
  │      • dev.<project> (post-merge)    — state: In Dev     │
  │                                                          │
  │      Walk through every AC. Record the verdict —         │
  │      Linear comment, PR comment, or session-log note.    │
  │                                                          │
  │      Do NOT auto-chain past this step. /work, /verify,   │
  │      /pk-exit must NOT invoke pk done or pk promote on   │
  │      their own. Surfaced 2026-05-13 (WIT-451): worker    │
  │      session auto-fired pk done before UAT completed     │
  │      and wiped the worktree mid-test.                    │
  │                                                          │
  │      v2.5.0+: pk done IS the legitimate UAT → In Dev     │
  │      transition (it verifies the merge). pk promote      │
  │      refuses with exit 1 if any bundled issue is in      │
  │      UAT (PR not yet merged) — pass --confirmed after    │
  │      env-UAT signoff to hop forward.                     │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [6] Merge PR (manual, GitHub UI)                         │
  │     • feature → dev: rebase or merge-commit              │
  │     • dev/beta → main: merge-commit (anchor per promote) │
  │     Squash is disabled repo-wide (v2.2.0+) — caused      │
  │     phantom conflicts on every subsequent dev → main.    │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [7] Session close + return to parent repo                │
  │     /pk-exit       writes Logs/Sessions/<date>_<HHMM>.md │
  │                    narrative for the worktree session    │
  │     /exit          close Claude in the worktree          │
  │     cd ~/Projects/<repo>                                 │
  │     claude --dangerously-skip-permissions                │
  └──────────────────────────────────────────────────────────┘
       │
┌──────┴──────────────────────────────────────────────────────────┐
│  PARENT REPO       cwd: ~/Projects/<repo>     branch: dev       │
└─────────────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [8] Cleanup + state transition                           │
  │     pk done <ID> [--merge]                               │
  │     • verifies PR merged (--merge runs gh pr merge first)│
  │     • auto-pulls integration branch (v2.6.0+)            │
  │     • posts journal highlights to Linear                 │
  │     • Linear: UAT → In <FirstEnv> (or → Done for 1-tier) │
  │     • removes worktree, deletes local branch             │
  │     • finds any prefix/<ID>-* (PK_BRANCH_PREFIXES)       │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
       ◇ accumulated 1-3 dev merges?
              │
       No  ───┼───→  loop to [1]
              │
       Yes ───┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [8a] Prod-Ready Gate (v4.3.0; HARD v4.17.0; projects w/  │
  │      a checks file — skip if absent)                     │
  │      /prod-ready [<ID>]                                  │
  │      • run ONCE per feature, at the production boundary  │
  │        — before the FINAL pk promote hop (the last Ship  │
  │        environments env; the merge to main on 1-tier)    │
  │      • six operational checks: monitoring, secrets-in-   │
  │        bundle, rate limits, backups, flags, dashboard    │
  │      • PASS/FAIL report + Linear comment (no state       │
  │        change)                                           │
  │      • PASS writes prodready-complete.md (source-branch  │
  │        sha); pk promote <final-env> REFUSES without it   │
  │        on armed projects (--force / PK_PRODREADY_BYPASS) │
  │      • 1-tier projects merge to main without pk promote  │
  │        → stays advisory there (no seam to gate)          │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [9] Promote — two-phase, one hop per invocation (v2.6.0+)│
  │                                                          │
  │     Phase 1 — open the promote PR:                       │
  │       pk promote <env>                                   │
  │       • walks Ship environments (e.g. dev,beta,main)     │
  │       • opens source → target PR per hop                 │
  │       • embeds bundled WIT tracker in PR body            │
  │       • WITs stay in source state until merge            │
  │       • 2-tier: pk promote (no arg) picks the only hop   │
  │                                                          │
  │     ── human merges PR in GitHub UI ──                   │
  │                                                          │
  │     Phase 2 — finish the promote post-merge:             │
  │       pk promote <env> --finish                          │
  │       • finds the merged promote PR                      │
  │       • parses the marker for bundled WITs               │
  │       • transitions each issue:                          │
  │           intermediate hop  →  In <Env>  (e.g. In Beta)  │
  │           final hop         →  Done                      │
  │                                                          │
  │     Eliminates the ~5min Linear-ahead-of-reality window  │
  │     (F2 fix). Phase 1 prints the exact --finish command  │
  │     so the two-step flow is discoverable without docs.   │
  └──────────────────────────────────────────────────────────┘
```

---

## Weekly loop (the portfolio, once a week — `/tpm`)

The two loops above move **one issue**. This loop decides **which issues**, once a week, and writes the answer where a Monday-morning session can read it in thirty seconds: `engineering/WEEKLY_PLAN.md`. `/tpm` is a conversation, not a report — it reads the board as it actually is, drafts the week, argues it with you one question at a time, and only writes once you say "go". You type it; nothing starts it for you. Rubric: `sop/TPM_SOP.md`.

### The three commands

| You want | Type | What happens | Writes |
|---|---|---|---|
| **Plan the week** — Sunday, or whenever `pk next` opens with `plan agreed Nd ago → /tpm` | `/tpm` | preflight → one-screen briefing → questions, one per turn → read-back → "go" → Linear writes → the plan file | Linear + plan |
| **Mid-week check-in** — what moved, what slipped, what is waiting on you | `/tpm --check` | re-reads the plan and compares it with Linear, worktrees, PRs and live sessions; rewrites only the plan's *Drift since agreement* sub-section; lists any `on-merge` note whose issue merged but whose command never ran | plan only — **no Linear writes** |
| **A change you already know** — a tier swap, a commitment that moved | `/tpm --quick` | briefing, at most three questions, then the same writes; skips the hygiene sweep unless Triage items exist | Linear + plan |

Run it from the **parent repo root of the portfolio's primary repo** — `§ Plan primary`, else `§ Runbook primary`, else the repo you are in — never from a `pk branch` worktree. A sibling on the same board names the primary (`Plan primary: ../<repo>`) and `/tpm` reads the one board once from there.

### What it reads before it asks you anything

- The board, once per Linear team — `pk status`, `pk portfolio` — across every repo in `§ Portfolio repos`.
- Every worktree, open PR and live Claude session, lined up against Linear state. An issue `In Progress` with no worktree and no PR is a question, not a fact; a merged PR still in `UAT` is a `pk done` you owe.
- Last week's plan: what was MUST, what shipped, which WAIT triggers fired, which commitments come due.
- Placement drift, via `/linear-hygiene --check` in a subagent.

It opens with a **one-screen briefing**: leaks (work that looks in flight but isn't, or the reverse), floors (a `Client Request` label forces High), the draft MUST / NEXT / WAIT with the capacity arithmetic, a `Themes:` line for work you named that isn't a lane yet, and a `Words:` line that glosses its own jargon. Titles sit beside IDs everywhere.

### The conversation

One question per turn, starting with what most changes the output: capacity this week, commitments with dates, which lane is tier A. Capacity is in **session-days** — working days × the sessions you usually run side by side (five days, three sessions → 15); effort per issue is `Tier effort days` (Quick 0.1 · Standard 0.5 · Heavy 1). Answer in a sentence. "Just do it" is allowed; the assumptions then appear at the top of the plan. Before anything is written it reads the agreement back — including what is **not** changing — and waits for "go".

### What it writes, and where

| Where | What |
|---|---|
| Linear | Focus tiers (`pk focus <LANE> A\|B\|C\|none`), Hard dependencies as `blocked by`, a `[tpm DATE] …` comment on every issue it moved or parked, and `[tpm DATE] on-merge: <pk command> · <why>` on an issue whose merge triggers a later decision |
| `engineering/WEEKLY_PLAN.md` (`§ Plan path`) | The week as a task list (below). Only the block between `<!-- tpm:begin · agreed YYYY-MM-DD … -->` and `<!-- tpm:end -->` is regenerated; outside it the file is yours |
| This runbook's `## Now` block | One line: `This week → engineering/WEEKLY_PLAN.md · agreed YYYY-MM-DD` |
| A sibling repo's `## Now` block | One line pointing at the primary's plan |

Then it re-runs `pk next` and shows that the order on the board is the order you agreed.

### Reading the plan

Written for the person at the keyboard, not as a Linear digest. Top to bottom:

- **Start now** — one row per session: the `pk branch <ID>` to type, what it is, the merge day.
- **Session 1 / 2 / 3 …** — a checklist per session with repo, effort and merge day; the "Ship it" rungs spelled out (`/sync-legacy`, `pk promote <env>`, …).
- **Free slot** · **If the week runs long** — what to pick up with spare time; what to drop first.
- **Lanes — the picture** — tiers A / B / C and the flow inside each: `▸` hard dependency (in Linear as `blocked by`), `⇢` soft order, `→` then.
- **Don't merge together** · **Merge calendar** — migrations one per day, and which branches must not land on the same day.
- **Commitments** · **Waiting on you** (hand work, not Linear writes) · **Parked (WAIT)** (each with its fallback and the trigger that brings it back) · **Not this week, and why** · **Themes** · **Notes from the session**.
- **Drift since agreement** — empty on Sunday; `/tpm --check` fills it in.

Tick the boxes as you go; edit anything. The next `/tpm` regenerates the block from Linear, so a change you want to keep goes into Linear or into the conversation, not into the file.

### During the week

- **`pk next`** reads the agreed date on the plan's begin marker and prints `plan agreed Nd ago → /tpm` once it is past `§ Plan stale days` (default 7), or `plan: no agreement yet → /tpm` when the plan was never written. Nothing nags before that.
- **`pk done <ID>`** reads any `[tpm] on-merge:` note on the issue after the merge, prints it under `TPM follow-through — [tpm] on-merge notes on <ID>:` and asks `Run now? [y/N]`. `y` runs the `pk` command (`pk focus I7.P10 C --swap`, say); anything else prints `not run — run each by hand`. Off a terminal, or with `PK_ON_MERGE=print`, it only prints. It cannot fail `pk done`.
- **The plan and Linear disagree?** Linear wins. `/tpm --check` says so; the next `/tpm` rewrites the plan.

### Setup (once, in `method.config.md`)

`Plan path` (default `engineering/WEEKLY_PLAN.md`) · `Plan primary` on a sibling repo that shares the board · `Plan stale days` (7) · `Weekly capacity days` (working days × average concurrent sessions) · `Tier effort days` (`Quick: 0.1, Standard: 0.5, Heavy: 1`) · `Portfolio repos`. The sync scaffolds an empty plan for a primary repo and never touches it again; `Runbook primary` / `Runbook stale days` still work as fallbacks for a project that has not added the Plan keys.

---

## Maintenance (periodic — keep the board healthy)

The two loops above run **per issue**. These run *between* issues, on a cadence — the Linear housekeeping that keeps `pk next` pointing at the right work and the roadmap honest. None is part of the daily loop; run each when its trigger fires, not every session. All are **propose-then-apply** (or read-only) — they never mutate state without showing you a manifest first.

| Skill | Job | Run when |
|---|---|---|
| `/linear-hygiene` | **Placement janitor, now the backstop** — since v4.37.0 the filers place follow-ups at creation (`sop/Linear_SOP.md § Filing a follow-up issue`); this homes whatever still lands orphaned (no project), Triage-stuck, or unprioritized, and names the filer that missed. Propose-then-apply; `--check` is read-only; `--session` scopes to issues filed this session. Placement only — never disposition, and **never touches `Roadmap: *` labels**. | `--check --session` at session end; the full sweep after `pk done`, before a phase, or when follow-ups have piled up. |
| `/tpm` | **Decide the week** — the weekly loop above: reconcile what is really in flight → one-screen briefing → agreement, one question at a time → tiers, relations and `[tpm]` comments in Linear → `engineering/WEEKLY_PLAN.md` (v5.1.0). `--quick` (≤3 questions), `--check` (read-only drift). Walkthrough: § Weekly loop. | Weekly, or when `pk next` opens with `plan agreed Nd ago → /tpm`. Before `/phase-plan --cut`. |
| `/brainstorm-review` | **Disposition** — Now / Later / Kill verdict on the Triage + Ideas backlog. Scope-reduces "Now" items; parks "Later" with a re-check trigger. | When the brainstorm backlog stacks up; before `/phase-plan`. |
| `/roadmap-review` | **Health audit** — Stage 0 gate + ongoing checks: completeness, dependencies, ordering, spec coverage, doc freshness, plus the optional **roadmap-progress** (checkbox ↔ Linear `Done`) and **phase-label-layer** checks. Reports which skill to run for each gap. | Before speccing a new initiative; at initiative start; monthly. |
| `/phase-plan` | **Advance the roadmap** — select the next execution batch and promote its issues to Needs Spec (which feeds the spec loop). | When the current sub-phase is closing. |

### Phase-label layer (optional — roadmaps whose phases span multiple projects)

If `method.config.md § Phase Label Layer` is configured, the board mirrors `ROADMAP.md`'s build order via `Roadmap: Phase *` / `Order: Any` labels + one Manual-sorted saved view per label — so Linear renders "this phase, in order" that a plain project filter can't. Upkeep lives in `/roadmap-review` Phase 3.5:

- **First run on an existing board** → it detects the un-scaffolded layer and offers a one-time **bootstrap**: create the labels + views, seed `sortOrder` from the roadmap order, apply membership + `blockedBy` relations.
- **Ongoing** → it drift-checks membership / `sortOrder` / relations against `ROADMAP.md` and proposes fixes; the checkbox ↔ `Done` reconciliation (Phase 2.5) rides along.
- **The one manual step** → toggle each saved view to **Manual sort** in the Linear UI (not settable over the API); until you do, the seeded `sortOrder` won't render.

---

## Command cheat sheet

> Each `pk` row shows the global `pk` form (after `pk install`) and the `./bin/pk` repo-local form. They're equivalent; pick whichever matches your shell state.

| # | Step | Command (global) | Command (repo-local) | Where | Auth |
|---|---|---|---|---|---|
| wk | Plan the week | `/tpm` | — (skill) | primary repo, parent | reads Linear + worktrees + PRs + sessions; on "go" writes tiers, `blocked by` relations, `[tpm]` comments, `engineering/WEEKLY_PLAN.md` and the `## Now` pointer (v5.1.0). § Weekly loop |
| wk | Mid-week check-in | `/tpm --check` | — (skill) | primary repo, parent | no Linear writes; rewrites only the plan's *Drift since agreement* sub-section; lists `on-merge` notes whose issue merged but whose command never ran |
| wk | A change you already know | `/tpm --quick` | — (skill) | primary repo, parent | briefing, at most three questions, then the same writes |
| wk | Set a lane's tier by hand | `pk focus <LANE> A\|B\|C\|none [--swap]` | `./bin/pk focus <LANE> A\|B\|C\|none [--swap]` | parent | writes Linear project priority (v4.38.0); `--swap` trades tiers with the lane that holds it |
| 1 | Find next (focus lanes, then initiative-aware) | `pk next` | `./bin/pk next` | parent, dev | focus lanes first — Linear project priority Urgent/High/Medium = tier A/B/C (v4.38.0), then their blockers, then the initiative walk (`i{N}.`/`I{N}.P{N}.`); `--lane <TAG>` pins one lane |
| 1 | Quick status | `pk status` | `./bin/pk status` | parent | reads Linear (full board, unscoped); leads with the `Focus  A … · B … · C …` strip |
| 1 | Who is waiting on me | `pk sessions` | `./bin/pk sessions` | anywhere | live Claude sessions from transcript tails, waiting first; no Linear read (v4.38.0) |
| 2 | Branch | `pk branch <ID>` | `./bin/pk branch <ID>` | parent, dev | writes Linear (In Progress) |
| 3 | Plan + execute | `/work <ID>` | — (skill) | worktree | reads Linear |
| 3 | (Variant) | `/work <ID> --deep` | — (skill) | worktree | reads Linear; spawns 2 grounding agents |
| 4 | Verify | `/verify` | `./bin/pk verify` | worktree | local-only |
| 5 | Ship | `pk ship` | `./bin/pk ship` | worktree | push + gh pr create as **Draft** (v2.6.0+) + writes Linear (UAT) |
| 5 | (Variant) | `pk ship --env=<env>` | `./bin/pk ship --env=<env>` | worktree | + targets specific environment |
| 5 | (Variant) | `pk ship --ready` | `./bin/pk ship --ready` | worktree | open Ready instead of Draft (v2.6.0+; for one-shot tiny WITs) |
| **5a** | **Flip Draft → Ready** | **`pk ready [<ID>]`** | **`./bin/pk ready [<ID>]`** | **worktree or parent** | **fires `ready_for_review` GH event → outside reviewers run (v2.6.0+). Refuses if source/a migration changed since `/verify`, or the verified sha is unreachable after a rebase (v4.27.0+) — re-verify or `--force`** |
| **5b** | **Antagonistic review** | **`pk ship --review`** | **`./bin/pk ship --review`** | **worktree** | **prints reviewer invocation; posts Linear "review in flight" comment (v2.1.0)** |
| **5c** | **/pr-fix triage** | **`/pr-fix`** | **— (skill)** | **worktree** | **interactive findings triage; cross-spec handoff scan; posts Linear summary (v2.1.0)** |
| **5d** | **/pr-security-review (opt-in)** | **`/pr-security-review`** | **— (skill)** | **worktree** | **security-focused PR review for migrations / RLS / SECURITY DEFINER / auth (v2.1.0)** |
| 7 | Cleanup | `pk done <ID> [--merge]` | `./bin/pk done <ID> [--merge]` | parent, dev | verifies PR merged (or `--merge` runs `gh pr merge` first), removes worktree, posts journal highlights to Linear, transitions Linear UAT → `In <FirstEnv>` (or → Done for 1-tier). **v2.6.0+**: also auto-pulls the integration branch. `--confirmed` accepted for backward compat (no-op). |
| **8** | **Promote — open** | `pk promote <env> [--confirmed] [--stash\|--take-remote]` | `./bin/pk promote <env> [--confirmed] [--stash\|--take-remote]` | parent, dev | **v2.6.0+ two-phase**: opens promote PR, embeds bundled-WIT tracker in PR body, **WITs stay in source state until merge**. Refuses if any bundled issue is still in `UAT`; pass `--confirmed` after env-UAT sign-off. |
| **8b** | **Promote — finish** | **`pk promote <env> --finish`** | **`./bin/pk promote <env> --finish`** | **parent, dev** | **v2.6.0+**: after the promote PR merges, transitions bundled WITs → `In <Env>` (intermediate) or → Done (final). Reads the tracker from the merged PR body; falls back to PR commits for older promote PRs without the marker. |
| **8′** | **Deploy (script projects)** | `pk deploy [<env>] [-- <args>]` | `./bin/pk deploy [<env>] [-- <args>]` | parent | **v4.6.0**: the script-deploy analog of promote (steps 8/8b). Runs the configured `Deploy command` for `<env>` (bare / `prod` → `Deploy command`; `pk deploy dev` → `Deploy command dev`); args after `--` pass to the script. Thin delegate — the script owns confirmation + safety. Used by projects that ship by script, not branch promotion (`Promote to main: false` + a `Deploy command`). |
| meta | Diagnose | `pk doctor` | `./bin/pk doctor` | anywhere | config + API ping |
| meta | Bootstrap | `pk init` | `./bin/pk init` | repo root | walks setup |
| meta | Install | `pk install` | `./bin/pk install` | repo root | symlinks pk onto $PATH (v2.0) |
| meta | View journal | `pk log` | `./bin/pk log` | worktree, feature | local-only |
| meta | Linear Agent | `pk delegate <ID> <prompt>` | `./bin/pk delegate <ID> <prompt>` | anywhere | posts @Linear-mentioned comment |
| meta | Help | `pk help` | `./bin/pk help` | anywhere | — |

---

## Configuration (`method.config.md` § V2)

| Key | Values | Default | Used by |
|---|---|---|---|
| **Integration branch** | `dev` \| `main` | derived from § Git Architecture | `pk ship` PR base |
| **Promote to main** | `true` \| `false` | `true` if integration is `dev` | `pk promote` enabled |
| **Require QA review** | `true` \| `false` | `false` | `/verify` runs QA subagent |
| **Default deep flag** | `true` \| `false` | `false` | `/work` always uses `--deep` |
| **Ship environments** | comma list | `dev,main` | `pk ship --env=<name>`; `pk promote <env>` walks the chain |
| **Worktree prefix** | path (trailing `-` or `/`) | `${root}/.worktrees/` | `pk branch` worktree location (v2.2.2+) |
| **Linear API key env var** | name | `LINEAR_API_KEY` | `pk` Linear access |

Secret resolution priority: **`.env.local` > `.env` > process env**.

---

## Antagonistic PR review (the third gate)

The v2 pipeline has three gates, only the first two are mandatory:

| Gate | What it catches | When |
|---|---|---|
| `/work` plan-verdict | Spec ambiguity, missing AC coverage, scope mismatch | Before any code is written |
| `/verify` (gate + QA) | Build/lint/type errors, AC traceability, omissions, scope creep | After code is written, before push |
| **`pk ship --review`** | **Cross-cutting concerns NOT in the spec** — auth posture, security headers, brand hygiene, test rot, double-click races, race conditions, things-the-spec-didn't-think-to-mention | **After PR opens, before merge** |

The first two validate **spec adherence**. The third plays **devil's advocate** — finds what the spec didn't ask but should have.

### When to use `--review`

Always opt in for:
- Anything touching auth, RLS, sessions, OAuth
- Financial logic (math, FX, tax, invoicing)
- New external API integrations
- Security headers / CSP changes
- Anything labeled `auth-rls`, `payments`, `pii`, `compliance`, `breaking-change`

Skip for:
- Pure copy/UI tweaks
- Internal-only refactors with no external surface

### Manual invocation (auto-dispatch on v2.1.x backlog)

If `pk ship --review` doesn't dispatch automatically, invoke directly:

```
Invoke `pr-review-toolkit:code-reviewer` agent on PR #<N> with antagonistic
rubric. Cite file:line for findings. Group by severity. Post review via:
  gh api -X POST repos/<owner>/<repo>/pulls/<N>/reviews \
    -f event=COMMENT -f body="<full markdown>"
```

### What it found tonight (RS-60 → PR #82)

- **Critical:** `enable_signup=false` documented but not boot-enforced
- **High:** e2e tests not in pre-deploy gate (will rot)
- **High:** `validateRedirectTo` zero e2e coverage for open-redirect attacks
- **High:** Server Action double-click race creates orphan PKCE codes

All four became RS-61 — none would have been caught by `/work` or `/verify` alone.

---

## Recovery (one rule)

**Rerun the command.** Every `pk *` is idempotent against Linear+git ground truth.

| Failure | Behavior |
|---|---|
| `pk branch` mid-failure | Rerun. Worktree exists? skip. Linear correct? skip. |
| `/work` interrupted during plan | Rerun. Plan committed? skip to dev. |
| `pk ship` after PR opens but Linear didn't transition | Rerun. PR exists? skip create, transition only. |
| `pk done` before merge | Refuses with "PR not merged yet." Merge first, retry. |
| `pk done` from inside worktree | Refuses. `exit && cd ~/Projects/<repo> && claude` then retry with `<ID>` arg. |
| Forgot to run `/pk-exit` before closing | No log written for that session. No recovery — write a manual entry in `Logs/Sessions/` if it mattered. |
| `gh pr view` returns empty / `pk ship` says "no PR" wrongly | GraphQL rate-limited. `pk_gh_pr_view` / `pk_gh_pr_create` use REST fallback — rerun. Confirm with `gh api rate_limit --jq '.resources.graphql.remaining'`. |

If a `pk *` rerun doesn't resolve in one cycle, capture the failure (paste output into your session, file a Linear issue) — every step is idempotent against Linear+git ground truth, so a real failure is a bug worth diagnosing, not something to route around.

---

## Backlog

> Historical "shipped" entries live in `CHANGELOG.md`, not here. This section tracks **open** work only.

### v2.1.x / v2.2 candidates (still backlog)

- **`resources/` vs `temp/` portable convention** — `resources/` for committed reference materials (design handoffs, spec dependencies); `temp/` fully gitignored for ephemera. Bake into `method.md`, `templates/`, and consuming-project bootstrap. Surfaced 2026-05-02 when RS-63's `/work` couldn't see the design handoff (lived in parent's `temp/`, gitignored, didn't travel to worktree).
- **`pk branch` worktree-aware resource sync** — copy `resources/` (and any `.pkignore`-listed paths) into new worktrees so gitignored-but-needed files travel with the work. Companion to the convention above.

### Flowchart promotion (still pending — v2.1.x or v2.2)

v2.1.0 added [5c] /pr-fix and [5d] /pr-security-review explicitly to the flowchart. Two items still pending:

- **Insert a new step between [4] Verify and [5] Ship**: visual-state verification — runs Playwright (or equivalent) against the worktree's running app at key user states, diffs against figma source. Optional gate (config: `Require visual review: true|false`). Catches the class of miss where components compile + tests pass but the integration didn't land (RS-64 example). **Deferred** because this needs new infra (Playwright + diff library + figma-source resolver) — too big for the v2.1.0 same-day cut.
- **"Defended status quo" guardrail at flowchart level** — already in `/work` skill prose (Step 6.5), but could be promoted to a dedicated flowchart step. Lower priority since the prose is already in.

After those land, final shape will be: 1 → 2 → 3 → 4 → **4b (visual)** → 5 → 5b → 5c → 5d → 6 → 7 → 8.

### Surfaced 2026-05-02 PM (RS-64 cross-spec miss)

A Phase 2.5 issue (RS-63) explicitly handed off integration work to its successor (RS-64) — *"RS-64 will replace the placeholder with real Drawer chrome + PropertyCard."* RS-64's PR shipped the components but never integrated them into `search-page.tsx`. Antagonistic review missed it (only had RS-64's AC to check). When the user later asked Claude in the worktree about the placeholder + provided a screenshot, Claude **rationalized the status quo** ("wiring harness for something to come later") rather than checking against intent. Three process gaps:

- **Cross-spec handoff verification** — when an issue's spec contains "`<other-issue>` will…" references, that's a load-bearing handoff promise. Antagonistic review and `/pr-fix` should fetch the predecessor's spec, extract its handoff statements, and verify each landed in the current PR. Right now reviewers only see the current issue's AC.
- **Visual-state verification step** — for any UI issue, the antagonistic-review prompt should explicitly require a screenshot of the running app at a key user-facing state (e.g., post-action, hover, modal-open) compared against the figma handoff or design source. Today the loop is all code review, no visual review. Could be `pk ship --review --visual <url>` or a new `/visual-review` skill that drives Playwright + diff against design source.
- **"Defended status quo" guardrail** — when Claude is asked about a UI/state question with a screenshot, the default behavior should be skepticism: re-read the spec, grep the integration site, check if what's shown matches what's intended. Today Claude pattern-matches on the artifact + nearest-comment-explanation and produces plausible-sounding rationale. Mitigation lives in skill prose (e.g., `/pr-fix` and `/work` should explicitly instruct: "if the user asks 'is this correct?' with a screenshot, do not defend — verify against spec first").
- Automated subagent dispatch from `pk ship --review` — see `temp/ship-skill-spec.md` for full scope. Crosses shell ↔ skill ↔ subagent boundary; needs `/ship` skill wrapper.

### beta candidates

- **beta.1** — multi-env `pk ship --env=<env>` for Piper (Vercel + Supabase branch + LaunchDarkly)
- **beta.1** — skills directory reorg: `skills/{loop,stage0,orthogonal}/` subdirs
- **beta.2** — GitHub Actions workflow `pr-review.yml` — antagonistic review on PR open (CI-side)

