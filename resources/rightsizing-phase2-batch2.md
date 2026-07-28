# Handoff — Rightsizing Phase 2, Batch 2 (design work)

**Written:** 2026-07-28, after v4.22.0 shipped (batch 1). **Target:** next Pipekit session, fresh context.

## Where batch 1 left off

v4.22.0 (merged + tagged 2026-07-28, both consumers synced same day) shipped the mechanical half of phase 2:

- All 35 skills renamed `skill.md` → `SKILL.md`; `sync-method.sh` case-migration (git-mv when tracked, `ls | grep -x` to read true on-disk case, legacy lowercase override basename normalization).
- CLAUDE.md Key Skills tables → current-behavior one-liners (12.1kB → 8.9kB); stale `--force`-waives-secgate claim fixed.
- Completion Claims loop demand-loaded: `pipekit-discipline.md` keeps a 9-line trigger; full loop in `sop/Completion_Claims_SOP.md`.
- 10 skill descriptions compressed to ≤265 chars.

Batch 2 is the **design half** — two items, deliberately deferred so they'd be designed against the landed state. Likely one release (v4.23.0) if both land clean; split if either balloons.

## Input data (from SiteLine's 2026-07-28 /doctor, quoted so this doc is self-contained)

- Always-resident memory in a SiteLine session: **~28k est. tokens** (rules ~25.2k). Largest single files: `pipekit-migrations.md` ~3.3k, `database.md` ~2.7k (project-owned), `pipekit-cmux.md` ~2.7k.
- Skill listing ~2.5× its routing budget; the vercel plugin is the largest share (kept — not Pipekit's problem). Batch 1's description compression relieved Pipekit's share.
- Anthropic Claude 5 context-engineering guidance (2026-07-24) is the doctrinal anchor: always-on = repo purpose + incident-anchored gotchas; rigid rules → judgment form; guard-rail prose for capable models is mostly waste. Enforcement thesis holds: deterministic gates (`bin/pk` sentinels, hooks, CI) are untouched by all of this.

## Item C — Tier-aware rule delivery

**Thesis:** the always-on `.claude/rules/pipekit-*` files are read by the *main* session, which runs on a frontier model. Guard-rail content written to keep *smaller* models from misbehaving is billed every turn to the model that least needs it — while the subagents that DO need it (execution `sonnet`/`medium`, grounding `haiku`/`low`, per `sop/Skills_SOP.md` § "Pinning models on subagents", ~line 212) receive it only if their **spawn prompt** carries it.

**First task — verify the premise empirically:** confirm what spawned agents actually inherit (CLAUDE.md? `.claude/rules/`? nothing?) on this harness before designing. Don't trust training data; spawn a probe agent and ask it what rules it sees.

**Then the design:**
1. Audit the five canonical rules for content whose *audience* is a smaller-tier subagent (mechanical do/don't lists, retry discipline, permission-denial protocol) vs. the main session (judgment-form principles, incident anchors). Expect the split to be uneven — most incident-anchored content stays.
2. Decide where canonical guard-rail text lives so six skills don't duplicate it. Constraint: spawn prompts must INLINE the text (a subagent won't demand-load an SOP mid-task reliably). Candidate: per-role guard-rail blocks in Skills_SOP that skills copy verbatim at spawn sites, with a sync-time or CI check against drift.
3. Update the spawning skills (`/work`, `/verify`, `/06-linear-todo-runner`, `/review-plan`, `/security-gate`, `/prod-ready`) to embed the tier-matched block; trim the always-on rules where the audit says the content was subagent-only.
4. Existing precedent to build on, not reinvent: Skills_SOP already has the permission-denial-stop instruction convention (§ ~line 284) — that IS tier-aware rule delivery, ad hoc. Generalize it.

**Risk to watch:** trimming an always-on rule that a *consumer's* main session (possibly on a smaller session model) still needs. Check `method.config.md § Model Policy` semantics — session model is not in Pipekit's control. May argue for moving content, not deleting it.

## Item D — Specs-as-code-references in `/light-spec`

**Thesis:** specs that paste code blocks rot (code moves) and cost double in Linear (`createIssue`/`updateIssue` echo the body — `pipekit-tooling.md` § MCP payloads). Specs should *reference* code — path + symbol/anchor — and let `/spec-preflight` verify the references empirically (it already does exactly this: paths, line refs, deps).

**Design points:**
1. Prefer symbol/heading anchors over raw line numbers (line numbers rot fastest; `/spec-preflight` can resolve a symbol).
2. Define when pasting IS right: exact expected diffs, small contracts (a type signature the implementation must match), content that doesn't exist yet. The rule is judgment-form, not a ban.
3. Touch points: `skills/01-light-spec/SKILL.md` (generation), `templates/light_spec_template.md`, `templates/spec_review_skill.md` (review agent must not demand pasted code back), `/02-light-spec-revise`, `/spec-preflight` (possibly strengthen symbol resolution).
4. Guard the core principle: "specs must be planning-safe — no guesswork into the next stage." A reference the executor must chase is fine; a reference that's ambiguous at plan time is not. The review agent should flag ambiguous references as Blocking, same as any spec gap.

## Mechanics for the session

- Branch `chore/release-v4.23.0` off main; per-item atomic commits; release commit last.
- Release checklist in `CHANGELOG.md` (top): constitutional stamps unconditional (method/RUNBOOK/GUIDE, HH:MM), stamp edited docs only otherwise, RUNBOOK line 14 example, PR title carries `v4.23.0`, smoke (`tests/pk-smoke.sh`, 133 expected — should not change; neither item touches `bin/pk`).
- Consumer syncs after merge; both were on v4.22.0 with local checkouts current as of 2026-07-28.
- Unrelated open items (do NOT fold in): Piper `## Model Policy` config section (user decision), rs-vault sync (different machine), Piper's first armed-secgate `pk ship` (happens in a Piper session).
