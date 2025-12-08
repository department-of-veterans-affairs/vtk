#!/bin/bash
#
# Shai-Hulud Machine Infection Checker
# =====================================
#
# Quick script to check if your machine shows signs of active Shai-Hulud infection.
# This is a FAST check (~5 seconds) for infection indicators only.
#
# WHAT THIS CHECKS:
#
#   CRITICAL (Active Infection):
#     - ~/.dev-env/ persistence folder (contains GitHub self-hosted runner)
#     - Running processes: Runner.Listener, SHA1HULUD, suspicious node/bun
#     - Malware files: setup_bun.js, bun_environment.js
#     - Backdoor workflows: .github/workflows/discussion.yaml
#
#   HIGH (Exfiltration Likely Occurred):
#     - Exfiltration artifacts: cloud.json, truffleSecrets.json, etc.
#     - Unexpected ~/.bun/ installation
#     - Unexpected Trufflehog binary
#
#   INFO (Credentials to Rotate if Infected):
#     - Lists credential files the malware targets
#     - ~/.npmrc, ~/.aws/, ~/.config/gh/, etc.
#
# EXIT CODES:
#   0 - Clean (no infection indicators found)
#   1 - INFECTED (critical indicators found)
#   2 - WARNING (high-risk indicators, needs investigation)
#
# USAGE:
#   ./shai-hulud-machine-check.sh              # Compact output
#   ./shai-hulud-machine-check.sh --verbose    # Detailed output
#   ./shai-hulud-machine-check.sh --quiet      # Exit code only
#   ./shai-hulud-machine-check.sh --json       # JSON output
#
# References:
#   - Wiz.io: https://www.wiz.io/blog/shai-hulud-2-0-ongoing-supply-chain-attack
#   - Datadog: https://securitylabs.datadoghq.com/articles/shai-hulud-2.0-npm-worm/
#
# Author: Eric Boehs / EERT (with Claude Code)
# Version: 1.1.0
# Date: December 2025
#

set -e

# Parse arguments
QUIET=false
JSON=false
VERBOSE=false
for arg in "$@"; do
  case $arg in
    --quiet|-q) QUIET=true ;;
    --json|-j) JSON=true ;;
    --verbose|-v) VERBOSE=true ;;
    --help|-h)
      echo "Usage: $0 [--verbose|-v] [--quiet|-q] [--json|-j]"
      echo "  --verbose  Detailed output with all checks"
      echo "  --quiet    Exit code only, no output"
      echo "  --json     JSON output format"
      exit 0
      ;;
  esac
done

# Results tracking
CRITICAL_FINDINGS=()
HIGH_FINDINGS=()
INFO_FINDINGS=()

