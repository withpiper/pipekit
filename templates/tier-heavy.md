# Tier: Heavy

> Extended pipeline for security-sensitive, multi-phase, or cross-strategy-doc work. Adds a security review gate and requires `/strategy-sync` before the initiative closes.

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
| **Strategy sync (mandatory)** | After merge, before the initiative closes — not a `pk ship`/`pk done` gate | `/strategy-sync` must run and produce no unapplied diffs |
| **Pre-deploy compliance check** | Before merge to production | Project-defined (e.g., SOC2 evidence capture) |

## Routing

Heavy tier always requires a full plan and explicit plan review, regardless of complexity rating. Batch runner is disallowed — every Heavy issue gets a `PLAN.md` and a `/review-plan` pass before native execution.

## Required artifacts

- Light spec with explicit threat model section (if security-sensitive)
- `PLAN.md` with risk/trap coverage
- Plan-review report
- QA verification report
- Security review report (artifact path defined per-project in `method.config.md`)
- `/strategy-sync` diff log showing docs match shipped reality (produced at the initiative boundary, not required to close this individual issue — see Gates table)

## Close path

Heavy tier adds extra checks before `pk ship` opens the PR:

1. QA report present and passing
2. Security review report present (`/pr-security-review` is the canonical mechanism for migrations / RLS / SECURITY DEFINER / auth surface)

If any check fails, `pk ship` is refused with a list of missing artifacts. Linear status only transitions to UAT once all checks pass. Post-merge: `pk done PROJ-XXX` does worktree cleanup + Linear UAT → `In <FirstEnv>`. `pk promote <env>` walks the chain — → `In <Env>` for intermediate hops, → Done for the final hop.

**`/strategy-sync` is not a `pk ship` or `pk done` gate.** It runs after merge — from `main`/the integration branch, against code that's actually shipped — typically at the initiative boundary (`/phase-plan --next` archiving a completed initiative), tracked by the `pending-strategy-sync` marker that `/pipekit-help` and `pk doctor` surface. Nothing in `bin/pk` blocks shipping or closing an individual issue on it; running it per-issue right after `pk ship` diffs docs against a Draft PR nobody's reviewed yet.
