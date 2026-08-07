# Security Gate SOP

> For the full development pipeline, see [method.md](../method.md).

**v4.31.0** — Last updated: 2026-08-07  *(**v4.31.0 — the whole-repo audit this gate is contrasted against is now `/repo-security-review`.** Renamed from `/security-review` (collided with Claude Code's built-in) and genericized to a project areas file. § Why a gate and the four-skill comparison table repointed; the coverage-before-filtering and adversarial-verification lineage this SOP cites is unchanged — that machinery moved verbatim. Carries v4.20.0: `pk ship --force` no longer waives this gate (`--force-secgate` does). Carries v4.17.0: the hard gate — PASS writes a sha-matched `secgate-complete.md` and `pk ship` refuses without one on categories-armed projects.)*

**Source of truth:** The concrete category signals for a project live in its definitions file (`resources/security-categories.md`, scaffolded from `templates/security-categories.template.md`) and `method.config.md`. This SOP provides the methodology that applies regardless of stack.

---

## Why a gate, when `/repo-security-review` already exists

Pipekit has had a whole-repo periodic audit (`/repo-security-review`, named `/security-review` before v4.31.0) and `/pr-security-review` (antagonistic, PR-scoped, on demand) for a while. Both are **opt-in** — a human decides to run them. The gap that left: a security-sensitive feature can sail Building → UAT → production without anyone deciding it needed a look, because nothing in the loop *forces* the decision.

`/security-gate` closes that. It runs at the Building → UAT seam (in the v2 loop, the `pk ship` transition) and its **first** job is to decide whether a review is owed at all. The deciding is the product: most features touch no sensitive category and pass in seconds; the ones that do don't reach UAT unreviewed.

This is distinct from the **PR-time** reviewers (`pk ready` fires Semgrep + claude-review; `pk ship --review` runs the antagonistic reviewer): those run *after* the feature has already left Building — generic, on the whole PR, at merge time. `/security-gate` runs *before* `pk ship`, is targeted to the change's specific category failure modes, and is adversarially verified — it's the pre-UAT decision, not a duplicate of the merge-time scans. Both layers are cheap insurance on a sensitive change; neither replaces the other.

| | `/verify` | `/security-gate` | `/repo-security-review` | `/pr-security-review` |
|---|---|---|---|---|
| **Scope** | the diff | the feature diff | the whole repo | a PR |
| **Question** | is the code correct? | was a sensitive change reviewed for its category? | is the repo's security posture sound? | is this PR safe? |
| **Cadence** | every task | once per feature, at Building → UAT | periodic / pre-release | on demand |
| **Trigger** | always | auto, via `/verify` Flag check F (classifies, then reviews only on a match) | human decides | human decides |

`/verify` and `/security-gate` both run **automatically** at the ship seam; the other two stay human-initiated. The classifier is its own pass — don't fold its logic into `/verify`'s gate (keep that fast and category-blind); `/verify` *invokes* the gate as a flag (below), it doesn't reimplement it.

## Where the gate sits — and why it runs from `/verify`

In the v2 daily loop the `pk ship` transition is what moves the issue to UAT and opens the Draft PR. The naive placement is "run `/security-gate` after `/verify`, before `pk ship`" — but there is **no human seam there**: on a clean Pass, `/verify` auto-invokes `pk ship` itself (the `/work → /verify → pk ship` rollover is uninterrupted). A standalone step in that gap would be silently skipped on the happy path — the exact failure this gate exists to prevent.

So the gate runs **from inside `/verify`, as Flag check F** (v4.4.0): when the project has a `Security categories` file, `/verify` classifies the diff and, on a category match, runs the category review and surfaces the verdict as a human-decision flag. A flag (FAIL or even a clean-but-matched PASS) **pauses the auto-ship** for the user to RECONCILE — the same mechanism the migration self-review uses. A no-match adds no flag and the rollover proceeds. `/security-gate` is also runnable standalone (re-run after a fix, or audit a branch).

```
/work → /verify ──(Flag check F: classify; review on match)──► pk ship (→ UAT) → … → pk done → /prod-ready → promote
                       ↑                                                                            ↑
              gap #3: per-feature security gate                                  gap #2: per-feature production gate
              (auto-run by /verify, pauses auto-ship on a match)                 (the production boundary)
```

Two per-feature gates now bracket the lifecycle: `/security-gate` at the *entry* to UAT (is this change safe to expose to testers?) and `/prod-ready` at the *exit* to production (can the environment absorb it?).

## How classification works

The gate's first stage is a read-only **classifier sub-agent** that maps the feature's changed surface to the six categories. Two inputs:

1. **The diff** (authoritative) — `git diff --name-only origin/<integration-branch>...HEAD` plus the hunks. The classifier reads the actual changed code.
2. **The project definitions file** — per-category **path globs** and **keywords** that mean "this category" in *this* repo, so the classifier isn't guessing from generic signals.

**Classify from opened files, never a filename alone.** A path under `auth/` whose only change is a comment is not an auth change; a `stripe` string in a test fixture is not a payments change. Open the hunk, confirm the change exercises the category. When genuinely ambiguous, **match** — a false match costs one extra checklist run; a false miss ships an unreviewed sensitive change. (This is the same coverage-before-filtering discipline `/repo-security-review` uses at its finding stage.)

If no category matches, the gate is an immediate **PASS** — no review sub-agents run. That is the common, cheap path and it is the point: the gate is nearly free on the features that don't need it.

## The six categories and their checklists

When a category matches, a read-only review sub-agent runs that category's checklist against the **feature diff** (not the whole repo). Findings are `file:line`-cited, severity- and confidence-tagged, then adversarially verified.

### 1. Auth — *login, session, password, OAuth/JWT, RLS*

- Session fixation (session id rotated on privilege change / login).
- Token leakage — tokens never in URLs, logs, or client-readable storage.
- Password handling — hashed (never reversible, never logged), reset flow safe.
- Login path **rate-limited** against brute force (this feature's path specifically — distinct from the app-wide middleware `/prod-ready` checks).
- Authorization enforced **at the query** (RLS / policy), not only in the UI.

### 2. Payments — *Stripe, billing, checkout, subscription, refund*

- Webhook **signature verification** (the provider's signing secret, constant-time compare).
- **Idempotency keys** on charge/refund so a retried webhook doesn't double-charge.
- Amounts **server-computed**, never trusted from the client.
- Card data / PII **redacted in logs**.
- Refund/credit/subscription-change paths **authorized**.

### 3. User input — *forms, uploads, search, comments*

- Input **sanitized at the boundary** (validated where it enters, not re-validated everywhere — see `pipekit-security.md`).
- **Parameterized queries** — no user string concatenated into SQL / shell / HTML / file paths.
- File uploads: **type and size validation**, no executable mime served back.
- No `eval`/template injection on user-supplied strings; output encoded.

### 4. External APIs — *webhooks, integrations, SSO callbacks*

- Secrets pulled from the **vault, not source** (see `pipekit-security.md` § Secrets Managers).
- Request **signing / mutual auth** where the integration requires it.
- **Error surface contained** — an upstream error body is not forwarded raw to the client (info leak).
- Timeouts and retry bounds on outbound calls (a hung upstream can't hang the request).

### 5. File storage — *S3, Supabase storage, public buckets*

- **Signed URLs** for private objects (not public-read buckets).
- Bucket ACLs least-privilege; a change that makes a bucket public is Critical until proven intended.
- Mime-type + size validation on upload.
- No path traversal in object keys derived from user input.

### 6. PII — *emails, names, addresses, phones, GDPR data*

- Storage location appropriate — not a public bucket or a client-readable table.
- A **retention / deletion pathway** exists (GDPR erasure).
- Not emitted to logs, analytics, or error reports.
- Access **authorized at the query**, same as Auth.

## Severity → status

- **Critical** — directly exploitable: auth bypass, unverified payment webhook, SQL injection from user input, a private object served publicly, PII in a public store.
- **High** — exploitable under conditions: no idempotency on a charge path, login with no brute-force limit, upstream error body leaked, a token in a log.
- **Medium** — real defense-in-depth gap (validation present but incomplete; redaction partial).
- **Low** — minor hardening / observability gap.

**Status:** any confirmed Critical or High → **FAIL** (hold `pk ship`). Only Medium/Low confirmed (or needs-info the user accepts) → **WARNINGS**. No category matched, or all matched checklists clean → **PASS**. (A single read-only gate run can't iterate-to-fix, so the verdict keys off confirmed severity, not an "addressed" loop — to clear a FAIL you fix in `/work` and re-run the gate.)

Every candidate finding is **adversarially verified** before it counts (try to refute it — is it reachable and exploitable given auth/RLS/real call sites?); refuted items go to an appendix, not the verdict. This keeps precision high without dropping the breadth from the finding stage.

The verdict is **enforced** (v4.17.0) — a PASS writes the sha-matched sentinel `pk ship` requires on any categories-armed project; a FAIL writes none, so `pk ship` refuses until the findings close and the gate re-runs. See § Enforcement roadmap.

## Project-type variants

The categories are constant; the signals change. Fill the definitions file for your stack.

- **Next.js + Supabase (default):** Auth = `getServerSession`/middleware + RLS policies in `supabase/migrations/`; User input = Server Actions + route handlers; File storage = Supabase Storage buckets; External APIs = `app/api/**/route.ts` webhooks.
- **PHP / classic server (e.g. SiteLine):** Auth = `requireAuth()` / `validateApiAuth()` in `src/app/api/`; User input = the PHP endpoints + form handlers; File storage = the storage helper + `.htaccess` rules.
- **Python (FastAPI/Django):** Auth = the auth dependency/middleware; User input = request models + ORM queries; External APIs = the webhook routers.

For any stack the definitions file must answer, per category: *which paths and keywords mean this category here*, and *what the project-specific correct pattern is* (the auth primitive's name, the rate limiter's location, which tables hold PII). List categories the product genuinely lacks under **Not applicable** with a reason — never silently treat "no payments code" as "payments reviewed."

## Overlap with `/prod-ready` (gap #2)

Rate limiting appears in both gates, deliberately, at different layers:

- **`/security-gate`** (Auth category) verifies *this feature's* sensitive path is correct in isolation — e.g. the **login route is itself rate-limited** against brute force.
- **`/prod-ready`** verifies the *app* throttles public traffic at all — that a **new public endpoint** is covered by the platform's rate-limit middleware.

Same word, different concern; both run. (Documented from the other side in `Production_Readiness_SOP.md` § Overlap.)

## Enforcement roadmap

**v4.3.0–v4.16.x: advisory.** The gate produced the PASS/FAIL report + Linear comment only; discipline carried the enforcement.

**v4.17.0: hard gate (shipped).** On PASS — every PASS, including the no-category-matched instant PASS — the gate writes `Logs/SecurityGate/<date>/<issue>/secgate-complete.md` with the gated HEAD `sha:` (mirroring `/verify`'s `verify-complete.md`). `pk ship` refuses to push / open the PR when the project's `Security categories` file exists and no sentinel matches HEAD. The sentinel is written on the no-match path too because `pk ship` cannot classify a diff itself — the sentinel is how it knows the classifier ran clean at this HEAD. A FAIL or an indeterminate surface writes **nothing**; the missing sentinel is the block. Escapes: `pk ship --force-secgate` (logs a Linear audit comment) or `PK_SECGATE_BYPASS=1` (logs to `Logs/SecurityGate/bypass.log`). As of v4.20.0 a plain `pk ship --force` waives **only** the verify gate — it does **not** waive this security gate; that requires the separate `--force-secgate` (a skipped security review is a distinct, louder decision from a stale-verify override). Projects without a categories file are untouched — the file that arms the skill arms the gate. The embedded run inside `/verify` Flag check F writes the same sentinel, so the `/work → /verify → pk ship` auto-rollover passes the gate without a separate manual step.
