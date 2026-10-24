# cmux Discipline

For sessions running inside cmux; informational otherwise. If anything here contradicts what you observe, check `cmux --help` or https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/cli-contract.md — a stale rule is worse than none.

## Discover before acting (never trust a stale ref)

<important>
Surface and pane refs from an earlier turn may be stale. Re-fetch the topology right before any split, send or read.
</important>

`cmux identify --json` (this caller's window/workspace/surface — it returns whatever was last focused), `cmux list-panes --workspace workspace:N`, `cmux list-pane-surfaces --pane pane:N`, `cmux tree`.

## Use the CLI, not the RPC, for input

<important>
Never use `cmux rpc surface.send_text`. It ignores its `surface` parameter, routes to the focused surface, and echoes that surface's id so the call looks successful.
</important>

```bash
cmux send --surface "$DST_REF" "your command"$'\n'
cmux send-key --surface "$DST_REF" enter
```

## Pair every send with a read-screen for verification

Every `cmux send` MUST be followed by `cmux read-screen --surface <ref> --lines 20`. If the command isn't there, the send went somewhere else.

## Track long-running work by process, not by scrollback

<important>
Scrollback is sticky: earlier runs leave "ERROR" / "DONE" / "OK" strings that later greps will match.
</important>

Start it in its pane with the PID captured, then poll the PID. If you must grep the screen, send `ctrl+l` first so the grep can't match stale output.

```bash
cmux send --surface "$DST" "npm run dev > /tmp/dev.log 2>&1 & echo PID=\$! && wait"$'\n'
kill -0 "$PID" && echo "still running" || echo "exited"
```

## One concern per pane

A pane running a dev server doesn't also run `git status` or one-off scripts — `cmux new-split` instead.

## Destructive commands still need user confirmation

A visible pane is not approval. Confirm before firing `rm -rf`, `git reset --hard`, `DROP TABLE`, `gh pr merge --admin` or a force-push into any pane, per `pipekit-discipline.md` § "Before taking destructive actions".

## Pipekit-specific patterns

- **Worker sessions in worktrees.** After `pk branch <ID>`, run `claude` in the worktree; the parent-repo session watches via `cmux list-pane-surfaces` + `cmux read-screen`. Don't `cmux send` into a worker mid-`/work`.
- **Notifications.** Wire Claude Code's `Stop` and `Notification` hooks to `cmux notify` so the sidebar lights up at human gates (UAT signoff, `pk done`, `pk promote --confirmed`).
- **Promote visibility.** During a multi-tier `pk promote`, keep panes for `gh pr checks <#> --watch`, the target deploy, and the Linear board.

## Orchestrating other Claude sessions

Before driving Claude workers in other panes, read `sop/Cmux_Orchestration_SOP.md` (`pipekit/sop/` in consuming projects) — four rules plus the orchestration anti-patterns. Not needed for single-session work.
