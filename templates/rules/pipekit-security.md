# Security Rules

Non-negotiable security discipline. These apply regardless of stack.

## Secrets

<important>
Never commit secrets to git. Ever. No exceptions for "just for testing" or "I'll remove it before merging."
</important>

- `.env` files are gitignored — verify before every commit
- Never put credentials, tokens, API keys, service-role keys in source code
- Never paste secrets into public issue trackers, pastebins, or PR descriptions
- When you see a secret-looking string during review, treat it as a secret until proven otherwise

If you accidentally commit a secret: rotate it immediately, then rewrite history. A committed secret is a leaked secret even if you delete the commit — assume it was scraped.

## Input Validation at Boundaries Only

- Validate user input at the entry point (API handlers, form submissions, CLI args)
- Do NOT re-validate the same data as it flows through internal functions
- Internal code trusts internal code — only the boundary is untrusted

Overvalidation is a smell: it suggests the architecture doesn't know where its trust boundaries are.

Security bugs live in the seams between layers — frontend↔backend, service↔service, app↔database, sync↔async. The boundary rule above says where to *validate*; this is where to *look* when auditing. When reviewing a change, name which seams it crosses and verify each crossing is intact.

## Authorization Must Be Explicit

Every data-access path must have authorization checked at the point of query, not in application code around the query. If the DB supports it (Row Level Security, policies, ACLs), use it there — auth-in-app-code is a layer that can be bypassed.

Specific rules:
- Never use service-role or admin-scope clients in code that runs on user input paths
- Never assume "the UI prevents this" means "it cannot happen" — the UI is a suggestion, the DB is the truth
- Anonymous/public paths must be explicitly marked and reviewed; default is authenticated

## SQL and Injection

- Always use parameterized queries / the ORM's safe API
- Never concatenate user input into SQL, shell commands, HTML, or file paths
- `eval()` and equivalents (shell `source`, `exec`) on untrusted input is a guaranteed vulnerability

## OWASP Top 10 Awareness

When editing code that touches any of these, stop and think:

1. **Broken Access Control** — auth enforced at every layer the data passes through
2. **Cryptographic Failures** — never roll your own crypto; use the stdlib or a reviewed library
3. **Injection** — covered above
4. **Insecure Design** — if the feature requires a trust decision, it belongs in a spec with human review
5. **Security Misconfiguration** — default-deny, not default-allow; explicit scopes on tokens, envs, buckets
6. **Vulnerable Components** — `pnpm audit` / `npm audit` shouldn't be a surprise
7. **Identification / Auth Failures** — session handling, password storage, MFA handoffs
8. **Data Integrity Failures** — signed artifacts, verified webhooks, trusted supply chain
9. **Logging / Monitoring Failures** — ensure the production failure path is observable
10. **SSRF** — external URLs entered by users must be validated against an allowlist

## Feature Flags and Kill Switches

If a feature could fail-unsafe (financial miscalculation, data leak, bulk destructive action), ship it behind a flag even when the product team didn't ask. Flag granularity should match blast radius — per-user for UI experiments, global for destructive ops.

Project-specific RLS, secrets-management, and auth patterns live in the project's own rules and SOPs. This file is the always-on baseline.
