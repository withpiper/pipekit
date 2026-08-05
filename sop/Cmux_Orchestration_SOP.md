# Cmux Orchestration SOP

> Base cmux pane discipline lives in `.claude/rules/pipekit-cmux.md` (always-on). This SOP is the demand-loaded half: read it **before** driving other Claude sessions in worker panes — not needed for ordinary single-session cmux work.

**v4.30.0** — Last updated: 2026-08-05  *(**v4.30.0 — the legacy planning layer is gone.** The 2026-05-17 menu-mapping anchor no longer names the executor path it mis-selected — that path was removed with the legacy planning layer, so naming it made the anchor cite something a reader can't find. The incident is unchanged: sending `6` selected option 4.)*

When master control is driving other Claude sessions in worker panes (the parallel-batch pattern), four extra rules apply that don't apply to non-Claude panes.

## Never send `<digit>\n` to a Claude interactive menu

<important>
Claude Code's interactive menus accept arrow-key navigation + Enter, OR numeric shortcuts — but the numeric mapping is NOT always 1:1 with what's rendered. Items like "Type something" or "Chat about this" may be parsed separately from the numbered options, and numeric input clamps to the last "real" option.
</important>

Empirically observed 2026-05-17: sending `"6"$'\n'` to confirm option 6 ("Chat about this") on a 6-option menu silently selected option 4 — a different execution path entirely. The worker proceeded down it, corrupting the run it was supposed to be measuring.

Use arrow-key navigation + Enter instead:

```bash
# Default: highlighted option is option 1
cmux send-key --surface "$WORKER" enter

# Navigate down before confirming
cmux send-key --surface "$WORKER" down
cmux send-key --surface "$WORKER" down
cmux send-key --surface "$WORKER" enter
```

Or send the literal text of what you want if the menu accepts text input.

## Wait 2-3s between `send-key enter` and the next `read-screen`

Claude needs a beat to repaint after a keystroke lands. Empirically observed 2026-05-17: a first `cmux send-key enter` on a `pk ship` confirmation appeared not to fire (next `read-screen` still showed the prompt). Re-sending as `cmux send "pk ship"$'\n'` worked. Possible the first send-key landed but the worker hadn't repainted yet.

Pattern:

```bash
cmux send-key --surface "$WORKER" enter
sleep 2
cmux read-screen --surface "$WORKER" --lines 20
# If state hasn't moved, fall back to explicit cmux send "<command>"$'\n'
```

## When a worker surface ref goes stale, fall back to git/Linear/`gh` as ground truth

<important>
Worker surface refs go stale the moment a worker session completes — and a busy cmux can host ~10 cross-project sessions, so a dead ref may now resolve to a different session entirely. Do not keep polling a surface to learn a worker's outcome.
</important>

Once a worker is done (or its surface stops responding), stop asking the pane and ask the durable state instead: `git log` / merged PRs (`gh pr list --state merged`), Linear issue state, and the live DB are the authoritative record of what a worker actually did. The pane is a view, not the truth. This is the orchestration-layer application of `pipekit-cmux.md` § "Track long-running work by process, not by scrollback" — for a completed worker, git/Linear/`gh` *is* the process you track.

## When watching a worker, detect turn-END — not narration keywords

<important>
Do NOT decide "the worker reached a gate / shipped / finished" by grepping its `read-screen` output for keywords like "Draft PR", "verdict", "tier:heavy", or "paused". A Claude worker *narrates its plan* using those exact words ("it will open a Draft PR", "if it derives tier:heavy I stop") — so a keyword watcher fires on the narration, minutes before anything actually happens.
</important>

Watch for the **turn ending** instead: a worker only stops (its spinner disappears) at a human gate or on completion. Poll for the absence of the live-spinner line — `Gerund… (Xm Ys · ↓ <n>k tokens` or `esc to interrupt` — and require it absent across 2 consecutive polls to ignore flicker. Critically, the live spinner is *present-tense* (`Recombobulating…`); the **past-tense completion marker** (`✻ Cooked for 11m`, `Churned for…`) is NOT activity — matching it keeps the watcher armed forever. When the turn ends, read the full screen to learn *why* it stopped.

Better still, wire the worker's `Stop`/`Notification` hooks to `cmux notify` (see `pipekit-cmux.md` § Pipekit-specific patterns) so turn-end signals the sidebar without any polling. Anchor: 2026-06-03, watching a `/pk-express` worker — a keyword watcher false-fired three times on the worker explaining its own gates before turn-end detection caught the real stops.

## Orchestration anti-patterns

- Sending `<digit>\n` to a Claude menu from a master orchestrator — numeric mapping is ambiguous when "Type something" / "Chat about this" rows are interleaved with numbered options. Use arrow-key navigation + Enter.
- Reading the screen immediately after `send-key enter` — wait 2-3s for the worker to repaint.
- Polling a completed worker's surface to learn its outcome — the ref is stale; read git/Linear/`gh` instead.
- Deciding a worker hit a gate / finished by grepping its `read-screen` for keywords — it narrates its plan in those exact words; detect turn-END (spinner gone) instead.
