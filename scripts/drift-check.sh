#!/bin/bash
#
# drift-check.sh — Detect stale references in documentation
#
# Scans markdown files for file path references and verifies they exist on disk.
# Also checks for stale docs and missing package.json scripts.
#
# Usage:
#   ./scripts/drift-check.sh              # Full check
#   ./scripts/drift-check.sh --paths      # File path check only
#   ./scripts/drift-check.sh --stale      # Staleness check only
#   ./scripts/drift-check.sh --scripts    # Script/command check only
#   ./scripts/drift-check.sh --ci         # Exit 1 if any drift found (for CI)
#   ./scripts/drift-check.sh --quick      # Skip staleness check; fast mode for hooks
#   ./scripts/drift-check.sh --install-hook    # Install as post-commit hook
#   ./scripts/drift-check.sh --uninstall-hook  # Remove post-commit hook
#
# Context detection:
#   - In the method repo: checks skills, templates, SOPs, method.md, GUIDE.md
#   - In a consuming project: checks CLAUDE.md, .claude/rules/, method/ docs

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# --- Configuration ---
STALE_THRESHOLD=50  # Flag docs not updated in this many commits
CI_MODE=false
CHECK_PATHS=true
CHECK_STALE=true
CHECK_SCRIPTS=true

# Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
DIM='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
DRIFT_COUNT=0
WARN_COUNT=0
OK_COUNT=0

# --- Hook management (handled before other flag parsing so they exit early) ---
HOOK_MARKER="# pipekit-drift-check"
HOOK_PATH=".git/hooks/post-commit"

install_hook() {
  if [ ! -d ".git" ]; then
    echo "ERROR: not a git repo root. Run from the project root." >&2
    exit 1
  fi

  if [ -f "$HOOK_PATH" ] && grep -q "$HOOK_MARKER" "$HOOK_PATH" 2>/dev/null; then
    echo "Drift-check hook already installed at $HOOK_PATH."
    exit 0
  fi

  mkdir -p "$(dirname "$HOOK_PATH")"

  if [ -f "$HOOK_PATH" ]; then
    # Existing hook — append
    {
      echo ""
      echo "$HOOK_MARKER"
      echo 'bash "$(git rev-parse --show-toplevel)/scripts/drift-check.sh" --quick --ci >/dev/null 2>&1 || echo "drift-check: issues found; run scripts/drift-check.sh for details"'
    } >> "$HOOK_PATH"
    echo "Appended drift-check block to existing $HOOK_PATH."
  else
    # New hook
    cat > "$HOOK_PATH" <<EOF
#!/bin/bash
$HOOK_MARKER
bash "\$(git rev-parse --show-toplevel)/scripts/drift-check.sh" --quick --ci >/dev/null 2>&1 || echo "drift-check: issues found; run scripts/drift-check.sh for details"
EOF
    chmod +x "$HOOK_PATH"
    echo "Installed post-commit drift-check hook at $HOOK_PATH."
  fi

  echo ""
  echo "Each commit will now run a fast drift check and warn on issues."
  echo "Uninstall with: bash scripts/drift-check.sh --uninstall-hook"
  exit 0
}

uninstall_hook() {
  if [ ! -f "$HOOK_PATH" ]; then
    echo "No post-commit hook found."
    exit 0
  fi

  if ! grep -q "$HOOK_MARKER" "$HOOK_PATH"; then
    echo "Hook at $HOOK_PATH is not a pipekit drift-check hook. Leaving it alone."
    exit 0
  fi

  # Remove the marker line + the next line (the actual check command)
  local tmp
  tmp=$(mktemp)
  awk -v marker="$HOOK_MARKER" '
    $0 == marker { skip=2 }
    skip > 0 { skip--; next }
    { print }
  ' "$HOOK_PATH" > "$tmp"

  # If the remaining hook is empty or just a shebang, remove the whole file
  local remaining_lines
  remaining_lines=$(grep -cvE '^(#!.*|[[:space:]]*)$' "$tmp" || true)
  if [ "$remaining_lines" -eq 0 ]; then
    rm "$HOOK_PATH"
    rm "$tmp"
    echo "Removed $HOOK_PATH (drift-check was the only content)."
  else
    mv "$tmp" "$HOOK_PATH"
    chmod +x "$HOOK_PATH"
    echo "Removed drift-check block from $HOOK_PATH (other hook content preserved)."
  fi
  exit 0
}

