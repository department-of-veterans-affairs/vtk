#!/bin/bash
#
# Shai-Hulud Repository Scanner
# =============================
#
# Scans a repository (or directory tree) for compromised npm packages
# and backdoor GitHub workflow files associated with the Shai-Hulud attack.
#
# WHAT THIS CHECKS:
#
#   Lockfiles (package-lock.json, yarn.lock, pnpm-lock.yaml):
#     - Compares installed packages against known compromised package list
#     - Supports recursive scanning for monorepos
#
#   Backdoor Workflows (.github/workflows/):
#     - discussion.yaml: Self-hosted runner with unescaped discussion body
#     - formatter_*.yml: Secrets extraction workflows
#
# EXIT CODES:
#   0 - Clean (no issues found)
#   1 - INFECTED (compromised packages found)
#   2 - WARNING (backdoor workflows found, but no compromised packages)
#
# USAGE:
#   ./shai-hulud-repo-check.sh [PATH]              # Scan directory (default: current dir)
#   ./shai-hulud-repo-check.sh -r [PATH]           # Recursive scan (default depth: 5)
#   ./shai-hulud-repo-check.sh --depth=0 [PATH]    # Recursive with unlimited depth
#   ./shai-hulud-repo-check.sh --json [PATH]       # JSON output
#   ./shai-hulud-repo-check.sh --quiet [PATH]      # Exit code only
#   ./shai-hulud-repo-check.sh --refresh [PATH]    # Force refresh package list
#
# KNOWN LIMITATIONS:
#   - pnpm-lock.yaml parsing tested with pnpm v6/v7/v9; other versions may vary
#   - Does not scan node_modules directly (lockfile is source of truth)
#   - Short flags cannot be combined (use "-r -j" not "-rj")
#
# References:
#   - https://department-of-veterans-affairs.github.io/eert/shai-hulud-dev-machine-cleanup-playbook
#
# Author: Eric Boehs / EERT (with Claude Code)
# Version: 1.0.0
# Date: December 2025
#

set -e

# Configuration
COMPROMISED_PACKAGES_URL="https://raw.githubusercontent.com/Cobenian/shai-hulud-detect/main/compromised-packages.txt"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/vtk"
CACHE_FILE="$CACHE_DIR/compromised-packages.txt"
CACHE_TTL=86400  # 24 hours
MIN_EXPECTED_PACKAGES=500
EXPECTED_HEADER="Shai-Hulud NPM Supply Chain Attack"
PLAYBOOK_URL="https://department-of-veterans-affairs.github.io/eert/shai-hulud-dev-machine-cleanup-playbook"

# Parse arguments
QUIET=false
JSON=false
RECURSIVE=false
REFRESH=false
VERBOSE=false
MAX_DEPTH=5
SCAN_PATH=""

for arg in "$@"; do
  case $arg in
    --quiet|-q) QUIET=true ;;
    --json|-j) JSON=true ;;
    --recursive|-r) RECURSIVE=true ;;
    --refresh) REFRESH=true ;;
    --verbose|-v) VERBOSE=true ;;
    --depth=*) MAX_DEPTH="${arg#*=}" ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS] [PATH]"
      echo ""
      echo "Scan a repository for compromised packages and backdoor workflows."
      echo ""
      echo "Options:"
      echo "  -h, --help       Display this help message"
      echo "  -j, --json       Output results as JSON"
      echo "  -q, --quiet      Exit code only, no output"
      echo "  -r, --recursive  Recursively scan subdirectories (default depth: 5)"
      echo "  -v, --verbose    Show each lockfile path as it's scanned"
      echo "      --depth=N    Max directory depth for recursive scan (default: 5, 0=unlimited)"
      echo "      --refresh    Force refresh of compromised packages list"
      echo ""
      echo "Arguments:"
      echo "  PATH             Directory to scan (default: current directory)"
      echo ""
      echo "Exit Codes:"
      echo "  0  Clean - no issues found"
      echo "  1  INFECTED - compromised packages found"
      echo "  2  WARNING - backdoor workflows found"
      exit 0
      ;;
    -*)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
    *)
      if [ -z "$SCAN_PATH" ]; then
        SCAN_PATH="$arg"
      fi
      ;;
  esac
