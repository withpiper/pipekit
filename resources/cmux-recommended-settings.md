# Recommended cmux settings for Pipekit projects

> Tuned for the v2 daily-loop: worktree-per-issue, multiple Claude sessions in flight, lots of in-flight PRs, heavy markdown navigation (RUNBOOK, SOPs, skill.md, specs).
>
> Written against cmux **v0.64.0** (2026-05-05 release notes — "v0.64.0"). Settings paths reference cmux's canonical config at `~/.cmux/cmux.json` (made canonical in #3409). Open with the command palette: **"Open cmux.json"** (#3424), or via Settings window (#3024).

---

## Why these defaults

Pipekit puts you in many simultaneous contexts:

- **Per-issue worktrees** at `~/Projects/<repo>/.worktrees/<ISSUE-ID>-<slug>/`
- **Per-worktree Claude session** running `/work`, `/verify`, `pk ship`
- **Per-PR sidebar status** (you can have 4–8 open at once)
- **Per-session log** in `Logs/Sessions/<date>_<HHMM>.md`

The settings below favor: fast session resume, low-churn PR polling, fast file inspection, and discoverable structured config. Skip anything that doesn't match your actual workflow.

---

## Highest-impact settings

### 1. Restore sessions + resume agents on relaunch

Added in #2978 + Sessions panel #2936 (renamed to **Vault** in #3528). When cmux relaunches (after an OS update, app crash, or you closing the last window), your Claude sessions auto-resume in their worktree contexts. This is load-bearing for the v2 loop — you do not want to manually `cd` and `claude --dangerously-skip-permissions` across 6 worktrees on every restart.

**Verify it's on** — Vault sidebar visible (right sidebar), session entries listed.

### 2. PR sidebar polling — coalesced, not thrashing

#2585 fixed the rate-limit issues; #2662 coalesced per-repo polling and state-machined the probe queue; #3273 split visibility from clickability; #3492 made clickability default-on.

For Pipekit users with many open PRs, this is the biggest perceived stability win. No action required — these are defaults. Just confirm:

- Sidebar PR rows render quickly when you open `pk ship`-created PRs
- No "rate limit exceeded" warnings in the cmux log

### 3. Shell integration: `report_pwd` (fixes worktree-detection drift)

#2778 — fixed a `ZDOTDIR` override bug where cmux didn't know your `cwd` because `pk branch` switched worktrees outside the shell's awareness.

This matters because:
- `pk done` and `pk ship` rely on `git rev-parse --show-toplevel` matching the active worktree
- The "branch keeps switching to main between turns" issue we hit in this repo's working tree is partly a consequence of cmux not tracking the worktree change cleanly

**Verify** — open a worktree (`pk branch RS-XX`), check that the cmux tab title and pane show the worktree path, not the parent repo path.

### 4. System-wide show/hide hotkey

#2389 — bind a global shortcut (recommended: `Cmd+Ctrl+\` or `F19`) to toggle cmux. Useful when you `/pk-exit` and want to switch context without alt-tab gymnastics.

```jsonc
// ~/.cmux/cmux.json
{
  "shortcuts": {
    "toggleAppVisibility": "cmd+ctrl+\\"
  }
}
```

### 5. Open Cmd-clicked markdown in cmux viewer (opt-in)

#2904 — opt-in setting. Cmd-click any `.md` path in terminal output and it opens in a native cmux viewer pane instead of an external app.

You read RUNBOOK, SOPs, skill.md, and specs constantly. Turn this on.

```jsonc
{
  "openMarkdownInCmux": true
}
```

### 6. Sidebar file preview panels

#3139 — quick-peek a file (RUNBOOK, skill.md, a Linear-pasted spec saved as `.md`) without opening a full pane. Hover or right-arrow on a file in the explorer; preview shows on the right.

Pairs naturally with #5 above.

### 7. Speed up large pastes

#3000 — paste perf fix for large bracketed-paste payloads.

