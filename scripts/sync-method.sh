#!/bin/bash
#
# sync-method.sh — Pull method repo content into a consuming project
#
# Usage:
#   ./scripts/sync-method.sh              # Sync from main
#   ./scripts/sync-method.sh v1.0         # Sync from a specific tag/branch
#   ./scripts/sync-method.sh --dry-run    # Show what would change
#
# What it syncs:
#   method/sop/        <- SOPs (Code Quality, Git, Linear, Skills, VBW)
#   method/templates/  <- Spec and review templates
#   method/method.md   <- The methodology overview
#   .claude/skills/    <- Portable skills (won't touch project-specific ones)
#
# What it does NOT touch:
#   method/decisions/       <- Project-specific ADRs
#   .claude/rules/          <- Project coding conventions
#   .claude/skills/{local}  <- Project-specific skills
#   .vbw-planning/          <- Project state
#   method.config.md        <- Project configuration
#
# Overrides (sync-safe customization):
#   .claude/overrides/skills/<name>/skill.md      <- full-file replacement
#   .claude/overrides/sop/<file>.md               <- full-file replacement
#   .claude/overrides/method.md.patch             <- unified diff applied to method.md
#   .claude/overrides/.upstream-snapshot/         <- managed by sync; do not edit
#   .claude/overrides/MANIFEST.md                 <- human-curated list (what + why)
#
# Overrides are applied AFTER upstream sync. Drift is surfaced when upstream
# changes a file that has an override — the user must review.

set -euo pipefail

METHOD_REPO="${METHOD_REPO:-https://github.com/withpiper/pipekit.git}"
DRY_RUN=false
REF="main"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHANGELOG="$PROJECT_ROOT/method/.sync-changelog.md"

# Parse flags without mutating $@ — the self-update guard below re-execs with
# "$@", and a shift here would silently drop --dry-run across the re-exec.
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -*) echo "WARN: unknown flag: $arg" >&2 ;;
    *) REF="$arg" ;;
  esac
done

echo "=== Method Sync ==="
echo "Source: $METHOD_REPO @ $REF"
echo "Target: $PROJECT_ROOT"
echo ""

# Clone to temp directory (or reuse one passed from a self-update re-exec)
if [ -n "${SYNC_METHOD_TEMP:-}" ] && [ -d "$SYNC_METHOD_TEMP" ]; then
  TEMP="$SYNC_METHOD_TEMP"
  unset SYNC_METHOD_TEMP
  trap "rm -rf $TEMP" EXIT
  echo "Reusing repo clone from self-update re-exec."
else
  TEMP=$(mktemp -d)
  trap "rm -rf $TEMP" EXIT

  echo "Fetching method repo..."
  git clone --depth 1 --branch "$REF" "$METHOD_REPO" "$TEMP" 2>/dev/null || {
    echo "ERROR: Failed to clone $METHOD_REPO at ref $REF"
    exit 1
  }
fi

# --- Self-update guard: if the upstream sync-method.sh differs from the one we're
# running, install the new version and re-exec with it. This makes single-invocation
# syncs always use the latest logic, even when new files or sync steps are added.
# The SYNC_METHOD_REEXEC flag prevents an infinite re-exec loop.
if [ -z "${SYNC_METHOD_REEXEC:-}" ] && [ -f "$TEMP/scripts/sync-method.sh" ]; then
  SELF_PATH=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)/$(basename "$0")
  if [ -f "$SELF_PATH" ] && ! cmp -s "$TEMP/scripts/sync-method.sh" "$SELF_PATH"; then
    echo ""
    echo "=== sync-method.sh self-update detected — installing and re-execing ==="
    cp "$TEMP/scripts/sync-method.sh" "$SELF_PATH"
    chmod +x "$SELF_PATH"
    export SYNC_METHOD_REEXEC=1
    export SYNC_METHOD_TEMP="$TEMP"
    trap - EXIT   # keep TEMP alive for the re-exec
    exec "$SELF_PATH" "$@"
  fi
fi

# --- Pre-sync: snapshot current state for changelog ---
SNAP=$(mktemp -d)
snapshot_dir() {
  local dir="$1"
  local label="$2"
  if [ -d "$dir" ]; then
    find "$dir" -type f -exec md5sum {} \; 2>/dev/null | sort > "$SNAP/$label.md5"
  else
    touch "$SNAP/$label.md5"
  fi
}

