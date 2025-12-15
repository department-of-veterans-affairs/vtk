#!/bin/bash
#
# Credential Audit Script
# =======================
#
# Audits which credentials are present on this machine and provides rotation
# instructions for each. Run this after a suspected or confirmed security incident.
#
# WHAT THIS CHECKS:
#
#   NPM:
#     - ~/.npmrc (auth tokens)
#     - $NPM_TOKEN, $NPM_CONFIG_TOKEN environment variables
#
#   AWS:
#     - ~/.aws/credentials, ~/.aws/config
#     - $AWS_ACCESS_KEY_ID, $AWS_SECRET_ACCESS_KEY
#
#   GCP:
#     - ~/.config/gcloud/application_default_credentials.json
#     - $GOOGLE_APPLICATION_CREDENTIALS
#
#   Azure:
#     - ~/.azure/ directory
#     - $AZURE_CLIENT_SECRET, $AZURE_TENANT_ID
#
#   GitHub:
#     - ~/.config/gh/hosts.yml (GitHub CLI)
#     - .git/config (stored credentials)
#     - $GITHUB_TOKEN, $GH_TOKEN
#
#   Other:
#     - SSH keys (~/.ssh/)
#     - Git credentials (~/.git-credentials)
#     - Docker config (~/.docker/config.json)
#     - Kubernetes config (~/.kube/config)
#     - Sensitive environment variables
#
# EXIT CODES:
#   0 - No credentials found
#   1 - Credentials found (rotation recommended)
#
# USAGE:
#   ./credential-audit.sh              # Standard output
#   ./credential-audit.sh --verbose    # Show all checks (even clean)
#   ./credential-audit.sh --json       # JSON output
#
# References:
#   - EERT Playbooks: https://department-of-veterans-affairs.github.io/eert/
#
# Author: Eric Boehs / EERT (with Claude Code)
# Version: 1.0.0
# Date: December 2025
#

set -e

# Parse arguments
JSON=false
VERBOSE=false
for arg in "$@"; do
  case $arg in
    --json|-j) JSON=true ;;
    --verbose|-v) VERBOSE=true ;;
    --help|-h)
      echo "Usage: $0 [--verbose|-v] [--json|-j]"
      echo "  --verbose    Show all checks including clean ones"
      echo "  --json       JSON output format"
      exit 0
      ;;
  esac
done

# Results tracking
ROTATION_INSTRUCTIONS=()
TOTAL_FOUND=0

