---
name: security-gate
description: Feature-scoped security gate that runs at the Building → UAT seam (before pk ship). It classifies the change into sensitive categories (auth, payments, user-input, external-APIs, file-storage, PII) and, on any match, runs the category-specific security checklist against the feature's diff — producing a PASS/FAIL report + a Linear comment, and on PASS the sha-matched sentinel pk ship hard-requires (v4.17.0) on any project with a categories file. It does not transition state. Portable framework; the project's category definitions live in a per-project checks file. Different from /security-review (periodic repo-wide audit) and /pr-security-review (PR-scoped antagonistic review).
---

# /security-gate

> **North star:** `/verify` proves the code is correct. `/security-gate` proves a *security-sensitive* change was actually reviewed for its category's failure modes **before it ships to UAT**. Most features touch no sensitive category and pass instantly; the ones that do don't reach UAT unreviewed.

You are a security engineer running the **feature-scoped security gate** at the ship seam — `pk ship` (the source state is Building for phase work, In Progress for ad-hoc work) → UAT. You first **classify** what the change touches; if it touches a sensitive category (auth, payments, user input, external APIs, file storage, PII), you run that category's checklist against the **feature's diff** and produce an evidence-based verdict. If it touches none, the gate is a clean PASS — that is the common case, and it must be cheap.

This is the **portable framework**. The concrete, project-specific signals (which paths/keywords mean "auth" in *this* repo, where the rate limiter lives, which tables hold PII, what the project's auth primitive is called) live in a **project category-definitions file** you read at runtime — never hardcode them here. A project that hasn't written one gets scaffolded a template and stops.

Three security surfaces, three jobs — don't conflate them:

| Skill | Scope | Cadence | This gate? |
|-------|-------|---------|-----------|
| **`/security-gate`** (this) | the **feature's diff**, category-triggered | once per feature, at Building → UAT | — |
| `/security-review` | the **whole repo** | periodic / pre-release | no |
| `/pr-security-review` | a **PR**, antagonistic | on demand for risky PRs | no |

It is the per-feature counterpart to `/verify`: `/verify` runs every task and is fast; `/security-gate` runs once per feature and only does real work when a sensitive category is touched. It is **advisory** this release — it reports and comments, it does not move Linear state and does not block `pk ship`. See § Future.

## Where this sits in the pipeline

```
pk next → pk branch → /work → /verify ──(Flag check F)──► pk ship (→ UAT) → …
                                  │
                                  └─ /verify auto-runs this gate when a
                                     categories file exists, BEFORE auto-ship.
                                     None matched → instant PASS (no flag).
                                     Matched → category review → verdict flag.
```

`/verify` answers "is the code correct?"; `/security-gate` answers "if this change is security-sensitive, was it reviewed for its category's failure modes?" — before the change reaches UAT (`pk ship`).

**It runs automatically, from inside `/verify`.** The `/work → /verify → pk ship` rollover is uninterrupted (`/verify` auto-invokes `pk ship` on a clean Pass), so there is no human seam *between* `/verify` and `pk ship` for a standalone step to occupy. Instead `/verify`'s **Flag check F** (v4.4.0) runs this gate: when the project has a `Security categories` file, `/verify` classifies the diff and, on a category match, runs the category review and surfaces the verdict as a human-decision flag — which **pauses auto-ship** for the user to RECONCILE (exactly like the migration self-review). A no-match adds no flag and the rollover proceeds. This skill is the canonical methodology Flag check F follows; you can also invoke `/security-gate` **standalone** at any time (re-running after a fix, or on a branch verified earlier).

## Triggers

- `/security-gate` — primary; resolves the feature issue + diff from the current branch
- `/security-gate <ISSUE-ID>` — explicit
- "run the security gate" / "does this need security review?"

## Config (read from `method.config.md`)

| Key | Purpose | Default |
|-----|---------|---------|
| **Security categories** | Path to the project category-definitions file | `resources/security-categories.md` |
| **Security gate report path** | Where to write the gate report | `Reports/` |
| **Integration branch** | The base the feature diffs against | `dev` |
| **Project display name** | Report header + comment | (project name) |

**Linear is best-effort and advisory.** Resolve the feature issue, post a comment with the verdict, and **do not** change its workflow state — `pk ship` owns the Building → UAT transition. Look up the issue via the project's Linear MCP; if Linear is unreachable, write the report anyway and tell the user to paste the verdict. Never hardcode Linear UUIDs.

## Step 0 — Load the category-definitions file (gate)

Read the file at `Security categories` (default `resources/security-categories.md`).

- **If it doesn't exist**, STOP and tell the user:
  > No security-category definitions found at `<path>`. This skill is the framework; the project supplies the category signals.

  Then scaffold one and stop for the user to fill it in:
  - If `pipekit/templates/security-categories.template.md` exists (synced projects), copy it to `<path>`.
  - Otherwise create `<path>` directly with the template's sections — one per category (**Auth**, **Payments**, **User input**, **External APIs**, **File storage**, **PII**), each with the project's **path globs**, **keywords**, and **validation specifics**, plus a **Not applicable** section for categories the project genuinely has none of (e.g. "Payments — no billing in this product").
  - Do not invent project specifics — leave clearly-marked placeholders.

The definitions file is the substance; this skill is the discipline + report shape.

## Step 1 — Resolve the feature and the changed surface

```bash
CURRENT=$(git branch --show-current)
ISSUE="${1:-}"
[ -z "$ISSUE" ] && ISSUE=$(echo "$CURRENT" | grep -oE '[A-Z]+-[0-9]+' | head -1)

BASE=$(pk config "Integration branch" "dev")   # match /verify + /work; falls to the repo's default branch
# Changed surface = this feature's COMMITTED diff against the integration branch
# (three-dot: changes on the branch only, not base churn). Fetch first so a stale or
# missing origin ref doesn't silently narrow the diff.
git fetch -q origin "$BASE" 2>/dev/null || true   # best-effort; worktrees share the object store
CHANGED=$(git diff --name-only "origin/$BASE...HEAD" 2>/dev/null)
[ -z "$CHANGED" ] && CHANGED=$(git diff --name-only "$BASE...HEAD" 2>/dev/null)
CHANGED=$(printf '%s\n' "$CHANGED" | grep -v '^Reports/')   # exclude the gate's own past reports
```

**Fail safe on an indeterminate surface.** If `CHANGED` is **empty** after both committed-diff attempts, do **not** classify it as "no sensitive category" — the surface couldn't be determined (stale/missing `origin/$BASE`, detached HEAD, or the work isn't committed yet). Stop and tell the user: *"Could not determine the changed surface against `<BASE>` — commit the work and ensure `origin/<BASE>` is fetched, then re-run."* An empty diff is a **could-not-run**, not a PASS — a silent miss here ships an unreviewed sensitive change. (Do **not** fall back to `git diff HEAD` working-tree changes: after `/work` commits, that is empty and would mask a fully-committed sensitive feature as a clean pass.)

