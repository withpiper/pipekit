---
name: prod-ready
description: Production-readiness gate — verifies operational preconditions /verify doesn't (monitoring, secrets, rate limits, backups, flags); writes the sentinel the final pk promote hard-requires on gated projects. Run once before the final promote.
---

# /prod-ready

> **North star:** `/verify` proves the code is correct in isolation. `/prod-ready` proves the system can absorb it safely **in production**. Two different questions, two different gates.

You are an SRE conducting a **production-readiness review** of a feature that is about to reach its production environment. You verify the *operational preconditions* — error monitoring, secret hygiene in the shipped bundle, rate limiting, backups, kill switches, dashboards — that the per-task pre-deploy gate (`/verify`) deliberately does not check.

This is the **portable framework**. The concrete, project-specific checks (the build command that produces the client bundle, the secret prefixes to grep, which monitoring tool, where rate-limit middleware lives, the backup provider, the feature-flag system, the dashboard URL) live in a **project checks file** you read at runtime — never hardcode them here. A project that hasn't written a checks file gets scaffolded one and stops.

Different from `/verify` (runs every task at Building → ship, fast: tests/lint/types) and `/repo-security-review` (repo-wide security audit). This one runs **once per feature**, late — at the seam before the feature reaches production — and is **advisory**: it reports and comments, it does not move Linear state. The human (or, in a future release, a hard `pk promote` gate) acts on the verdict.

## Where this sits in the pipeline

```
Multi-env (dev,beta,main):
  … pk done → [env UAT] → pk promote beta … → pk promote main …
                                                     ↑
                              run /prod-ready before the FINAL promote
                              (the last entry in `Ship environments`)

1-tier (Ship environments: main; pk promote disabled):
  … /verify → pk ship → pk ready → /prod-ready → pk done [--merge]
                                        ↑
                  the merge to `main` IS the production boundary —
                  run /prod-ready before pk done, NOT before a pk promote
```

- **Multi-env projects** (e.g. `dev,beta,main`): run `/prod-ready` before the promote into the **last** env in `Ship environments` — the production env. Earlier hops (dev, beta) are testing grounds; the operational preconditions matter at the production boundary.
- **1-tier projects** (`Ship environments: main`, `Promote to main: false`): there is no promote chain — `pk promote` is disabled. The merge to `main` (`pk done`) *is* the production boundary, so run `/prod-ready` before `pk done`.

It runs **once per feature**, not per task — that is the whole reason it is separate from `/verify`. Keep `/verify` fast; layer production readiness on top, late.

## Triggers

- `/prod-ready` — primary; resolves the feature issue from the current branch
- `/prod-ready <ISSUE-ID>` — explicit
- "is this production-ready?" / "run prod readiness"

## Config (read from `method.config.md`)

| Key | Purpose | Default |
|-----|---------|---------|
| **Prod-ready checks** | Path to the project checks file | `resources/prod-readiness-checks.md` |
| **Prod-ready report path** | Where to write the readiness report | `Reports/` |
| **Ship environments** | Comma-separated, ordered; the **last** entry is the production env this gate guards | `dev,main` |
| **Project display name** | Report header + comment | (project name) |

**Linear is best-effort and advisory.** Resolve the feature issue ID, post a comment with the verdict, and **do not** change its workflow state — promotion (and the human signoff before it) owns the transition. Look up the issue via the project's Linear MCP; if Linear is unreachable, write the report anyway and tell the user to paste the verdict manually. Never hardcode Linear UUIDs.

## Step 0 — Load the checks file (gate)

Read the checks file at `Prod-ready checks` (default `resources/prod-readiness-checks.md`).

- **If it doesn't exist**, STOP and tell the user:
  > No production-readiness checks file found at `<path>`. This skill is the framework; the project supplies the checks.

  Then scaffold one and stop for the user to fill it in:
  - If `pipekit/templates/prod-readiness-checks.template.md` exists (synced projects), copy it to `<path>`.
  - Otherwise create `<path>` directly with the template's sections, each filled for the project: **Build command**, **Secret prefixes**, **Monitoring**, **Public endpoints & rate limiting**, **Backups**, **Feature flags**, **Dashboards**, **Not applicable** (checks this project opts out of, with a one-line reason).
  - Do not invent project specifics — leave clearly-marked placeholders for the user.