# Handle hook management first
for arg in "$@"; do
  case "$arg" in
    --install-hook)   install_hook ;;
    --uninstall-hook) uninstall_hook ;;
  esac
done

# --- Parse arguments ---
for arg in "$@"; do
  case "$arg" in
    --paths)   CHECK_STALE=false; CHECK_SCRIPTS=false ;;
    --stale)   CHECK_PATHS=false; CHECK_SCRIPTS=false ;;
    --scripts) CHECK_PATHS=false; CHECK_STALE=false ;;
    --quick)   CHECK_STALE=false ;;  # skip the git log-heavy staleness check
    --ci)      CI_MODE=true ;;
  esac
done

# --- Detect context ---
IS_METHOD_REPO=false
if [ -f "$PROJECT_ROOT/method.md" ] && [ -d "$PROJECT_ROOT/skills" ] && [ -d "$PROJECT_ROOT/sop" ]; then
  IS_METHOD_REPO=true
fi

# --- Collect markdown files to scan ---
collect_docs() {
  local docs=()

  if $IS_METHOD_REPO; then
    # Method repo: scan everything
    [ -f "method.md" ]    && docs+=("method.md")
    [ -f "GUIDE.md" ]     && docs+=("GUIDE.md")
    [ -f "CLAUDE.md" ]    && docs+=("CLAUDE.md")
    [ -f "README.md" ]    && docs+=("README.md")
    [ -f "STARTUP.md" ]   && docs+=("STARTUP.md")
    [ -f "METHOD_IMPROVEMENTS.md" ] && docs+=("METHOD_IMPROVEMENTS.md")
    [ -f "method.config.template.md" ] && docs+=("method.config.template.md")

    # Skills
    while IFS= read -r f; do docs+=("$f"); done < <(find skills -name "skill.md" 2>/dev/null)

    # SOPs
    while IFS= read -r f; do docs+=("$f"); done < <(find sop -name "*.md" 2>/dev/null)

    # Templates (but not strategy templates — they're fill-in-the-blank)
    while IFS= read -r f; do docs+=("$f"); done < <(find templates -maxdepth 1 -name "*.md" 2>/dev/null)
    while IFS= read -r f; do docs+=("$f"); done < <(find templates/rules -name "*.md" 2>/dev/null)
  else
    # Consuming project: scan project docs
    [ -f "CLAUDE.md" ] && docs+=("CLAUDE.md")
    [ -f "method.config.md" ] && docs+=("method.config.md")

    # Rules
    while IFS= read -r f; do docs+=("$f"); done < <(find .claude/rules -name "*.md" 2>/dev/null)

    # Synced method docs
    while IFS= read -r f; do docs+=("$f"); done < <(find method -name "*.md" 2>/dev/null)

    # Synced skills
    while IFS= read -r f; do docs+=("$f"); done < <(find .claude/skills -name "skill.md" 2>/dev/null)
  fi

  printf '%s\n' "${docs[@]}"
}

