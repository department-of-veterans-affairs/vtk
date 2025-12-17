<#
.SYNOPSIS
    Credential Audit Script for Windows

.DESCRIPTION
    Audits which credentials are present on this machine and provides rotation
    instructions for each. Run this after a suspected or confirmed security incident.

    WHAT THIS CHECKS:

      NPM:
        - %USERPROFILE%\.npmrc (auth tokens)
        - $env:NPM_TOKEN, $env:NPM_CONFIG_TOKEN environment variables

      AWS:
        - %USERPROFILE%\.aws\credentials, .aws\config
        - $env:AWS_ACCESS_KEY_ID, $env:AWS_SECRET_ACCESS_KEY

      GCP:
        - %APPDATA%\gcloud\application_default_credentials.json
        - $env:GOOGLE_APPLICATION_CREDENTIALS

      Azure:
        - %USERPROFILE%\.azure\ directory
        - $env:AZURE_CLIENT_SECRET, $env:AZURE_TENANT_ID

      GitHub:
        - %APPDATA%\GitHub CLI\hosts.yml (GitHub CLI)
        - %USERPROFILE%\.git-credentials
        - $env:GITHUB_TOKEN, $env:GH_TOKEN

      Other:
        - SSH keys (%USERPROFILE%\.ssh\)
        - Docker config (%USERPROFILE%\.docker\config.json)
        - Kubernetes config (%USERPROFILE%\.kube\config)
        - Sensitive environment variables

    EXIT CODES:
      0 - No credentials found
      1 - Credentials found (rotation recommended)

.PARAMETER Verbose
    Show all checks including clean ones

.PARAMETER Json
    Output results as JSON

.EXAMPLE
    .\credential-audit.ps1
    Standard output

.EXAMPLE
    .\credential-audit.ps1 -Verbose
    Show all checks even clean ones

.EXAMPLE
    .\credential-audit.ps1 -Json
    JSON output format

.NOTES
    Author: Eric Boehs / EERT (with Claude Code)
    Version: 1.0.0
    Date: December 2025
    Requires: PowerShell 5.1+

    References:
      - EERT Playbooks: https://department-of-veterans-affairs.github.io/eert/
#>

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$Help
)

# Handle help
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# Results tracking
$script:RotationInstructions = [System.Collections.ArrayList]::new()
$script:TotalFound = 0

# Color support - SupportsVirtualTerminal doesn't exist in PS 5.1, so check safely
$UseColors = -not $Json -and (($Host.UI.psobject.Properties.Name -contains 'SupportsVirtualTerminal') -and $Host.UI.SupportsVirtualTerminal)

function Write-Log {
    param([string]$Message)
    if (-not $Json) {
        Write-Host $Message
    }
}

function Write-LogVerbose {
    param([string]$Message)
    if ($VerbosePreference -eq 'Continue' -and -not $Json) {
        Write-Host $Message
    }
}

function Write-Found {
    param([string]$Message)
    if ($UseColors) {
        Write-Host "  [FOUND] " -ForegroundColor Red -NoNewline
        Write-Host $Message
    } else {
        Write-Host "  [FOUND] $Message"
    }
}

function Write-Clean {
    param([string]$Message)
    if ($VerbosePreference -eq 'Continue' -and -not $Json) {
        if ($UseColors) {
            Write-Host "  [CLEAN] " -ForegroundColor Green -NoNewline
            Write-Host $Message
        } else {
            Write-Host "  [CLEAN] $Message"
        }
    }
}

function Write-Skip {
    param([string]$Message)
    if ($VerbosePreference -eq 'Continue' -and -not $Json) {
        if ($UseColors) {
            Write-Host "  [SKIP] " -ForegroundColor DarkGray -NoNewline
            Write-Host $Message
        } else {
            Write-Host "  [SKIP] $Message"
        }
    }
}

function Log-Found {
    param(
        [string]$Service,
        [string]$Location,
        [string]$Instruction
    )
    [void]$script:RotationInstructions.Add([PSCustomObject]@{
        Service = $Service
        Location = $Location
        Instruction = $Instruction
    })
    $script:TotalFound++
}