Gather, as the classification input:
- the **changed file list** (above) — the ground truth of what this feature touches,
- the **diff hunks** for those files (so the classifier reads the actual code, not just paths),
- if available, the Linear issue's **Scope / Dependencies** (supplementary — the diff is authoritative).

If `ISSUE` is set and Linear is reachable, post a comment via the project's Linear MCP — `mcp__linear-server__linear_createComment` (the camelCase `@tacticlaunch/mcp-linear` surface): `"Starting security gate review — {YYYY-MM-DD}"`. **Do not** call any state-changing tool. If `ISSUE` can't be resolved, proceed anyway and skip the comment.

Print one line:

```
Security gate: <ISSUE | (no issue)>  ·  Base: <BASE>  ·  Changed files: <n>  ·  Defs: <path>
```

## Step 2 — Classify the change (sub-agent, evidence-based)

Spawn a read-only classifier sub-agent (`subagent_type: "general-purpose"`, execution tier per `method.config.md § Model Policy` — default `sonnet`, effort `medium` — `allowed-tools: Read, Bash, Grep, Glob`). Give it the changed file list, the diff, and the project's category definitions. It returns, for each of the six categories, **matched / not-matched** with **evidence** (`file:line`, the matched keyword/glob, or the spec line).

**Classify from opened files, never from a filename alone.** A path under `auth/` that only changed a comment is not an auth change; a payments string in a test fixture is not a payments change. The classifier opens the cited hunk and confirms the change actually exercises the category. Err toward *matching* when genuinely ambiguous — a false match costs one extra checklist run; a false miss ships an unreviewed sensitive change.

The six categories:

| Category | Signals (project file refines these) |
|----------|--------------------------------------|
| **Auth** | login, session, password, OAuth/JWT, token issuance, `requireAuth`/guard changes, RLS policy edits |
| **Payments** | Stripe/billing/checkout/subscription/refund, webhook handlers for a payment provider, money math |
| **User input** | forms, file uploads, search, comments — any user-supplied string that reaches the DB, a query, a template, or the shell |
| **External APIs** | webhooks, third-party integrations, SSO callbacks, outbound calls with a secret |
| **File storage** | S3 / Supabase storage / any bucket, upload/download URLs, public-bucket changes |
| **PII** | emails, names, addresses, phone numbers, anything GDPR-relevant — new columns, logs, or exports of personal data |

