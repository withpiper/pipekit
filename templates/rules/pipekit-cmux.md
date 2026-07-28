# cmux Discipline

Rules for any Claude Code session running inside cmux. If the project is not running in cmux (plain terminal, tmux, Zellij, etc.) this rule is informational and need not be enforced.

cmux ships a CLI that controls workspaces, panes, surfaces, browser tabs, and notifications. Use it to orchestrate multi-pane work that needs to stay visible — never `&`-background a process that you'll want to inspect later.

This is the cmux-shaped half of the broader parallel-work principle. See `pipekit-discipline.md` § Parallel work patterns for the subagent half and the shared rule ("spawn parallel work, don't block on it").

## Canonical references

Fetch these if anything in this rule contradicts what you observe — `cmux` evolves fast and a stale rule is worse than no rule:

- `cmux --help`
- https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/cli-contract.md
- https://raw.githubusercontent.com/manaflow-ai/cmux/main/skills/cmux/SKILL.md

## Discover before acting (never trust a stale ref)

<important>
Surface and pane refs from a previous turn may be stale. Re-fetch the topology before splitting, sending, or reading.
</important>

```bash
cmux identify --json              # current window/workspace/surface for THIS caller
cmux list-panes --workspace workspace:N
cmux list-pane-surfaces --pane pane:N
cmux tree                         # full topology dump
```

`cmux identify` returns whatever was last focused. If the user switched windows between turns, you're looking at the wrong workspace. Re-fetch right before any split-or-send.

## Use the CLI, not the RPC, for input

<important>
Never use `cmux rpc surface.send_text`. It ignores its `surface` parameter and routes to the focused surface, then echoes the focused surface's id in the response so the call looks successful.
</important>

This bug fired a load-test run into a different Claude session in another workspace — wasted ~1 hour debugging "why is the wrong thing running" before the routing bug was identified. The fix is to use the surface-aware CLI command:

```bash
# Correct:
cmux send --surface "$DST_REF" "your command"$'\n'
cmux send-key --surface "$DST_REF" enter

# Wrong (silently routes to focused, lies about success):
cmux rpc surface.send_text --surface "$DST_REF" "your command"
```

## Pair every send with a read-screen for verification

Every `cmux send` MUST be followed by a `cmux read-screen --surface <ref> --lines 20` (or similar) to verify the command landed where you intended:

```bash
cmux send --surface "$DST" "npm run dev"$'\n'
cmux read-screen --surface "$DST" --lines 20
```

This is the cheap antidote to the routing-bug class: if `read-screen` doesn't show the command you just sent, the send went somewhere else.

## Track long-running work by process, not by scrollback

<important>
Scrollback is sticky. Earlier runs leave matchable strings ("ERROR", "DONE", "OK") that future greps will hit and lie about current state.
</important>

For any long-running process — dev server, test runner, k6, supabase, vercel — capture the PID at start and poll it instead of greping screen contents:

```bash
# Start
cmux send --surface "$DST" "npm run dev > /tmp/dev.log 2>&1 & echo PID=\$! && wait"$'\n'

# Poll
kill -0 "$PID" && echo "still running" || echo "exited"
```

If you genuinely need to grep the screen (e.g. checking for a specific output line), send `Ctrl+L` (clear screen) FIRST so the grep can't match stale output:

```bash
cmux send-key --surface "$DST" ctrl+l
cmux send --surface "$DST" "<the command>"$'\n'
sleep 1
cmux read-screen --surface "$DST" | grep "the expected line"
```

## One concern per pane

If a pane is running `npm run dev`, don't share it with `git status` checks or one-off scripts. Spawn another pane (`cmux new-split`) instead. Mixed concerns make scrollback-greping even worse, and prevent stopping one process without disturbing the other.

## Destructive commands still need user confirmation

cmux doesn't change the blast radius of dangerous commands. `rm -rf`, `git reset --hard`, `DROP TABLE`, `gh pr merge --admin`, force-pushes — all the same confirmation rules apply per `pipekit-discipline.md` § "Before taking destructive actions." A pane being visible doesn't mean the human approved the action — get explicit confirmation before firing destructive commands into a pane, even your own.

## Pipekit-specific patterns

- **Worker sessions in worktrees.** `pk branch <ID>` opens a worktree; the recommended pattern is to `cd` into the worktree, run `claude` there, and treat that surface as the worker session. Master control (the parent-repo session) coordinates via `cmux list-pane-surfaces` + `cmux read-screen` to watch worker progress. Don't use `cmux send` to drive `/work` mid-execution — let the worker drive itself.
- **`pk done` notifications.** Claude Code's `Stop` and `Notification` hooks should be wired to `cmux notify` (see `~/.claude/settings.json` example in the cmux docs). Sidebar lights up when a worker session waits for human input — useful for Pipekit's "deliberate human gate" steps (UAT signoff, `pk done` confirmation, `pk promote --confirmed`).
- **Promote visibility.** When `pk promote` opens a multi-tier promote PR, consider keeping panes open for: (a) PR CI status (`gh pr checks <#> --watch`), (b) target-env deploy progress, (c) Linear board view. cmux can layout these so you don't alt-tab during a promote.

## Orchestrating other Claude sessions

Driving other Claude sessions in worker panes (the parallel-batch pattern) has its own incident-anchored failure modes: menu numeric shortcuts that don't map 1:1 to what's rendered, repaint lag after keystrokes, surface refs that go stale on worker completion, and workers narrating their plans in the exact keywords a naive watcher greps for. **Before orchestrating, read `sop/Cmux_Orchestration_SOP.md`** (`pipekit/sop/` in consuming projects) — four rules plus the orchestration anti-patterns. Not needed for ordinary single-session cmux work.

## Anti-patterns to avoid

- Backgrounding a long-running command with `&` instead of spawning a pane — the process is invisible and you can't see its output without `tee`/log-tailing tricks.
- Reusing a surface ref from earlier in the conversation without re-fetching — it may be stale.
- Sending a command without reading the screen after — you don't know if it landed correctly.
- Greping `read-screen` output for "ERROR" without first clearing the screen — sticky scrollback will lie.
- Calling `cmux rpc surface.send_text` for any reason — the routing bug is unfixed at this writing.
- (Orchestrating Claude workers? The orchestration anti-patterns live in `sop/Cmux_Orchestration_SOP.md`.)