snapshot_dir "$PROJECT_ROOT/.claude/skills" "skills"
snapshot_dir "$PROJECT_ROOT/method" "method"

# Track changes
CHANGES=0

# Changelog arrays
NEW_SKILLS=""
UPDATED_SKILLS=""
REMOVED_SKILLS=""
UPDATED_FILES=""
NEW_FILES=""

sync_dir() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ ! -d "$src" ]; then
    echo "  SKIP $label (source not found)"
    return
  fi

  mkdir -p "$dst"

  if $DRY_RUN; then
    local diff_count
    # `diff -rq` exits 1 when files differ — that's normal, not an error.
    # Without `|| true`, pipefail propagates the 1 and set -e kills the script.
    diff_count=$({ diff -rq "$src" "$dst" 2>/dev/null || true; } | wc -l | tr -d ' ')
    if [ "$diff_count" -gt 0 ]; then
      echo "  WOULD UPDATE $label ($diff_count files differ)"
      { diff -rq "$src" "$dst" 2>/dev/null || true; } | head -10 | sed 's/^/    /'
      CHANGES=$((CHANGES + diff_count))
    else
      echo "  OK $label (no changes)"
    fi
  else
    rsync -av --delete "$src/" "$dst/" | tail -n +2 | head -20 | sed 's/^/    /'
    echo "  SYNCED $label"
    CHANGES=$((CHANGES + 1))
  fi
}

sync_file() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ ! -f "$src" ]; then
    echo "  SKIP $label (source not found)"
    return
  fi

  if $DRY_RUN; then
    if [ -f "$dst" ] && diff -q "$src" "$dst" >/dev/null 2>&1; then
      echo "  OK $label (no changes)"
    else
      echo "  WOULD UPDATE $label"
      CHANGES=$((CHANGES + 1))
    fi
  else
    cp "$src" "$dst"
    echo "  SYNCED $label"
    CHANGES=$((CHANGES + 1))
  fi
}

# --- Sync method docs ---
echo ""
echo "Method docs:"
mkdir -p "$PROJECT_ROOT/method"
sync_dir "$TEMP/sop" "$PROJECT_ROOT/method/sop" "sop/"
sync_dir "$TEMP/templates" "$PROJECT_ROOT/method/templates" "templates/"
sync_file "$TEMP/method.md" "$PROJECT_ROOT/method/method.md" "method.md"
sync_file "$TEMP/GUIDE.md" "$PROJECT_ROOT/method/GUIDE.md" "GUIDE.md"
sync_file "$TEMP/STARTUP.md" "$PROJECT_ROOT/method/STARTUP.md" "STARTUP.md"

# --- Sync Pipekit hook scripts (VBW lifecycle integration) ---
echo ""
echo "Hook scripts:"
mkdir -p "$PROJECT_ROOT/scripts"
sync_file "$TEMP/scripts/pipekit-post-archive.sh" "$PROJECT_ROOT/scripts/pipekit-post-archive.sh" "scripts/pipekit-post-archive.sh"
[ -f "$PROJECT_ROOT/scripts/pipekit-post-archive.sh" ] && chmod +x "$PROJECT_ROOT/scripts/pipekit-post-archive.sh"
sync_file "$TEMP/scripts/pipekit-next-step-nudge.sh" "$PROJECT_ROOT/scripts/pipekit-next-step-nudge.sh" "scripts/pipekit-next-step-nudge.sh"
[ -f "$PROJECT_ROOT/scripts/pipekit-next-step-nudge.sh" ] && chmod +x "$PROJECT_ROOT/scripts/pipekit-next-step-nudge.sh"
sync_file "$TEMP/scripts/pipekit-state-dir.sh" "$PROJECT_ROOT/scripts/pipekit-state-dir.sh" "scripts/pipekit-state-dir.sh"
[ -f "$PROJECT_ROOT/scripts/pipekit-state-dir.sh" ] && chmod +x "$PROJECT_ROOT/scripts/pipekit-state-dir.sh"
sync_file "$TEMP/scripts/verify-next-md-defer.sh" "$PROJECT_ROOT/scripts/verify-next-md-defer.sh" "scripts/verify-next-md-defer.sh"
[ -f "$PROJECT_ROOT/scripts/verify-next-md-defer.sh" ] && chmod +x "$PROJECT_ROOT/scripts/verify-next-md-defer.sh"
sync_file "$TEMP/scripts/pipekit-configure-repo.sh" "$PROJECT_ROOT/scripts/pipekit-configure-repo.sh" "scripts/pipekit-configure-repo.sh"
[ -f "$PROJECT_ROOT/scripts/pipekit-configure-repo.sh" ] && chmod +x "$PROJECT_ROOT/scripts/pipekit-configure-repo.sh"
sync_file "$TEMP/scripts/pipekit-journal-hook.sh" "$PROJECT_ROOT/scripts/pipekit-journal-hook.sh" "scripts/pipekit-journal-hook.sh"
[ -f "$PROJECT_ROOT/scripts/pipekit-journal-hook.sh" ] && chmod +x "$PROJECT_ROOT/scripts/pipekit-journal-hook.sh"