You paste big transcripts into Claude often (today's session had several multi-thousand-character pastes). This used to noticeably lag. No setting needed; it's automatic in v0.64.0+.

---

## Quality-of-life settings worth flipping

### Configurable tab-bar font size

#2645. Pipekit worktree branch names get long (`feature/RS-29-jpg-export-for-files`). Bump tab font slightly so the Linear ID doesn't truncate.

```jsonc
{
  "tabBar": { "fontSize": 13 }
}
```

### Hover tooltips on workspace and pane tabs

#3329 — full branch name shows on hover. Default behavior; verify it's on.

### Auto-hide terminal scroll bar

#2678 — cleaner panes during long Claude sessions. Default on; #2729 added an explicit disable setting if you prefer the bar.

### Cmd+click file path punctuation trimming fix

#2831 — Cmd-clicking `src/foo.ts:42` from `git grep` output now correctly opens `src/foo.ts` at line 42, instead of including a trailing comma or paren.

Critical for the operational Step 6.5 grep workflow we shipped in PR #66 — Cmd-click any match line to jump to the integration site.

### Browser pane: passkeys / WebAuthn / FIDO2

#2727 — fresh implementation after the #2660/#2681 revert. Sign into Linear, GitHub, 1Password directly in the browser pane instead of falling back to your phone for the FIDO challenge.

### Cmd+Shift+V paste in browser pane

#2779 — fixed paste in the browser pane. Useful for pasting Linear URLs / spec content into web forms.

### Workspace color picker — fix blink

#2566 — visual fix; no setting needed.

### Workspace color for selected sidebar rows

#3038 + #3082 (left rail). If you use workspace colors to distinguish projects (recommended for multi-project Pipekit setup — one color per repo), the selection highlight respects them.

```jsonc
{
  "workspaces": {
    "default-colors": {
      "rs-vault":   "#5b8def",
      "pipekit":    "#9b88ff",
      "distill":    "#ff8a5c",
      "piper":      "#43b581"
    }
  }
}
```

### Sessions popover: cancel drag on Escape

#2995 — small UX, no setting needed.

### Command palette ID copy actions

#3247 + #3183 — quick-copy workspace IDs / session IDs to clipboard. Useful for cross-referencing in Linear or PR descriptions.

### Settings search aliases (localized)

#3294 + #3296 — settings search now matches synonyms and is localized. If you can't find a setting by exact name, the alias often works.

---

## Multi-agent surface (optional)

You're currently Claude-only, but if you ever route portions of the v2 loop to other agents, cmux added native session integrations for:

- **Cursor** + **Gemini CLI** (#2717)
- **Rovo Dev** (#3530, #3535)
- **Codex** approvals through Feed (#3420)
- **OpenCode** plan approvals through Feed (#3405)

Each gets its own Vault entry and session hooks. Default off. Enable per-agent only when you need it — extra integrations = extra polling = more sidebar churn.

---

## Beta features worth knowing about

#3537 added beta toggles. Two relevant:

- **Feed** — workstream MVP (#3057). Bridges OpenCode plan approvals + cmux feed-hook + IDE plugin events into a unified activity stream. Useful only if you're going multi-agent.
- **Dock** — sidebar agent prompt UI (#3217, #3393). Lets you fire prompts at agent panes from a dock instead of typing into each one. Niche for solo Claude work; consider if you start running parallel `/work` against multiple issues.

```jsonc
{
  "betaFeatures": {
    "feed": false,
    "dock": false
  }
}
```

---

## Skip / not for you

- **Cloud VM stack** (#3046, #3185, #3196, #3219, #3437) — remote build VMs via Freestyle. Overkill for the Pipekit local-first model.
- **macOS clear glass background blur** (#3313) — cosmetic.
- **iMessage mode for agent prompts** (#3252) — alternative prompt UI; not needed.
- **Bilibili / LinkedIn route fixes** (#2836, #2930) — only relevant if you use the browser pane heavily on those sites.

---

## Verification after applying

1. **Sessions resume** — quit cmux, relaunch, confirm Vault entries auto-resume their `claude` processes in the right worktrees.
2. **PR polling** — run `pk ship` on a feature branch, confirm the new PR appears in the sidebar within ~2s with no rate-limit warnings.
3. **`report_pwd`** — `cd` into a worktree, confirm the cmux tab title updates to the worktree path.
4. **Cmd-click markdown** — Cmd-click a `RUNBOOK.md:175` reference in any output; should open the in-cmux viewer at line 175.
5. **Cmd-click code path** — `git grep -n RS-XX src/`, Cmd-click a result; opens correct file at correct line.

If any of these fail, file in cmux's issue tracker — most likely a regression worth flagging upstream.

---

## Related Pipekit settings

These settings make the cmux integrations more useful:

| Pipekit setting | Where | Why |
|---|---|---|
| `Worktree prefix` | `method.config.md` | cmux tab titles + Vault entries derive from the worktree path; setting a clean prefix (`~/Projects/<repo>-`) keeps them readable |
| Session log path (`Logs/Sessions/`) | `method.config.md` | When you `/pk-exit` mid-session, cmux can show the session log alongside the Vault entry on next resume |
| `Self-reference check: enabled` | `method.config.md` (PR #67) | Cmd-clickable matches in `pk verify` output route through #2831's path-punctuation fix |
| `Backend: native` | `method.config.md` | Smaller in-context Claude sessions reuse the same pane; less Vault entry sprawl than `vbw` (which spawns multiple sub-agents) |

---

## Updates

- **2026-05-05** — Initial draft against cmux v0.64.0 release notes.
