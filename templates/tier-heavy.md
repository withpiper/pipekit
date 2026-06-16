# Tier: Heavy

> Extended pipeline for security-sensitive, multi-phase, or cross-strategy-doc work. Adds a security review gate and requires `/strategy-sync` before the issue can close.

## When to use

- Touches authn/authz, payments, billing, PII, or audit trails
- Spans multiple Strategy docs (e.g., changes both Permissions and Data Model)
- Multi-phase delivery with explicit checkpoints
- Compliance-sensitive (SOC2, GDPR, HIPAA, etc.)
- Externally-visible API or contract changes
- A failed change has non-reversible side effects (data, billing, customer comms)

## When NOT to use

- Internal refactors with no surface-area change → Standard
- Single-PR feature, even if "important" → Standard (Heavy is about *risk*, not *priority*)

## Gates

Heavy = Standard + the additions below. Every Standard gate is also required.

| Added gate | When | Owner |
|------------|------|-------|
| **Security review** | After QA passes, before `--close` | `/security-review` skill (or human security review for projects without it) |
| **Strategy sync (mandatory)** | Before `--close` | `/strategy-sync` must run and produce no unapplied diffs |
| **Pre-deploy compliance check** | Before merge to production | Project-defined (e.g., SOC2 evidence capture) |

## Routing

Heavy tier always requires a full plan and explicit plan review, regardless of complexity rating. Batch runner is disallowed — every Heavy issue gets a `PLAN.md` and a `/review-plan` pass before native execution.

## Required artifacts

- Light spec with explicit threat model section (if security-sensitive)
- `PLAN.md` with risk/trap coverage
- Plan-review report
- QA verification report
- Security review report (artifact path defined per-project in `method.config.md`)
- `/strategy-sync` diff log showing docs match shipped reality

## Close path

Heavy tier adds extra checks before `pk ship` opens the PR:

1. QA report present and passing
2. Security review report present (`/pr-security-review` is the canonical mechanism for migrations / RLS / SECURITY DEFINER / auth surface)
3. `/strategy-sync` last-run timestamp is after this issue's last build commit
4. No `pending-strategy-sync` marker in Pipekit's state dir (`bash scripts/pipekit-state-dir.sh`)

If any check fails, `pk ship` is refused with a list of missing artifacts. Linear status only transitions to UAT once all checks pass. Post-merge: `pk done PROJ-XXX` does worktree cleanup + Linear UAT → `In <FirstEnv>`. `pk promote <env>` walks the chain — → `In <Env>` for intermediate hops, → Done for the final hop.