# --- Sync v2 bin/pk dispatcher (alpha) ---
# v2 daily-loop runner. Coexists with v1 skills — non-colliding names.
if [ -d "$TEMP/bin" ]; then
  echo ""
  echo "v2 bin/:"
  mkdir -p "$PROJECT_ROOT/bin"
  sync_file "$TEMP/bin/pk" "$PROJECT_ROOT/bin/pk" "bin/pk"
  [ -f "$PROJECT_ROOT/bin/pk" ] && chmod +x "$PROJECT_ROOT/bin/pk"
fi

# --- Sync v2 templates ---
if [ -d "$TEMP/templates/v2" ]; then
  mkdir -p "$PROJECT_ROOT/method/templates/v2"
  sync_dir "$TEMP/templates/v2" "$PROJECT_ROOT/method/templates/v2" "templates/v2/"
fi

# --- Sync canonical .claude/rules/ files ---
# Contract: Pipekit owns three canonical rule files prefixed `pipekit-`
# (pipekit-discipline, pipekit-tooling, pipekit-security) plus the README
# that documents the hub-and-spoke model. These get overwritten on every
# sync — changes must round-trip through pipekit.
#
# The `pipekit-` prefix exists specifically to avoid collision with common
# project-specific filenames (security.md, tooling.md are typical names
# consumers use for app-specific rules). Before the prefix, sync would
# silently overwrite project content.
#
# Any OTHER file in .claude/rules/ is untouched (we use sync_file, not
# sync_dir --delete, so project-specific rules like patterns.md, naming.md,
# security.md (project-authored), or {library}-pitfalls.md persist).
if [ -d "$TEMP/templates/rules" ]; then
  echo ""
  echo "Canonical rules (.claude/rules/):"
  mkdir -p "$PROJECT_ROOT/.claude/rules"
  for canonical in README.md pipekit-discipline.md pipekit-tooling.md pipekit-security.md; do
    if [ -f "$TEMP/templates/rules/$canonical" ]; then
      sync_file "$TEMP/templates/rules/$canonical" "$PROJECT_ROOT/.claude/rules/$canonical" ".claude/rules/$canonical"
    fi
  done
fi

# --- Sync Pipekit agents (subagents spawned by Pipekit skills) ---
if [ -d "$TEMP/agents" ]; then
  echo ""
  echo "Agents:"
  mkdir -p "$PROJECT_ROOT/.claude/agents"
  sync_dir "$TEMP/agents" "$PROJECT_ROOT/.claude/agents" "agents/"
fi

# --- Sync portable skills ---
echo ""
echo "Portable skills:"

# Get list of portable skills from method repo
PORTABLE_SKILLS=$(ls -d "$TEMP/skills/"*/ 2>/dev/null | xargs -I{} basename {})

for skill in $PORTABLE_SKILLS; do
  src="$TEMP/skills/$skill"
  dst="$PROJECT_ROOT/.claude/skills/$skill"

  if [ ! -d "$src" ]; then
    continue
  fi

  # Track new vs updated
  if [ ! -d "$dst" ]; then
    NEW_SKILLS="$NEW_SKILLS $skill"
  elif ! diff -rq "$src" "$dst" >/dev/null 2>&1; then
    UPDATED_SKILLS="$UPDATED_SKILLS $skill"
  fi

  mkdir -p "$dst"

  if $DRY_RUN; then
    if [ -d "$dst" ]; then
      diff_count=$({ diff -rq "$src" "$dst" 2>/dev/null || true; } | wc -l | tr -d ' ')
      if [ "$diff_count" -gt 0 ]; then
        echo "  WOULD UPDATE skill: $skill"
        CHANGES=$((CHANGES + 1))
      else
        echo "  OK skill: $skill"
      fi
    else
      echo "  WOULD CREATE skill: $skill"
      CHANGES=$((CHANGES + 1))
    fi
  else
    rsync -av "$src/" "$dst/" >/dev/null 2>&1
    echo "  SYNCED skill: $skill"
    CHANGES=$((CHANGES + 1))
  fi
