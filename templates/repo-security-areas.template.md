# Repo Security Areas — {PROJECT}

Project-specific audit areas consumed by the portable `/repo-security-review` skill. Copy this
file to your project (default path `resources/repo-security-areas.md`, or set `Repo security areas`
in `method.config.md`) and fill in every section for your stack. The skill supplies the discipline,
the coverage rule, the adversarial verification pass, and the report shape; this file supplies the
substance. Keep it committed — it's project-owned, never overwritten by sync.

**One area = one parallel sub-agent.** Add areas your project has; delete areas it doesn't (or move
them to § Not applicable with a reason — a deleted area is invisible, a listed-N/A area is auditable).

Each area block answers three questions:

- **Paths** — where does this area live? (globs the agent scopes its sweep to)
- **Primitives** — what are the *actual names* in this repo? (the functions, middleware, policies,
  and config the agent greps for). This is the section that makes the audit real: "check auth is
  enforced" is a wish; "every file under `src/pages/` calls `requireSession()` from `lib/auth.ts`"
  is a check.
- **Checks** — what must be true? Each one phrased so a `file:line` citation can prove or disprove it.

> Examples below are illustrative, drawn from a few different stacks. Replace them — an example
> left in place is worse than an empty section, because the agent will faithfully audit a primitive
> your repo doesn't have and report a clean sweep.

---

## Area: Authentication & authorization

**Paths**

```
# EXAMPLE — replace:
src/app/**/page.tsx
src/lib/auth/**
supabase/migrations/**   # RLS policies
```

**Primitives**

```
# EXAMPLE — replace with YOUR repo's names:
auth guard:          requireSession()  — src/lib/auth/session.ts
authorization layer: Postgres RLS policies (one per table holding user data)
privileged client:   createServiceClient() — src/lib/db/service.ts (must never be reachable from user input)
session store:       httpOnly cookie `sid`, 24h expiry
```

**Checks**

- Every user-reachable route/page enforces the auth guard above.
- Every table holding user data has RLS enabled **and** a policy (enabled with no policy = deny-all, which is a correctness bug even though it isn't a leak).
- The privileged client appears in no file on a user-input path.
- Session lifecycle is sound: issuance, expiry, and invalidation on logout / password change.

## Area: API & input handling

**Paths**

```
# EXAMPLE — replace:
src/app/api/**
src/server/handlers/**
```

**Primitives**

```
# EXAMPLE — replace:
auth middleware:  withAuth()      — src/server/middleware/auth.ts
CORS:             withCors()      — src/server/middleware/cors.ts
rate limiting:    withRateLimit() — src/server/middleware/rate-limit.ts (required on cost-sensitive + login endpoints)
DB access:        the query builder only; raw SQL is a finding
```

**Checks**

- Every endpoint composes the auth, CORS, and rate-limit middleware named above (list the exemptions here, with reasons — an undocumented exemption is a finding).
- All queries are parameterized; no string-built SQL, shell, or template interpolation from user input.
- Validation happens at the boundary, once (per `pipekit-security.md` — overvalidation downstream is a smell, not a control).
- Error responses don't leak upstream internals (stack traces, DB errors, third-party response bodies).

## Area: Headers, transport & infrastructure

**Paths**

```
# EXAMPLE — replace:
next.config.js
middleware.ts
.htaccess
infra/**
```

**Primitives**

```
# EXAMPLE — replace:
header source:  the `headers()` block in next.config.js
CSP:            script-src 'self' — no 'unsafe-inline' / 'unsafe-eval'
secret store:   environment variables via the platform's secret manager; .env is gitignored
dep audit:      pnpm audit --audit-level=high
```

**Checks**

- Security headers present and not permissive: CSP (no unsafe sources), HSTS, frame options, content-type options, referrer policy.
- SRI on every third-party script tag.
- No hardcoded secrets, credentials, tokens, or keys in source, config, or committed fixtures.
- Dependency audit clean at the project's threshold.

## Area: Data protection & storage

**Paths**

```
# EXAMPLE — replace:
supabase/migrations/**
src/lib/storage/**
src/lib/telemetry/**
```

**Primitives**

```
# EXAMPLE — replace:
object storage:   Supabase Storage buckets — `avatars` (public), `documents` (private, signed URLs only)
error reporting:  Sentry — beforeSend scrubber in src/lib/telemetry/sentry.ts
PII columns:      users.email, users.full_name, users.phone
retention:        30-day soft delete → hard delete cron
```

**Checks**

- Bucket/object policies are least-privilege; anything holding user data is private and served via signed URLs.
- PII does not reach logs, error reporting, or analytics — verify the scrubber actually covers the PII columns listed above.
- Migrations reviewed for security implications (new columns holding PII, weakened policies, new GRANTs).
- A retention/deletion pathway exists and is reachable.

## Area: {add your own}

Projects have areas these four don't cover — background jobs, a webhook fleet, a browser extension,
an admin surface, a public API with its own key model, agent/LLM prompt-injection surface. Add a
block per area, same three sections. The skill spawns one agent per block, so an area you add here
gets audited; one you leave out does not.

---

## Not applicable

Areas this project genuinely has none of, **with the reason**. The skill reports these as `N/A —
{reason}`, never as a pass — the difference matters when someone reads the report next quarter.

```
# EXAMPLE:
- Headers, transport & infrastructure — no web surface; this repo ships a CLI binary only.
- Data protection & storage — stateless service, no persistence and no user data at rest.
```

## Live external scans

Which live scans apply, and what to do with them. The host itself comes from `Security scan host`
in `method.config.md` — set it there, not here, so it stays in one place. Blank host, or "none"
below, and the skill records `n/a` rather than a pass.

```
# EXAMPLE — replace or set to "none":
- HTTP header grading via WebFetch against a header-analysis service (e.g. MDN Observatory's analyze API)
- Lighthouse best-practices audit, if a Lighthouse MCP tool is bound in the session
```

## Known gaps / accepted risks

Carried into every report so they're tracked rather than rediscovered as new findings each cycle.
An entry here is a *decision*, so record who accepted it and when — an accepted risk with no owner
is just an unfixed bug with better manners.

```
# EXAMPLE:
- No CSP nonce on inline analytics snippet — accepted 2026-06-01 (vendor requires inline); revisit when vendor ships a nonce-compatible loader.
- Admin surface has no rate limiting — accepted, internal-network-only until the SSO migration lands.
```

## Scoring rubric (optional)

If you want scores comparable across cycles, define the rubric here; otherwise the skill scores each
area on confirmed findings by severity and names the rubric it used.

```
# EXAMPLE:
Per area, out of 10: start at 10, −4 per confirmed HIGH, −2 per MEDIUM, −0.5 per LOW.
Overall = mean of area scores, excluding N/A areas.
```