# --- Check 1: File path references ---
check_paths() {
  echo -e "${BOLD}== File Path References ==${NC}"
  echo ""

  local total=0
  local missing=0
  local checked_paths=()

  while IFS= read -r doc; do
    # Extract backtick-quoted strings that look like real file paths
    # Strategy: only match strings that look like actual on-disk paths,
    # not skill invocations, commands, glob patterns, or examples
    local paths
    paths=$(grep -oE '`[^`]+`' "$doc" 2>/dev/null | sed 's/`//g' | \
      grep -E '/' | \
      grep -vE '^https?://' | \
      grep -vE '^\$' | \
      grep -vE '\{[^}]+\}' | \
      grep -vE '^\*' | \
      grep -vE '^/' | \
      grep -vE '^~/' | \
      grep -vE '^@/' | \
      grep -vE '\*\*' | \
      grep -vE '^\.\.\.' | \
      grep -vE '^mcp__' | \
      grep -vE '^<' | \
      grep -vE 'node_modules' | \
      grep -vE '^(pnpm|npm|yarn|git|cd|cp|cat|find|grep|echo|bash|mkdir|rm|rsync|diff|vercel) ' | \
      grep -vE '^(feature|fix|hotfix|refactor)/' | \
      grep -vE ' ' | \
      grep -E '\.(md|ts|tsx|js|jsx|json|sh|yml|yaml|toml|sql|css|env)$|/$' | \
      sort -u || true)

    if [ -z "$paths" ]; then
      continue
    fi

    local doc_has_issues=false

    while IFS= read -r path; do
      # Clean the path first — remove trailing punctuation, markdown artifacts
      path=$(echo "$path" | sed 's/[,;:)]*$//' | sed 's/^"//' | sed 's/"$//')

      # Skip if already checked this cleaned path
      local already_checked=false
      for cp in "${checked_paths[@]+"${checked_paths[@]}"}"; do
        if [ "$cp" = "$path" ]; then
          already_checked=true
          break
        fi
      done
      if $already_checked; then continue; fi
      checked_paths+=("$path")

      # Skip template/example paths
      if echo "$path" | grep -qE '\[.*\]|{.*}|<.*>|your-project|kebab-name|XXX|YYYY'; then
        continue
      fi

      # Skip glob patterns
      if echo "$path" | grep -qE '\*'; then
        continue
      fi

      # Skip paths that are clearly about consuming project structure (when in method repo)
      if $IS_METHOD_REPO; then
        if echo "$path" | grep -qE '^\.(claude|vbw-planning)/'; then
          continue
        fi
        if echo "$path" | grep -qE '^(method/|Strategy/|Security/|src/|src_poc/|packages/|Logs/|rules/)'; then
          continue
        fi
        if echo "$path" | grep -qE '^concept-brief\.md$|^project-definition\.md$|^method\.config\.md$'; then
          continue
        fi
        # Skip relative paths within skill directories (references/ subdirs, etc.)
        if echo "$path" | grep -qE '^references/'; then
          continue
        fi
      fi

      total=$((total + 1))

      if [ -e "$path" ]; then
        OK_COUNT=$((OK_COUNT + 1))
      else
        if ! $doc_has_issues; then
          echo -e "  ${DIM}$doc:${NC}"
          doc_has_issues=true
        fi
        echo -e "    ${RED}MISSING${NC}  $path"
        missing=$((missing + 1))
        DRIFT_COUNT=$((DRIFT_COUNT + 1))
      fi
    done <<< "$paths"
  done < <(collect_docs)

  if [ $missing -eq 0 ]; then
    echo -e "  ${GREEN}All $total referenced paths exist${NC}"
  else
    echo ""
    echo -e "  ${RED}$missing/$total paths missing${NC}"
  fi
  echo ""
}

# --- Check 2: Stale documents ---
check_stale() {
  echo -e "${BOLD}== Document Staleness ==${NC}"
  echo ""

  # Get total commit count
  local total_commits
  total_commits=$(git rev-list --count HEAD 2>/dev/null || echo "0")

  if [ "$total_commits" -lt "$STALE_THRESHOLD" ]; then
    echo -e "  ${DIM}Repo has only $total_commits commits (threshold: $STALE_THRESHOLD). Skipping staleness check.${NC}"
    echo ""
    return
  fi

  local stale_count=0

  while IFS= read -r doc; do
    # Get commits since this file was last modified
    local last_commit
    last_commit=$(git log -1 --format="%H" -- "$doc" 2>/dev/null || echo "")

    if [ -z "$last_commit" ]; then
      # File not tracked by git
      continue
    fi

    local commits_since
    commits_since=$(git rev-list --count "$last_commit..HEAD" 2>/dev/null || echo "0")

    if [ "$commits_since" -ge "$STALE_THRESHOLD" ]; then
      local last_date
      last_date=$(git log -1 --format="%cr" -- "$doc" 2>/dev/null)
      echo -e "  ${YELLOW}STALE${NC}  $doc — last updated $last_date ($commits_since commits ago)"
      stale_count=$((stale_count + 1))
      WARN_COUNT=$((WARN_COUNT + 1))
    fi
  done < <(collect_docs)

  if [ $stale_count -eq 0 ]; then
    echo -e "  ${GREEN}All documents updated within last $STALE_THRESHOLD commits${NC}"
  fi
  echo ""
}