The checks file is the substance; this skill is the discipline + report shape.

## Step 1 — Resolve the feature, target env, and open the review

```bash
CURRENT=$(git branch --show-current)
ISSUE="${1:-}"
[ -z "$ISSUE" ] && ISSUE=$(echo "$CURRENT" | grep -oE '[A-Z]+-[0-9]+' | head -1)

# The production env this gate guards = the LAST entry in Ship environments.
# Falls back to the integration branch, then "main", if the key is unset.
SHIP_ENVS=$(pk config "Ship environments" "")
[ -z "$SHIP_ENVS" ] && SHIP_ENVS=$(pk config "Integration branch" "main")
PROD_ENV=$(echo "$SHIP_ENVS" | tr ',' '\n' | sed 's/[[:space:]]//g' | grep -v '^$' | tail -1)
```

`PROD_ENV` is resolved, not assumed — **always print it** in the summary line below so the user can correct a mis-resolution before acting. On a 1-tier project (`Ship environments: main`, `Promote to main: false`) there is no promote chain; `PROD_ENV` is the integration branch and the gate is advisory-before-merge (see § Where this sits).

If `ISSUE` is set and Linear is reachable, post a comment on the issue via the project's Linear MCP — `mcp__linear-server__linear_createComment` (the camelCase `@tacticlaunch/mcp-linear` surface; use whatever comment tool the project exposes): `"Starting production-readiness review for the {PROD_ENV} boundary — {YYYY-MM-DD}"`. **Do not** call any state-changing tool.

If `ISSUE` can't be resolved (detached HEAD, no ID in branch), proceed anyway — the report still gets written; just skip the Linear comment.

Print one line:

```
Prod-ready: <ISSUE | (no issue)>  ·  Target env: <PROD_ENV>  ·  Checks: <path>
```

## Step 2 — Build the production bundle (for the secrets check)

Read the checks file's **Build command**, the **client-served output dir** (`CLIENT_OUTPUT_DIR`), and the grep **excludes**. Run the build; check 2 greps the client-served dir, never the whole build tree.

```bash
# Shape — real values come from the checks file:
#   pnpm build  →  CLIENT_OUTPUT_DIR=.next/static  (NOT all of .next/ — .next/server/ is server-only)
#   exclude *.map (sourcemaps embed source-side env refs by design)
```

- If the build **fails**: **Critical** (can't ship an artifact that doesn't build). Surface immediately, continue the other checks against source.
- If the build command is **blank**: check 2 can only be skipped if the checks file lists it under **Not applicable** with a reason. A blank build command **without** an explicit N/A entry is **not** a silent skip — record it as a **Medium** finding ("secrets check could not run — confirm this project ships no client bundle"). Fail safe, not open: the one check whose miss means "a secret reached every browser" never silently passes.

## Step 3 — Parallel readiness audit (sub-agents)

Run the six checks. Each is tagged by how it's verified:

- **automatable** — the skill runs a command and reads the result (deterministic)
- **agent-verifiable** — a read-only sub-agent reads the code/config and returns a verdict with `file:line` evidence
- **manual-confirm** — the skill cannot prove it; ask the user to confirm (paste a URL / answer yes-no), and record their answer

Spawn the agent-verifiable checks as **parallel read-only sub-agents** (`subagent_type: "general-purpose"`, execution tier per `method.config.md § Model Policy` — default `sonnet`, effort `medium`, `allowed-tools: Read, Bash, Grep, Glob`). They return findings with evidence; they do not fix. Each finding carries `file:line` or a command result.

