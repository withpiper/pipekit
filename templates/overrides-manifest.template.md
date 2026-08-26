# Overrides Manifest

> Local overrides applied on top of the upstream Pipekit sync. Each entry must explain **what** is overridden and **why** — without the why, future-you can't tell whether the override is still needed.

## How overrides work

- `.claude/overrides/skills/<name>/<file>` — full-file replacement for any file in a synced skill's directory (`SKILL.md`, `skill.json`, data files)
- `.claude/overrides/sop/<file>.md` — full-file replacement for a synced SOP
- `.claude/overrides/method.md.patch` — unified diff applied to `pipekit/method.md`

Overrides are applied automatically by `scripts/sync-method.sh` after the upstream sync. The script saves the upstream version it replaced under `.claude/overrides/.upstream-snapshot/` so the next sync can detect upstream drift.

## When to revisit

- **Upstream drift warning** during sync — upstream changed the file you override. Review whether the override is still needed or needs updating.
- **Patch failed to apply** — upstream diverged enough that the patch context no longer matches. Re-author the patch from the new upstream.

## Active overrides

<!-- One row per override. Keep "Why" short and specific — link to issues/commits where useful. -->

| Path | Type | Authored | Why |
|------|------|----------|-----|
| _example: `skills/work/SKILL.md`_ | full-file | 2026-04-26 | Adds project-specific gate for X; upstream gate too strict for Y workflow |
| _example: `method.md.patch`_ | patch | 2026-04-26 | Inserts custom Stage 1.5 doc-review step required by compliance |

## Removed overrides

<!-- When you delete an override, log it here. Helps future-you understand why the override no longer exists. -->

| Path | Removed | Reason |
|------|---------|--------|
| | | |
