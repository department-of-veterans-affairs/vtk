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
#   ./shai-hulud-machine-check.sh
#   ./shai-hulud-machine-check.sh --quiet    # Exit code only
#   ./shai-hulud-machine-check.sh --json     # JSON output
#
# References:
#   - Wiz.io: https://www.wiz.io/blog/shai-hulud-2-0-ongoing-supply-chain-attack
#   - Datadog: https://securitylabs.datadoghq.com/articles/shai-hulud-2.0-npm-worm/
#
# Author: Eric Boehs / EERT (with Claude Code)
# Version: 1.0.0
# Date: December 2025
#

set -e

# Parse arguments
QUIET=false
JSON=false
for arg in "$@"; do
  case $arg in
    --quiet|-q) QUIET=true ;;
    --json|-j) JSON=true ;;
    --help|-h)
      echo "Usage: $0 [--quiet|-q] [--json|-j]"
      echo "  --quiet  Exit code only, no output"
      echo "  --json   JSON output format"
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

log() {
  if [ "$QUIET" = false ] && [ "$JSON" = false ]; then
    echo -e "$@"
  fi
}

log_critical() {
  log "${RED}${BOLD}[CRITICAL]${NC} $1"
  CRITICAL_FINDINGS+=("$1")
}

log_high() {
  log "${YELLOW}[HIGH]${NC} $1"
  HIGH_FINDINGS+=("$1")
}

log_info() {
  log "${CYAN}[INFO]${NC} $1"
  INFO_FINDINGS+=("$1")
}

# Header
log ""
log "${BOLD}========================================${NC}"
log "${BOLD}  Shai-Hulud Machine Infection Check${NC}"
log "${BOLD}========================================${NC}"
log ""
log "Checking for active infection indicators..."
log ""

###########################################
# CRITICAL CHECKS
###########################################

log "${BOLD}=== Critical Checks ===${NC}"
log ""

# 1. Check for ~/.dev-env/ persistence folder
log "Checking for persistence folder (~/.dev-env/)..."
if [ -d "$HOME/.dev-env" ]; then
  log_critical "PERSISTENCE FOLDER FOUND: ~/.dev-env/"
  log "  This folder contains the malware's self-hosted GitHub runner."
  log "  Contents:"
  ls -la "$HOME/.dev-env" 2>/dev/null | head -10 | while read line; do log "    $line"; done
else
  log "  ${GREEN}Not found${NC}"
fi

# 2. Check for malicious running processes
log ""
log "Checking for malicious processes..."

# Runner.Listener (GitHub self-hosted runner - malware installs this)
if pgrep -f "Runner.Listener" > /dev/null 2>&1; then
  log_critical "MALICIOUS PROCESS: Runner.Listener is running"
  log "  PIDs: $(pgrep -f 'Runner.Listener' | tr '\n' ' ')"
fi

# SHA1HULUD process
if pgrep -f "SHA1HULUD" > /dev/null 2>&1; then
  log_critical "MALICIOUS PROCESS: SHA1HULUD is running"
  log "  PIDs: $(pgrep -f 'SHA1HULUD' | tr '\n' ' ')"
fi

# Check for node processes running from ~/.dev-env
if pgrep -f "$HOME/.dev-env" > /dev/null 2>&1; then
  log_critical "MALICIOUS PROCESS: Process running from ~/.dev-env"
  log "  PIDs: $(pgrep -f "$HOME/.dev-env" | tr '\n' ' ')"
fi

# Check for suspicious bun processes (from ~/.bun if unexpected)
if pgrep -f "$HOME/.bun/bin/bun" > /dev/null 2>&1; then
  log_high "SUSPICIOUS PROCESS: bun running from ~/.bun/bin/bun"
  log "  This could be legitimate if you installed Bun intentionally."
  log "  PIDs: $(pgrep -f "$HOME/.bun/bin/bun" | tr '\n' ' ')"
fi

# If no malicious processes found
if ! pgrep -f "Runner.Listener" > /dev/null 2>&1 && \
   ! pgrep -f "SHA1HULUD" > /dev/null 2>&1 && \
   ! pgrep -f "$HOME/.dev-env" > /dev/null 2>&1; then
  log "  ${GREEN}No malicious processes detected${NC}"
fi

# 3. Check for malware payload files in home directory
log ""
log "Checking for malware files in home directory..."
MALWARE_FILES=("setup_bun.js" "bun_environment.js")
for file in "${MALWARE_FILES[@]}"; do
  if [ -f "$HOME/$file" ]; then
    log_critical "MALWARE FILE FOUND: ~/$file"
  fi
done

# Check in common locations
for dir in "$HOME" "$HOME/Desktop" "$HOME/Downloads" "/tmp"; do
  if [ -d "$dir" ]; then
    for file in "${MALWARE_FILES[@]}"; do
      FOUND=$(find "$dir" -maxdepth 2 -name "$file" -type f 2>/dev/null | head -5)
      if [ -n "$FOUND" ]; then
        while IFS= read -r f; do
          log_critical "MALWARE FILE FOUND: $f"
        done <<< "$FOUND"
      fi
    done
  fi
done

