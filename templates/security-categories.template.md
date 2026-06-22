# Security Categories — {PROJECT}

Project-specific category signals consumed by the portable `/security-gate` skill. Copy
this file to your project (default path `resources/security-categories.md`, or set
`Security categories` in `method.config.md`) and fill in every section for your stack. The
skill supplies the discipline + classifier + report shape; this file supplies the signals
(what each category *looks like* in this repo) and the correct patterns. Keep it committed —
it's project-owned, never overwritten by sync.

> Examples below assume a Next.js app with Supabase (the stack `/security-gate` ships
> defaults for). Replace them with your own; delete what doesn't apply, and list any
> category the product genuinely lacks under **Not applicable**.

For each category, fill three things:
- **Paths** — globs where this category lives in *this* repo (the classifier matches the diff against these).
- **Keywords** — identifiers/strings in changed code that signal the category (the classifier confirms by opening the hunk).
- **Correct pattern** — the project-specific thing the review verifies (your auth primitive's name, where the rate limiter lives, which tables hold PII).

---

## Auth — login, session, password, OAuth/JWT, RLS

```
# EXAMPLE — replace:
Paths:     src/app/(auth)/**, src/lib/auth/**, supabase/migrations/*policy*.sql
Keywords:  getServerSession, requireAuth, signIn, jwt, RLS, CREATE POLICY, auth.uid()
Correct:   every route reads the session via requireAuth(); every table has an RLS policy;
           the login action is rate-limited (see src/lib/ratelimit.ts); tokens never logged.
```

## Payments — Stripe, billing, checkout, subscription, refund

```
# EXAMPLE — replace:
Paths:     src/app/api/stripe/**, src/lib/billing/**
Keywords:  stripe, checkout, webhook, refund, subscription, paymentIntent, amount
Correct:   webhook handler verifies stripe-signature; charge/refund use an idempotency key;
           amounts computed server-side from the DB, never from the request body.
```

## User input — forms, uploads, search, comments

```
# EXAMPLE — replace:
Paths:     src/app/api/**/route.ts, src/app/**/actions.ts, src/components/**/forms/**
Keywords:  formData, request.json, searchParams, upload, sql`, .raw(, dangerouslySetInnerHTML
Correct:   inputs validated with zod at the boundary; all DB access via the query builder /
           parameterized SQL (never string-built); uploads check mime-type + size.
```

## External APIs — webhooks, integrations, SSO callbacks

```
# EXAMPLE — replace:
Paths:     src/app/api/webhooks/**, src/lib/integrations/**
Keywords:  webhook, fetch(, axios, signature, callback, bearer, x-hub-signature
Correct:   secrets read from the vault (op:// refs), not source; inbound webhooks verify a
           signature; upstream error bodies are caught and not forwarded to the client.
```

## File storage — S3, Supabase storage, public buckets

```
# EXAMPLE — replace:
Paths:     src/lib/storage/**, supabase/migrations/*storage*.sql
Keywords:  createSignedUrl, getPublicUrl, .upload(, bucket, storage.from, ACL, public: true
Correct:   private objects served via createSignedUrl (never getPublicUrl); buckets default
           private; uploads validate mime-type; object keys are not raw user input.
```

## PII — emails, names, addresses, phones, GDPR data

```
# EXAMPLE — replace:
Paths:     supabase/migrations/**, src/lib/analytics/**, src/lib/logger.ts
Keywords:  email, phone, address, full_name, ssn, date_of_birth, capture(, logger.info(
Correct:   PII columns live in RLS-protected tables (not public buckets / client-readable
           views); a deletion pathway exists (GDPR erasure); PII never sent to analytics/logs.
```

## Not applicable

Categories this product genuinely has none of, each with a one-line reason. Listed here so
the gate records them as `N/A — <reason>` rather than a classifier guessing, and so a future
"we added billing" diff is a visible change to this file.

```
# EXAMPLE:
# Payments: N/A — no billing in this product; all access is free-tier.
# File storage: N/A — no uploads; all assets are build-time static.
```