| # | Check | Kind | What it verifies (specifics from the checks file) |
|---|-------|------|----|
| 1 | **Error monitoring wired** | agent-verifiable | The feature's code path emits to the project's monitoring tool (Sentry/PostHog/LogRocket) and the capture is configured. Sub-agent reads the changed files + the monitoring init, confirms the new error surface is observable. Missing = **High**. |
| 2 | **No secrets in client bundle** | automatable | `grep -rE` the checks file's **Secret prefixes** against **`CLIENT_OUTPUT_DIR`** (e.g. `.next/static`), **excluding** sourcemaps (`*.map`) and any server-only dir (`.next/server/`). Match the *value/prefix* (`sk_live_`, the `service_role` JWT marker, a PEM header) — env-var **names** won't appear in a minified bundle. Any match = **Critical**. Greps the *built client output*, never source. |
| 3 | **Rate limiting on new public endpoints** | agent-verifiable | For every new public API route in the diff, the rate-limit middleware named in the checks file is applied. A new unauthenticated/public route with no rate limit = **High**. |
| 4 | **Backups active on target env** | manual-confirm | The production DB on `PROD_ENV` has a backup policy configured (provider-specific — Supabase backup tab, self-hosted cron). Ask the user to confirm the policy is active; record the answer. Unconfirmed on a DB-touching feature = **High** (downgrade to **Low** if the feature touches no DB). |
| 5 | **Feature flag / kill switch** | agent-verifiable | If the feature is risky (financial calc, data leak, bulk destructive op), a flag wraps the risky path. Sub-agent reads the diff, classifies risk, confirms the flag exists and gates the path. Risky + no flag = **High**. |
| 6 | **Monitoring dashboard chart** | manual-confirm | A dashboard chart exists for the feature's key metric. Ask the user for the dashboard URL / doc reference; record it. Missing = **Low** (recommendation, not a blocker). |

Skip any check the checks file lists under **Not applicable** (record it as `N/A — <reason>` in the report, not as a pass).

## Step 4 — Reconcile and rate

Collect every finding. Apply the severity rubric (below). The headline status:

- **FAIL** — any **Critical** finding, OR any unaddressed **High** finding.
- **WARNINGS** — only Medium/Low findings, or manual-confirms the user couldn't confirm but judged acceptable.
- **PASS** — every applicable check clean (or N/A), no Critical/High.

**This gate is hard as of v4.17.0:** on a project with a `Prod-ready checks` file, `pk promote <PROD_ENV>` (the final `Ship environments` hop) refuses without a PASS sentinel matching the source branch head (Step 5 writes it). A FAIL writes **no sentinel** — close the findings and re-run; the escape hatches are `pk promote <env> --force` or `PK_PRODREADY_BYPASS=1` (both logged to `Logs/ProdReady/bypass.log`).

## Step 5 — Generate the report + sentinel

Write `<Prod-ready report path>/Production_Readiness_<ISSUE>_<YYYY-MM-DD>.md` (omit `<ISSUE>_` if no issue resolved):

```markdown
# Production Readiness Review — {ISSUE}  ·  {Project display name}
**Target env:** {PROD_ENV}  ·  **Date:** {YYYY-MM-DD}

## Summary
- **Status:** PASS / FAIL / WARNINGS
- **Critical:** {n}  ·  **High:** {n}  ·  **Medium:** {n}  ·  **Low:** {n}
- **Build:** {ok / FAILED}

## Checks
| # | Check | Kind | Result | Evidence |
|---|-------|------|--------|----------|
| 1 | Error monitoring wired | agent-verifiable | Pass / Fail / N/A | `<file>:<line>` |
| 2 | No secrets in client bundle | automatable | Pass / Fail | grep result |
| 3 | Rate limiting on new public endpoints | agent-verifiable | Pass / Fail / N/A | `<file>:<line>` |
| 4 | Backups active on {PROD_ENV} | manual-confirm | Confirmed / Unconfirmed / N/A | user answer |
| 5 | Feature flag / kill switch | agent-verifiable | Pass / Fail / N/A | `<file>:<line>` |
| 6 | Monitoring dashboard chart | manual-confirm | Confirmed / Missing | URL / doc ref |

## Findings
### Critical
{list with file:line / command result, or "None"}
### High
{list, or "None"}
### Medium
{list, or "None"}
### Low / Recommendations
{list, or "None"}

## Next actions
{specific, ordered — what to wire/fix before promoting to PROD_ENV}
```

