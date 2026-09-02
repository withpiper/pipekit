# Hooks SOP

> Claude Code hooks are shell commands the harness runs on lifecycle events (prompt submit, tool use, session start, etc.). They belong in the **CI / Hooks** layer of Pipekit's [three-layer enforcement model](Skills_SOP.md#how-skills-work) — hard enforcement that runs without Claude's cooperation.

**v4.35.0** — Last updated: 2026-09-02  *(**v4.35.0 — rewritten: Pipekit ships and syncs a project hook.** `validate-commit.sh` under two events, the data-vs-invocation corpus, why there is no `if:` filter. The v1.1.0 text said no hook ships and none are synced; both were false.)*

---

## Where hooks live

Two kinds, with different homes:

- **Pipekit-owned project hooks** live in `templates/hooks/` and are synced by `scripts/sync-method.sh` into the consuming project's `.claude/hooks/` (force-tracked, so the hook reaches every clone and worktree, not just one machine) and registered idempotently in the project's committed `.claude/settings.json`. These are enforcement, not preference — a consumer opts out by removing the registration, and the sync reports rather than re-adds it only when the entry is present.
- **Personal reference hooks** are per-machine: install into `~/.claude/hooks/` and register in `~/.claude/settings.json`. Nothing in the sync touches them.

---

## Available hooks

### `validate-commit.sh` — commit-subject format (project hook, synced)

**What it does.** Enforces `{type}({scope}): {desc}`, scope required — the rule in `pipekit-discipline.md` § Commit discipline. One script, registered under two events with matcher `Bash`:

| Event | Effect |
|---|---|
| `PreToolUse` | Denies an off-format `git commit` before it runs (`permissionDecision: "deny"`, reason carried to the model). The commit never exists. (v4.35.0) |
| `PostToolUse` | Advisory nudge after a commit whose subject the pre-check could not extract: instructs to `git commit --amend` now, before any push. Always exits 0 — a PostToolUse hook cannot block or undo. |

The subject extractor treats `git commit` as an invocation only when command-initial or preceded by a shell operator, and never inside a heredoc body — the false-positive corpus (a grep pattern, an echoed example, prose in a `gh pr comment --body`) is in `tests/pk-smoke.sh` § commit-format hook and must stay silent under both events, since under PreToolUse a false positive blocks a tool call. There is deliberately no `if:` filter on the registration: permission patterns are matched per `&&`-separated subcommand, so `cd dir && git commit …` might never reach a filtered hook; the script's own `grep -q "git commit"` is the filter.

`pk ship` is the second gate: it reads the real subjects on the branch and refuses to push an off-format one (`--force` waives with a Linear audit comment). See `sop/Git_and_Deployment.md` § Commit Messages.

**Install.** Automatic on sync. Manual registration snippet in the script header.

**Debug.** Pipe a hook payload into it: `printf '%s' '{"hook_event_name":"PreToolUse","tool_input":{"command":"git commit -m \"docs: x\""}}' | bash .claude/hooks/validate-commit.sh`. Empty output means no decision; a JSON body with `permissionDecision` is a deny. Requires `jq` — without it the script exits 0 silently on both events.

### Previously shipped

- `check-context.sh` + `statusline-wrapper.sh` — removed 2026-04-21. Warned at 60%/80% of the context window on `UserPromptSubmit`. Removed because the Claude Code statusline already shows a live context gauge in the status bar (covers the same use case) and the hook's context-window detection had to couple to undocumented Claude Code harness payload fields to distinguish 200K vs 1M sessions. That coupling broke twice across two machines in a single install attempt. If you want the warning back, the git history has the scripts — but prefer leaning on the statusline gauge.

---

## Writing new hooks

If you add a new hook to `hooks/`, also:

1. Add a section to this SOP matching the format used previously: **What it does**, **Install**, **Debug**.
2. Decide if it should be per-machine (most hooks) or per-project (rare — would need a project-local `.claude/hooks/` and a `settings.json` entry). Default to per-machine.
3. Decide deliberately whether it is enforcement (synced project hook, like `validate-commit.sh`) or preference (per-machine reference hook). Only enforcement goes through `scripts/sync-method.sh`.
4. Avoid coupling to undocumented harness payload fields. Claude Code's hook payloads are deliberately minimal and the shapes shift. If your hook needs runtime state the harness doesn't directly expose, prefer reading the transcript JSONL or a user-maintained config file over screen-scraping internal payloads.