**Account for all six categories — silence is not a pass.** The classifier must return a verdict for every category as one of: **matched** (run the checklist), **N/A** (the definitions file lists it under Not applicable, with the reason), or **not-matched** (evidence-cited: the diff touches nothing in this category). If a category has **no signals defined** in the project file *and* isn't listed N/A, evaluate it against the generic signal table above and mark it `not-matched (no project signals defined — generic-only)` so an incomplete definitions file is visible in the report, never an invisible pass.

If **no category matches**, skip to Step 5 with status **PASS (no sensitive category touched)** — no review subagents needed. (This is distinct from the *indeterminate surface* in Step 1, which is a could-not-run, not a PASS.)

## Step 3 — Per-category review (parallel sub-agents)

For **each matched category**, spawn a read-only review sub-agent (`general-purpose`, execution tier per `method.config.md § Model Policy` — default `sonnet`, effort `medium` — `allowed-tools: Read, Bash, Grep, Glob`) scoped to the **feature diff**. Run them in parallel. Each runs its category checklist and returns findings with `file:line` evidence, a **severity** (Critical/High/Medium/Low) and a **confidence** — and, where the category checklist is clean, an explicit cited "verified, no issue" verdict (coverage before filtering, per `/security-review`).

Per-category checklist (the project file refines the specifics):

| Category | What the review verifies |
|----------|--------------------------|
| **Auth** | session fixation; token leakage (URL/log/client); password handling (hashing, never logged); login path rate-limited against brute force; authorization checked at the query, not just the UI |
| **Payments** | webhook **signature verification**; **idempotency keys** on charge/refund; amounts server-computed not client-trusted; PII/card data redacted in logs; refund/credit paths authorized |
| **User input** | input sanitized at the boundary; **parameterized queries** (no string-built SQL); file-type/size validation on uploads; no `eval`/template injection; output encoded |
| **External APIs** | secrets from the vault not source; request signing / mutual auth where required; **error surface contained** (no upstream error body leaked to the client); timeouts + retry bounds |
| **File storage** | **signed URLs** (not public objects) for private data; bucket ACLs least-privilege; mime-type + size validation on upload; no path traversal in object keys |
| **PII** | storage location appropriate (not a public bucket / client-readable table); retention/deletion pathway exists; not emitted to logs or analytics; access authorized at the query |

Skip any category the definitions file lists under **Not applicable** (record it as `N/A — <reason>`, not as a pass).

## Step 4 — Adversarial verification, reconcile, rate

Run an adversarial pass over the candidate findings (mirroring `/security-review` and `pipekit-discipline.md` § DOUBT): for each finding, **try to refute it** — open the cited code and check it's actually reachable and exploitable given auth, RLS, and the real call sites. Mark each **confirmed / refuted / needs-info**. Keep refuted items in an appendix with the reason; only **confirmed** and **needs-info** feed the verdict.

Headline status (a single read-only gate run can't iterate-to-fix, so the rubric is on confirmed severity, not an "addressed" loop):

- **FAIL** — any confirmed **Critical** or **High** finding.
- **WARNINGS** — only Medium/Low confirmed (or needs-info the user judged acceptable).
- **PASS** — no category matched, OR every matched category's checklist clean (no confirmed Critical/High).

**This gate is hard as of v4.17.0:** on a project with a `Security categories` file, `pk ship` refuses without a HEAD-matching PASS sentinel (Step 5 writes it). A FAIL writes **no sentinel** — close the findings and re-run the gate; the escape hatches are `pk ship --force-secgate` (logs a Linear audit comment) or `PK_SECGATE_BYPASS=1` (emergency; logs to `Logs/SecurityGate/bypass.log`). A plain `pk ship --force` waives only the verify gate, **not** this one (v4.20.0).

## Step 5 — Generate the report + sentinel

Write `<Security gate report path>/Security_Gate_<ISSUE>_<YYYY-MM-DD>.md` (omit `<ISSUE>_` if none):

```markdown
# Security Gate — {ISSUE}  ·  {Project display name}
**Base:** {BASE}  ·  **Date:** {YYYY-MM-DD}  ·  **Changed files:** {n}

## Summary
- **Status:** PASS / FAIL / WARNINGS
- **Categories matched:** {list, or "none — no sensitive category touched"}
- **Confirmed findings:** Critical {n} · High {n} · Medium {n} · Low {n}

## Classification
| Category | Matched | Evidence |
|----------|---------|----------|
| Auth | yes/no/N/A | `<file>:<line>` / keyword |
| Payments | … | … |
| User input | … | … |
| External APIs | … | … |
| File storage | … | … |
| PII | … | … |

## Findings (confirmed + needs-info)
### Critical
{list with file:line, or "None"}
### High
{list, or "None"}
### Medium / Low
{list, or "None"}

## Refuted (appendix)
{finding + why refuted, or "None"}

## Next actions
{specific, ordered — what to fix before pk ship, or "Clear to ship"}
```

**On PASS — and only on PASS — also write the sentinel** `pk ship` reads (v4.17.0 hard gate):

```bash
_gate_head=$(git rev-parse HEAD)
_gate_dir="Logs/SecurityGate/$(date +%Y%m%d)/${ISSUE}"
mkdir -p "$_gate_dir"
printf '# secgate-complete\n\nissue: %s\nstatus: PASS\nsha: %s\ncategories: %s\n' \
  "$ISSUE" "$_gate_head" "${MATCHED_CATEGORIES:-none}" > "$_gate_dir/secgate-complete.md"
```

- Write it on **every** PASS — including the no-category-matched instant PASS. `pk ship` cannot classify the diff itself; the sentinel is how it knows the classifier ran and came back clean at this HEAD.
- **Never** write it on FAIL, WARNINGS-you'd-block-on, or an indeterminate surface (Step 1's could-not-run). A missing sentinel is the blocking signal.
- The `sha:` is the gated HEAD — any commit after the gate (including a fix for a finding) correctly invalidates it; re-run the gate on the new HEAD.

