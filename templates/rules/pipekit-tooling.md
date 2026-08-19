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

**Worst-class failure mode: API takes a target arg but ignores it AND lies about success.** Anchor: `cmux rpc surface.send_text`, 2026-05-17 — routed input to the focused surface regardless of its `--surface` arg, echoed success, ~1h lost to "why is the wrong thing running" (full anatomy: `pipekit-cmux.md` § Use the CLI, not the RPC). Generalization: when an API's shape is "target identifier + payload," verify by sending to a known target and checking it landed there — never by trusting the response, doubly so for RPC/socket surfaces that echo server-side state rather than the requested operation.

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

Anchor: WIT-461 worktree, 2026-05-25 — a session advised "dev-merge doesn't auto-trigger the supabase workflow" knowing about ONE workflow, without `ls .github/workflows/`; a second workflow (`supabase-dev.yml`) DID fire on dev-merge and applied the migration. Correct about the file it knew, wrong about the surface.

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

### The Verification Method Must Be Able to See the Failure

Sibling to the above: a check that structurally cannot observe the thing it claims to check reports clean and means nothing.

- **Line-based `grep` cannot match a claim that wraps a line.** Anchor: PIPER-486, 2026-07-31 — two facts restated across several files survived multiple "fixed everywhere" commits because the pattern only matched the single-line instances. When a fact is restated in prose across files, scan with whitespace normalized and comment markers stripped, not with a line-anchored pattern.
- **Measure a regression against the integration branch, never against your own worktree.** A regression measured against your own half-finished tree reads as a no-op, and a no-op does not get flagged.
- **A CLI's agent auto-detection can make its output format depend on who's running it.** The Supabase CLI's global `--agent` flag defaults to `auto` (verified against installed CLI, `supabase migration list --help`: "Override agent detection: yes, no, or auto (default auto)") — under auto-detection, a script piping its output into a parser can work when an AI session runs it and silently break for a human running the identical command, or vice versa, because each environment resolves the default differently. Anchor: SiteLine PIPER-533, 2026-07-31 — `scripts/local-dev/reset-db.sh` piped bare `supabase migration list` into `JSON.parse` without pinning `--agent`, so it worked from inside Claude Code but reported a false failure when a human ran it in a terminal. Pin `--agent no` (or `--output-format` explicitly) on any command whose output a script parses; never rely on the auto default when the same command might run under both a human and an agent.

- **A CI check can go green because the step ran, not because it did its job.** A third-party action that declines to run — unmet precondition, self-protection guard, missing input — commonly logs a warning and **exits 0**, which renders as a green check indistinguishable from a clean pass. Anchor: Piper PIPER-699, 2026-08-19 — `anthropics/claude-code-action` refuses to run when the workflow file differs from the default branch's copy (a guard against a PR editing its own reviewer); on a PR that touched the workflow it logged "Action skipped due to workflow validation error", exited 0, and the `claude-review` check went green in 20s having reviewed nothing. Assert on the **artifact the job should have produced** — the posted review comment, the uploaded file, the deployed revision — never on the check's colour. Corollary for reviewers specifically: a fast run is the tell, since a real review cannot be quick.
- **A tool that announces what *will* happen is making a prediction, and predictions need the same scrutiny as claims.** Anchor: Piper PIPER-699, 2026-08-19 — `pk ready` printed "PR reviewers will now fire: Claude Code Review, Semgrep" on every PR, because its probe scanned `.github/workflows/` for a `ready_for_review` trigger but ignored each workflow's `branches:` filter; on a `feature/* → dev` PR the named reviewer could never fire. This was the *second* recurrence of the same over-claim in that one message — the probe existed only because a hardcoded string had previously named a reviewer the repo did not have (SiteLine, 2026-07-29). When a tool predicts an effect, scope the prediction to every condition the effect actually depends on, or say less.

Before trusting a clean result, ask what a failure would have to look like for this check to miss it. If that shape is plausible, the check is not evidence.

### And ask the converse: can this check *cheat*?

A check can also fail by seeing **more** than it should. The result looks clean — or looks like a brilliant catch — because the method had access to the answer, not because it derived it.

- **A `git worktree` does not hide the future.** It shares the parent repo's object database and refs, so a worktree detached at an old commit can still read every later commit — including the ones that fixed the bug you are asking about. Anchor: Pipekit, 2026-08-02 — a blind-review trial checked out two PRs at their head commits in worktrees; the reviewer read the follow-up fix PRs and cited them ("the later PIPER-554 migration confirms both defects") at confidence 100. Real isolation needs a separate clone with all refs deleted except the pinned commits, reflogs expired, and `gc --prune=now`.
- **The artifact under review may already encode the answer.** Reviewing a PR at its *head* means reviewing a version that already absorbed earlier review rounds — documented residuals, updated prose, added tests. A reviewer "finding" those is reading, not discovering. When measuring a reviewer, pin the commit it would actually have seen.
- **Generalization:** whenever a check is supposed to be blind — a benchmark, an A/B, a held-out evaluation, a "fresh eyes" reviewer — name the channel through which the answer could reach it, and close that channel explicitly. A suspiciously confident result is the tell: a genuine derivation carries hedges, a leaked one does not.

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

1. **State reads that drag the whole record.** `linear_getIssueById` returns the full description **plus the entire comment thread** (postmortems, UAT rounds, review blocks — often a dozen comments). Called just to learn an issue's state / merge / PR status, it can spend several percent of the budget and stay resident for the rest of the session. **For state-only reads, use `pk issue show <ID>` (a lean, field-scoped structured read — comments off by default; `bin/pk`, v4.19.0+), `pk next` / `pk status` / `pk portfolio` (compact text), `linear_searchIssues` (filtered, no bodies), or `git` / `gh` — never `getIssueById`.** Reserve `getIssueById` for a genuine full-content read (and even then `pk issue show <ID> --comments` pulls the thread only when you ask for it).
2. **Writes that echo their input back.** `linear_createIssue` / `linear_updateIssue` return the full issue description in their result — so a spec-length body is paid for twice (sent + echoed) and the echo persists. Doing many of these is the expensive case.
3. **Doing either inline in the main thread.** The main thread is where a payload costs the most: it rides every remaining turn. An MCP-heavy read/write batch belongs in a subagent that returns a distilled summary — the fat payloads live and die in the subagent's context. See `pipekit-discipline.md` § Parallel work patterns.

The fix is **behavioral — keep fat payloads out of the main thread** — not a blunt output-size cap. A hard truncation setting can silently drop needed data; instead scope the query, prefer the CLI or a filtered read for scalars, and delegate the batch.