**On PASS — and only on PASS — also write the sentinel** `pk promote` reads (v4.17.0 hard gate):

```bash
# The sha is the audited code: the head of the branch being promoted to PROD_ENV
# (the second-to-last `Ship environments` entry — e.g. `dev` on 2-tier, `beta` on 3-tier).
_src_branch="<second-to-last Ship environments entry>"
_src_sha=$(git rev-parse "origin/${_src_branch}" 2>/dev/null || git rev-parse "${_src_branch}")
_pr_dir="Logs/ProdReady/$(date +%Y%m%d)"
mkdir -p "$_pr_dir"
printf '# prodready-complete\n\nstatus: PASS\nsha: %s\nenv: %s\n' \
  "$_src_sha" "$PROD_ENV" > "$_pr_dir/prodready-complete.md"
```

- **Never** write it on FAIL or WARNINGS-you'd-block-on. A missing sentinel is the blocking signal.
- The `sha:` pins the audited source-branch head — a feature merged into the source branch *after* this audit correctly invalidates the sentinel (the batch changed; re-run the gate).
- Not issue-scoped: prod-ready audits the promote batch at the boundary, and a promote bundles WITs.

- If `ISSUE` resolved and Linear reachable: post a comment — the **Summary** block + a link/path to the report. **Do not** change state.
- Present to the user: overall status, finding counts, top findings by severity, and the explicit next-action — `Promote to {PROD_ENV}` if PASS, or `Hold — close {n} finding(s) first` if FAIL.

## Severity rubric

- **Critical** — a secret is in the shipped client bundle, or the production artifact does not build. Ship-stopping.
- **High** — a new error surface with no monitoring; a new public endpoint with no rate limit; a risky path with no kill switch; backups unconfirmed on a DB-touching feature. Operationally unsafe in production.
- **Medium** — partial coverage (monitoring wired but the new path not instrumented; rate limit present but mis-scoped).
- **Low** — no dashboard chart; nice-to-have observability gaps. Recommendation, not a blocker.

## Key principles

1. **Code readiness ≠ production readiness.** `/verify` proves the code; this proves the environment can absorb it. Never merge the two gates — different cadence, different failure modes.
2. **Greps the built artifact, not source.** The secrets check is meaningless against source — a `.env` reference in source is fine; the same value baked into `.next/static/…` is a leak. Always build first.
3. **Evidence-based.** Every finding cites a `file:line`, a command result, or a recorded user answer. No vibes.
4. **Hard-gated, once per feature.** It reports, comments, and (on PASS) writes the sentinel `pk promote` requires at the final hop; it does not transition Linear state and does not run per task.
5. **Framework here, checks in the project.** Never hardcode a project's build command, secret prefixes, monitoring tool, or dashboard URL — they live in the checks file and `method.config.md`.

## What this skill does NOT do

- No Linear state transitions — promotion owns those; this only comments.
- No code modifications — sub-agents are read-only (`Read, Bash, Grep, Glob`).
- No per-task running — that's `/verify`. This runs once, at the production boundary.
- No blocking of its own — the skill writes the PASS sentinel; **`pk promote` does the refusing** at the final hop (v4.17.0). The skill never aborts a promote itself.
- No session-log writes — `/pk-exit` owns the session log.

## The hard gate (shipped v4.17.0)

The fast-follow documented since v4.3.0 is built: this skill writes a sha-matched sentinel on PASS (`Logs/ProdReady/<date>/prodready-complete.md`, mirroring `/verify`'s `verify-complete.md`), and **`pk promote` refuses** to open the production PR — the final `Ship environments` hop only — when the project's `Prod-ready checks` file exists and no sentinel matches the source branch head. Escapes: `pk promote <env> --force` or `PK_PRODREADY_BYPASS=1` (both logged to `Logs/ProdReady/bypass.log`). Intermediate hops and projects without a checks file are unaffected — the same file that arms this skill arms the promote gate, so opting in is one file. **Known limitation:** single-tier projects (`Promote to main: false`) merge to `main` without `pk promote`, so the hard gate has no seam there — the skill stays advisory for them.
