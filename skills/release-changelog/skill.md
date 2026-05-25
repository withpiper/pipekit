---
name: release-changelog
description: Draft a CHANGELOG entry from git commits between tags. Use when cutting a release and need a starting CHANGELOG block. Use after a version bump to regroup commits into canonical sections. Read-only on git and CHANGELOG.md — outputs to stdout.
---

# Release Changelog Skill

You generate a **draft** CHANGELOG.md entry from the git commits in a release range. Commit messages already encode 80% of what an entry needs (`type(scope): description` is enforced by hook in this repo); this skill regroups them into the canonical sections so the human only authors the narrative pieces.

The skill is **read-only** on git state and on `CHANGELOG.md`. Output goes to stdout. The human copies the draft into `CHANGELOG.md`, edits the prose, and commits — that loop preserves human judgment over the narrative while saving the rote restructuring work.

Read `method.config.md` for project context (Pipekit doesn't strictly require it, but stays consistent with other portable skills).

## Triggers

- `/release-changelog --version v1.5.0`
- `/release-changelog --version v1.5.0 --from v1.4.1`
- `/release-changelog --version v1.5.0 --from v1.4.1 --to HEAD`

## Arguments

| Argument | Default | Notes |
|----------|---------|-------|
| `--version vX.Y.Z` | required | The new tag being prepared. Must match `vX.Y.Z` or `vX.Y.Z-<suffix>` (e.g., `v1.5.0-rc1`). |
| `--from <ref>` | `git describe --tags --abbrev=0` | Previous release tag. If no prior tag exists, the skill errors and asks for an explicit `--from`. |
| `--to <ref>` | `HEAD` | Range end. Useful for previewing the next release before everything has merged. |

## When to use

After the last commit lands on the release branch (typically `main` for Pipekit), before `git tag`. Workflow:

1. `/release-changelog --version vX.Y.Z` — print draft to terminal
2. Copy output, paste into `CHANGELOG.md` above the previous release header
3. Edit the human-authored sections (narrative lead, migration specifics, deferred items)
4. `git add CHANGELOG.md && git commit -m "docs(release): vX.Y.Z changelog"`
5. `git tag vX.Y.Z && git push --tags`

This skill does **not** automate steps 2-5. Auto-writing to `CHANGELOG.md` would lose the editing pass that makes the entry useful.

## When NOT to use

- For point releases with a single commit. The structured entry is overkill — write it inline.
- When commits don't follow `type(scope): description`. The skill will still run (misformatted commits bucket gracefully into "Other Changes"), but the output is less useful when most commits don't parse.

## Algorithm

### Step 1 — Validate arguments

1. Require `--version`. If absent: stop with `"--version vX.Y.Z is required."`.
2. Validate `--version` matches `^v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$`. If not: stop with `"--version must be vX.Y.Z or vX.Y.Z-<suffix>; got: {value}"`.
3. Resolve `--from`:
   - If supplied, use it verbatim.
   - Else, run `git describe --tags --abbrev=0`. If that fails (no prior tag): stop with `"No prior tag found. Pass --from <ref> explicitly (e.g., --from <first-commit-sha>)."`.
4. Resolve `--to`. Default `HEAD`. No validation beyond existence.

### Step 2 — Read commits

Run:

```bash
git log --pretty=format:'%H%x09%s%x09%b%x1e' <from>..<to>
```

`%x09` is a tab separator inside a record; `%x1e` is the record separator (ASCII 30, "Record Separator"). This avoids collisions with newlines that appear in commit bodies.

Split on `%x1e` to get one record per commit; split each record on `%x09` to get `(sha, subject, body)`.

If the range is empty: print `"no changes since {from}"` and exit (code 0). Not an error.

### Step 3 — Bucket commits

For each commit, parse the subject against `^(?P<type>feat|fix|docs|refactor|chore|test|perf)\((?P<scope>[^)]+)\):\s*(?P<rest>.+)$`.

Map by `type`:

| Subject `type` | Section in output |
|----------------|-------------------|
| `feat` | **What's New** |
| `fix` | **Fix** |
| `docs` | **Documentation** |
| `refactor`, `chore`, `test`, `perf` | **Other Changes** |
| anything else (no match) | **Other Changes** with the full original subject |

Empty buckets are *omitted* from the output entirely — don't render an empty `### Fix` section. The exception is **What's New**, which is always rendered (even if empty) because the human writes the narrative lead there.

### Step 4 — Extract issue refs

For each commit, scan both the subject `rest` portion and the body for issue references. Two patterns:

- `Closes #N` / `closes #N` / `Fixes #N` (preserved as `closes #N` in the bullet, since GitHub auto-closes only on the literal forms in commit messages — but we surface it in the changelog purely for traceability)
- Bare `#N` mentions (preserved as `#N`)

Dedupe per commit. Append issue refs to the bullet in parentheses: `(closes #9, #11)`.

### Step 5 — Render the draft

Print to stdout in this exact shape (mirrors `CHANGELOG.md` v1.4.0 / v1.4.1 entries):

```markdown
## {version} — {today YYYY-MM-DD}

### What's New

[TODO human: 1-2 sentence narrative lead summarizing the release theme]

{for each feat commit, in input order:}
**{commit subject rest, capitalized}** ({issue refs}). {body first paragraph, if non-empty, otherwise omit}.

### Fix

{for each fix commit:}
**{subject rest}** ({issue refs}). {body first paragraph if present}

### Documentation

{for each docs commit:}
- {subject rest} ({issue refs})

### Migration

For consuming projects on {previous version, derived from --from}:

- `./scripts/sync-method.sh {version}` — {auto-detect: list new files in `skills/` introduced in this range; if none, say "no new skills"}
- [TODO human: write migration specifics — config changes, breaking changes, manual steps]

### Other Changes

{for each commit in this bucket:}
- {full subject if no match, else `{type}({scope}): {rest}`} ({issue refs})

[TODO human: deferred items / open items list — carry forward from previous release if anything remains]
```

Section ordering: `What's New` → `Fix` → `Documentation` → `Migration` → `Other Changes`. Skip empty sections (except `What's New` and `Migration`, which are always rendered as scaffolding for the human).

For the auto-detect of new skill directories: run

```bash
git diff --name-only --diff-filter=A <from>..<to> -- 'skills/*/skill.md'
```

and list the resulting directory names (`skills/<name>/`) under the `sync-method.sh` bullet. If empty: `"no new skills"`.

### Step 6 — Date

Use `$(date +%Y-%m-%d)` in the local timezone. Do **not** use commit dates from the range — the convention in `CHANGELOG.md` is "release date is when the entry was published," and that's today.

### Step 7 — Print and stop

Print the rendered markdown block. Print a one-line trailer:

```
[Draft printed above. Copy into CHANGELOG.md above the previous entry, edit TODO markers, commit.]
```

Do nothing else. Do not write `CHANGELOG.md`. Do not tag. Do not push.

## What the human still authors

The TODO markers above are intentional placeholders — the skill cannot generate these well without context only the human has:

- **What's New narrative lead** — what's the release *about*? A theme sentence makes the entry navigable. Auto-generation would produce generic copy.
- **Migration specifics** — config changes, breaking changes, manual steps, schema bumps. The skill detects new skill files but can't infer required `method.config.md` edits or behavioral diffs.
- **Deferred / open items** — what slipped to the next release? This is forward-looking; the skill only sees backwards.
- **Per-bullet narrative** — the auto-rendered bullet is the commit subject + body's first paragraph. For load-bearing commits (the marquee features), the human typically expands this into a paragraph or two with rationale.

## Edge Cases

| Condition | Behavior |
|-----------|----------|
| No prior tag and no `--from` | Stop with error. Do not silently fall back to first commit. |
| Invalid `--version` format | Stop with error. The semver-ish convention is load-bearing for the sync script. |
| Empty commit range | Exit 0 with `"no changes since {from}"`. Not an error. |
| Commit subject doesn't match `type(scope):` | Bucket as **Other Changes** with the full original subject — don't drop it. |
| Commit body contains the record separator (ASCII 30) | Vanishingly unlikely; if it happens, the parse will mis-split. Document as a known limitation. |
| `--to` ref doesn't exist | `git log` errors loudly. Surface the error verbatim. |

## Output Example

```
$ /release-changelog --version v1.5.0 --from v1.4.1

## v1.5.0 — 2026-04-28

### What's New

[TODO human: 1-2 sentence narrative lead summarizing the release theme]

**`/spec-preflight` automates empirical pre-flight checks on specs** (closes #9). New skill verifies file paths, line refs, phase-detect baseline, Linear status, and dependency claims against reality. Read-only — never modifies the spec or transitions Linear. Slots between Spec Review Agent and `pk branch`.

**`/release-changelog` generates draft CHANGELOG entry from commits** (closes #10). New skill that parses `type(scope): subject` commits between two refs, buckets by section, and prints a draft entry to stdout. Human edits narrative + migration sections, then commits.

### Documentation

- sop: add /spec-preflight and /release-changelog to portable skills table
- method: document /spec-preflight and /release-changelog in skill tables

### Migration

For consuming projects on v1.4.1:

- `./scripts/sync-method.sh v1.5.0` — pulls skills/spec-preflight/, skills/release-changelog/
- [TODO human: write migration specifics — config changes, breaking changes, manual steps]

[Draft printed above. Copy into CHANGELOG.md above the previous entry, edit TODO markers, commit.]
```

## Rules of Engagement

- **Read-only on `CHANGELOG.md`.** Never modify the file. The human's editing pass is load-bearing.
- **Read-only on git state.** No `git tag`, no `git push`, no `git commit`. The skill is a *generator*, not a release driver.
- **Don't generalize the version.** If `--version` is malformed, stop. The skill should never invent a version number.
- **Don't infer migration steps.** Auto-listing new skill files is a structural hint; the human always writes the actual migration narrative because it requires judgment about what consumers must do.
- **Don't recurse.** The skill prints the draft and ends. The user copies, edits, commits, and tags themselves.

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `/pk-exit` | Writes the per-session narrative log to `Logs/Sessions/<date>_<HHMM>.md`. Independent of release work — this skill is per-release, `/pk-exit` is per-session. |
| `/pipekit-update` | Pulls a tagged Pipekit version into a consumer project. The tag has to exist first — `/release-changelog` is part of the workflow that produces the tag. |
| `/strategy-sync` | Closes the docs loop after a feature ships. Independent of Pipekit's own release flow, but conceptually similar (both convert "what shipped" into "what the doc says"). |