# Header
Write-Log ""
Write-Log "Credential Audit"
Write-Log "Checking for credentials that may need rotation..."
Write-Log ""

###########################################
# NPM CREDENTIALS
###########################################

Write-Log "NPM"
$npmFound = 0

# Check ~/.npmrc
$npmrcPath = Join-Path $env:USERPROFILE ".npmrc"
if (Test-Path $npmrcPath -PathType Leaf) {
    $content = Get-Content $npmrcPath -Raw -ErrorAction SilentlyContinue
    if ($content -match "//.*:_authToken=|_auth=|authToken") {
        Write-Found "~\.npmrc contains auth tokens"
        Log-Found "NPM" "~\.npmrc" "npm token revoke <token> && npm login"
        $npmFound++
    } else {
        Write-Clean "~\.npmrc exists but no tokens found"
    }
} else {
    Write-Skip "~\.npmrc not found"
}

# Check NPM environment variables
if ($env:NPM_TOKEN) {
    Write-Found "`$env:NPM_TOKEN is set"
    Log-Found "NPM" "`$env:NPM_TOKEN" "Revoke token in npm account settings, regenerate and update env"
    $npmFound++
}

if ($env:NPM_CONFIG_TOKEN) {
    Write-Found "`$env:NPM_CONFIG_TOKEN is set"
    Log-Found "NPM" "`$env:NPM_CONFIG_TOKEN" "Revoke token in npm account settings, regenerate and update env"
    $npmFound++
}

if ($npmFound -eq 0) {
    Write-Log "  None found"
}

Write-Log ""

###########################################
# AWS CREDENTIALS
###########################################

Write-Log "AWS"
$awsFound = 0

# Check ~/.aws/credentials
$awsCredsPath = Join-Path $env:USERPROFILE ".aws\credentials"
if (Test-Path $awsCredsPath -PathType Leaf) {
    Write-Found "~\.aws\credentials"
    Log-Found "AWS" "~\.aws\credentials" "aws iam delete-access-key && aws iam create-access-key"
    $awsFound++
} else {
    Write-Skip "~\.aws\credentials not found"
}

# Check ~/.aws/config
$awsConfigPath = Join-Path $env:USERPROFILE ".aws\config"
if (Test-Path $awsConfigPath -PathType Leaf) {
    $content = Get-Content $awsConfigPath -Raw -ErrorAction SilentlyContinue
    if ($content -match "aws_access_key_id|aws_secret_access_key") {
        Write-Found "~\.aws\config contains access keys"
        Log-Found "AWS" "~\.aws\config" "Remove keys from config, use aws configure"
        $awsFound++
    } else {
        Write-Clean "~\.aws\config exists (no embedded keys)"
    }
} else {
    Write-Skip "~\.aws\config not found"
}

# Check AWS environment variables
if ($env:AWS_ACCESS_KEY_ID) {
    Write-Found "`$env:AWS_ACCESS_KEY_ID is set"
    Log-Found "AWS" "`$env:AWS_ACCESS_KEY_ID" "Rotate key in IAM console, update env"
    $awsFound++
}

if ($env:AWS_SECRET_ACCESS_KEY) {
    Write-Found "`$env:AWS_SECRET_ACCESS_KEY is set"
    Log-Found "AWS" "`$env:AWS_SECRET_ACCESS_KEY" "Rotate key in IAM console, update env"
    $awsFound++
}

if ($env:AWS_SESSION_TOKEN) {
    if ($UseColors) {
        Write-Host "  [FOUND] " -ForegroundColor Yellow -NoNewline
        Write-Host "`$env:AWS_SESSION_TOKEN is set (temporary)"
    } else {
        Write-Host "  [FOUND] `$env:AWS_SESSION_TOKEN is set (temporary)"
    }
    Log-Found "AWS" "`$env:AWS_SESSION_TOKEN" "Wait for expiration or re-authenticate with aws sso login"
    $awsFound++
}

if ($awsFound -eq 0) {
    Write-Log "  None found"
}

Write-Log ""

###########################################
# GCP CREDENTIALS
###########################################

