# Production Readiness SOP

> For the full development pipeline, see [method.md](../method.md).

**v4.17.0** — Last updated: 2026-07-16  *(**v4.17.0 — the hard gate ships.** `/prod-ready` now writes a `prodready-complete.md` sentinel on PASS (sha of the audited source-branch head), and `pk promote` **refuses** the final `Ship environments` hop without a matching sentinel on any project whose `Prod-ready checks` file exists — escapes `--force` / `PK_PRODREADY_BYPASS=1` (both logged to bypass.log). 1-tier projects have no promote seam, so the gate stays advisory there. § Enforcement roadmap updated. Carries v4.3.0: new SOP — the production-readiness gate: `/prod-ready` verifies the operational preconditions a feature needs to reach production safely, distinct from `/verify`'s per-task code-readiness gate.)*

**Source of truth:** The concrete checks for a project live in its checks file (`resources/prod-readiness-checks.md`, scaffolded from `templates/prod-readiness-checks.template.md`) and `method.config.md`. This SOP provides the methodology that applies regardless of stack.

> **Note on stack:** Examples use Next.js on Vercel with Supabase Postgres (the most common Pipekit consumer stack). The checks are stack-agnostic in shape; § Project-type variants gives the substitutions for Python/Railway and a generic skeleton.

---

## The split

Pipekit has always had a pre-deploy gate (`/verify`): it runs every task at Building → ship, and it answers **"is this code correct in isolation?"** — types, lint, tests, AC coverage. It is fast and it runs constantly.

It does **not** answer **"can the system absorb this code safely in production?"** That is a different question with a different cadence and different failure modes, so it gets a different gate:

| | Code readiness (`/verify`) | Production readiness (`/prod-ready`) |
|---|---|---|
| **Question** | Is the code correct in isolation? | Can production absorb it safely? |
| **Runs at** | Building → ship, **every task** | The production boundary, **once per feature** |
| **Checks** | types, lint, tests, AC | monitoring, secrets-in-bundle, rate limits, backups, flags, dashboards |
| **Failure fix** | minutes (lint error, test) | infra work (wire Sentry, add a flag, verify backup policy) |
| **Mechanism** | turbo commands + QA subagent | SRE checklist + read-only audit subagents + manual confirms |

**Never merge the two gates.** Folding production readiness into the per-task gate creates a slow feedback loop on every commit. Keep `/verify` fast; layer `/prod-ready` on top, late, once.

## Where the gate sits

The gate guards the **production boundary** — the point where the feature reaches the env real users hit:

- **Multi-env** (`Ship environments: dev,beta,main`): run `/prod-ready` before `pk promote main` (the **last** entry). `dev` and `beta` are testing grounds; operational readiness is a production concern.
- **1-tier** (`Ship environments: main`): run `/prod-ready` before the merge to `main` / `pk done` — that merge is the production boundary.

By the production boundary, the code is frozen for the release *and* the target env is real — so both the code-property checks (secrets, rate limits, flags) and the env-property checks (backups, dashboards) are meaningful at the same moment.

## The six checks

Each check is tagged by **how** it's verified:

- **automatable** — a deterministic command + result read (the skill runs it)
- **agent-verifiable** — a read-only subagent reads the code/config and returns a `file:line`-cited verdict
- **manual-confirm** — the skill can't prove it; it asks the user and records the answer

### 1. Error monitoring wired — *agent-verifiable*

The feature's new error surface must be observable. A subagent reads the changed files plus the monitoring init (Sentry/PostHog/LogRocket), and confirms the new path either throws into a boundary the tool wraps or calls `captureException` explicitly. **A new error surface with no path to capture = High.** The most common miss: a new server action / async route with a bare `try/catch` that swallows the error and never reports it (a silent failure — see `pipekit-discipline.md`).

### 2. No secrets in the client bundle — *automatable*

`grep -rE` the **built** client output (not source) for the checks file's secret prefixes (`sk_live_`, `SUPABASE_SERVICE_ROLE_KEY`, PEM private keys, …). **Any match = Critical.** This check is meaningless against source — a `process.env.SERVICE_ROLE_KEY` reference in a server file is fine; the same value baked into `.next/static/chunks/…` is a leak that ships to every browser. The gate **builds first**, then greps the output dir.

### 3. Rate limiting on new public endpoints — *agent-verifiable*

Every new publicly-reachable route in the diff must be covered by the project's rate-limit middleware. A subagent enumerates new route files, determines which are public (not behind an auth guard), and confirms each is covered by the matcher (or calls the limiter inline). **A new public endpoint with no rate limit = High.** (Overlap with `/security-review` is intentional and resolved — see § Overlap below.)

### 4. Backups active on the target env — *manual-confirm*

The production DB on the target env must have a backup policy configured. This is provider-specific (Supabase backup tab + PITR, self-hosted cron, RDS automated backups) and not greppable, so the skill asks the user to confirm and records the answer. **Unconfirmed on a DB-touching feature = High;** downgrades to **Low** if the feature touches no DB.

### 5. Feature flag / kill switch — *agent-verifiable*

If the feature is risky — financial calculation, data leak, bulk/destructive op, anything that fails unsafe — a flag must wrap the risky path and default to the safe state. A subagent reads the diff, classifies risk, and confirms the flag gates the path. **Risky + no flag = High.** This is the methodology counterpart to `pipekit-security.md` § Feature Flags and Kill Switches: that rule says ship risky features behind a flag; this check verifies it actually happened before production.

### 6. Monitoring dashboard chart — *manual-confirm*

A dashboard chart should exist for the feature's key metric (request volume, error rate, the new KPI). The skill asks the user for the dashboard URL / doc reference and records it. **Missing = Low** — a recommendation, not a blocker. The point is that "we shipped it and have no way to see it working" is caught before, not after, the incident.

## Severity → status

- **Critical** — secret in the shipped bundle, or the artifact doesn't build. Ship-stopping.
- **High** — unmonitored new error surface; unrate-limited new public endpoint; risky path with no kill switch; backups unconfirmed on a DB feature. Operationally unsafe.
- **Medium** — partial coverage (monitoring wired but new path uninstrumented; rate limit mis-scoped).
- **Low** — no dashboard chart; minor observability gaps.

**Status:** any Critical or unaddressed High → **FAIL** (hold the promote). Only Medium/Low → **WARNINGS**. All applicable checks clean or N/A → **PASS**.

The verdict is **enforced** (v4.17.0) — a PASS writes the sentinel `pk promote` requires at the final hop on any checks-armed project; a FAIL writes none, so the production promote refuses until the findings close and the gate re-runs. See § Enforcement roadmap.

## Project-type variants

The shape is constant; the substitutions change. Fill the checks file for your stack.

### Next.js on Vercel + Supabase (default)

- **Build:** `pnpm build` → `.next/`; grep `.next/static/` for secret prefixes.
- **Monitoring:** Sentry via `instrumentation.ts` / `sentry.*.config.ts`.
- **Rate limiting:** `@upstash/ratelimit` in `src/middleware.ts`, keyed by IP.
- **Backups:** Supabase managed PITR (Pro plan) — Database → Backups.
- **Flags:** LaunchDarkly, or a `feature_flags` table / env-var gate.
- **Dashboards:** PostHog / Vercel Analytics.

### Python on Railway (or similar)

- **Build:** the container/build step; grep the built image layers or the static-assets dir.
- **Monitoring:** Sentry Python SDK; confirm `sentry_sdk.init` covers the new handler.
- **Rate limiting:** the framework's limiter (`slowapi` for FastAPI, `django-ratelimit`).
- **Backups:** Railway Postgres backups, or the managed DB provider's policy.
- **Flags:** the project's flag lib / config gate.
- **Dashboards:** Grafana / the provider's metrics.

### Generic skeleton

For any other stack, the checks file must still answer: *what command produces the user-facing artifact*, *what strings must never appear in it*, *how is an error made observable*, *where do public requests get throttled*, *how are backups confirmed*, *how is a risky path gated*, and *where is it watched*. If a check genuinely doesn't apply, list it under **Not applicable** with a reason — never silently skip it.

## Overlap with `/security-review` (gap #3)

Rate limiting appears in both `/prod-ready` and the security review. The split is clean:

- **`/security-review`** verifies *this feature's* auth/input/secret handling is correct in isolation — e.g. the login route is itself rate-limited against brute force.
- **`/prod-ready`** verifies the *app* throttles public traffic at all — that the new public endpoint is covered by the platform's rate-limit middleware.

Same word, different layer. Both run; neither subsumes the other.

## Enforcement roadmap

**v4.3.0–v4.16.x: advisory.** The gate produced the PASS/FAIL report + Linear comment only; discipline carried the enforcement.

**v4.17.0: hard gate (shipped).** On PASS the gate writes `Logs/ProdReady/<date>/prodready-complete.md` with the `sha:` of the audited source-branch head (the second-to-last `Ship environments` entry — the code being promoted). `pk promote` refuses to open the production PR — the **final hop only**; intermediate hops are untouched — when the project's `Prod-ready checks` file exists and no sentinel matches the source branch head. A feature merged into the source branch *after* the audit correctly invalidates the sentinel: the batch changed, re-run the gate. A FAIL writes **nothing**; the missing sentinel is the block. Escapes: `pk promote <env> --force` or `PK_PRODREADY_BYPASS=1` (both logged to `Logs/ProdReady/bypass.log`). **Known limitation:** single-tier projects (`Promote to main: false`) merge to `main` without `pk promote`, so there is no seam to gate — the skill stays advisory for them.
