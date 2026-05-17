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

## Pipekit `pk` CLI

`pk` is a globally-installed CLI binary at `~/.local/bin/pk`, **not** a slash command. When the user types `pk <subcommand>` (e.g. `pk next`, `pk status`, `pk branch RS-69`, `pk ship`, `pk done`, `pk promote`), execute it as a bash command in the current project's working tree. Do **not** search for `/pk-status`, `/pk-next`, or similar slash commands — they don't exist. The `pk` binary reads `method.config.md` and `.vbw-planning/PHASES.md` from the current project.
