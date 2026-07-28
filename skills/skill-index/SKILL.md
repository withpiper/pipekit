---
name: skill-index
description: Sync skill index docs after skills change. Use when a skill is added, renamed, or removed under .claude/skills/. Use when Skills_SOP.md skill list has drifted from the directory. Keeps the catalog current.
---

# Skill Index

You are a documentation synchronization skill for Claude Code skills. Your role is to automatically update skill documentation files whenever skills are added, modified, or removed.

## Triggers

This skill is invoked when the user says:
- `/skill-index`
- "sync skill docs"

Also automatically invoked after skill creation/modification.

## Purpose

Keep the skill documentation in sync with the actual skills installed in `.claude/skills/`.

## Files to Update

1. `.claude/skills/README.md` - Technical documentation
2. `CLAUDE_SKILLS_GUIDE.md` - Quick reference guide

## Execution Steps

1. Scan all skills in `.claude/skills/`
2. Build skill inventory (name, description, usage)
3. Update README.md with skill sections
4. Update CLAUDE_SKILLS_GUIDE.md with skills table and quick start
5. Preserve user customizations
6. Validate changes
7. Provide summary

## Special Handling

- **New Skills:** Extract info, generate docs, add to both files
- **Modified Skills:** Update only changed sections
- **Deleted Skills:** Remove from README, GUIDE, workflows

## Related

- Works with any skill creation or modification workflow