done

# Default to current directory
SCAN_PATH="${SCAN_PATH:-.}"

# Resolve to absolute path
SCAN_PATH="$(cd "$SCAN_PATH" 2>/dev/null && pwd)" || {
  echo "ERROR: Directory not found: $SCAN_PATH" >&2
  exit 1
}

# Results tracking
declare -a COMPROMISED_FINDINGS=()
declare -a BACKDOOR_FINDINGS=()
declare -a WARNINGS=()
declare -a LOCKFILES_SCANNED=()  # Format: "path|package_count"
TOTAL_PACKAGES_SCANNED=0

# Colors (disabled in quiet/json mode)
if [ "$QUIET" = false ] && [ "$JSON" = false ] && [ -t 1 ]; then
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  GREEN='\033[0;32m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' YELLOW='' GREEN='' BOLD='' NC=''
fi

# Logging
log() {
  if [ "$QUIET" = false ] && [ "$JSON" = false ]; then
    echo -e "$@"
  fi
}

log_status() {
  if [ "$QUIET" = false ] && [ "$JSON" = false ]; then
    echo -e "$@" >&2
  fi
}

###########################################
# CACHE MANAGEMENT
###########################################

ensure_cache_dir() {
  mkdir -p "$CACHE_DIR"
}

cache_stale() {
  if [ ! -f "$CACHE_FILE" ]; then
    return 0  # true, cache is stale (doesn't exist)
  fi

  local file_age
  if [[ "$OSTYPE" == "darwin"* ]]; then
    file_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
  else
    file_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
  fi

  [ "$file_age" -gt "$CACHE_TTL" ]
}

validate_package_list() {
  local content="$1"

  # Check for expected header
  if ! echo "$content" | grep -q "$EXPECTED_HEADER"; then
    echo "Downloaded file missing expected header - possible MITM or corrupted file" >&2
    return 1
  fi

  # Count packages (non-comment lines with colons)
  local package_count
  package_count=$(echo "$content" | grep -v '^#' | grep -c ':' || true)

  if [ "$package_count" -lt "$MIN_EXPECTED_PACKAGES" ]; then
    echo "Downloaded file has only $package_count packages (expected $MIN_EXPECTED_PACKAGES+)" >&2
    return 1
  fi

  return 0
}

fetch_compromised_packages() {
  log_status "Fetching compromised packages list..."

  local content
  if command -v curl &>/dev/null; then
    content=$(curl -sS --fail -A "vtk-security-scanner" "$COMPROMISED_PACKAGES_URL") || {
      echo "Failed to fetch compromised packages list" >&2
      return 1
    }
  elif command -v wget &>/dev/null; then
    content=$(wget -qO- --user-agent="vtk-security-scanner" "$COMPROMISED_PACKAGES_URL") || {
      echo "Failed to fetch compromised packages list" >&2
      return 1
    }
  else
    echo "ERROR: Neither curl nor wget found" >&2
    return 1
  fi

  if ! validate_package_list "$content"; then
    return 1
  fi

  echo "$content" > "$CACHE_FILE"
  local count
  count=$(echo "$content" | grep -v '^#' | grep -c ':' || true)
  log_status "Cached $count compromised packages"
}

load_compromised_packages() {
  ensure_cache_dir

  if [ "$REFRESH" = true ] || cache_stale; then
    fetch_compromised_packages || {
      if [ ! -f "$CACHE_FILE" ]; then
        echo "ERROR: No compromised packages list available. Check your network connection." >&2
        exit 1
      fi
      log_status "WARNING: Using cached version"
    }
  fi

  if [ ! -f "$CACHE_FILE" ]; then
    echo "ERROR: No compromised packages list available." >&2
    exit 1
  fi
}

is_compromised() {
  local package="$1"
  grep -qxF "$package" "$CACHE_FILE" 2>/dev/null
}

###########################################
# LOCKFILE PARSING
###########################################