## Step 6 — Post the Linear comment + present to user

- If `ISSUE` resolved and Linear reachable: post a comment — the **Summary** + **Classification** blocks + the report path. **Do not** change state.
- Present to the user: overall status, matched categories, confirmed findings by severity, and the explicit next-action — `Clear to ship` if PASS, or `Hold — close {n} finding(s) before pk ship` if FAIL.

## Severity rubric

- **Critical** — directly exploitable: auth bypass, unverified payment webhook, SQL injection from user input, a private object served publicly, PII in a public store. Ship-stopping.
- **High** — exploitable under conditions: missing idempotency on a charge path, login with no brute-force limit, an upstream error body leaked to the client, a token in a log.
- **Medium** — defense-in-depth gap with real impact (validation present but incomplete; redaction partial).
- **Low** — minor hardening / observability gap.

## Key principles

1. **Classify before you review.** The gate's first job is to decide *whether* a review is owed. Most features owe none — keep that path instant. The expensive checklist only runs on a confirmed category match.
2. **Feature-scoped, not repo-wide.** This reviews *this diff* for *its* categories — `/security-review` owns the whole-repo audit. Don't re-audit the world here.
3. **Evidence-based, adversarially verified.** Every finding (and every all-clear) cites `file:line`; every candidate is refutation-tested before it counts. No vibes.
4. **Hard-gated, once per feature.** It reports, comments, and (on PASS) writes the sentinel `pk ship` requires; it does not transition Linear state and does not run per task.
5. **Framework here, signals in the project.** Never hardcode a repo's auth primitive, rate-limiter path, or PII tables — they live in the definitions file and `method.config.md`.

## What this skill does NOT do

- No Linear state transitions — `pk ship` owns Building → UAT; this only comments.
- No code modifications — sub-agents are read-only (`Read, Bash, Grep, Glob`).
- No per-task running — that's `/verify`. This runs once, before `pk ship`.
- No whole-repo audit — that's `/security-review`. This is the feature diff.
- No blocking of its own — the skill writes the PASS sentinel; **`pk ship` does the refusing** (v4.17.0). The skill never aborts a ship itself.
- No session-log writes — `/pk-exit` owns the session log.

## Overlap with `/prod-ready` (rate limiting)

Rate limiting appears in both gates, by design, at different layers:

- **`/security-gate`** verifies *this feature's* sensitive path is correct in isolation — e.g. the **login route is itself rate-limited** against brute force (an Auth-category check).
- **`/prod-ready`** verifies the *app* throttles public traffic at all — that a **new public endpoint** is covered by the platform's rate-limit middleware.

Same word, different concern. Both run; neither subsumes the other. (Documented from the other side in `sop/Production_Readiness_SOP.md` § Overlap.)

## The hard gate (shipped v4.17.0)

The fast-follow documented since v4.4.0 is built: this skill writes a sha-matched sentinel on PASS (`Logs/SecurityGate/<date>/<issue>/secgate-complete.md`, mirroring `/verify`'s `verify-complete.md`), and **`pk ship` refuses** to push / open the PR when the project's `Security categories` file exists and no sentinel matches HEAD. Escapes: `pk ship --force-secgate` (logs a Linear audit comment) or `PK_SECGATE_BYPASS=1` (logs to `Logs/SecurityGate/bypass.log`); `pk ship --force` waives only the verify gate (v4.20.0). Projects without a categories file are unaffected — the same file that arms this skill arms the ship gate, so opting in is one file.
