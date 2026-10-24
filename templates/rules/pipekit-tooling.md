# Tooling Rules

How to use libraries, package managers, CLIs and checks. Incidents behind these rules: `sop/Rules_SOP.md` § Anchors (`pipekit/sop/` in consuming projects).

## Verify Library API Before Use

Before calling a library API — especially a fast-moving one (Next.js, React, Supabase SDK, shadcn, AG Grid, Tailwind, any SDK from the last 12 months) — verify it against the **installed version**, not training data: check the version (`pnpm list <pkg> --depth=0`, or `package.json`), read the exported surface under `node_modules/<pkg>/`, and prefer the `context7` MCP for version-matched docs. Never assume signatures, config options, import paths or defaults are unchanged. Skip only for standard-library calls, long-stable APIs (fetch, Promise, Array), or a lib you verified earlier this session.

**An API that takes a target argument may ignore it and still report success.** When the shape is "target identifier + payload", verify by sending to a known target and checking it landed there — never by trusting the response, doubly so for RPC/socket surfaces that echo server-side state.

### Source Authority Hierarchy

Higher tier wins on conflict:

| Tier | Source |
|------|--------|
| 1 | Official docs matching the installed version + installed source under `node_modules/<pkg>/` |
| 2 | Vendor changelogs, release notes, official blog posts (for version-dated claims) |
| 3 | Web standards (MDN, ECMA, IETF RFCs) |
| 4 | Runtime compatibility tables (caniuse, Node.js docs) |
| — | StackOverflow, third-party blogs, AI-generated examples, your training data — leads, not facts |

### Verification Failure: UNVERIFIED Flag

If no Tier 1–4 source is reachable, emit the claim flagged, never as confident prose:

```
UNVERIFIED: <claim>
  Reason: <docs offline | no matching version | could not locate in node_modules>
  Need: <what would confirm>
```

### Enumerate the Surface Before Claiming Behavior

For any claim about project infrastructure ("will workflow X fire?", "is migration X applied?", "where is env var X set?"), **list the full surface first**, read every entry that matches, then synthesize. Reading only the expected file is partial verification masquerading as verified.

| Claim | List first |
|---|---|
| What CI runs / will X fire | `ls .github/workflows/`, then each file's `on:` block |
| Migration applied to env | `ls supabase/migrations/`, then `gh run list --workflow=<deploy>.yml` |
| Where an env var is set | `ls .env*` and `grep -r <VAR>` in CI workflow files |
| What scripts exist | `package.json` scripts, `ls scripts/`, `Makefile` — all three before calling a command absent |
| What rules / skills load | `ls .claude/rules/`, `ls .claude/skills/` (names may differ from upstream) |

If two entries contradict, name both and explain the split before claiming a behavior.

### The Verification Method Must Be Able to See the Failure

A check that structurally cannot observe what it claims to check reports clean and means nothing. Before trusting a clean result, ask what a failure would have to look like for this check to miss it.

- **Line-based `grep` misses a claim that wraps a line.** Scan prose with whitespace normalized and comment markers stripped.
- **Measure a regression against the integration branch**, never your own worktree.
- **Pin the output format of any command a script parses** (e.g. `supabase … --agent no`). Agent auto-detection can make the output differ between a human and an AI session running the identical command.
- **A green check means the step ran, not that it did its job.** Actions that decline to run often exit 0. Assert on the artifact the job should have produced (the review comment, the uploaded file, the deployed revision). A suspiciously fast reviewer run is the tell.
- **A tool's announcement of what *will* happen is a prediction.** Scope it to every condition the effect depends on (triggers *and* branch filters), or say less.

### And ask the converse: can this check *cheat*?

A blind check can also see too much. A `git worktree` shares the parent's objects and refs, so it does not hide later commits; real isolation needs a separate clone with all other refs deleted, reflogs expired and `gc --prune=now`. Reviewing a PR at its head means reviewing a version that already absorbed earlier review rounds; when measuring a reviewer, pin the commit it would actually have seen. Whenever a check is meant to be blind (benchmark, A/B, held-out eval, fresh-eyes reviewer), name the channel the answer could leak through and close it. A suspiciously confident result is the tell.

## Package Manager

Read it from `method.config.md` or the lockfile (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm). Never mix them.

## Pre-Deploy Gate

The gate in `method.config.md` → `## Pre-Deploy Gate` is authoritative. Before declaring a task done, run the full gate; every command must exit 0; never `--no-verify` through a failure — fix the cause. If the gate has drifted from CI, raise it — don't route around it.

## CLI Commands

Use `package.json` scripts (e.g. an existing `typecheck`) rather than ad-hoc invocations, so you match CI.

## MCP Server Configuration

<important>
Project-critical MCP servers go in the version-controlled `.mcp.json` at the repo root — never only in the per-project block of `~/.claude.json`, which is invisible inside the worktrees where `/work` runs.
</important>

If the work needs the server (a data-grid helper, the project's Supabase or Linear integration, a domain API), it's project-critical. Keep the global block for personal, non-load-bearing tools.

## MCP Result Payloads Are Sticky

<important>
Every MCP result stays in context and is re-sent as input on every later turn: cost is payload size × remaining turns, and nothing prunes it but a manual `/compact`. Keep fat payloads out of the main thread.
</important>

- **State-only reads:** `pk issue show <ID>` (comments off by default), `pk next` / `pk status` / `pk portfolio`, `pk issue search` or `linear_searchIssues` (filtered, no bodies), or `git` / `gh` — never `linear_getIssueById`, which drags the description and the whole comment thread. Reserve it for a genuine full-content read, and even then prefer `pk issue show <ID> --comments`.
- **Writes that echo their input** (`linear_createIssue` / `linear_updateIssue`) pay for a long body twice; batch them in a subagent.
- **MCP-heavy batches belong in a subagent** that returns a distilled summary (`pipekit-discipline.md` § Parallel work patterns).

On the default `Linear transport: api` route the Linear case doesn't arise; these rules bind the `mcp` route and every other MCP server. Scope queries rather than imposing a hard output cap, which can silently drop needed data.