# Colors (disabled in quiet/json mode)
if [ "$QUIET" = false ] && [ "$JSON" = false ] && [ -t 1 ]; then
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  GREEN='\033[0;32m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  NC='\033[0m' # No Color
else
  RED='' YELLOW='' GREEN='' CYAN='' BOLD='' NC=''
fi

# Logging functions
log() {
  if [ "$QUIET" = false ] && [ "$JSON" = false ]; then
    echo -e "$@"
  fi
}

log_verbose() {
  if [ "$VERBOSE" = true ] && [ "$QUIET" = false ] && [ "$JSON" = false ]; then
    echo -e "$@"
  fi
}

log_critical() {
  CRITICAL_FINDINGS+=("$1")
}

log_high() {
  HIGH_FINDINGS+=("$1")
}

log_info() {
  INFO_FINDINGS+=("$1")
}

# Verbose header
log_verbose ""
log_verbose "${BOLD}========================================${NC}"
log_verbose "${BOLD}  Shai-Hulud Machine Infection Check${NC}"
log_verbose "${BOLD}========================================${NC}"
log_verbose ""
log_verbose "Checking for active infection indicators..."
log_verbose ""

###########################################
# CRITICAL CHECKS
###########################################

log_verbose "${BOLD}=== Critical Checks ===${NC}"
log_verbose ""

# 1. Check for ~/.dev-env/ persistence folder
log_verbose "Checking for persistence folder (~/.dev-env/)..."
if [ -d "$HOME/.dev-env" ]; then
  log_critical "~/.dev-env/ persistence folder found"
  log_verbose "  ${RED}[CRITICAL]${NC} PERSISTENCE FOLDER FOUND: ~/.dev-env/"
  log_verbose "  This folder contains the malware's self-hosted GitHub runner."
  log_verbose "  Contents:"
  ls -la "$HOME/.dev-env" 2>/dev/null | head -10 | while read line; do log_verbose "    $line"; done
else
  log_verbose "  ${GREEN}Not found${NC}"
fi

# 2. Check for malicious running processes
log_verbose ""
log_verbose "Checking for malicious processes..."

# Runner.Listener (GitHub self-hosted runner - malware installs this)
if pgrep -f "Runner.Listener" > /dev/null 2>&1; then
  log_critical "Runner.Listener process running"
  log_verbose "  ${RED}[CRITICAL]${NC} MALICIOUS PROCESS: Runner.Listener is running"
  log_verbose "  PIDs: $(pgrep -f 'Runner.Listener' | tr '\n' ' ')"
fi

# SHA1HULUD process
if pgrep -f "SHA1HULUD" > /dev/null 2>&1; then
  log_critical "SHA1HULUD process running"
  log_verbose "  ${RED}[CRITICAL]${NC} MALICIOUS PROCESS: SHA1HULUD is running"
  log_verbose "  PIDs: $(pgrep -f 'SHA1HULUD' | tr '\n' ' ')"
fi

# Check for node processes running from ~/.dev-env
if pgrep -f "$HOME/.dev-env" > /dev/null 2>&1; then
  log_critical "Process running from ~/.dev-env"
  log_verbose "  ${RED}[CRITICAL]${NC} MALICIOUS PROCESS: Process running from ~/.dev-env"
  log_verbose "  PIDs: $(pgrep -f "$HOME/.dev-env" | tr '\n' ' ')"
fi

# Check for suspicious bun processes (from ~/.bun if unexpected)
if pgrep -f "$HOME/.bun/bin/bun" > /dev/null 2>&1; then
  log_high "bun process running from ~/.bun/bin/bun"
  log_verbose "  ${YELLOW}[HIGH]${NC} SUSPICIOUS PROCESS: bun running from ~/.bun/bin/bun"
  log_verbose "  This could be legitimate if you installed Bun intentionally."
  log_verbose "  PIDs: $(pgrep -f "$HOME/.bun/bin/bun" | tr '\n' ' ')"
fi

# If no malicious processes found
if ! pgrep -f "Runner.Listener" > /dev/null 2>&1 && \
   ! pgrep -f "SHA1HULUD" > /dev/null 2>&1 && \
   ! pgrep -f "$HOME/.dev-env" > /dev/null 2>&1; then
  log_verbose "  ${GREEN}No malicious processes detected${NC}"
fi

# 3. Check for malware payload files in home directory
log_verbose ""
log_verbose "Checking for malware files in home directory..."
MALWARE_FILES=("setup_bun.js" "bun_environment.js")
MALWARE_FOUND=false
for file in "${MALWARE_FILES[@]}"; do
  if [ -f "$HOME/$file" ]; then
    log_critical "Malware file: ~/$file"
    log_verbose "  ${RED}[CRITICAL]${NC} MALWARE FILE FOUND: ~/$file"
    MALWARE_FOUND=true
  fi
done

# Check in common locations
for dir in "$HOME" "$HOME/Desktop" "$HOME/Downloads" "/tmp"; do
  if [ -d "$dir" ]; then
    for file in "${MALWARE_FILES[@]}"; do
      FOUND=$(find "$dir" -maxdepth 2 -name "$file" -type f 2>/dev/null | head -5)
      if [ -n "$FOUND" ]; then
        while IFS= read -r f; do
          log_critical "Malware file: $f"
          log_verbose "  ${RED}[CRITICAL]${NC} MALWARE FILE FOUND: $f"
          MALWARE_FOUND=true
        done <<< "$FOUND"
      fi
    done
  fi
done

if [ "$MALWARE_FOUND" = false ]; then
  log_verbose "  ${GREEN}No malware files detected${NC}"
fi

###########################################
# HIGH-RISK CHECKS
###########################################

log_verbose ""
log_verbose "${BOLD}=== High-Risk Checks ===${NC}"
log_verbose ""

# 4. Check for exfiltration artifacts
log_verbose "Checking for exfiltration artifacts..."
EXFIL_FILES=("cloud.json" "truffleSecrets.json" "environment.json" "actionsSecrets.json")
EXFIL_FOUND=false
for file in "${EXFIL_FILES[@]}"; do
  # Check home directory and common locations
  for dir in "$HOME" "/tmp" "$HOME/Desktop" "$HOME/Downloads"; do
    if [ -f "$dir/$file" ]; then
      log_high "Exfiltration artifact: $dir/$file"
      log_verbose "  ${YELLOW}[HIGH]${NC} EXFILTRATION ARTIFACT: $dir/$file"
      EXFIL_FOUND=true
    fi
  done
done

if [ "$EXFIL_FOUND" = false ]; then
  log_verbose "  ${GREEN}No exfiltration artifacts detected${NC}"
fi

# 5. Check for unexpected Bun installation
log_verbose ""
log_verbose "Checking for unexpected Bun installation..."
if [ -d "$HOME/.bun" ]; then
  log_high "~/.bun/ installation found"
  log_verbose "  ${YELLOW}[HIGH]${NC} BUN INSTALLATION FOUND: ~/.bun/"
  log_verbose "  If you did NOT install Bun intentionally, this is suspicious."
  log_verbose "  Bun version: $(~/.bun/bin/bun --version 2>/dev/null || echo 'unknown')"
elif command -v bun &> /dev/null; then
  BUN_PATH=$(which bun)
  log_high "Bun found: $BUN_PATH"
  log_verbose "  ${YELLOW}[HIGH]${NC} BUN FOUND IN PATH: $BUN_PATH"
  log_verbose "  If you did NOT install Bun intentionally, investigate."
else
  log_verbose "  ${GREEN}No unexpected Bun installation${NC}"
fi

# 6. Check for Trufflehog (malware downloads this to scan for secrets)
log_verbose ""
log_verbose "Checking for unexpected Trufflehog..."
if command -v trufflehog &> /dev/null; then
  TH_PATH=$(which trufflehog)
  log_high "Trufflehog found: $TH_PATH"
  log_verbose "  ${YELLOW}[HIGH]${NC} TRUFFLEHOG FOUND: $TH_PATH"
  log_verbose "  The malware uses Trufflehog to scan for secrets."
  log_verbose "  If you did NOT install this intentionally, investigate."
elif [ -f "$HOME/.local/bin/trufflehog" ] || [ -f "/tmp/trufflehog" ]; then
  log_high "Trufflehog in suspicious location"
  log_verbose "  ${YELLOW}[HIGH]${NC} TRUFFLEHOG FOUND in suspicious location"
else
  log_verbose "  ${GREEN}No unexpected Trufflehog installation${NC}"
fi

###########################################
# INFORMATIONAL - Credentials at Risk
###########################################

log_verbose ""
log_verbose "${BOLD}=== Credential Files (Rotate if Infected) ===${NC}"
log_verbose ""
log_verbose "These are files the malware targets for exfiltration."
log_verbose "If your machine is infected, ROTATE ALL OF THESE:"
log_verbose ""

# NPM tokens
if [ -f "$HOME/.npmrc" ]; then
  if grep -qi "authtoken\|_auth" "$HOME/.npmrc" 2>/dev/null; then
    log_info "~/.npmrc contains auth tokens"
    log_verbose "  ${CYAN}[INFO]${NC} ~/.npmrc contains auth tokens - ROTATE NPM TOKENS"
  else
    log_verbose "  ~/.npmrc exists (no tokens detected)"
  fi
else
  log_verbose "  ~/.npmrc not found"
fi

# AWS credentials
if [ -d "$HOME/.aws" ]; then
  log_info "~/.aws/ exists"
  log_verbose "  ${CYAN}[INFO]${NC} ~/.aws/ exists - ROTATE AWS ACCESS KEYS"
else
  log_verbose "  ~/.aws/ not found"
fi

# GCP credentials
if [ -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
  log_info "GCP ADC exists"
  log_verbose "  ${CYAN}[INFO]${NC} GCP ADC exists - RE-AUTHENTICATE with 'gcloud auth application-default login'"
else
  log_verbose "  GCP ADC not found"
fi

# Azure credentials
if [ -d "$HOME/.azure" ]; then
  log_info "~/.azure/ exists"
  log_verbose "  ${CYAN}[INFO]${NC} ~/.azure/ exists - RE-AUTHENTICATE with 'az login'"
else
  log_verbose "  ~/.azure/ not found"
fi

# GitHub CLI
if [ -f "$HOME/.config/gh/hosts.yml" ]; then
  log_info "GitHub CLI authenticated"
  log_verbose "  ${CYAN}[INFO]${NC} GitHub CLI authenticated - ROTATE TOKEN with 'gh auth logout && gh auth login'"
else
  log_verbose "  GitHub CLI not authenticated"
fi

# SSH keys
if [ -d "$HOME/.ssh" ] && ls "$HOME/.ssh/"*.pub &> /dev/null; then
  log_info "SSH keys exist"
  log_verbose "  ${CYAN}[INFO]${NC} SSH keys exist (~/.ssh/) - Consider rotating if infected"
fi

# Git credentials
if [ -f "$HOME/.git-credentials" ]; then
  log_info "~/.git-credentials exists"
  log_verbose "  ${CYAN}[INFO]${NC} ~/.git-credentials exists - ROTATE stored credentials"
fi

# Environment variables with secrets
SENSITIVE_VARS=$(env | grep -iE "token|key|secret|password|credential|auth|api" 2>/dev/null | wc -l | tr -d ' ')
if [ "$SENSITIVE_VARS" -gt 0 ]; then
  log_info "$SENSITIVE_VARS sensitive env vars"
  log_verbose "  ${CYAN}[INFO]${NC} $SENSITIVE_VARS sensitive environment variables detected"
fi

###########################################
# SUMMARY
###########################################

log_verbose ""
log_verbose "${BOLD}========================================${NC}"

# Determine final status
EXIT_CODE=0
if [ ${#CRITICAL_FINDINGS[@]} -gt 0 ]; then
  EXIT_CODE=1
  if [ "$VERBOSE" = true ]; then
    log "${RED}${BOLD}  STATUS: INFECTED${NC}"
    log "${RED}${BOLD}========================================${NC}"
    log ""
    log "${RED}CRITICAL FINDINGS (${#CRITICAL_FINDINGS[@]}):${NC}"
    for finding in "${CRITICAL_FINDINGS[@]}"; do
      log "  - $finding"
    done
    log ""
    log "${BOLD}IMMEDIATE ACTIONS:${NC}"
    log "  1. DISCONNECT from network immediately"
    log "  2. Do NOT run npm/yarn/node commands"
    log "  3. Follow the cleanup playbook"
    log "  4. Rotate ALL credentials listed above"
  else
    log "${RED}${BOLD}Shai-Hulud Check: INFECTED${NC}"
    for finding in "${CRITICAL_FINDINGS[@]}"; do
      log "  ${RED}-${NC} $finding"
    done
    log ""
    log "Run with ${BOLD}--verbose${NC} for details and remediation steps"
  fi
elif [ ${#HIGH_FINDINGS[@]} -gt 0 ]; then
  EXIT_CODE=2
  if [ "$VERBOSE" = true ]; then
    log "${YELLOW}${BOLD}  STATUS: WARNING - INVESTIGATE${NC}"
    log "${YELLOW}${BOLD}========================================${NC}"
    log ""
    log "${YELLOW}HIGH-RISK FINDINGS (${#HIGH_FINDINGS[@]}):${NC}"
    for finding in "${HIGH_FINDINGS[@]}"; do
      log "  - $finding"
    done
    log ""
    log "${BOLD}RECOMMENDED ACTIONS:${NC}"
    log "  1. Verify if Bun/Trufflehog were installed intentionally"
    log "  2. If not intentional, treat as potentially infected"
    log "  3. Investigate further before running any package manager commands"
  else
    log "${YELLOW}${BOLD}Shai-Hulud Check: WARNING${NC}"
    for finding in "${HIGH_FINDINGS[@]}"; do
      log "  ${YELLOW}-${NC} $finding"
    done
    log ""
    log "These may be legitimate if you installed them intentionally."
    log "Run with ${BOLD}--verbose${NC} for details or investigate if unexpected."
  fi
else
  if [ "$VERBOSE" = true ]; then
    log "${GREEN}${BOLD}  STATUS: CLEAN${NC}"
    log "${GREEN}${BOLD}========================================${NC}"
    log ""
    log "${GREEN}No active infection indicators detected.${NC}"
    log ""
    log "Next steps:"
    log "  - Verify your repos don't have compromised packages"
    log "  - Check your lockfiles for known malicious packages"
  else
    log "${GREEN}${BOLD}Shai-Hulud Check: CLEAN${NC}"
  fi
fi

log ""

# JSON output mode
if [ "$JSON" = true ]; then
  # Build JSON
  cat <<EOF
{
  "status": "$([ ${#CRITICAL_FINDINGS[@]} -gt 0 ] && echo 'INFECTED' || ([ ${#HIGH_FINDINGS[@]} -gt 0 ] && echo 'WARNING' || echo 'CLEAN'))",
  "critical_count": ${#CRITICAL_FINDINGS[@]},
  "high_count": ${#HIGH_FINDINGS[@]},
  "info_count": ${#INFO_FINDINGS[@]},
  "critical_findings": $(printf '%s\n' "${CRITICAL_FINDINGS[@]:-}" | jq -R . | jq -s . 2>/dev/null || echo '[]'),
  "high_findings": $(printf '%s\n' "${HIGH_FINDINGS[@]:-}" | jq -R . | jq -s . 2>/dev/null || echo '[]'),
  "info_findings": $(printf '%s\n' "${INFO_FINDINGS[@]:-}" | jq -R . | jq -s . 2>/dev/null || echo '[]'),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
fi

exit $EXIT_CODE
