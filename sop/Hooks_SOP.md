# Hooks SOP

> Claude Code hooks are shell commands the harness runs on lifecycle events (prompt submit, tool use, session start, etc.). They belong in the **CI / Hooks** layer of Pipekit's [three-layer enforcement model](Skills_SOP.md#how-skills-work) — hard enforcement that runs without Claude's cooperation.

**v1.1.0** — Last updated: 2026-04-21  *(check-context hook removal)*

---

## Where hooks live

Hooks are per-machine, not per-project. When Pipekit ships a reference hook it lives in `hooks/` at the repo root, but it is **not** synced via `sync-method.sh` — each developer installs the ones they want into `~/.claude/hooks/` and registers them in `~/.claude/settings.json`.

Keeping hooks out of the sync avoids fighting developers who don't want a given hook, and avoids committing machine-specific paths.

---

## Available hooks

None currently shipped.

### Previously shipped

- `check-context.sh` + `statusline-wrapper.sh` — removed 2026-04-21. Warned at 60%/80% of the context window on `UserPromptSubmit`. Removed because the Claude Code statusline already shows a live context gauge in the status bar (covers the same use case) and the hook's context-window detection had to couple to undocumented Claude Code harness payload fields to distinguish 200K vs 1M sessions. That coupling broke twice across two machines in a single install attempt. If you want the warning back, the git history has the scripts — but prefer leaning on the statusline gauge.

---

## Writing new hooks

If you add a new hook to `hooks/`, also:

1. Add a section to this SOP matching the format used previously: **What it does**, **Install**, **Debug**.
2. Decide if it should be per-machine (most hooks) or per-project (rare — would need a project-local `.claude/hooks/` and a `settings.json` entry). Default to per-machine.
3. Do not modify `scripts/sync-method.sh` to auto-sync hooks unless there's a clear reason. Reference hooks are discoverable via this SOP.
4. Avoid coupling to undocumented harness payload fields. Claude Code's hook payloads are deliberately minimal and the shapes shift. If your hook needs runtime state the harness doesn't directly expose, prefer reading the transcript JSONL or a user-maintained config file over screen-scraping internal payloads.
