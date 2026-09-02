---
name: pr-security-review
description: Security-focused antagonistic PR diff review. Use when a PR touches migrations, RLS, SECURITY DEFINER, auth, or Server Actions on privileged tables. Use before merge of any security-sensitive change. Different from /repo-security-review (repo-wide) and /pr-fix (broad review).
---

# /pr-security-review — Security-focused PR review

## Triggers

- `/pr-security-review` (uses current branch's PR)
- `/pr-security-review <PR-number>`
- `/pr-security-review --pr <number>`
- Auto-suggest when running `/pr-fix` on a PR whose diff matches the security surface (see § Auto-trigger conditions below)

## Purpose

Run an antagonistic security-focused review of a specific PR's diff and post findings as a PR review comment via `gh api`. Companion to `/pr-fix` for triage.

This skill is **purpose-built for the security-sensitive surface**. Use it when generic antagonistic review (`pk ship --review`) is too broad and `/repo-security-review` (periodic repo audit) is the wrong shape.

## When to use this skill

Run `/pr-security-review` when the PR touches **any** of:

- `supabase/migrations/**` or `*.sql` files
- Code referencing `auth.uid()`, `is_approved_active_user()`, or other gate functions
- New or modified `SECURITY DEFINER` functions
- New or modified RLS policies (`CREATE POLICY`, `ALTER POLICY`)
- New `GRANT` / `REVOKE` statements
- Authentication code paths — by path (`/api/auth`, middleware, session handling) **or by content**
  (a call to one of the project's shared auth helpers, or an import of a shared auth module), since a
  handler that authenticates lives anywhere. The helper names are the project's, not this skill's: the
  `Keywords:` line of the **Auth** category in the `Security categories` file (`method.config.md`;
  default `resources/security-categories.md`). Without that file, fall back to the generic set
  `requireAuth(`, `requireUser(`, `getServerSession(`, `requireServiceCaller(`.
- Caller-supplied or DB-sourced text interpolated into an LLM prompt (`messages:`, `role: "user"`, `system:`)
- Server Actions that read or write privileged tables (`audit_log`, `profiles`, etc.)
- Any code that constructs SQL strings dynamically

## When NOT to use this skill

- Pure UI / styling PRs — use `pk ship --review` instead (generic antagonistic)
- Periodic codebase-wide security audits — use `/repo-security-review` (different skill, different shape)
- Broad PR review covering many dimensions — use `pr-review-toolkit:review-pr`

## Common Rationalizations

| You're about to say… | The rebuttal |
|---|---|
| "Semgrep/CI already passed" | CI catches known *patterns*; this skill reviews privilege-boundary *logic* — RLS policy scope, SECURITY DEFINER search_path, GRANT blast radius. Different failure class; both run. |
| "The migration is one line" | One-line GRANT/POLICY changes have outsized blast radius, and an applied migration is frozen — the fix is a *new* migration (`pipekit-migrations.md`). Small diff ≠ small consequence; cheap review now vs. hardening-migration later. |
| "It's behind RLS anyway" | RLS correctness is exactly what's under review (R1–R6). "The policy protects it" assumes the conclusion. |
| "`/verify` passed" | `/verify` proves spec adherence; this rubric hunts what the spec didn't ask — the whole reason the antagonistic layer exists beside the gate layer. |

## Auto-trigger conditions

When `/pr-fix` runs on a PR, it should suggest `/pr-security-review` as a sibling step if **any** of these match the diff:

```bash
git diff $(git merge-base HEAD origin/dev)..HEAD --name-only | \
  grep -qE '(supabase/migrations/|\.sql$|SECURITY DEFINER|CREATE POLICY|ALTER POLICY|REVOKE|GRANT)'
```

Or content-based:

```bash
# Auth helper names come from the project's Security categories file (Auth → Keywords:),
# falling back to a generic set. Each keyword is escaped for grep -E. A Keywords: line
# may wrap onto indented continuation lines (SiteLine's Auth block does) — join them,
# or the second half of the signals never reaches the grep (v4.36.0).
CATS=$(pk config "Security categories" "resources/security-categories.md")
AUTH_HELPERS=$(awk '/^## Auth/{f=1} f && /^Keywords:/{sub(/^Keywords:[ ]*/,""); k=$0; g=1; next} g && /^[ \t]+[^ \t]/{sub(/^[ \t]+/,""); k=k ", " $0; next} g{print k; p=1; exit} END{if (g && !p) print k}' "$CATS" 2>/dev/null \
  | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$' | sed 's/[][\.*^$()+?{}|]/\\&/g' | paste -sd'|' -)
AUTH_HELPERS=${AUTH_HELPERS:-'requireAuth\(|requireUser\(|getServerSession\(|requireServiceCaller\('}
git diff $(git merge-base HEAD origin/dev)..HEAD | \
  grep -qE "SECURITY DEFINER|auth\.uid\(\)|CREATE POLICY|REVOKE EXECUTE|GRANT EXECUTE|${AUTH_HELPERS}|role: *\"user\"|messages: *\["
```

## Execution Steps

### Phase 1 — Identify PR + diff

```bash
PR_NUM=${1:-$(gh pr view --json number --jq .number)}
PR_URL=$(gh api repos/$(gh repo view --json nameWithOwner --jq .nameWithOwner)/pulls/$PR_NUM --jq .html_url)
BASE_SHA=$(gh pr view $PR_NUM --json baseRefOid --jq .baseRefOid)
git diff $BASE_SHA...HEAD --stat
```

If no PR found for the current branch, refuse with: `No PR found. Open a PR first via 'pk ship'.`

### Phase 2 — Classify security surface

Identify which of the following surfaces the diff touches. Each surface gets its own dedicated rubric in Phase 3.

| Surface | Detection | Rubric loaded |
|---|---|---|
| **Migration** | files under `supabase/migrations/` | M1–M8 below |
| **RLS policies** | `CREATE POLICY` / `ALTER POLICY` / `DROP POLICY` in diff | R1–R6 below |
| **SECURITY DEFINER functions** | `SECURITY DEFINER` keyword in diff | S1–S8 below |
| **GRANT/REVOKE** | grant/revoke statements in diff | G1–G3 below |
| **Auth code** | files matching `auth/`, `middleware`, `session` — **or** a diff calling one of the project's auth helpers (Auth → `Keywords:` in the `Security categories` file; generic fallback set in § When to use) or importing a shared auth module, at any path | A1–A5 below |
| **Untrusted content in an LLM prompt** | diff interpolates a request-body or DB-sourced string into a prompt (`messages:`, `role: "user"`, `system:`, `max_tokens`) | L1–L4 below |
| **Server Actions on privileged tables** | actions that read/write `audit_log`, `profiles`, `auth.users` | P1–P4 below |

A PR can touch multiple surfaces. Load all relevant rubrics.

### Phase 3 — Run the rubric

Spawn a `pr-review-toolkit:code-reviewer` subagent (or invoke directly) with a security-first prompt that includes **only the rubric items relevant to the detected surfaces**. Each finding must include severity (Critical / High / Medium / Low / Nit), file:line citation, and concrete remediation.

#### Migration rubric (M1–M8)

- **M1** — All schema changes are idempotent (`IF NOT EXISTS`, `OR REPLACE`, `DROP POLICY IF EXISTS` before `CREATE POLICY`). Non-idempotent migrations break `supabase db reset` and replay.
- **M2** — No `DROP TABLE` / `DROP COLUMN` without an explicit data-migration plan. Schema-loss migrations require a separate written rationale.
- **M3** — New columns with `NOT NULL` constraint either have a default OR a backfill in the same migration. Otherwise the migration fails on existing data.
- **M4** — Foreign keys explicitly specify `ON DELETE` behavior. Defaults can cascade-delete unexpectedly.
- **M5** — New tables enable RLS (`ALTER TABLE … ENABLE ROW LEVEL SECURITY`) and have at least one explicit policy. Tables without policies + RLS enabled = no access for anyone (often the wrong default).
- **M6** — `pg_trgm`, `unaccent`, or other extensions are added with explicit version pinning if available.
- **M7** — Type regeneration (`supabase gen types typescript`) is in the diff if the schema changes. Code that consumes the new schema needs the types.
- **M8** — Migration filename uses the project's timestamp convention; no out-of-order timestamps that would break `supabase db push --include-all`.

#### RLS rubric (R1–R6)

- **R1** — Each policy uses `auth.uid()` (or equivalent gate) and does NOT use `current_user` or other server-side identifiers that bypass auth.
- **R2** — `USING` clause filters reads; `WITH CHECK` clause filters writes. Both required where applicable. A policy with only `USING` for INSERT/UPDATE silently lets users insert rows they couldn't read.
- **R3** — The policy's filter actually restricts to the intended subject. Common bug: `USING (true)` left from a development scaffold.
- **R4** — Tables that should be admin-only have a policy that checks role or membership, not just `is_approved_active_user()`.
- **R5** — When DELETE policy is absent, deletion is denied — verify this matches intent. If user-initiated deletion is expected, the policy must be explicit.
- **R6** — Policies have descriptive names following project convention (e.g. `<table>_<verb>_<scope>`), not generic names that obscure intent.

#### SECURITY DEFINER rubric (S1–S8)

- **S1** — `SET search_path = public, pg_temp` (or stricter) is set on the function. Without this, an attacker can shadow function calls via search_path manipulation.
- **S2** — `revoke all on function … from public` is paired with `grant execute on function … to <intended-role>` — public execute is the default and almost always wrong for SECURITY DEFINER.
- **S3** — The function's body checks an authorization gate at entry (`is_approved_active_user()`, role check, ownership check). SECURITY DEFINER bypasses RLS — the body is the last line of defense.
- **S4** — Returned columns are explicitly enumerated. `SELECT *` from a privileged table inside a SECURITY DEFINER function is a leak vector.
- **S5** — If the function reads from an admin-only table (e.g. `audit_log`), it sanitizes the projection: no full email, no internal IDs, no JSONB payload, no sensitive fields. Whitelist the columns.
- **S6** — If the function joins or filters on user-controlled input, it uses parameter binding — no string concatenation into dynamic SQL.
- **S7** — Action allowlists (e.g. for `homepage_team_activity`) cover **every** admin-only action from the audit log. Walk the audit_log enum / action types and verify each is either allowed or denied explicitly.
- **S8** — `LANGUAGE sql` vs `plpgsql` — `STABLE` / `IMMUTABLE` markers are correct. Wrong markers can cause unsafe inlining or wrong query plans.

#### GRANT/REVOKE rubric (G1–G3)

- **G1** — Every `GRANT EXECUTE` is to the narrowest role that needs it (typically `authenticated`, sometimes `service_role`). `GRANT … TO PUBLIC` on privileged functions is almost always a bug.
- **G2** — `REVOKE` precedes `GRANT` for SECURITY DEFINER functions, since `EXECUTE` defaults to PUBLIC on creation.
- **G3** — No `GRANT` on `audit_log`, `auth.users`, or other privileged base tables to non-admin roles. Reads should go through SECURITY DEFINER projection functions.

#### Auth rubric (A1–A5)

- **A1** — Middleware checks happen before any privileged read/write. Order matters.
- **A2** — Session refresh / cookie handling does not log session tokens or full email addresses.
- **A3** — Password / token comparison uses constant-time equality (avoids timing attacks).
- **A4** — Pending / deactivated users are blocked at every entry point, not just one (gate consistency: DB-layer + middleware + UI).
- **A5** — Error messages don't leak whether an email exists in the system (avoids account enumeration).

#### Server Actions on privileged tables (P1–P4)

- **P1** — Actions that write to `audit_log` are server-only and never accept user input as the action type or actor.
- **P2** — Actions that read from privileged tables go through SECURITY DEFINER projection functions, not direct queries.
- **P3** — Actions validate the caller's identity (`auth.uid()`) and authorization separately. Authentication ≠ authorization.
- **P4** — Actions return only the data the caller is entitled to see, even if the underlying query reads more (project the result before returning).

#### Untrusted content in an LLM prompt (L1–L4)

- **L1** — Standing instructions live in the `system` parameter, never the user turn, and the system prompt states an explicit instruction hierarchy. A bare splice of caller-supplied text into a `role: "user"` turn alongside the instructions is Critical/High: the model cannot distinguish data from directive.
- **L2** — Untrusted text is wrapped in a **per-request, non-guessable** delimiter, and any occurrence of that delimiter inside the untrusted text is scrubbed **before** the real markers are added. A fixed hardcoded delimiter fails this — the caller can plant a matching one and close the block early.
- **L3** — The text is neutralized against whatever other trigger shapes the codebase keys on (reuse the project's existing neutralizer; don't fork one).
- **L4** — Input and output are both length-bounded, and the bound is applied **after** any step that can grow the string (neutralization prefixes, heading demotion). Model output is normalized so a reply cannot spoof the app's own framing. Check the order, not just the presence.

### Phase 4 — Post review

Format the findings as a structured PR review comment:

```markdown
## Security review — PR #<N>

**Surface(s) reviewed:** Migration, SECURITY DEFINER, RLS

**Verdict:** Hold | Approve with notes | Approve

**Findings:** N Critical · N High · N Medium · N Low · N Nit

### Critical (block merge)
- **C1** — `<file>:<line>` — <issue>. **Remediation:** <action>.
- ...

### High (fix before merge unless waived)
- ...

### Medium / Low / Nit
- ...

### Out-of-scope observations (FYI, no action required)
- ...
```

Post via:

```bash
gh api -X POST repos/<owner>/<repo>/pulls/<N>/reviews \
  -f event=COMMENT -f body="<full markdown above>"
```

### Phase 5 — Linear visibility

Post a Linear comment on the PR's linked issue with the review summary:

```
**Security review posted** (PR #<N>)
- Surface(s): <list>
- Findings: N Critical · N High · N Medium · N Low · N Nit
- Verdict: <verdict>
- PR comment: <url>
```

Use `pk_linear_comment "<ISSUE-ID>" "<summary>"` (the same helper `pk done` uses).

### Phase 6 — Hand off to /pr-fix

Print:

```
✓ Security review posted to PR #<N>: <url>
✓ Linear updated.

Next:
  /pr-fix       — triage findings + apply fixes (recommended)
  Review on GitHub manually if you'd rather pick which to fix yourself.

Critical findings should NOT be merged without fix or explicit waive rationale.
```

## Severity guidance

| Severity | Definition | Examples |
|---|---|---|
| **Critical** | Direct exploit path or data leak. Block merge. | RLS missing, `GRANT EXECUTE TO PUBLIC` on SECURITY DEFINER, payload field returned in sanitized projection |
| **High** | Significant risk; fix before merge unless explicit waive. | Action allowlist missing one admin event, `search_path` not pinned, error message leaks account existence |
| **Medium** | Real risk but contained or unlikely to exploit immediately. | Naming inconsistency in policies, missing `WITH CHECK` on UPDATE, type regen missing |
| **Low** | Best-practice gap, not exploit-grade. | Missing comment on policy intent, no test for empty-result fallback |
| **Nit** | Style / preference. | Function name not following project convention |

## What this skill does NOT do

- Doesn't fix anything — that's `/pr-fix`'s job
- Doesn't replace `/repo-security-review` — that's the periodic repo-wide audit
- Doesn't replace `pk ship --review` — that's broader / non-security-focused
- Doesn't run static analysis tools (semgrep, etc.) — out of scope; could be a v2.2 follow-on

## Related

- `/pr-fix` — triage findings (the natural next step)
- `pk ship --review` — generic antagonistic review (run alongside for non-security dimensions)
- `/repo-security-review` — periodic codebase-wide audit (different skill, different shape)
- `pr-review-toolkit:code-reviewer` — the underlying agent this skill drives

## Calibration notes

- **Critical findings have a verification bar.** Today's RS-63 antagonistic review marked one finding Critical that turned out to be a false positive (AG Grid var() support, verified via MCP). Same discipline applies here: a Critical finding should be verifiable against authoritative source (Postgres docs, Supabase docs, project conventions). Don't merge a panic Critical without verifying.
- **Surface a "questionable but not blocking" finding** under Out-of-scope observations rather than inflating it to High. Reviewer fatigue is real.
