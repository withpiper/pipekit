# Tooling Rules

Constraints on how to use libraries, package managers, and build tools in this project.

## Verify Library API Before Use

Before calling any library API — especially for fast-moving libs (Next.js, React, Supabase SDK, shadcn, AG Grid, Tailwind, any SDK released in the last 12 months) — verify the API against the **installed version**, not your training data.

**Required sequence:**

1. **Check the installed version:**
   ```bash
   # pnpm
   pnpm list <package> --depth=0
   # npm / yarn
   cat package.json | grep <package>
   ```

2. **Read the source as ground truth:**
   ```bash
   # Find the entry point
   cat node_modules/<package>/package.json | grep '"main"\|"types"'
   # Read the actual exported surface
   less node_modules/<package>/dist/...
   ```

3. **Prefer the `context7` MCP tool** when available for current docs — it fetches version-appropriate documentation rather than relying on training data.

**Why:** Training data is reliably wrong on recent API changes. Next.js 14 → 15 alone broke `cookies()`, `headers()`, `draftMode()` type signatures. Supabase JS v2 renamed half its surface. Silent API drift → silent bugs.

**Never assume:**
- Function signatures haven't changed
- Config options still exist
- Import paths are the same
- Default behaviors haven't flipped

**Worst-class failure mode: API takes a target arg but ignores it AND lies about success.**

Case study (cmux, 2026-05-17): `cmux rpc surface.send_text --surface <ref> "..."` accepts a `surface` arg but routes the input to the currently-focused surface regardless, then echoes the focused surface's id back so the call looks successful. A load-test run fired into a different Claude Code session in another workspace; ~1 hour was wasted debugging "why is the wrong thing running" before the routing bug surfaced. The fix path was the surface-aware CLI command (`cmux send --surface <ref>`), which the docs documented but training-data examples hadn't been updated to reflect.

Generalization: when an API has any function-shape that includes "target identifier + payload," verify by sending a payload to a known surface and checking it landed there — not by trusting the response. Doubly so for RPC/socket surfaces where the response often echoes server-side state rather than reflecting the requested operation.

Skip the verify step **only** for standard library calls, long-stable APIs (fetch, Promise, Array methods), or libs whose version you just verified in the same session.

### Source Authority Hierarchy

When verifying a library API, source rank matters. Higher tier wins on conflict:

| Tier | Source | Authoritative? |
|------|--------|----------------|
| 1 | Official package docs (matching installed version) + installed source under `node_modules/<pkg>/` | Yes — ground truth |
| 2 | Official blog posts, changelogs, release notes from the vendor | Yes — for version-dated claims |
| 3 | Web standards (MDN, ECMA, IETF RFCs) | Yes — for platform behavior |
| 4 | Runtime compatibility tables (caniuse, Node.js docs) | Yes — for "does X work on Y" |
| — | StackOverflow, third-party blogs, AI-generated examples, your own training data | **No** — leads, not facts |

### Verification Failure: UNVERIFIED Flag

If you cannot reach a Tier 1–4 source for an API claim, emit it as UNVERIFIED rather than asserting:

```
UNVERIFIED: <claim>
  Reason: <docs offline | no matching version | could not locate in node_modules>
  Need: <what would confirm — e.g., "run `pnpm list <pkg>`" or "ask user to paste current docs">
```

Never collapse UNVERIFIED claims into confident prose. The flag is the load-bearing signal.

### Enumerate the Surface Before Claiming Behavior

The verify-installed-source rule has a sibling: when asked "what does the CI/CD do?" / "will X fire on Y?" / "is the migration applied?", **list the full surface first**, then read each entry. Reading only the first or expected file is partial verification masquerading as verified.

Case study (Pipekit-the-repo, 2026-05-25): a session inside the WIT-461 worktree advised the user that "dev-merge doesn't auto-trigger supabase-production.yml — that fires on beta-merge per the 2026-05-24 schema-first sequencing." Technically correct about `supabase-production.yml`, but the session knew about ONE workflow and didn't `ls .github/workflows/`. There was a second workflow (`supabase-dev.yml`) that DID fire on dev-merge and applied the migration to piper-dev. The advisory caused the user to manually check whether the migration had landed — extra friction triggered by an incomplete-enumeration claim.

**Required sequence** for any claim about project infrastructure:

1. **List the surface.** Concrete commands by domain:

| Claim category | List command |
|---|---|
| "Will workflow X fire?" / "What CI runs on Y?" | `ls .github/workflows/` (or your project's equivalent) — read each file's `on:` block |
| "Has migration X applied to env Y?" | `ls supabase/migrations/` then `gh run list --workflow=<workflow>.yml` for the deploy workflow |
| "Where is env var X set?" | `ls .env*` AND `grep -r <VAR>` in CI workflow files (env vars may be set in multiple places) |
| "What scripts can I run?" | `cat package.json` AND `ls scripts/` AND `cat Makefile` — don't claim a command absent before checking all three |
| "What rules auto-load?" | `ls .claude/rules/` — multiple files share the namespace |
| "What skills are installed?" | `ls .claude/skills/` — names may differ from upstream Pipekit's `skills/` |

2. **Read each entry that matches the question.** Skipping ahead to "the obvious one" is the exact failure mode.

3. **Only then synthesize.** If two entries contradict (e.g., one workflow says it fires on `dev`, another says it fires on `beta`), name both and explain the split before claiming a behavior.

**Why this lives in tooling, not discipline:** the failure is structural to how AI sessions browse the filesystem — they grep for a known string and stop. Discipline rules ask the session to verify what it knows; this rule asks the session to discover what it didn't know existed.

## Package Manager

Read the project's package manager from `method.config.md` or infer from lockfile:

- `pnpm-lock.yaml` → `pnpm`
- `yarn.lock` → `yarn`
- `package-lock.json` → `npm`

Never mix them. If the lockfile is `pnpm-lock.yaml`, running `npm install` creates a conflicting `package-lock.json` that breaks the next dev's install.

## Pre-Deploy Gate

The project's pre-deploy gate (defined in `method.config.md` → `## Pre-Deploy Gate`) is authoritative. Before declaring a task "done":

1. Run the full gate
2. All commands must exit 0
3. Do not `--no-verify` through a failing gate; fix the cause

If the gate has drifted from what's actually enforced in CI, that's its own bug — raise it, don't route around it.

## CLI Commands

Use commands defined in `package.json` scripts, not ad-hoc invocations. If you need to run `tsc --noEmit`, check `package.json` for an existing `check-types` or `typecheck` script first — using the project's alias keeps your invocation consistent with CI.

## MCP Server Configuration

<important>
Project-critical MCP servers must be declared in the version-controlled `.mcp.json` at the repo root — never only in the global per-project block of `~/.claude.json`.
</important>

`pk branch` creates a **git worktree** for each issue. A worktree checks out the repo's tracked files, so an MCP server in committed `.mcp.json` is visible inside it. An MCP server configured in the per-path block of `~/.claude.json` is keyed to the main repo path and is **invisible in every worktree** — which is exactly where `/work` runs. The failure mode is silent: the tool the work depends on simply isn't there, and the session may not notice the MCP is missing until mid-task.

Rule: if a server is required to do the work (a data-grid helper, the project's Supabase/Linear integration, a domain API), put it in `.mcp.json`. Reserve the global per-project block for personal, non-load-bearing tools.

## MCP Result Payloads Are Sticky

<important>
An MCP tool result is not a one-time cost. Every payload it returns stays in the conversation context and is re-sent as input tokens on *every subsequent turn*. Cost scales with **(payload size × remaining turns)**, not with the call — a few fat payloads early in a session tax the whole session. Nothing prunes them automatically; `/compact` is the only lever, and it is manual and disruptive.
</important>

This is server-agnostic — Linear, Supabase, Sentry, GitKraken all share the economics. A routine day's Linear work (create an initiative + a handful of projects + a dozen issues, then draft and agent-review a spec) has been observed to leave the `linear-server` MCP holding **~17%** of the session budget, matching the documented ~18% `supabase` pattern. The work was correct; the cost was the payloads persisting, not the calls.

Three shapes make it acute — avoid each:

1. **State reads that drag the whole record.** `linear_getIssueById` returns the full description **plus the entire comment thread** (postmortems, UAT rounds, review blocks — often a dozen comments). Called just to learn an issue's state / merge / PR status, it can spend several percent of the budget and stay resident for the rest of the session. **For state-only reads, use `pk next` / `pk status` / `pk portfolio` (compact, width-controlled text), `linear_searchIssues` (filtered, no bodies), or `git` / `gh` — never `getIssueById`.** Reserve `getIssueById` for a genuine full-content read.
2. **Writes that echo their input back.** `linear_createIssue` / `linear_updateIssue` return the full issue description in their result — so a spec-length body is paid for twice (sent + echoed) and the echo persists. Doing many of these is the expensive case.
3. **Doing either inline in the main thread.** The main thread is where a payload costs the most: it rides every remaining turn. An MCP-heavy read/write batch belongs in a subagent that returns a distilled summary — the fat payloads live and die in the subagent's context. See `pipekit-discipline.md` § Parallel work patterns.

The fix is **behavioral — keep fat payloads out of the main thread** — not a blunt output-size cap. A hard truncation setting can silently drop needed data; instead scope the query, prefer the CLI or a filtered read for scalars, and delegate the batch.
