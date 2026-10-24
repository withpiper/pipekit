# Security Rules

Non-negotiable security discipline, regardless of stack.

## Secrets

<important>
Never commit secrets to git. No exceptions for "just for testing" or "I'll remove it before merging."
</important>

- Verify `.env` files are gitignored before every commit.
- No credentials, tokens, API keys or service-role keys in source, issue trackers, pastebins or PR descriptions.
- Treat a secret-looking string as a secret until proven otherwise.
- A committed secret is leaked even if the commit is deleted: rotate it immediately, then rewrite history.

## Secrets Managers and Worktrees

With a secrets manager (reference pattern: 1Password for Developers):

- **Committed reference files carry pointers, never values.** `op://` files (`secrets.op`, `op-references.conf`, `*.tpl`) are tracked, so they reach every worktree. Inject at the edge: `op run --env-file=<refs> -- <cmd>` locally, `op inject` at deploy, `1password/load-secrets-action` in CI. A reference is not a credential — exempt `op://` lines from secret scanners.
- **An `.envrc` wrapping `op run`** is config, not a secret; `pk branch` symlinks it into worktrees and auto-allows direnv.
- **Plaintext `.env*` symlinking is the legacy fallback**, and `pk branch` **never links `.env.prod`**. Render prod values from the vault at deploy time.
- **Loaded ≠ valid.** When migrating a write-only secret (e.g. GitHub Actions secrets), exercise the real auth path once before declaring the cutover done.

## Input Validation at Boundaries Only

Validate at entry points (API handlers, form submissions, CLI args). Do not re-validate the same data as it flows through internal functions — internal code trusts internal code. Overvalidation means the architecture doesn't know its trust boundaries. Security bugs live in the seams (frontend↔backend, service↔service, app↔database, sync↔async): when reviewing a change, name the seams it crosses and verify each.

## Authorization Must Be Explicit

Every data-access path must check authorization at the point of query, not in application code around it — use the DB's RLS / policies / ACLs where they exist.

- Never use service-role or admin-scope clients on user-input paths.
- "The UI prevents this" does not mean it cannot happen.
- Anonymous/public paths must be explicitly marked and reviewed; the default is authenticated.

## SQL and Injection

Use parameterized queries or the ORM's safe API. Never concatenate user input into SQL, shell commands, HTML or file paths. `eval()` and equivalents (`source`, `exec`) on untrusted input is a guaranteed vulnerability.

## OWASP Top 10 Awareness

When a change touches access control (enforced at every layer the data passes through), crypto (never roll your own — use the stdlib or a reviewed library), injection, insecure design (trust decisions belong in a spec with human review), misconfiguration (default-deny, explicit scopes), vulnerable components (`pnpm audit` / `npm audit`), auth (sessions, password storage, MFA handoffs), data integrity (signed artifacts, verified webhooks), logging of the failure path, or SSRF (allowlist user-entered URLs) — stop and think.

## Feature Flags and Kill Switches

If a feature could fail unsafe (financial miscalculation, data leak, bulk destructive action), ship it behind a flag even unasked. Match flag granularity to blast radius — per-user for UI experiments, global for destructive ops.

Project-specific RLS, secrets and auth patterns live in the project's own rules and SOPs.