# Colors (disabled in json mode)
if [ "$JSON" = false ] && [ -t 1 ]; then
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  GREEN='\033[0;32m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  DIM='\033[2m'
  NC='\033[0m'
else
  RED='' YELLOW='' GREEN='' CYAN='' BOLD='' DIM='' NC=''
fi

# Logging functions
log() {
  if [ "$JSON" = false ]; then
    echo -e "$@"
  fi
}

log_verbose() {
  if [ "$VERBOSE" = true ] && [ "$JSON" = false ]; then
    echo -e "$@"
  fi
}

log_found() {
  local service="$1"
  local location="$2"
  local instruction="$3"
  ROTATION_INSTRUCTIONS+=("$service|$location|$instruction")
  ((TOTAL_FOUND++)) || true
}

# Header
log ""
log "${BOLD}Credential Audit${NC}"
log "${DIM}Checking for credentials that may need rotation...${NC}"
log ""

###########################################
# NPM CREDENTIALS
###########################################

log "${BOLD}NPM${NC}"
NPM_FOUND=0

# Check ~/.npmrc
if [ -f "$HOME/.npmrc" ]; then
  if grep -qiE "//.*:_authToken=|_auth=|authToken" "$HOME/.npmrc" 2>/dev/null; then
    log "  ${RED}[FOUND]${NC} ~/.npmrc contains auth tokens"
    log_found "NPM" "~/.npmrc" "npm token revoke <token> && npm login"
    NPM_FOUND=1
  else
    log_verbose "  ${GREEN}[CLEAN]${NC} ~/.npmrc exists but no tokens found"
  fi
else
  log_verbose "  ${DIM}[SKIP]${NC} ~/.npmrc not found"
fi

# Check NPM environment variables
if [ -n "$NPM_TOKEN" ]; then
  log "  ${RED}[FOUND]${NC} \$NPM_TOKEN is set"
  log_found "NPM" "\$NPM_TOKEN" "Revoke token in npm account settings, regenerate and update env"
  NPM_FOUND=1
fi

if [ -n "$NPM_CONFIG_TOKEN" ]; then
  log "  ${RED}[FOUND]${NC} \$NPM_CONFIG_TOKEN is set"
  log_found "NPM" "\$NPM_CONFIG_TOKEN" "Revoke token in npm account settings, regenerate and update env"
  NPM_FOUND=1
fi

if [ "$NPM_FOUND" -eq 0 ]; then
  log "  ${DIM}None found${NC}"
fi

log ""

###########################################
# AWS CREDENTIALS
###########################################

log "${BOLD}AWS${NC}"
AWS_FOUND=0

# Check ~/.aws/credentials
if [ -f "$HOME/.aws/credentials" ]; then
  log "  ${RED}[FOUND]${NC} ~/.aws/credentials"
  log_found "AWS" "~/.aws/credentials" "aws iam delete-access-key && aws iam create-access-key"
  AWS_FOUND=1
else
  log_verbose "  ${DIM}[SKIP]${NC} ~/.aws/credentials not found"
fi

# Check ~/.aws/config (may contain SSO or role info)
if [ -f "$HOME/.aws/config" ]; then
  if grep -qE "aws_access_key_id|aws_secret_access_key" "$HOME/.aws/config" 2>/dev/null; then
    log "  ${RED}[FOUND]${NC} ~/.aws/config contains access keys"
    log_found "AWS" "~/.aws/config" "Remove keys from config, use aws configure"
    AWS_FOUND=1
  else
    log_verbose "  ${GREEN}[CLEAN]${NC} ~/.aws/config exists (no embedded keys)"
  fi
else
  log_verbose "  ${DIM}[SKIP]${NC} ~/.aws/config not found"
fi

# Check AWS environment variables
if [ -n "$AWS_ACCESS_KEY_ID" ]; then
  log "  ${RED}[FOUND]${NC} \$AWS_ACCESS_KEY_ID is set"
  log_found "AWS" "\$AWS_ACCESS_KEY_ID" "Rotate key in IAM console, update env"
  AWS_FOUND=1
fi

if [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
  log "  ${RED}[FOUND]${NC} \$AWS_SECRET_ACCESS_KEY is set"
  log_found "AWS" "\$AWS_SECRET_ACCESS_KEY" "Rotate key in IAM console, update env"
  AWS_FOUND=1
fi

if [ -n "$AWS_SESSION_TOKEN" ]; then
  log "  ${YELLOW}[FOUND]${NC} \$AWS_SESSION_TOKEN is set (temporary)"
  log_found "AWS" "\$AWS_SESSION_TOKEN" "Wait for expiration or re-authenticate with aws sso login"
  AWS_FOUND=1
fi

if [ "$AWS_FOUND" -eq 0 ]; then
  log "  ${DIM}None found${NC}"
fi

log ""

###########################################
# GCP CREDENTIALS
###########################################

log "${BOLD}GCP${NC}"
GCP_FOUND=0

# Check Application Default Credentials
ADC_PATH="$HOME/.config/gcloud/application_default_credentials.json"
if [ -f "$ADC_PATH" ]; then
  log "  ${RED}[FOUND]${NC} Application Default Credentials"
  log_found "GCP" "$ADC_PATH" "gcloud auth application-default revoke && gcloud auth application-default login"
  GCP_FOUND=1
else
  log_verbose "  ${DIM}[SKIP]${NC} ADC not found"
fi

# Check gcloud auth
if [ -d "$HOME/.config/gcloud" ] && [ -f "$HOME/.config/gcloud/credentials.db" ]; then
  log "  ${RED}[FOUND]${NC} gcloud credentials.db"
  log_found "GCP" "~/.config/gcloud/credentials.db" "gcloud auth revoke --all && gcloud auth login"
  GCP_FOUND=1
fi

# Check GOOGLE_APPLICATION_CREDENTIALS
if [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
  if [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    log "  ${RED}[FOUND]${NC} \$GOOGLE_APPLICATION_CREDENTIALS points to: $GOOGLE_APPLICATION_CREDENTIALS"
    log_found "GCP" "\$GOOGLE_APPLICATION_CREDENTIALS" "Rotate service account key in GCP Console"
    GCP_FOUND=1
  else
    log_verbose "  ${DIM}[SKIP]${NC} \$GOOGLE_APPLICATION_CREDENTIALS set but file doesn't exist"
  fi
fi

if [ "$GCP_FOUND" -eq 0 ]; then
  log "  ${DIM}None found${NC}"
fi

log ""

###########################################
# AZURE CREDENTIALS
###########################################

log "${BOLD}Azure${NC}"
AZURE_FOUND=0

# Check ~/.azure directory
if [ -d "$HOME/.azure" ]; then
  if [ -f "$HOME/.azure/accessTokens.json" ] || [ -f "$HOME/.azure/azureProfile.json" ]; then
    log "  ${RED}[FOUND]${NC} ~/.azure/ contains auth tokens"
    log_found "Azure" "~/.azure/" "az logout && az login"
    AZURE_FOUND=1
  else
    log_verbose "  ${GREEN}[CLEAN]${NC} ~/.azure/ exists but no tokens found"
  fi
else
  log_verbose "  ${DIM}[SKIP]${NC} ~/.azure/ not found"
fi

# Check Azure environment variables
if [ -n "$AZURE_CLIENT_SECRET" ]; then
  log "  ${RED}[FOUND]${NC} \$AZURE_CLIENT_SECRET is set"
  log_found "Azure" "\$AZURE_CLIENT_SECRET" "Rotate client secret in Azure AD app registration"
  AZURE_FOUND=1
fi

if [ -n "$AZURE_CLIENT_ID" ] && [ -n "$AZURE_TENANT_ID" ]; then
  log "  ${YELLOW}[INFO]${NC} Azure service principal env vars configured"
fi

if [ "$AZURE_FOUND" -eq 0 ]; then
  log "  ${DIM}None found${NC}"
fi

log ""

###########################################
# GITHUB CREDENTIALS
###########################################

log "${BOLD}GitHub${NC}"
GITHUB_FOUND=0

# Check GitHub CLI
if [ -f "$HOME/.config/gh/hosts.yml" ]; then
  log "  ${RED}[FOUND]${NC} GitHub CLI authenticated (~/.config/gh/hosts.yml)"
  log_found "GitHub" "~/.config/gh/hosts.yml" "gh auth logout && gh auth login"
  GITHUB_FOUND=1
else
  log_verbose "  ${DIM}[SKIP]${NC} GitHub CLI not authenticated"
fi

# Check for GITHUB_TOKEN / GH_TOKEN
if [ -n "$GITHUB_TOKEN" ]; then
  log "  ${RED}[FOUND]${NC} \$GITHUB_TOKEN is set"
  log_found "GitHub" "\$GITHUB_TOKEN" "Revoke token at github.com/settings/tokens, regenerate"
  GITHUB_FOUND=1
fi

if [ -n "$GH_TOKEN" ]; then
  log "  ${RED}[FOUND]${NC} \$GH_TOKEN is set"
  log_found "GitHub" "\$GH_TOKEN" "Revoke token at github.com/settings/tokens, regenerate"
  GITHUB_FOUND=1
fi

# Check .git/config for stored credentials (in home dir)
if [ -f "$HOME/.gitconfig" ]; then
  if grep -qE "helper.*store|credential.*=.*https" "$HOME/.gitconfig" 2>/dev/null; then
    log "  ${YELLOW}[WARN]${NC} ~/.gitconfig uses credential store"
    log_found "GitHub" "~/.gitconfig" "git config --global --unset credential.helper (if using store)"
    GITHUB_FOUND=1
  fi
fi

# Check .git-credentials
if [ -f "$HOME/.git-credentials" ]; then
  log "  ${RED}[FOUND]${NC} ~/.git-credentials (plaintext credentials)"
  log_found "GitHub" "~/.git-credentials" "rm ~/.git-credentials && regenerate PATs"
  GITHUB_FOUND=1
fi

if [ "$GITHUB_FOUND" -eq 0 ]; then
  log "  ${DIM}None found${NC}"
fi

log ""

###########################################
# SSH KEYS
###########################################

log "${BOLD}SSH${NC}"
SSH_FOUND=0

if [ -d "$HOME/.ssh" ]; then
  # Count private keys (files without .pub extension that aren't config/known_hosts)
  PRIVATE_KEYS=$(find "$HOME/.ssh" -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$PRIVATE_KEYS" -gt 0 ]; then
    log "  ${RED}[FOUND]${NC} $PRIVATE_KEYS SSH private key(s) in ~/.ssh/"
    log_found "SSH" "~/.ssh/" "ssh-keygen -t ed25519, update public keys on all services"
    SSH_FOUND=1

    # List the keys
    if [ "$VERBOSE" = true ]; then
      find "$HOME/.ssh" -type f ! -name "*.pub" ! -name "known_hosts*" ! -name "config" ! -name "authorized_keys" 2>/dev/null | while read -r key; do
        log "       - $(basename "$key")"
      done
    fi
  else
    log_verbose "  ${DIM}[SKIP]${NC} No SSH private keys found"
  fi
else
  log_verbose "  ${DIM}[SKIP]${NC} ~/.ssh/ not found"
fi

if [ "$SSH_FOUND" -eq 0 ]; then
  log "  ${DIM}None found${NC}"
fi

log ""

###########################################
# DOCKER CREDENTIALS
###########################################

log "${BOLD}Docker${NC}"
DOCKER_FOUND=0

if [ -f "$HOME/.docker/config.json" ]; then
  if grep -q "auth" "$HOME/.docker/config.json" 2>/dev/null; then
    log "  ${RED}[FOUND]${NC} ~/.docker/config.json contains auth"
    log_found "Docker" "~/.docker/config.json" "docker logout && docker login"
    DOCKER_FOUND=1
  else
    log_verbose "  ${GREEN}[CLEAN]${NC} ~/.docker/config.json exists (no auth)"
  fi
else
  log_verbose "  ${DIM}[SKIP]${NC} ~/.docker/config.json not found"
fi

if [ "$DOCKER_FOUND" -eq 0 ]; then
  log "  ${DIM}None found${NC}"
fi

log ""

###########################################
# KUBERNETES CREDENTIALS
###########################################

log "${BOLD}Kubernetes${NC}"
K8S_FOUND=0

if [ -f "$HOME/.kube/config" ]; then
  log "  ${RED}[FOUND]${NC} ~/.kube/config"
  log_found "Kubernetes" "~/.kube/config" "Rotate cluster credentials, re-run az aks get-credentials or equivalent"
  K8S_FOUND=1
else
  log_verbose "  ${DIM}[SKIP]${NC} ~/.kube/config not found"
fi

if [ "$K8S_FOUND" -eq 0 ]; then
  log "  ${DIM}None found${NC}"
fi

log ""

###########################################
# SENSITIVE ENVIRONMENT VARIABLES
###########################################

log "${BOLD}Environment Variables${NC}"

# Count sensitive env vars (excluding ones we already checked)
SENSITIVE_PATTERNS="token|secret|password|credential|api.?key|auth"
EXCLUDED_VARS="NPM_TOKEN|NPM_CONFIG_TOKEN|AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN|GITHUB_TOKEN|GH_TOKEN|GOOGLE_APPLICATION_CREDENTIALS|AZURE_CLIENT_SECRET"
SENSITIVE_VARS=$(env | grep -iE "$SENSITIVE_PATTERNS" | grep -vE "^($EXCLUDED_VARS)=" 2>/dev/null || true)
SENSITIVE_COUNT=$(echo "$SENSITIVE_VARS" | grep -c . 2>/dev/null || echo 0)

if [ "$SENSITIVE_COUNT" -gt 0 ]; then
  log "  ${YELLOW}[FOUND]${NC} $SENSITIVE_COUNT additional sensitive env var(s)"
  log_found "Environment" "shell environment" "Check ~/.zshrc, ~/.bashrc, or shell profile for secrets"

  if [ "$VERBOSE" = true ]; then
    echo "$SENSITIVE_VARS" | while read -r line; do
      VAR_NAME=$(echo "$line" | cut -d= -f1)
      log "       - \$$VAR_NAME"
    done
  fi
else
  log "  ${DIM}None found${NC}"
fi

log ""

###########################################
# SUMMARY
###########################################

log "${BOLD}========================================${NC}"

if [ "$TOTAL_FOUND" -gt 0 ]; then
  log "${RED}${BOLD}  CREDENTIALS FOUND: $TOTAL_FOUND${NC}"
  log "${BOLD}========================================${NC}"
  log ""
  log "${BOLD}Rotation Instructions:${NC}"
  log ""

  # Group by service
  CURRENT_SERVICE=""
  for entry in "${ROTATION_INSTRUCTIONS[@]}"; do
    SERVICE=$(echo "$entry" | cut -d'|' -f1)
    LOCATION=$(echo "$entry" | cut -d'|' -f2)
    INSTRUCTION=$(echo "$entry" | cut -d'|' -f3)

    if [ "$SERVICE" != "$CURRENT_SERVICE" ]; then
      log "${CYAN}$SERVICE:${NC}"
      CURRENT_SERVICE="$SERVICE"
    fi
    log "  ${DIM}$LOCATION${NC}"
    log "    ${BOLD}$INSTRUCTION${NC}"
    log ""
  done

  log "${YELLOW}${BOLD}IMPORTANT:${NC} If your machine was compromised, assume ALL of these"
  log "credentials were exfiltrated. Rotate them immediately."
  log ""
  log "${DIM}Note: This list is not exhaustive. You may need to rotate other"
  log "credentials not detected by this scan (e.g., database passwords,"
  log "API keys in config files, or service-specific tokens).${NC}"
  log ""
  log "See: ${CYAN}https://department-of-veterans-affairs.github.io/eert/${NC}"

  EXIT_CODE=1
else
  log "${GREEN}${BOLD}  NO CREDENTIALS FOUND${NC}"
  log "${BOLD}========================================${NC}"
  log ""
  log "No credential files or environment variables were detected."
  log "This machine has minimal credential exposure risk."

  EXIT_CODE=0
fi

log ""

###########################################
# JSON OUTPUT
###########################################

if [ "$JSON" = true ]; then
  echo "{"
  echo "  \"status\": \"$([ "$TOTAL_FOUND" -gt 0 ] && echo 'CREDENTIALS_FOUND' || echo 'CLEAN')\","
  echo "  \"credentials_found\": $TOTAL_FOUND,"
  echo "  \"credentials\": ["

  FIRST=true
  for entry in "${ROTATION_INSTRUCTIONS[@]}"; do
    SERVICE=$(echo "$entry" | cut -d'|' -f1)
    LOCATION=$(echo "$entry" | cut -d'|' -f2)
    INSTRUCTION=$(echo "$entry" | cut -d'|' -f3)

    # Escape for JSON
    LOCATION="${LOCATION//\\/\\\\}"
    LOCATION="${LOCATION//\"/\\\"}"
    INSTRUCTION="${INSTRUCTION//\\/\\\\}"
    INSTRUCTION="${INSTRUCTION//\"/\\\"}"

    if [ "$FIRST" = true ]; then
      FIRST=false
    else
      echo ","
    fi
    printf "    {\"service\": \"%s\", \"location\": \"%s\", \"rotation\": \"%s\"}" "$SERVICE" "$LOCATION" "$INSTRUCTION"
  done

  echo ""
  echo "  ],"
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
  echo "}"
fi

exit $EXIT_CODE