Write-Log "GCP"
$gcpFound = 0

# Check Application Default Credentials
$adcPath = Join-Path $env:APPDATA "gcloud\application_default_credentials.json"
if (Test-Path $adcPath -PathType Leaf) {
    Write-Found "Application Default Credentials"
    Log-Found "GCP" $adcPath "gcloud auth application-default revoke && gcloud auth application-default login"
    $gcpFound++
} else {
    Write-Skip "ADC not found"
}

# Check gcloud credentials.db
$gcloudCredsDb = Join-Path $env:APPDATA "gcloud\credentials.db"
if (Test-Path $gcloudCredsDb -PathType Leaf) {
    Write-Found "gcloud credentials.db"
    Log-Found "GCP" "~\AppData\Roaming\gcloud\credentials.db" "gcloud auth revoke --all && gcloud auth login"
    $gcpFound++
}

# Check GOOGLE_APPLICATION_CREDENTIALS
if ($env:GOOGLE_APPLICATION_CREDENTIALS) {
    if (Test-Path $env:GOOGLE_APPLICATION_CREDENTIALS -PathType Leaf) {
        Write-Found "`$env:GOOGLE_APPLICATION_CREDENTIALS points to: $($env:GOOGLE_APPLICATION_CREDENTIALS)"
        Log-Found "GCP" "`$env:GOOGLE_APPLICATION_CREDENTIALS" "Rotate service account key in GCP Console"
        $gcpFound++
    } else {
        Write-Skip "`$env:GOOGLE_APPLICATION_CREDENTIALS set but file doesn't exist"
    }
}

if ($gcpFound -eq 0) {
    Write-Log "  None found"
}

Write-Log ""

###########################################
# AZURE CREDENTIALS
###########################################

Write-Log "Azure"
$azureFound = 0

# Check ~/.azure directory
$azureDir = Join-Path $env:USERPROFILE ".azure"
if (Test-Path $azureDir -PathType Container) {
    $accessTokens = Join-Path $azureDir "accessTokens.json"
    $azureProfile = Join-Path $azureDir "azureProfile.json"
    if ((Test-Path $accessTokens -PathType Leaf) -or (Test-Path $azureProfile -PathType Leaf)) {
        Write-Found "~\.azure\ contains auth tokens"
        Log-Found "Azure" "~\.azure\" "az logout && az login"
        $azureFound++
    } else {
        Write-Clean "~\.azure\ exists but no tokens found"
    }
} else {
    Write-Skip "~\.azure\ not found"
}

# Check Azure environment variables
if ($env:AZURE_CLIENT_SECRET) {
    Write-Found "`$env:AZURE_CLIENT_SECRET is set"
    Log-Found "Azure" "`$env:AZURE_CLIENT_SECRET" "Rotate client secret in Azure AD app registration"
    $azureFound++
}

if ($env:AZURE_CLIENT_ID -and $env:AZURE_TENANT_ID) {
    if ($UseColors) {
        Write-Host "  [INFO] " -ForegroundColor Yellow -NoNewline
        Write-Host "Azure service principal env vars configured"
    } else {
        Write-Host "  [INFO] Azure service principal env vars configured"
    }
}

if ($azureFound -eq 0) {
    Write-Log "  None found"
}

Write-Log ""

###########################################
# GITHUB CREDENTIALS
###########################################

Write-Log "GitHub"
$githubFound = 0

# Check GitHub CLI
$ghHostsPath = Join-Path $env:APPDATA "GitHub CLI\hosts.yml"
if (Test-Path $ghHostsPath -PathType Leaf) {
    Write-Found "GitHub CLI authenticated (~\AppData\Roaming\GitHub CLI\hosts.yml)"
    Log-Found "GitHub" "~\AppData\Roaming\GitHub CLI\hosts.yml" "gh auth logout && gh auth login"
    $githubFound++
} else {
    Write-Skip "GitHub CLI not authenticated"
}

# Check GITHUB_TOKEN / GH_TOKEN
if ($env:GITHUB_TOKEN) {
    Write-Found "`$env:GITHUB_TOKEN is set"
    Log-Found "GitHub" "`$env:GITHUB_TOKEN" "Revoke token at github.com/settings/tokens, regenerate"
    $githubFound++
}