find_lockfiles() {
  local dir="$1"
  local lockfiles=()

  if [ "$RECURSIVE" = true ]; then
    local depth_arg=""
    [ "$MAX_DEPTH" -gt 0 ] && depth_arg="-maxdepth $MAX_DEPTH"
    while IFS= read -r -d '' file; do
      lockfiles+=("$file")
    done < <(find "$dir" $depth_arg -type f \( -name "package-lock.json" -o -name "yarn.lock" -o -name "pnpm-lock.yaml" \) -print0 2>/dev/null | sort -z)
  else
    for name in package-lock.json yarn.lock pnpm-lock.yaml; do
      if [ -f "$dir/$name" ]; then
        lockfiles+=("$dir/$name")
      fi
    done
  fi

  printf '%s\n' "${lockfiles[@]}"
}

# Parse package-lock.json and extract package:version pairs
parse_package_lock() {
  local file="$1"

  # Handle both v2/v3 format (packages) and v1 format (dependencies)
  # Using sed+awk for portability (no jq dependency)
  # Works with both pretty-printed and minified JSON

  # v2/v3: Extract from "packages" section
  # Preprocess: add newlines before each "node_modules/ to handle minified JSON
  # Then use awk to match package name and version across lines
  sed 's/"node_modules\//\n"node_modules\//g' "$file" 2>/dev/null | \
  awk '
    /"node_modules\/[^"]+":/ {
      # Extract package name: remove everything before "node_modules/ and after closing "
      pkg = $0
      sub(/.*"node_modules\//, "", pkg)
      sub(/".*/, "", pkg)
    }
    /"version":/ && pkg != "" {
      # Extract version: find "version": "X.Y.Z" pattern
      ver = $0
      sub(/.*"version": *"/, "", ver)
      sub(/".*/, "", ver)
      if (ver != "") {
        print pkg ":" ver
        pkg = ""
      }
    }
  ' 2>/dev/null || true

  # v1: Extract from "dependencies" section (top-level deps without node_modules path)
  # Preprocess: add newlines before each opening brace to separate entries
  sed 's/": *{/": {\n/g' "$file" 2>/dev/null | \
  awk '
    /"[^"]+": *\{/ && !/node_modules/ && !/packages/ {
      # Potential package name line - extract the key
      pkg = $0
      sub(/.*"/, "", pkg)
      sub(/":.*/, "", pkg)
      # Skip metadata keys
      if (pkg ~ /^(name|lockfileVersion|requires|dependencies|devDependencies|optionalDependencies)$/) {
        pkg = ""
      }
    }
    /"version":/ && pkg != "" {
      ver = $0
      sub(/.*"version": *"/, "", ver)
      sub(/".*/, "", ver)
      # Only accept semver-like versions
      if (ver ~ /^[0-9]+\.[0-9]+\.[0-9]/) {
        print pkg ":" ver
        pkg = ""
      }
    }
    # Reset pkg when we exit a block
    /^\s*\}/ { pkg = "" }
  ' 2>/dev/null || true
}

# Parse yarn.lock and extract package:version pairs
parse_yarn_lock() {
  local file="$1"

  # yarn.lock format:
  # "package@^1.0.0":
  #   version "1.2.3"
  awk '
    /^"?[^#@][^"]*@/ || /^"?@/ {
      # Extract package name (before the @version specifier)
      # Save original line to check for scoped packages
      original = $0
      gsub(/^"/, "", $0)
      gsub(/".*/, "", $0)
      split($0, parts, "@")
      if (original ~ /^"?@/ || parts[1] == "") {
        # Scoped package: @scope/name (parts[1] is empty when line starts with @)
        pkg = "@" parts[2]
      } else {
        pkg = parts[1]
      }
    }
    /^  version / {
      gsub(/^  version "?/, "", $0)
      gsub(/".*/, "", $0)
      if (pkg != "") {
        print pkg ":" $0
        pkg = ""
      }
    }
  ' "$file" 2>/dev/null | sort -u || true
}

# Parse pnpm-lock.yaml and extract package:version pairs
parse_pnpm_lock() {
  local file="$1"

  # pnpm-lock.yaml format (in packages section):
  # /@scope/pkg@1.2.3:
  # /pkg@1.2.3:
  grep -E "^  '?/?@?[^:]+@[0-9]" "$file" 2>/dev/null | \
    sed -E "s/^  '?\/?(@?[^@:]+)@([^:']+).*/\1:\2/" || true
}

parse_lockfile() {
  local file="$1"
  local basename
  basename=$(basename "$file")

  case "$basename" in
    package-lock.json)
      parse_package_lock "$file"
      ;;
    yarn.lock)
      parse_yarn_lock "$file"
      ;;
    pnpm-lock.yaml)
      parse_pnpm_lock "$file"
      ;;
  esac
}

output_lockfile_jsonl() {
  local lockfile="$1"
  local pkg_scanned="$2"
  shift 2
  local compromised=("$@")

  # Build compromised array JSON
  local compromised_json="["
  local first=true
  for pkg in "${compromised[@]}"; do
    if [ "$first" = true ]; then
      first=false
    else
      compromised_json+=","
    fi
    pkg="${pkg//\\/\\\\}"
    pkg="${pkg//\"/\\\"}"
    compromised_json+="\"$pkg\""
  done
  compromised_json+="]"

  # Determine status
  local status="CLEAN"
  if [ ${#compromised[@]} -gt 0 ]; then
    status="INFECTED"
  fi

  # Escape path for JSON
  local path_escaped="${lockfile//\\/\\\\}"
  path_escaped="${path_escaped//\"/\\\"}"

  echo "{\"lockfile\":\"$path_escaped\",\"packages_scanned\":$pkg_scanned,\"status\":\"$status\",\"compromised_packages\":$compromised_json}"
}

check_lockfiles() {
  local lockfiles
  lockfiles=$(find_lockfiles "$SCAN_PATH")

  if [ -z "$lockfiles" ]; then
    WARNINGS+=("No lockfiles found (package-lock.json, yarn.lock, or pnpm-lock.yaml)")
    return
  fi

  # Count total for progress display
  local total count=0
  total=$(echo "$lockfiles" | wc -l | tr -d ' ')

  # Check if we should show inline progress (not in JSON, quiet, or verbose mode)
  local show_progress=false
  if [ "$QUIET" = false ] && [ "$JSON" = false ] && [ "$VERBOSE" = false ] && [ -t 2 ]; then
    show_progress=true
  fi

  while IFS= read -r lockfile; do
    [ -z "$lockfile" ] && continue
    count=$((count + 1))

    # Get relative path for cleaner display
    local rel_path="${lockfile#$SCAN_PATH/}"

    # Show progress (file name first, then update with package count)
    # Note: verbose is ignored in JSON mode
    if [ "$VERBOSE" = true ] && [ "$JSON" = false ]; then
      log_status "[$count/$total] $lockfile"
    elif [ "$show_progress" = true ] && [ "$RECURSIVE" = true ]; then
      printf "\r\033[K[%d/%d] %s" "$count" "$total" "$rel_path" >&2
    elif [ "$show_progress" = true ]; then
      # Non-recursive: show scanning status
      printf "\r\033[KScanning %s..." "$rel_path" >&2
    fi

    local packages
    packages=$(parse_lockfile "$lockfile" | sort -u)
    local pkg_count=0
    if [ -n "$packages" ]; then
      pkg_count=$(echo "$packages" | wc -l | tr -d ' ')
    fi

    # Update progress with package count (will be overwritten by scanning progress)
    if [ "$VERBOSE" = true ] && [ "$JSON" = false ] && [ -t 2 ]; then
      printf "        └─ 0/%d packages..." "$pkg_count" >&2
    elif [ "$show_progress" = true ] && [ "$RECURSIVE" = true ]; then
      printf "\r\033[K[%d/%d] %s (0/%d packages)" "$count" "$total" "$rel_path" "$pkg_count" >&2
    elif [ "$show_progress" = true ]; then
      # Non-recursive: show package count
      printf "\r\033[KScanning %s (0/%d packages)..." "$rel_path" "$pkg_count" >&2
    fi

    # Track compromised packages for this lockfile (for JSONL output)
    local lockfile_compromised=()

    local pkg_scanned=0
    while IFS= read -r pkg; do
      [ -z "$pkg" ] && continue
      pkg_scanned=$((pkg_scanned + 1))

      # Show package scanning progress every 100 packages
      if [ $((pkg_scanned % 100)) -eq 0 ]; then
        if [ "$VERBOSE" = true ] && [ "$JSON" = false ] && [ -t 2 ]; then
          printf "\r\033[K        └─ %d/%d packages..." "$pkg_scanned" "$pkg_count" >&2
        elif [ "$show_progress" = true ]; then
          if [ "$RECURSIVE" = true ]; then
            printf "\r\033[K[%d/%d] %s (%d/%d packages)" "$count" "$total" "$rel_path" "$pkg_scanned" "$pkg_count" >&2
          else
            printf "\r\033[KScanning %s (%d/%d packages)..." "$rel_path" "$pkg_scanned" "$pkg_count" >&2
          fi
        fi
      fi

      if is_compromised "$pkg"; then
        COMPROMISED_FINDINGS+=("$pkg|$lockfile")
        lockfile_compromised+=("$pkg")
      fi
    done <<< "$packages"

    # Track total packages scanned
    TOTAL_PACKAGES_SCANNED=$((TOTAL_PACKAGES_SCANNED + pkg_scanned))

    # Track this lockfile for JSON output (non-recursive)
    LOCKFILES_SCANNED+=("$lockfile|$pkg_scanned")

    # Output JSONL for recursive JSON mode
    if [ "$JSON" = true ] && [ "$RECURSIVE" = true ]; then
      output_lockfile_jsonl "$lockfile" "$pkg_scanned" "${lockfile_compromised[@]}"
    fi

    # Show final count for this lockfile
    if [ "$VERBOSE" = true ] && [ "$JSON" = false ] && [ -t 2 ]; then
      # Clear progress line and show final count on new line
      printf "\r\033[K        └─ %d packages\n" "$pkg_count" >&2
    elif [ "$show_progress" = true ] && [ "$pkg_count" -gt 0 ]; then
      if [ "$RECURSIVE" = true ]; then
        printf "\r\033[K[%d/%d] %s (%d/%d packages)" "$count" "$total" "$rel_path" "$pkg_count" "$pkg_count" >&2
      else
        printf "\r\033[KScanning %s (%d/%d packages)..." "$rel_path" "$pkg_count" "$pkg_count" >&2
      fi
    fi
  done <<< "$lockfiles"

  # Clear progress line
  if [ "$show_progress" = true ] && [ "$VERBOSE" = false ]; then
    if [ "$RECURSIVE" = true ]; then
      printf "\r\033[KScanned %d lockfiles (%d packages).\n" "$total" "$TOTAL_PACKAGES_SCANNED" >&2
    else
      printf "\r\033[KScanned %d packages.\n" "$TOTAL_PACKAGES_SCANNED" >&2
    fi
  fi
}

###########################################
# BACKDOOR WORKFLOW DETECTION
###########################################

find_workflow_dirs() {
  if [ "$RECURSIVE" = true ]; then
    local depth_arg=""
    [ "$MAX_DEPTH" -gt 0 ] && depth_arg="-maxdepth $MAX_DEPTH"
    find "$SCAN_PATH" $depth_arg -type d -path "*/.github/workflows" 2>/dev/null
  else
    local dir="$SCAN_PATH/.github/workflows"
    if [ -d "$dir" ]; then
      echo "$dir"
    fi
  fi
}

check_discussion_backdoor() {
  local workflows_dir="$1"

  for filename in discussion.yaml discussion.yml; do
    local workflow_path="$workflows_dir/$filename"
    [ -f "$workflow_path" ] || continue

    local content
    content=$(cat "$workflow_path")

    # Check for malicious pattern: discussion trigger + self-hosted + unescaped body
    if echo "$content" | grep -q "discussion" && \
       echo "$content" | grep -q "self-hosted" && \
       echo "$content" | grep -qE '\$\{\{\s*github\.event\.discussion\.body\s*\}\}'; then
      BACKDOOR_FINDINGS+=("$workflow_path|discussion_backdoor")
    fi
  done
}

check_formatter_backdoor() {
  local workflows_dir="$1"

  # Match timestamp-based formatter files (formatter_ + digits) per Wiz report
  # This reduces false positives on legitimate files like formatter_config.yml
  for workflow in "$workflows_dir"/formatter_[0-9]*.yml; do
    [ -f "$workflow" ] || continue
    BACKDOOR_FINDINGS+=("$workflow|secrets_extraction")
  done
}

check_backdoor_workflows() {
  local workflow_dirs
  workflow_dirs=$(find_workflow_dirs)

  while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    check_discussion_backdoor "$dir"
    check_formatter_backdoor "$dir"
  done <<< "$workflow_dirs"
}

###########################################
# OUTPUT
###########################################

report_text() {
  log ""

  # Report compromised packages
  if [ ${#COMPROMISED_FINDINGS[@]} -gt 0 ]; then
    log "${RED}🚨 COMPROMISED PACKAGES FOUND:${NC}"
    for finding in "${COMPROMISED_FINDINGS[@]}"; do
      local pkg="${finding%%|*}"
      local lockfile="${finding#*|}"
      log "   $pkg"
      log "   └─ in $lockfile"
    done
    log ""
  fi

  # Report backdoors
  if [ ${#BACKDOOR_FINDINGS[@]} -gt 0 ]; then
    log "${RED}🚨 BACKDOOR WORKFLOWS FOUND:${NC}"
    for finding in "${BACKDOOR_FINDINGS[@]}"; do
      local file="${finding%%|*}"
      local type="${finding#*|}"
      log "   $file"
      log "   └─ Type: $type"
    done
    log ""
  fi

  # Report warnings (only if no critical findings)
  if [ ${#COMPROMISED_FINDINGS[@]} -eq 0 ] && [ ${#BACKDOOR_FINDINGS[@]} -eq 0 ] && [ ${#WARNINGS[@]} -gt 0 ]; then
    for warning in "${WARNINGS[@]}"; do
      log "${YELLOW}⚠️  $warning${NC}"
    done
    log ""
  fi

  # Status
  local status
  if [ ${#COMPROMISED_FINDINGS[@]} -gt 0 ]; then
    status="${RED}INFECTED - Compromised packages found${NC}"
  elif [ ${#BACKDOOR_FINDINGS[@]} -gt 0 ]; then
    status="${YELLOW}WARNING - Backdoor workflows found${NC}"
  else
    status="${GREEN}CLEAN${NC}"
  fi

  log "Status: $status"

  if [ ${#COMPROMISED_FINDINGS[@]} -gt 0 ] || [ ${#BACKDOOR_FINDINGS[@]} -gt 0 ]; then
    log ""
    log "See cleanup playbook:"
    log "  $PLAYBOOK_URL"
  fi
}

report_json() {
  # Build lockfiles_scanned JSON array
  local lockfiles_json="["
  local first=true
  for entry in "${LOCKFILES_SCANNED[@]}"; do
    local lockfile="${entry%%|*}"
    local pkg_count="${entry#*|}"
    if [ "$first" = true ]; then
      first=false
    else
      lockfiles_json+=","
    fi
    # Escape for JSON
    lockfile="${lockfile//\\/\\\\}"
    lockfile="${lockfile//\"/\\\"}"
    lockfiles_json+="{\"path\":\"$lockfile\",\"packages_scanned\":$pkg_count}"
  done
  lockfiles_json+="]"

  # Build compromised_packages JSON array
  local compromised_json="["
  first=true
  for finding in "${COMPROMISED_FINDINGS[@]}"; do
    local pkg="${finding%%|*}"
    local lockfile="${finding#*|}"
    if [ "$first" = true ]; then
      first=false
    else
      compromised_json+=","
    fi
    # Escape for JSON
    pkg="${pkg//\\/\\\\}"
    pkg="${pkg//\"/\\\"}"
    lockfile="${lockfile//\\/\\\\}"
    lockfile="${lockfile//\"/\\\"}"
    compromised_json+="{\"package\":\"$pkg\",\"lockfile\":\"$lockfile\"}"
  done
  compromised_json+="]"

  local backdoors_json="["
  first=true
  for finding in "${BACKDOOR_FINDINGS[@]}"; do
    local file="${finding%%|*}"
    local type="${finding#*|}"
    if [ "$first" = true ]; then
      first=false
    else
      backdoors_json+=","
    fi
    file="${file//\\/\\\\}"
    file="${file//\"/\\\"}"
    backdoors_json+="{\"file\":\"$file\",\"type\":\"$type\"}"
  done
  backdoors_json+="]"

  local warnings_json="["
  first=true
  for warning in "${WARNINGS[@]}"; do
    if [ "$first" = true ]; then
      first=false
    else
      warnings_json+=","
    fi
    warning="${warning//\\/\\\\}"
    warning="${warning//\"/\\\"}"
    warnings_json+="\"$warning\""
  done
  warnings_json+="]"

  local status
  if [ ${#COMPROMISED_FINDINGS[@]} -gt 0 ]; then
    status="INFECTED - Compromised packages found"
  elif [ ${#BACKDOOR_FINDINGS[@]} -gt 0 ]; then
    status="WARNING - Backdoor workflows found"
  else
    status="CLEAN"
  fi

  # Escape path for JSON
  local path_escaped="${SCAN_PATH//\\/\\\\}"
  path_escaped="${path_escaped//\"/\\\"}"

  cat <<EOF
{
  "path": "$path_escaped",
  "status": "$status",
  "packages_scanned": $TOTAL_PACKAGES_SCANNED,
  "lockfiles_scanned": $lockfiles_json,
  "compromised_packages": $compromised_json,
  "backdoors": $backdoors_json,
  "warnings": $warnings_json
}
EOF
}

###########################################
# MAIN
###########################################

output_jsonl_summary() {
  # Build backdoors JSON array
  local backdoors_json="["
  local first=true
  for finding in "${BACKDOOR_FINDINGS[@]}"; do
    local file="${finding%%|*}"
    local type="${finding#*|}"
    if [ "$first" = true ]; then
      first=false
    else
      backdoors_json+=","
    fi
    file="${file//\\/\\\\}"
    file="${file//\"/\\\"}"
    backdoors_json+="{\"file\":\"$file\",\"type\":\"$type\"}"
  done
  backdoors_json+="]"

  # Build warnings JSON array
  local warnings_json="["
  first=true
  for warning in "${WARNINGS[@]}"; do
    if [ "$first" = true ]; then
      first=false
    else
      warnings_json+=","
    fi
    warning="${warning//\\/\\\\}"
    warning="${warning//\"/\\\"}"
    warnings_json+="\"$warning\""
  done
  warnings_json+="]"

  local status
  if [ ${#COMPROMISED_FINDINGS[@]} -gt 0 ]; then
    status="INFECTED"
  elif [ ${#BACKDOOR_FINDINGS[@]} -gt 0 ]; then
    status="WARNING"
  else
    status="CLEAN"
  fi

  local path_escaped="${SCAN_PATH//\\/\\\\}"
  path_escaped="${path_escaped//\"/\\\"}"

  echo "{\"type\":\"summary\",\"path\":\"$path_escaped\",\"status\":\"$status\",\"total_packages_scanned\":$TOTAL_PACKAGES_SCANNED,\"total_lockfiles\":${#LOCKFILES_SCANNED[@]},\"total_compromised\":${#COMPROMISED_FINDINGS[@]},\"backdoors\":$backdoors_json,\"warnings\":$warnings_json}"
}

main() {
  # Show scan info up front
  if [ "$QUIET" = false ] && [ "$JSON" = false ]; then
    if [ "$RECURSIVE" = true ]; then
      if [ "$MAX_DEPTH" -eq 0 ]; then
        log "Scanning: $SCAN_PATH (recursive, unlimited depth)"
      else
        log "Scanning: $SCAN_PATH (recursive, max depth: $MAX_DEPTH)"
      fi
    else
      log "Scanning: $SCAN_PATH"
    fi
  fi

  # Load compromised packages list
  load_compromised_packages

  # Run checks
  check_lockfiles
  check_backdoor_workflows

  # Output results
  if [ "$QUIET" = false ]; then
    if [ "$JSON" = true ]; then
      if [ "$RECURSIVE" = true ]; then
        # JSONL mode: lockfiles already output, just add summary
        output_jsonl_summary
      else
        report_json
      fi
    else
      report_text
    fi
  fi

  # Exit code
  if [ ${#COMPROMISED_FINDINGS[@]} -gt 0 ]; then
    exit 1
  elif [ ${#BACKDOOR_FINDINGS[@]} -gt 0 ]; then
    exit 2
  else
    exit 0
  fi
}

main