# --- Check 3: Package.json script references ---
check_scripts() {
  echo -e "${BOLD}== Script References ==${NC}"
  echo ""

  # Find package.json — could be root or monorepo
  local pkg_json=""
  if [ -f "package.json" ]; then
    pkg_json="package.json"
  else
    echo -e "  ${DIM}No package.json found. Skipping script check.${NC}"
    echo ""
    return
  fi

  # Extract script names from package.json
  local available_scripts
  available_scripts=$(grep -oE '"[^"]+"\s*:' "$pkg_json" | \
    sed -n '/scripts/,/}/p' 2>/dev/null | \
    grep -oE '"[^"]+"' | sed 's/"//g' | grep -v scripts || true)

  # If no scripts section or jq not parsing well, try a simpler approach
  if [ -z "$available_scripts" ] && command -v jq &>/dev/null; then
    available_scripts=$(jq -r '.scripts // {} | keys[]' "$pkg_json" 2>/dev/null || true)
  fi

  if [ -z "$available_scripts" ]; then
    echo -e "  ${DIM}Could not parse scripts from package.json. Skipping.${NC}"
    echo ""
    return
  fi

  local missing_scripts=0
  local checked_scripts=()

  while IFS= read -r doc; do
    # Find pnpm/npm/yarn run commands in code blocks
    local commands
    commands=$(grep -oE '(pnpm|npm|yarn)( run)? [a-zA-Z0-9:_-]+' "$doc" 2>/dev/null | \
      sed -E 's/(pnpm|npm|yarn)( run)? //' | sort -u || true)

    # Also find turbo run commands
    local turbo_commands
    turbo_commands=$(grep -oE 'turbo run [a-zA-Z0-9:_-]+' "$doc" 2>/dev/null | \
      sed 's/turbo run //' | sort -u || true)

    commands=$(printf '%s\n%s' "$commands" "$turbo_commands" | sort -u | grep -v '^$' || true)

    if [ -z "$commands" ]; then
      continue
    fi

    while IFS= read -r cmd; do
      # Skip if already checked
      local already=false
      for cs in "${checked_scripts[@]+"${checked_scripts[@]}"}"; do
        if [ "$cs" = "$cmd" ]; then already=true; break; fi
      done
      if $already; then continue; fi
      checked_scripts+=("$cmd")

      # Skip generic/example commands
      if echo "$cmd" | grep -qE 'check-types|lint|test|build|dev|start'; then
        # These are common — only flag if package.json exists and lacks them
        if ! echo "$available_scripts" | grep -qx "$cmd"; then
          # In method repo, these are example commands for consuming projects
          if $IS_METHOD_REPO; then continue; fi
          echo -e "  ${YELLOW}MISSING SCRIPT${NC}  '$cmd' referenced but not in package.json"
          echo -e "    ${DIM}(found in $doc)${NC}"
          missing_scripts=$((missing_scripts + 1))
          WARN_COUNT=$((WARN_COUNT + 1))
        fi
      fi
    done <<< "$commands"
  done < <(collect_docs)

  if [ $missing_scripts -eq 0 ]; then
    echo -e "  ${GREEN}All referenced scripts found in package.json${NC}"
  fi
  echo ""
}