if ($env:GH_TOKEN) {
    Write-Found "`$env:GH_TOKEN is set"
    Log-Found "GitHub" "`$env:GH_TOKEN" "Revoke token at github.com/settings/tokens, regenerate"
    $githubFound++
}

# Check .gitconfig for credential store
$gitconfigPath = Join-Path $env:USERPROFILE ".gitconfig"
if (Test-Path $gitconfigPath -PathType Leaf) {
    $content = Get-Content $gitconfigPath -Raw -ErrorAction SilentlyContinue
    if ($content -match "helper.*store|credential.*=.*https") {
        if ($UseColors) {
            Write-Host "  [WARN] " -ForegroundColor Yellow -NoNewline
            Write-Host "~\.gitconfig uses credential store"
        } else {
            Write-Host "  [WARN] ~\.gitconfig uses credential store"
        }
        Log-Found "GitHub" "~\.gitconfig" "git config --global --unset credential.helper (if using store)"
        $githubFound++
    }
}

# Check .git-credentials
$gitCredsPath = Join-Path $env:USERPROFILE ".git-credentials"
if (Test-Path $gitCredsPath -PathType Leaf) {
    Write-Found "~\.git-credentials (plaintext credentials)"
    Log-Found "GitHub" "~\.git-credentials" "Remove-Item ~\.git-credentials && regenerate PATs"
    $githubFound++
}

if ($githubFound -eq 0) {
    Write-Log "  None found"
}

Write-Log ""

###########################################
# SSH KEYS
###########################################

Write-Log "SSH"
$sshFound = 0

$sshDir = Join-Path $env:USERPROFILE ".ssh"
if (Test-Path $sshDir -PathType Container) {
    # Count private keys (files without .pub extension that aren't config/known_hosts)
    $privateKeys = Get-ChildItem $sshDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "*.pub" -and $_.Name -notlike "known_hosts*" -and $_.Name -ne "config" -and $_.Name -ne "authorized_keys" }

    if ($privateKeys) {
        Write-Found "$($privateKeys.Count) SSH private key(s) in ~\.ssh\"
        Log-Found "SSH" "~\.ssh\" "ssh-keygen -t ed25519, update public keys on all services"
        $sshFound++

        if ($VerbosePreference -eq 'Continue') {
            foreach ($key in $privateKeys) {
                Write-Log "       - $($key.Name)"
            }
        }
    } else {
        Write-Skip "No SSH private keys found"
    }
} else {
    Write-Skip "~\.ssh\ not found"
}

if ($sshFound -eq 0) {
    Write-Log "  None found"
}

Write-Log ""

###########################################
# DOCKER CREDENTIALS
###########################################

Write-Log "Docker"
$dockerFound = 0

$dockerConfigPath = Join-Path $env:USERPROFILE ".docker\config.json"
if (Test-Path $dockerConfigPath -PathType Leaf) {
    $content = Get-Content $dockerConfigPath -Raw -ErrorAction SilentlyContinue
    if ($content -match '"auth"') {
        Write-Found "~\.docker\config.json contains auth"
        Log-Found "Docker" "~\.docker\config.json" "docker logout && docker login"
        $dockerFound++
    } else {
        Write-Clean "~\.docker\config.json exists (no auth)"
    }
} else {
    Write-Skip "~\.docker\config.json not found"
}

if ($dockerFound -eq 0) {
    Write-Log "  None found"
}

Write-Log ""

###########################################
# KUBERNETES CREDENTIALS
###########################################

Write-Log "Kubernetes"
$k8sFound = 0

$kubeConfigPath = Join-Path $env:USERPROFILE ".kube\config"
if (Test-Path $kubeConfigPath -PathType Leaf) {
    Write-Found "~\.kube\config"
    Log-Found "Kubernetes" "~\.kube\config" "Rotate cluster credentials, re-run az aks get-credentials or equivalent"
    $k8sFound++
} else {
    Write-Skip "~\.kube\config not found"
}

