# Production Readiness Checks — {PROJECT}

Project-specific checks consumed by the portable `/prod-ready` skill. Copy this file to
your project (default path `resources/prod-readiness-checks.md`, or set `Prod-ready checks`
in `method.config.md`) and fill in every section for your stack. The skill supplies the
discipline + report shape; this file supplies the substance. Keep it committed — it's
project-owned, never overwritten by sync.

> Examples below assume a Next.js app on Vercel with a Supabase Postgres backend (the
> stack `/prod-ready` ships defaults for). Replace them with your own; delete what doesn't
> apply, and list anything you intentionally skip under **Not applicable**.

---

## Build command

The command that produces the **client bundle** the secrets check greps. The secrets
check is meaningless against source — it must run against the built output, and against
the **client-served** subdir only (not server output, which legitimately references
server secrets and never reaches a browser).

```bash
# EXAMPLE — replace:
pnpm build                  # Next.js → emits .next/
# The CLIENT-SERVED subdir the secrets check greps (NOT the whole build dir):
CLIENT_OUTPUT_DIR=.next/static
# Exclude these from the grep (legitimate, not shipped to browsers as executable JS):
SECRETS_GREP_EXCLUDE='*.map'     # sourcemaps contain source-side env refs by design
```

Notes for the grep:
- Grep `$CLIENT_OUTPUT_DIR`, not the whole build dir. For Next.js, `.next/server/` is
  server-only — grepping it produces false-positive "leaks" from server code.
- Exclude sourcemaps (`*.map`): they intentionally embed source-side `process.env.X`
  references and are not the shipped executable bundle.
- The check looks for secret **values/prefixes**, not env-var **names**. `SERVICE_ROLE_KEY`
  as an *identifier* won't appear in a minified bundle; the greppable signal is the value
  prefix (`sk_live_`, the `service_role` JWT marker, a PEM header). List those below.

A build failure is a **Critical** finding. Leave the command blank to opt out of the
bundle check — but then you **must** list check 2 under **Not applicable** with a reason
(the skill treats a blank build command with no N/A entry as a finding, not a silent skip).

## Secret prefixes

Strings that must NEVER appear in the built client bundle. Any match in
`$CLIENT_OUTPUT_DIR` (minus the excludes above) is a **Critical** finding (a leaked secret).

> **Use specific, anchored prefixes — not short fragments.** `sk_live_` is safe; bare
> `sk_` matches minified identifiers and produces false-positive Criticals. Each entry
> should be a string that has no legitimate reason to appear in client JS.

```
# EXAMPLE — replace/extend with your project's prefixes:
sk_live_                      # Stripe secret key (anchored — not bare `sk_`)
sk_test_                      # Stripe test secret key
service_role                  # Supabase service-role JWT marker (server-only key)
AKIA[0-9A-Z]{16}              # AWS access key id
-----BEGIN.*PRIVATE KEY       # any PEM private key
```

## Monitoring

The error-monitoring tool and how to verify a feature's error surface is observable.

```
# EXAMPLE — replace:
Tool:        Sentry
Init file:   src/instrumentation.ts   (or sentry.client/server.config.ts)
Verify:      the changed code path either throws into a boundary Sentry wraps, or calls
             captureException explicitly; new async/server actions have a try/catch that
             reports. A new error surface with no path to capture = High.
```

## Public endpoints & rate limiting

Where public/unauthenticated routes live and where the rate-limit middleware is applied.
A new public route with no rate limit = **High**.

```
# EXAMPLE — replace:
Public route dirs:   app/api/**/route.ts   (any route NOT under an auth guard)
Rate-limit middleware: src/middleware.ts uses @upstash/ratelimit, keyed by IP
Verify:              every new route file in the diff that is publicly reachable is
                     covered by the middleware matcher (or calls the limiter inline).
Exempt:              routes behind auth / internal-only (note how the skill can tell).
```

## Backups

The production DB backup policy and how to confirm it's active. This is **manual-confirm** —
the skill asks you; record the answer.

```
# EXAMPLE — replace:
Provider:     Supabase (managed) — Project → Database → Backups
Cadence:      daily PITR, 7-day retention (Pro plan)
Confirm by:   paste the backup-tab screenshot/URL, or confirm PITR is enabled.
Applies when: the feature touches the DB. No DB change → check downgrades to Low.
```

## Feature flags

The flag system and which features require a kill switch. A risky path with no flag = **High**.

```
# EXAMPLE — replace:
System:       LaunchDarkly  (or a `feature_flags` table / env-var gate)
Risky =>      financial calculation changes, bulk/destructive ops, data-migration-backed
              reads, anything that fails unsafe.
Verify:       the risky code path is wrapped in a flag check that defaults OFF / safe.
```

## Dashboards

Where the operational dashboard lives and what chart the feature needs. **manual-confirm** —
record the URL/doc reference. Missing = **Low** (recommendation).

```
# EXAMPLE — replace:
Dashboard:    https://app.posthog.com/project/.../dashboard/123
Needs:        a chart for the feature's key metric (request volume, error rate, the new
              KPI). Confirm the chart exists or note it as a follow-up.
```

## Not applicable

Checks this project intentionally skips, each with a one-line reason. Listed here so the
report records them as `N/A — <reason>` rather than silently passing.

```
# EXAMPLE:
# (none — all six checks apply)
# OR, e.g.:
# Check 3 (rate limiting): no public endpoints — every route is behind Clerk auth.
```