# --- Check 4: Cross-references between skills ---
check_skill_refs() {
  echo -e "${BOLD}== Skill Cross-References ==${NC}"
  echo ""

  if ! $IS_METHOD_REPO; then
    # In consuming projects, check .claude/skills/
    local skills_dir=".claude/skills"
    if [ ! -d "$skills_dir" ]; then
      echo -e "  ${DIM}No skills directory found. Skipping.${NC}"
      echo ""
      return
    fi
  else
    local skills_dir="skills"
  fi

  local missing_refs=0

  # Collect all skill names
  local skill_names=()
  while IFS= read -r skill_dir; do
    local name
    name=$(basename "$skill_dir")
    skill_names+=("$name")
  done < <(find "$skills_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

  # Collect files to scan — skill files AND all other docs
  local files_to_scan=()
  while IFS= read -r f; do files_to_scan+=("$f"); done < <(find "$skills_dir" -name "skill.md" 2>/dev/null)
  while IFS= read -r f; do files_to_scan+=("$f"); done < <(collect_docs)

  # Deduplicate
  local unique_files
  unique_files=$(printf '%s\n' "${files_to_scan[@]}" | sort -u)

  # Check each file for skill references
  local checked_refs=()
  while IFS= read -r scan_file; do
    # Find /skill-name references
    local refs
    refs=$(grep -oE '`/[a-z][a-z0-9-]+`' "$scan_file" 2>/dev/null | sed 's/`//g; s/^\///' | sort -u || true)

    if [ -z "$refs" ]; then continue; fi

    while IFS= read -r ref; do
      # Skip well-known non-skill references
      if echo "$ref" | grep -qE '^(g-promote|g-test|g-deploy|migrate|component|reset-user|seed-data)'; then
        continue  # Project-specific skills — not expected in method repo
      fi
      if echo "$ref" | grep -qE '^(vbw:|speckit|board|code-review|commit|simplify|skill-name)'; then
        continue  # External tools / Claude Code built-ins / generic examples
      fi
      # Skip references with arguments (e.g., /work PROJ-123, /light-spec PROJ-1)
      if echo "$ref" | grep -qE ' '; then
        continue
      fi

      # Skip if already checked this ref
      local already=false
      for cr in "${checked_refs[@]+"${checked_refs[@]}"}"; do
        if [ "$cr" = "$ref" ]; then already=true; break; fi
      done
      if $already; then continue; fi
      checked_refs+=("$ref")

      # Check if a skill directory exists for this reference
      local found=false
      for sn in "${skill_names[@]}"; do
        # Match skill name to reference (handle numbered prefixes like 01-light-spec → light-spec)
        local stripped
        stripped=$(echo "$sn" | sed 's/^[0-9]*-//')
        if [ "$ref" = "$sn" ] || [ "$ref" = "$stripped" ]; then
          found=true
          break
        fi
      done

      if ! $found; then
        echo -e "  ${YELLOW}UNRESOLVED${NC}  /$ref — referenced in $scan_file"
        missing_refs=$((missing_refs + 1))
        WARN_COUNT=$((WARN_COUNT + 1))
      fi
    done <<< "$refs"
  done <<< "$unique_files"

  if [ $missing_refs -eq 0 ]; then
    echo -e "  ${GREEN}All skill cross-references resolve${NC}"
  fi
  echo ""
}

# --- Check 5: method.config.md completeness (consuming projects only) ---
check_config() {
  if $IS_METHOD_REPO; then return; fi
  if [ ! -f "method.config.md" ]; then return; fi

  echo -e "${BOLD}== Config Completeness ==${NC}"
  echo ""

  local empty_count=0

  # Check for empty table cells (| value | `` | or | value |  |)
  local empty_cells
  empty_cells=$(grep -nE '\| \*\*[^*]+\*\* \| `?`? \|' method.config.md 2>/dev/null || true)

  if [ -n "$empty_cells" ]; then
    while IFS= read -r line; do
      echo -e "  ${YELLOW}EMPTY${NC}  $line"
      empty_count=$((empty_count + 1))
      WARN_COUNT=$((WARN_COUNT + 1))
    done <<< "$empty_cells"
  fi

  # Check Strategy Docs table — do referenced files exist?
  local strategy_files
  strategy_files=$(grep -oE '`Strategy/[^`]+`' method.config.md 2>/dev/null | sed 's/`//g' || true)

  if [ -n "$strategy_files" ]; then
    while IFS= read -r sf; do
      if [ ! -f "$sf" ]; then
        echo -e "  ${RED}MISSING${NC}  $sf — listed in config but doesn't exist"
        empty_count=$((empty_count + 1))
        DRIFT_COUNT=$((DRIFT_COUNT + 1))
      fi
    done <<< "$strategy_files"
  fi

  if [ $empty_count -eq 0 ]; then
    echo -e "  ${GREEN}Config complete — all fields populated, all referenced files exist${NC}"
  fi
  echo ""
}

# --- Main ---
echo ""
echo -e "${BOLD}=== Drift Check ===${NC}"
if $IS_METHOD_REPO; then
  echo -e "${DIM}Context: method repo${NC}"
else
  echo -e "${DIM}Context: consuming project${NC}"
fi
echo ""

$CHECK_PATHS && check_paths
$CHECK_PATHS && check_skill_refs
$CHECK_STALE && check_stale
$CHECK_SCRIPTS && check_scripts
check_config

# --- Summary ---
echo -e "${BOLD}=== Summary ===${NC}"
if [ $DRIFT_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
  echo -e "  ${GREEN}No drift detected.${NC}"
else
  [ $DRIFT_COUNT -gt 0 ] && echo -e "  ${RED}$DRIFT_COUNT errors${NC} (missing files/paths)"
  [ $WARN_COUNT -gt 0 ]  && echo -e "  ${YELLOW}$WARN_COUNT warnings${NC} (stale docs, missing scripts, unresolved refs)"
fi
echo ""

if $CI_MODE && [ $DRIFT_COUNT -gt 0 ]; then
  exit 1
fi