done

# Check for skills that exist locally but not in the method repo (removed/renamed)
if [ -d "$PROJECT_ROOT/.claude/skills" ]; then
  for existing_skill_dir in "$PROJECT_ROOT/.claude/skills"/*/; do
    existing_skill=$(basename "$existing_skill_dir")
    if [ ! -d "$TEMP/skills/$existing_skill" ]; then
      # Could be project-specific or a removed portable skill
      # Only flag it if it has no project-specific marker
      if [ -f "$existing_skill_dir/skill.md" ]; then
        # Check if this was a portable skill (existed in a previous sync)
        if grep -q "^  SYNCED skill: $existing_skill" "$PROJECT_ROOT/method/.sync-changelog.md" 2>/dev/null || \
           echo "$PORTABLE_SKILLS" | grep -qv "$existing_skill"; then
          REMOVED_SKILLS="$REMOVED_SKILLS $existing_skill"
        fi
      fi
    fi
  done
fi

# --- Sync scripts ---
echo ""
echo "Scripts:"
sync_file "$TEMP/scripts/drift-check.sh" "$PROJECT_ROOT/scripts/drift-check.sh" "drift-check.sh"
# Also update the sync script itself
sync_file "$TEMP/scripts/sync-method.sh" "$PROJECT_ROOT/scripts/sync-method.sh" "sync-method.sh"
# Make scripts executable
for script in drift-check.sh sync-method.sh; do
  if [ -f "$PROJECT_ROOT/scripts/$script" ]; then
    chmod +x "$PROJECT_ROOT/scripts/$script"
  fi
done

# --- Apply overrides ---
# Project-local overrides live under .claude/overrides/. After upstream sync,
# we replay full-file overrides for skills/sop and apply method.md.patch.
# We snapshot the upstream version we replaced so the *next* sync can detect
# upstream drift on overridden files.
OVERRIDES_DIR="$PROJECT_ROOT/.claude/overrides"
OVERRIDE_SNAPSHOT="$OVERRIDES_DIR/.upstream-snapshot"
OVERRIDES_APPLIED=""
OVERRIDE_DRIFT=""

apply_override() {
  # $1 = override file path (under OVERRIDES_DIR)
  # $2 = target file path (in project)
  # $3 = label for output
  local override="$1"
  local target="$2"
  local label="$3"

  if [ ! -f "$target" ]; then
    echo "  SKIP override $label (target missing: $target)"
    return
  fi

  local rel="${override#$OVERRIDES_DIR/}"
  local snap_path="$OVERRIDE_SNAPSHOT/$rel"
  mkdir -p "$(dirname "$snap_path")"

  # Drift check: if a previous snapshot exists and doesn't match the upstream
  # version we just synced, upstream changed underneath the override.
  if [ -f "$snap_path" ] && ! cmp -s "$snap_path" "$target"; then
    OVERRIDE_DRIFT="$OVERRIDE_DRIFT $label"
    echo "  ⚠ DRIFT $label — upstream changed; review override against new upstream"
  fi

  if $DRY_RUN; then
    echo "  WOULD OVERRIDE $label"
  else
    # Snapshot the upstream version BEFORE overwriting it.
    cp "$target" "$snap_path"
    cp "$override" "$target"
    echo "  OVERRIDE $label"
    OVERRIDES_APPLIED="$OVERRIDES_APPLIED $label"
  fi
}

apply_patch_override() {
  # $1 = patch file (under OVERRIDES_DIR)
  # $2 = target file (in project)
  # $3 = label
  local patch_file="$1"
  local target="$2"
  local label="$3"

  if [ ! -f "$target" ]; then
    echo "  SKIP patch $label (target missing: $target)"
    return
  fi

  local rel="${patch_file#$OVERRIDES_DIR/}"
  local snap_path="$OVERRIDE_SNAPSHOT/$rel.target"
  mkdir -p "$(dirname "$snap_path")"

  # Drift check on patches: compare new upstream target to last-known upstream.
  if [ -f "$snap_path" ] && ! cmp -s "$snap_path" "$target"; then
    OVERRIDE_DRIFT="$OVERRIDE_DRIFT $label"
    echo "  ⚠ DRIFT $label — upstream changed; patch may not apply cleanly"
  fi

  if $DRY_RUN; then
    echo "  WOULD PATCH $label"
    return
  fi

  # Snapshot upstream BEFORE patching.
  cp "$target" "$snap_path"

  # Apply patch. Use --dry-run first to fail loud rather than half-apply.
  if patch --dry-run -p1 -d "$(dirname "$target")" -i "$patch_file" >/dev/null 2>&1; then
    patch -p1 -d "$(dirname "$target")" -i "$patch_file" >/dev/null
    echo "  PATCHED $label"
    OVERRIDES_APPLIED="$OVERRIDES_APPLIED $label"
  else
    echo "  ✗ PATCH FAILED $label — upstream diverged from patch context."
    echo "    Inspect: $patch_file"
    echo "    Upstream snapshot: $snap_path"
    echo "    Sync continuing; resolve patch manually before next sync."
  fi
}

if [ -d "$OVERRIDES_DIR" ]; then
  echo ""
  echo "Overrides:"

  # Skill overrides: .claude/overrides/skills/<name>/skill.md
  if [ -d "$OVERRIDES_DIR/skills" ]; then
    while IFS= read -r -d '' override_file; do
      skill_name=$(basename "$(dirname "$override_file")")
      target="$PROJECT_ROOT/.claude/skills/$skill_name/$(basename "$override_file")"
      apply_override "$override_file" "$target" "skills/$skill_name/$(basename "$override_file")"
    done < <(find "$OVERRIDES_DIR/skills" -type f -name '*.md' -print0 2>/dev/null)
  fi

  # SOP overrides: .claude/overrides/sop/<file>.md
  if [ -d "$OVERRIDES_DIR/sop" ]; then
    while IFS= read -r -d '' override_file; do
      target="$PROJECT_ROOT/method/sop/$(basename "$override_file")"
      apply_override "$override_file" "$target" "sop/$(basename "$override_file")"
    done < <(find "$OVERRIDES_DIR/sop" -type f -name '*.md' -print0 2>/dev/null)
  fi

  # method.md patch
  if [ -f "$OVERRIDES_DIR/method.md.patch" ]; then
    apply_patch_override \
      "$OVERRIDES_DIR/method.md.patch" \
      "$PROJECT_ROOT/method/method.md" \
      "method.md.patch"
  fi

  if [ -z "$OVERRIDES_APPLIED" ] && [ -z "$OVERRIDE_DRIFT" ]; then
    echo "  (no overrides found)"
  fi
fi

# --- Check for method.config.md ---
echo ""
if [ ! -f "$PROJECT_ROOT/method.config.md" ]; then
  if $DRY_RUN; then
    echo "NOTE: method.config.md not found. Would copy template."
  else
    cp "$TEMP/method.config.template.md" "$PROJECT_ROOT/method.config.md"
    echo "CREATED method.config.md from template — fill in your project values!"
  fi
fi

# --- Post-sync: generate changelog ---
if ! $DRY_RUN; then
  # Compare method files
  for f in method.md GUIDE.md STARTUP.md; do
    dst="$PROJECT_ROOT/method/$f"
    if [ -f "$dst" ]; then
      old_hash=$(grep "$dst" "$SNAP/method.md5" 2>/dev/null | awk '{print $1}' || true)
      new_hash=$(md5sum "$dst" 2>/dev/null | awk '{print $1}')
      if [ "$old_hash" != "$new_hash" ]; then
        UPDATED_FILES="$UPDATED_FILES $f"
      fi
    fi
  done

  # Write changelog
  SYNC_DATE=$(date '+%Y-%m-%d %H:%M')
  cat > "$CHANGELOG" << CHLOG
# Sync Changelog

**Synced:** $SYNC_DATE
**Source:** $METHOD_REPO @ $REF

## Skills

CHLOG

  if [ -n "$NEW_SKILLS" ]; then
    echo "### New" >> "$CHANGELOG"
    for s in $NEW_SKILLS; do
      desc=""
      if [ -f "$PROJECT_ROOT/.claude/skills/$s/skill.md" ]; then
        desc=$(grep '^description:' "$PROJECT_ROOT/.claude/skills/$s/skill.md" 2>/dev/null | head -1 | sed 's/^description: *//')
      fi
      echo "- \`/$s\` — $desc" >> "$CHANGELOG"
    done
    echo "" >> "$CHANGELOG"
  fi

  if [ -n "$UPDATED_SKILLS" ]; then
    echo "### Updated" >> "$CHANGELOG"
    for s in $UPDATED_SKILLS; do
      echo "- \`/$s\`" >> "$CHANGELOG"
    done
    echo "" >> "$CHANGELOG"
  fi

  if [ -n "$REMOVED_SKILLS" ]; then
    echo "### Possibly Removed/Renamed" >> "$CHANGELOG"
    for s in $REMOVED_SKILLS; do
      echo "- \`/$s\` — exists locally but not in method repo (may be renamed or project-specific)" >> "$CHANGELOG"
    done
    echo "" >> "$CHANGELOG"
  fi

  if [ -z "$NEW_SKILLS" ] && [ -z "$UPDATED_SKILLS" ] && [ -z "$REMOVED_SKILLS" ]; then
    echo "No skill changes." >> "$CHANGELOG"
    echo "" >> "$CHANGELOG"
  fi

  echo "## Method Docs" >> "$CHANGELOG"
  if [ -n "$UPDATED_FILES" ]; then
    for f in $UPDATED_FILES; do
      echo "- \`$f\` — updated" >> "$CHANGELOG"
    done
  else
    echo "No doc changes." >> "$CHANGELOG"
  fi
  echo "" >> "$CHANGELOG"

  echo "## Config" >> "$CHANGELOG"
  # Check if template has fields not in project config
  if [ -f "$PROJECT_ROOT/method.config.md" ] && [ -f "$TEMP/method.config.template.md" ]; then
    new_fields=$(diff <(grep '^\| \*\*' "$PROJECT_ROOT/method.config.md" 2>/dev/null | sort) \
                      <(grep '^\| \*\*' "$TEMP/method.config.template.md" 2>/dev/null | sort) \
                      2>/dev/null | grep '^>' | sed 's/^> //' || true)
    if [ -n "$new_fields" ]; then
      echo "New fields in template (may need adding to method.config.md):" >> "$CHANGELOG"
      echo "$new_fields" | while read -r line; do
        echo "- $line" >> "$CHANGELOG"
      done
    else
      echo "No new config fields." >> "$CHANGELOG"
    fi
  else
    echo "No config comparison available." >> "$CHANGELOG"
  fi
  echo "" >> "$CHANGELOG"
  echo "---" >> "$CHANGELOG"
  echo "_Read by \`/pipekit-update\` for reconciliation. Safe to delete after review._" >> "$CHANGELOG"

  if [ -n "$OVERRIDES_APPLIED" ] || [ -n "$OVERRIDE_DRIFT" ]; then
    echo "" >> "$CHANGELOG"
    echo "## Overrides" >> "$CHANGELOG"
    if [ -n "$OVERRIDES_APPLIED" ]; then
      echo "### Applied" >> "$CHANGELOG"
      for o in $OVERRIDES_APPLIED; do
        echo "- \`$o\`" >> "$CHANGELOG"
      done
    fi
    if [ -n "$OVERRIDE_DRIFT" ]; then
      echo "### Drift (review required)" >> "$CHANGELOG"
      for o in $OVERRIDE_DRIFT; do
        echo "- \`$o\` — upstream changed; verify override is still correct" >> "$CHANGELOG"
      done
    fi
  fi

  echo ""
  echo "Changelog written to: method/.sync-changelog.md"
fi

# Clean up snapshot
rm -rf "$SNAP"

# --- Summary ---
echo ""
echo "=== Sync Complete ==="
if $DRY_RUN; then
  echo "Dry run: $CHANGES items would change"
  echo "Remove --dry-run to apply"
else
  echo "Synced from: $METHOD_REPO @ $REF"
  if [ -n "$OVERRIDE_DRIFT" ]; then
    echo ""
    echo "⚠ Override drift detected on:$OVERRIDE_DRIFT"
    echo "  Upstream changed files you override. Review before committing."
  fi
  echo ""
  echo "Next steps:"
  echo "  1. Review method/.sync-changelog.md for what changed"
  echo "  2. Run /pipekit-update reconciliation (restart Claude Code first)"
  echo "  3. Commit the synced files"
fi