if ($k8sFound -eq 0) {
    Write-Log "  None found"
}

Write-Log ""

###########################################
# SENSITIVE ENVIRONMENT VARIABLES
###########################################

Write-Log "Environment Variables"

# Get all env vars and filter for sensitive ones (excluding already checked)
$excludedVars = @("NPM_TOKEN", "NPM_CONFIG_TOKEN", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY",
                  "AWS_SESSION_TOKEN", "GITHUB_TOKEN", "GH_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS",
                  "AZURE_CLIENT_SECRET")

$sensitiveVars = [Environment]::GetEnvironmentVariables().GetEnumerator() |
    Where-Object { $_.Key -match "token|secret|password|credential|api.?key|auth" } |
    Where-Object { $_.Key -notin $excludedVars }

$sensitiveCount = ($sensitiveVars | Measure-Object).Count

if ($sensitiveCount -gt 0) {
    if ($UseColors) {
        Write-Host "  [FOUND] " -ForegroundColor Yellow -NoNewline
        Write-Host "$sensitiveCount additional sensitive env var(s)"
    } else {
        Write-Host "  [FOUND] $sensitiveCount additional sensitive env var(s)"
    }
    Log-Found "Environment" "shell environment" "Check PowerShell profile for secrets"

    if ($VerbosePreference -eq 'Continue') {
        foreach ($var in $sensitiveVars) {
            Write-Log "       - `$$($var.Key)"
        }
    }
} else {
    Write-Log "  None found"
}

Write-Log ""

###########################################
# SUMMARY
###########################################

Write-Log "========================================"

if ($script:TotalFound -gt 0) {
    if ($UseColors) {
        Write-Host "  CREDENTIALS FOUND: $($script:TotalFound)" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
    } else {
        Write-Log "  CREDENTIALS FOUND: $($script:TotalFound)"
        Write-Log "========================================"
    }
    Write-Log ""
    Write-Log "Rotation Instructions:"
    Write-Log ""

    # Group by service
    $grouped = $script:RotationInstructions | Group-Object -Property Service
    foreach ($group in $grouped) {
        if ($UseColors) {
            Write-Host "$($group.Name):" -ForegroundColor Cyan
        } else {
            Write-Log "$($group.Name):"
        }
        foreach ($item in $group.Group) {
            Write-Log "  $($item.Location)"
            Write-Log "    $($item.Instruction)"
            Write-Log ""
        }
    }

    if ($UseColors) {
        Write-Host "IMPORTANT: " -ForegroundColor Yellow -NoNewline
        Write-Host "If your machine was compromised, assume ALL of these"
    } else {
        Write-Log "IMPORTANT: If your machine was compromised, assume ALL of these"
    }
    Write-Log "credentials were exfiltrated. Rotate them immediately."
    Write-Log ""
    Write-Log "Note: This list is not exhaustive. You may need to rotate other"
    Write-Log "credentials not detected by this scan (e.g., database passwords,"
    Write-Log "API keys in config files, or service-specific tokens)."
    Write-Log ""
    Write-Log "See: https://department-of-veterans-affairs.github.io/eert/"

    $exitCode = 1
} else {
    if ($UseColors) {
        Write-Host "  NO CREDENTIALS FOUND" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
    } else {
        Write-Log "  NO CREDENTIALS FOUND"
        Write-Log "========================================"
    }
    Write-Log ""
    Write-Log "No credential files or environment variables were detected."
    Write-Log "This machine has minimal credential exposure risk."

    $exitCode = 0
}

Write-Log ""

###########################################
# JSON OUTPUT
###########################################

if ($Json) {
    $status = if ($script:TotalFound -gt 0) { "CREDENTIALS_FOUND" } else { "CLEAN" }

    $credentials = @()
    foreach ($item in $script:RotationInstructions) {
        $credentials += [PSCustomObject]@{
            service = $item.Service
            location = $item.Location
            rotation = $item.Instruction
        }
    }

    $output = [ordered]@{
        status = $status
        credentials_found = $script:TotalFound
        credentials = $credentials
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }

    $output | ConvertTo-Json -Depth 3
}

exit $exitCode