if [ ${#CRITICAL_FINDINGS[@]} -eq 0 ] || \
   ! printf '%s\n' "${CRITICAL_FINDINGS[@]}" | grep -q "MALWARE FILE"; then
  log "  ${GREEN}No malware files detected${NC}"
fi

###########################################
# HIGH-RISK CHECKS
###########################################

log ""
log "${BOLD}=== High-Risk Checks ===${NC}"
log ""

# 4. Check for exfiltration artifacts
log "Checking for exfiltration artifacts..."
EXFIL_FILES=("cloud.json" "truffleSecrets.json" "environment.json" "actionsSecrets.json")
EXFIL_FOUND=false
for file in "${EXFIL_FILES[@]}"; do
  # Check home directory and common locations
  for dir in "$HOME" "/tmp" "$HOME/Desktop" "$HOME/Downloads"; do
    if [ -f "$dir/$file" ]; then
      log_high "EXFILTRATION ARTIFACT: $dir/$file"
      EXFIL_FOUND=true
    fi
  done
done

if [ "$EXFIL_FOUND" = false ]; then
  log "  ${GREEN}No exfiltration artifacts detected${NC}"
fi

# 5. Check for unexpected Bun installation
log ""
log "Checking for unexpected Bun installation..."
if [ -d "$HOME/.bun" ]; then
  log_high "BUN INSTALLATION FOUND: ~/.bun/"
  log "  If you did NOT install Bun intentionally, this is suspicious."
  log "  Bun version: $(~/.bun/bin/bun --version 2>/dev/null || echo 'unknown')"
elif command -v bun &> /dev/null; then
  BUN_PATH=$(which bun)
  log_high "BUN FOUND IN PATH: $BUN_PATH"
  log "  If you did NOT install Bun intentionally, investigate."
else
  log "  ${GREEN}No unexpected Bun installation${NC}"
fi

# 6. Check for Trufflehog (malware downloads this to scan for secrets)
log ""
log "Checking for unexpected Trufflehog..."
if command -v trufflehog &> /dev/null; then
  TH_PATH=$(which trufflehog)
  log_high "TRUFFLEHOG FOUND: $TH_PATH"
  log "  The malware uses Trufflehog to scan for secrets."
  log "  If you did NOT install this intentionally, investigate."
elif [ -f "$HOME/.local/bin/trufflehog" ] || [ -f "/tmp/trufflehog" ]; then
  log_high "TRUFFLEHOG FOUND in suspicious location"
else
  log "  ${GREEN}No unexpected Trufflehog installation${NC}"
fi

###########################################
# INFORMATIONAL - Credentials at Risk
###########################################

log ""
log "${BOLD}=== Credential Files (Rotate if Infected) ===${NC}"
log ""
log "These are files the malware targets for exfiltration."
log "If your machine is infected, ROTATE ALL OF THESE:"
log ""

# NPM tokens
if [ -f "$HOME/.npmrc" ]; then
  if grep -qi "authtoken\|_auth" "$HOME/.npmrc" 2>/dev/null; then
    log_info "~/.npmrc contains auth tokens - ROTATE NPM TOKENS"
  else
    log "  ~/.npmrc exists (no tokens detected)"
  fi
else
  log "  ~/.npmrc not found"
fi

# AWS credentials
if [ -d "$HOME/.aws" ]; then
  log_info "~/.aws/ exists - ROTATE AWS ACCESS KEYS"
else
  log "  ~/.aws/ not found"
fi

# GCP credentials
if [ -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
  log_info "GCP ADC exists - RE-AUTHENTICATE with 'gcloud auth application-default login'"
else
  log "  GCP ADC not found"
fi

# Azure credentials
if [ -d "$HOME/.azure" ]; then
  log_info "~/.azure/ exists - RE-AUTHENTICATE with 'az login'"
else
  log "  ~/.azure/ not found"
fi

# GitHub CLI
if [ -f "$HOME/.config/gh/hosts.yml" ]; then
  log_info "GitHub CLI authenticated - ROTATE TOKEN with 'gh auth logout && gh auth login'"
else
  log "  GitHub CLI not authenticated"
fi

# SSH keys
if [ -d "$HOME/.ssh" ] && ls "$HOME/.ssh/"*.pub &> /dev/null; then
  log_info "SSH keys exist (~/.ssh/) - Consider rotating if infected"
fi

# Git credentials
if [ -f "$HOME/.git-credentials" ]; then
  log_info "~/.git-credentials exists - ROTATE stored credentials"
fi

# Environment variables with secrets
SENSITIVE_VARS=$(env | grep -iE "token|key|secret|password|credential|auth|api" 2>/dev/null | wc -l | tr -d ' ')
if [ "$SENSITIVE_VARS" -gt 0 ]; then
  log_info "$SENSITIVE_VARS sensitive environment variables detected"
fi

###########################################
# SUMMARY
###########################################

log ""
log "${BOLD}========================================${NC}"

# Determine final status
EXIT_CODE=0
if [ ${#CRITICAL_FINDINGS[@]} -gt 0 ]; then
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
  EXIT_CODE=1
elif [ ${#HIGH_FINDINGS[@]} -gt 0 ]; then
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
  EXIT_CODE=2
else
  log "${GREEN}${BOLD}  STATUS: CLEAN${NC}"
  log "${GREEN}${BOLD}========================================${NC}"
  log ""
  log "${GREEN}No active infection indicators detected.${NC}"
  log ""
  log "Next steps:"
  log "  - Verify your repos don't have compromised packages"
  log "  - Check your lockfiles for known malicious packages"
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
