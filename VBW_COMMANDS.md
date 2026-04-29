# VBW Commands Reference

Output of `/vbw:help` (VBW v1.35.1) — included here for context on how Pipekit wraps VBW.

Regenerate this file from the current installed VBW version with:
```
bash "$(find ~/.claude/plugins/cache/vbw-marketplace/vbw -maxdepth 1 -mindepth 1 -type d | sort -V | tail -1)/scripts/help-output.sh"
```

---

## Lifecycle — The Main Loop

| Command | Description |
|:--------|-------------|
| `/vbw:discuss [N] [--assumptions]` | Start or continue phase discussion to build context before planning. |
| `/vbw:init` | Set up environment, scaffold `.vbw-planning`, detect project context, and bootstrap project-defining files. |
| `/vbw:vibe [intent or flags]` | The one command. Detects state, parses intent, routes to any lifecycle mode — bootstrap, scope, plan, execute, verify, discuss, archive, and more. |

**`/vbw:vibe` flags:** `--plan`, `--execute`, `--verify`, `--discuss`, `--assumptions`, `--scope`, `--add`, `--insert`, `--remove`, `--archive`, `--yolo`, `--effort=level`, `--skip-qa`, `--skip-audit`, `--plan=NN`, `[N]`

## Monitoring — Trust But Verify

| Command | Description |
|---------|-------------|
| `/vbw:status [--verbose] [--metrics]` | Display project progress dashboard with phase status, velocity metrics, and next action. |

> **Deprecated (v1.35.0):** `/vbw:qa` and `/vbw:verify` were removed from the public help surface and absorbed into `/vbw:vibe --verify`. They still exist as hidden internal commands for direct invocation by `/launch`, but new work should route through `/vbw:vibe` for the integrated QA + UAT flow.

## Supporting — The Safety Net

| Command | Description |
|---------|-------------|
| `/vbw:compress <filepath>` | Compress a natural language file into caveman format to save input tokens. Preserves code blocks, URLs, and structure. |
| `/vbw:config [setting value]` | View and modify VBW configuration including effort profile, verification tier, and skill-hook wiring. |
| `/vbw:debug <bug description>` | Investigate a bug using the Debugger agent's scientific method protocol. The `/debug` command is now self-contained — it absorbs QA and UAT inline and maintains its own session lifecycle. |
| `/vbw:doctor` | Run health checks on VBW installation and project setup. |
| `/vbw:fix <description>` | Apply a quick fix or small change with commit discipline. Turbo mode — no planning ceremony. |
| `/vbw:help [command-name]` | Display all available VBW commands with descriptions and usage examples. |
| `/vbw:list-todos [priority filter]` | List pending todos from STATE.md with action hints. |
| `/vbw:pause [notes]` | Save session notes for next time (state auto-persists). |
| `/vbw:profile [profile-name \| save \| delete]` | Switch between work profiles or create custom ones. Profiles change effort, autonomy, and verification in one go. |
| `/vbw:report [problem description]` | Collect diagnostic context, classify bug or feature, and file a GitHub issue. Auto-files (the `--file-issue` flag was removed in PR #346). |
| `/vbw:resume` | Restore project context from `.vbw-planning/` state. |
| `/vbw:skills [--search \| --list \| --refresh]` | Browse and install community skills from skills.sh based on your project's tech stack. |
| `/vbw:teach ["convention" \| remove \| refresh]` | View, add, or manage project conventions. Shows what VBW already knows and warns about conflicts. |
| `/vbw:todo <description> [--priority=...]` | Add an item to the persistent backlog in STATE.md. |

## Advanced — For When You're Feeling Ambitious

| Command | Description |
|---------|-------------|
| `/vbw:map [--incremental] [--package=name] [--tier=...]` | Analyze existing codebase with adaptive Scout teammates to produce structured mapping documents. |
| `/vbw:research <topic> [--parallel]` | Run standalone research by spawning Scout agent(s) for web searches and documentation lookups. Supports staleness tracking (PR #397, #401). |
| `/vbw:uninstall` | Cleanly remove all VBW traces from the system before plugin uninstall. |
| `/vbw:update [--check]` | Update VBW to the latest version with automatic cache refresh. |
| `/vbw:whats-new [version]` | View changelog and recent updates since your installed version. |

## Pipekit-Relevant Lifecycle Hooks (v1.35.0)

VBW v1.35.0 added configurable lifecycle hooks via `.vbw-planning/config.json` under `.hooks`:

| Hook | When it fires | Pipekit usage |
|------|---------------|----------------|
| `post_archive` | After `/vbw:vibe --archive` completes | `scripts/pipekit-post-archive.sh` writes a `pending-strategy-sync` marker to Pipekit's out-of-repo state dir (resolved by `scripts/pipekit-state-dir.sh`); surfaced by `/start-session` |

See `method.md` § Event Hook: Post-Archive → Strategy Sync for registration details.

## Quick Start

```
/vbw:init → /vbw:vibe → /vbw:vibe --archive
```
