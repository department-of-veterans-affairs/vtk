<#
.SYNOPSIS
    Shai-Hulud Machine Infection Checker for Windows

.DESCRIPTION
    Quick script to check if your machine shows signs of active Shai-Hulud infection.
    This is a FAST check (~5 seconds) for infection indicators only.

    WHAT THIS CHECKS:

      CRITICAL (Active Infection):
        - %USERPROFILE%\.dev-env\ persistence folder (contains GitHub self-hosted runner)
        - %USERPROFILE%\.truffler-cache\ malware cache (NOT legit Trufflehog which uses .trufflehog)
        - Running processes: Runner.Listener, SHA1HULUD, suspicious node/bun
        - Malware files: setup_bun.js, bun_environment.js
        - Backdoor workflows: .github\workflows\discussion.yaml

      HIGH (Exfiltration Likely Occurred):
        - Exfiltration artifacts: cloud.json, truffleSecrets.json, etc.
        - Unexpected %USERPROFILE%\.bun\ installation
        - Unexpected Trufflehog binary

      INFO (Credentials to Rotate if Infected):
        - Lists credential files the malware targets
        - .npmrc, .aws\, .config\gh\, etc.

    EXIT CODES:
      0 - Clean (no infection indicators found)
      1 - INFECTED (critical indicators found)
      2 - WARNING (high-risk indicators, needs investigation)

.PARAMETER Verbose
    Show detailed output with all checks

.PARAMETER Quiet
    Exit code only, no output

.PARAMETER Json
    Output results as JSON

.PARAMETER ScanDirs
    Additional directories to scan for backdoor workflows (comma-separated)

.EXAMPLE
    .\shai-hulud-machine-check.ps1
    Runs with compact output

.EXAMPLE
    .\shai-hulud-machine-check.ps1 -Verbose
    Runs with detailed output

.EXAMPLE
    .\shai-hulud-machine-check.ps1 -Json
    Outputs JSON format

.NOTES
    Author: Eric Boehs / EERT (with Claude Code)
    Version: 1.0.0
    Date: December 2025
    Requires: PowerShell 5.1+

    References:
      - Wiz.io: https://www.wiz.io/blog/shai-hulud-2-0-ongoing-supply-chain-attack
      - Datadog: https://securitylabs.datadoghq.com/articles/shai-hulud-2.0-npm-worm/
#>

[CmdletBinding()]
param(
    [switch]$Quiet,
    [switch]$Json,
    [string]$ScanDirs,
    [switch]$Help
)

# Handle help
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# Results tracking
$script:CriticalFindings = [System.Collections.ArrayList]::new()
$script:HighFindings = [System.Collections.ArrayList]::new()
$script:InfoFindings = [System.Collections.ArrayList]::new()

# Default directories to scan for backdoor workflows
$DefaultScanDirs = @(
    "$env:USERPROFILE\Code",
    "$env:USERPROFILE\Projects",
    "$env:USERPROFILE\src",
    "$env:USERPROFILE\dev",
    "$env:USERPROFILE\workspace",
    "$env:USERPROFILE\repos"
)

# Build final scan dirs list
$AllScanDirs = [System.Collections.ArrayList]::new()
foreach ($dir in $DefaultScanDirs) {
    [void]$AllScanDirs.Add($dir)
}

if ($ScanDirs) {
    $extraDirs = $ScanDirs -split ','
    foreach ($dir in $extraDirs) {
        $expanded = $dir.Trim() -replace '^~', $env:USERPROFILE
        [void]$AllScanDirs.Add($expanded)
    }
}

# Color support
$UseColors = -not $Quiet -and -not $Json -and $Host.UI.SupportsVirtualTerminal

function Write-Log {
    param([string]$Message)
    if (-not $Quiet -and -not $Json) {
        Write-Host $Message
    }
}

function Write-LogVerbose {
    param([string]$Message)
    if ($VerbosePreference -eq 'Continue' -and -not $Quiet -and -not $Json) {
        Write-Host $Message
    }
}

function Write-ColorText {
    param(
        [string]$Text,
        [string]$Color = 'White'
    )
    if ($UseColors) {
        Write-Host $Text -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Text -NoNewline
    }
}

function Log-Critical {
    param([string]$Finding)
    [void]$script:CriticalFindings.Add($Finding)
}

function Log-High {
    param([string]$Finding)
    [void]$script:HighFindings.Add($Finding)
}

function Log-Info {
    param([string]$Finding)
    [void]$script:InfoFindings.Add($Finding)
}

# Verbose header
Write-LogVerbose ""
Write-LogVerbose "========================================"
Write-LogVerbose "  Shai-Hulud Machine Infection Check"
Write-LogVerbose "========================================"
Write-LogVerbose ""
Write-LogVerbose "Checking for active infection indicators..."
Write-LogVerbose ""

###########################################
# CRITICAL CHECKS
###########################################

Write-LogVerbose "=== Critical Checks ==="
Write-LogVerbose ""

# 1. Check for persistence folder
Write-LogVerbose "Checking for persistence folder (~\.dev-env\)..."
$devEnvPath = Join-Path $env:USERPROFILE ".dev-env"
if (Test-Path $devEnvPath -PathType Container) {
    Log-Critical "~\.dev-env\ persistence folder found"
    Write-LogVerbose "  [CRITICAL] PERSISTENCE FOLDER FOUND: $devEnvPath"
    Write-LogVerbose "  This folder contains the malware's self-hosted GitHub runner."
    Write-LogVerbose "  Contents:"
    Get-ChildItem $devEnvPath -ErrorAction SilentlyContinue | Select-Object -First 10 | ForEach-Object {
        Write-LogVerbose "    $($_.Name)"
    }
} else {
    Write-LogVerbose "  Not found"
}

# 1b. Check for malware Trufflehog cache
Write-LogVerbose ""
Write-LogVerbose "Checking for malware Trufflehog cache (~\.truffler-cache\)..."
$trufflerCachePath = Join-Path $env:USERPROFILE ".truffler-cache"
if (Test-Path $trufflerCachePath -PathType Container) {
    Log-Critical "~\.truffler-cache\ malware cache found"
    Write-LogVerbose "  [CRITICAL] MALWARE CACHE FOUND: $trufflerCachePath"
    Write-LogVerbose "  This is a MALWARE-SPECIFIC path (legit Trufflehog uses .trufflehog)."
    Write-LogVerbose "  Contents:"
    Get-ChildItem $trufflerCachePath -ErrorAction SilentlyContinue | Select-Object -First 10 | ForEach-Object {
        Write-LogVerbose "    $($_.Name)"
    }
} else {
    Write-LogVerbose "  Not found"
}

# 2. Check for malicious processes
Write-LogVerbose ""
Write-LogVerbose "Checking for malicious processes..."

$maliciousProcessFound = $false

# Runner.Listener
$runnerProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*Runner.Listener*" -or $_.Path -like "*Runner.Listener*" }
if ($runnerProcs) {
    Log-Critical "Runner.Listener process running"
    Write-LogVerbose "  [CRITICAL] MALICIOUS PROCESS: Runner.Listener is running"
    Write-LogVerbose "  PIDs: $($runnerProcs.Id -join ', ')"
    $maliciousProcessFound = $true
}

# SHA1HULUD
$sha1hulud = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*SHA1HULUD*" -or $_.Path -like "*SHA1HULUD*" }
if ($sha1hulud) {
    Log-Critical "SHA1HULUD process running"
    Write-LogVerbose "  [CRITICAL] MALICIOUS PROCESS: SHA1HULUD is running"
    Write-LogVerbose "  PIDs: $($sha1hulud.Id -join ', ')"
    $maliciousProcessFound = $true
}

# Processes from .dev-env
$devEnvProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*\.dev-env\*" }
if ($devEnvProcs) {
    Log-Critical "Process running from ~\.dev-env"
    Write-LogVerbose "  [CRITICAL] MALICIOUS PROCESS: Process running from .dev-env"
    Write-LogVerbose "  PIDs: $($devEnvProcs.Id -join ', ')"
    $maliciousProcessFound = $true
}

# Suspicious bun processes
$bunPath = Join-Path $env:USERPROFILE ".bun\bin\bun.exe"
$bunProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $bunPath }
if ($bunProcs) {
    Log-High "bun process running from ~\.bun\bin\bun.exe"
    Write-LogVerbose "  [HIGH] SUSPICIOUS PROCESS: bun running from .bun"
    Write-LogVerbose "  This could be legitimate if you installed Bun intentionally."
    Write-LogVerbose "  PIDs: $($bunProcs.Id -join ', ')"
}

if (-not $maliciousProcessFound) {
    Write-LogVerbose "  No malicious processes detected"
}

# 3. Check for malware files
Write-LogVerbose ""
Write-LogVerbose "Checking for malware files..."

$malwareFiles = @("setup_bun.js", "bun_environment.js")
$malwareFound = $false

foreach ($file in $malwareFiles) {
    $filePath = Join-Path $env:USERPROFILE $file
    if (Test-Path $filePath -PathType Leaf) {
        Log-Critical "Malware file: ~\$file"
        Write-LogVerbose "  [CRITICAL] MALWARE FILE FOUND: $filePath"
        $malwareFound = $true
    }
}

# Check common locations
$searchDirs = @(
    $env:USERPROFILE,
    (Join-Path $env:USERPROFILE "Desktop"),
    (Join-Path $env:USERPROFILE "Downloads"),
    $env:TEMP
)

foreach ($dir in $searchDirs) {
    if (Test-Path $dir -PathType Container) {
        foreach ($file in $malwareFiles) {
            $found = Get-ChildItem -Path $dir -Filter $file -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 5
            foreach ($f in $found) {
                Log-Critical "Malware file: $($f.FullName)"
                Write-LogVerbose "  [CRITICAL] MALWARE FILE FOUND: $($f.FullName)"
                $malwareFound = $true
            }
        }
    }
}

if (-not $malwareFound) {
    Write-LogVerbose "  No malware files detected"
}

# 4. Check for backdoor workflows
Write-LogVerbose ""
Write-LogVerbose "Checking for backdoor workflow files..."
Write-LogVerbose "  Scanning directories:"

foreach ($dir in $AllScanDirs) {
    if (Test-Path $dir -PathType Container) {
        Write-LogVerbose "    - $dir"
    } else {
        Write-LogVerbose "    - $dir (not found)"
    }
}

Write-LogVerbose ""
$backdoorFound = $false

foreach ($baseDir in $AllScanDirs) {
    if (-not (Test-Path $baseDir -PathType Container)) { continue }

    $workflowFiles = Get-ChildItem -Path $baseDir -Filter "discussion.yaml" -Recurse -Depth 5 -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -like "*\.github\workflows*" } |
        Select-Object -First 10

    foreach ($wf in $workflowFiles) {
        $content = Get-Content $wf.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -match "self-hosted" -and $content -match "github\.event\.discussion") {
            Log-Critical "Backdoor workflow: $($wf.FullName)"
            Write-LogVerbose "  [CRITICAL] BACKDOOR WORKFLOW FOUND: $($wf.FullName)"
            Write-LogVerbose "  This workflow uses self-hosted runner with discussion body injection."
            $backdoorFound = $true
        } else {
            Log-High "Unverified discussion.yaml: $($wf.FullName)"
            Write-LogVerbose "  [HIGH] UNVERIFIED WORKFLOW: $($wf.FullName)"
            Write-LogVerbose "  Found discussion.yaml - please verify this is legitimate."
        }
    }
}

if (-not $backdoorFound) {
    Write-LogVerbose "  No backdoor workflows detected"
}

###########################################
# HIGH-RISK CHECKS
###########################################

Write-LogVerbose ""
Write-LogVerbose "=== High-Risk Checks ==="
Write-LogVerbose ""

# 5. Check for exfiltration artifacts
Write-LogVerbose "Checking for exfiltration artifacts..."
$exfilFiles = @("cloud.json", "truffleSecrets.json", "environment.json", "actionsSecrets.json", "contents.json")
$exfilFound = $false

foreach ($file in $exfilFiles) {
    foreach ($dir in @($env:USERPROFILE, $env:TEMP, (Join-Path $env:USERPROFILE "Desktop"), (Join-Path $env:USERPROFILE "Downloads"))) {
        $filePath = Join-Path $dir $file
        if (Test-Path $filePath -PathType Leaf) {
            Log-High "Exfiltration artifact: $filePath"
            Write-LogVerbose "  [HIGH] EXFILTRATION ARTIFACT: $filePath"
            $exfilFound = $true
        }
    }
}

if (-not $exfilFound) {
    Write-LogVerbose "  No exfiltration artifacts detected"
}

# 6. Check for unexpected Bun installation
Write-LogVerbose ""
Write-LogVerbose "Checking for unexpected Bun installation..."
$bunDir = Join-Path $env:USERPROFILE ".bun"
if (Test-Path $bunDir -PathType Container) {
    Log-High "~\.bun\ installation found"
    Write-LogVerbose "  [HIGH] BUN INSTALLATION FOUND: $bunDir"
    Write-LogVerbose "  If you did NOT install Bun intentionally, this is suspicious."
    $bunExe = Join-Path $bunDir "bin\bun.exe"
    if (Test-Path $bunExe) {
        try {
            $bunVersion = & $bunExe --version 2>$null
            Write-LogVerbose "  Bun version: $bunVersion"
        } catch {
            Write-LogVerbose "  Bun version: unknown"
        }
    }
} elseif (Get-Command bun -ErrorAction SilentlyContinue) {
    $bunPath = (Get-Command bun).Source
    Log-High "Bun found: $bunPath"
    Write-LogVerbose "  [HIGH] BUN FOUND IN PATH: $bunPath"
    Write-LogVerbose "  If you did NOT install Bun intentionally, investigate."
} else {
    Write-LogVerbose "  No unexpected Bun installation"
}

# 7. Check for Trufflehog
Write-LogVerbose ""
Write-LogVerbose "Checking for unexpected Trufflehog..."
if (Get-Command trufflehog -ErrorAction SilentlyContinue) {
    $thPath = (Get-Command trufflehog).Source
    Log-High "Trufflehog found: $thPath"
    Write-LogVerbose "  [HIGH] TRUFFLEHOG FOUND: $thPath"
    Write-LogVerbose "  The malware uses Trufflehog to scan for secrets."
    Write-LogVerbose "  If you did NOT install this intentionally, investigate."
} else {
    $suspiciousLocations = @(
        (Join-Path $env:USERPROFILE ".local\bin\trufflehog.exe"),
        (Join-Path $env:TEMP "trufflehog.exe")
    )
    $thFound = $false
    foreach ($loc in $suspiciousLocations) {
        if (Test-Path $loc -PathType Leaf) {
            Log-High "Trufflehog in suspicious location: $loc"
            Write-LogVerbose "  [HIGH] TRUFFLEHOG FOUND in suspicious location: $loc"
            $thFound = $true
        }
    }
    if (-not $thFound) {
        Write-LogVerbose "  No unexpected Trufflehog installation"
    }
}

###########################################
# INFORMATIONAL - Credentials at Risk
###########################################

Write-LogVerbose ""
Write-LogVerbose "=== Credential Files (Rotate if Infected) ==="
Write-LogVerbose ""
Write-LogVerbose "These are files the malware targets for exfiltration."
Write-LogVerbose "If your machine is infected, ROTATE ALL OF THESE:"
Write-LogVerbose ""

# NPM tokens
$npmrcPath = Join-Path $env:USERPROFILE ".npmrc"
if (Test-Path $npmrcPath -PathType Leaf) {
    $content = Get-Content $npmrcPath -Raw -ErrorAction SilentlyContinue
    if ($content -match "authtoken|_auth") {
        Log-Info "~\.npmrc contains auth tokens"
        Write-LogVerbose "  [INFO] ~\.npmrc contains auth tokens - ROTATE NPM TOKENS"
    } else {
        Write-LogVerbose "  ~\.npmrc exists (no tokens detected)"
    }
} else {
    Write-LogVerbose "  ~\.npmrc not found"
}

# AWS credentials
$awsDir = Join-Path $env:USERPROFILE ".aws"
if (Test-Path $awsDir -PathType Container) {
    Log-Info "~\.aws\ exists"
    Write-LogVerbose "  [INFO] ~\.aws\ exists - ROTATE AWS ACCESS KEYS"
} else {
    Write-LogVerbose "  ~\.aws\ not found"
}

# GCP credentials
$gcpAdcPath = Join-Path $env:APPDATA "gcloud\application_default_credentials.json"
if (Test-Path $gcpAdcPath -PathType Leaf) {
    Log-Info "GCP ADC exists"
    Write-LogVerbose "  [INFO] GCP ADC exists - RE-AUTHENTICATE with 'gcloud auth application-default login'"
} else {
    Write-LogVerbose "  GCP ADC not found"
}

# Azure credentials
$azureDir = Join-Path $env:USERPROFILE ".azure"
if (Test-Path $azureDir -PathType Container) {
    Log-Info "~\.azure\ exists"
    Write-LogVerbose "  [INFO] ~\.azure\ exists - RE-AUTHENTICATE with 'az login'"
} else {
    Write-LogVerbose "  ~\.azure\ not found"
}

# GitHub CLI
$ghHostsPath = Join-Path $env:APPDATA "GitHub CLI\hosts.yml"
if (Test-Path $ghHostsPath -PathType Leaf) {
    Log-Info "GitHub CLI authenticated"
    Write-LogVerbose "  [INFO] GitHub CLI authenticated - ROTATE TOKEN with 'gh auth logout && gh auth login'"
} else {
    Write-LogVerbose "  GitHub CLI not authenticated"
}

# SSH keys
$sshDir = Join-Path $env:USERPROFILE ".ssh"
if (Test-Path $sshDir -PathType Container) {
    $pubKeys = Get-ChildItem -Path $sshDir -Filter "*.pub" -ErrorAction SilentlyContinue
    if ($pubKeys) {
        Log-Info "SSH keys exist"
        Write-LogVerbose "  [INFO] SSH keys exist (~\.ssh\) - Consider rotating if infected"
    }
}

# Git credentials
$gitCredPath = Join-Path $env:USERPROFILE ".git-credentials"
if (Test-Path $gitCredPath -PathType Leaf) {
    Log-Info "~\.git-credentials exists"
    Write-LogVerbose "  [INFO] ~\.git-credentials exists - ROTATE stored credentials"
}

# Environment variables with secrets
$sensitiveVars = [Environment]::GetEnvironmentVariables() |
    Where-Object { $_.Key -match "token|key|secret|password|credential|auth|api" } |
    Measure-Object

if ($sensitiveVars.Count -gt 0) {
    Log-Info "$($sensitiveVars.Count) sensitive env vars"
    Write-LogVerbose "  [INFO] $($sensitiveVars.Count) sensitive environment variables detected"
}

###########################################
# SUMMARY
###########################################

Write-LogVerbose ""
Write-LogVerbose "========================================"

$exitCode = 0

if ($script:CriticalFindings.Count -gt 0) {
    $exitCode = 1
    if ($VerbosePreference -eq 'Continue') {
        Write-Log ""
        if ($UseColors) {
            Write-Host "  STATUS: INFECTED" -ForegroundColor Red
            Write-Host "========================================" -ForegroundColor Red
        } else {
            Write-Log "  STATUS: INFECTED"
            Write-Log "========================================"
        }
        Write-Log ""
        Write-Log "CRITICAL FINDINGS ($($script:CriticalFindings.Count)):"
        foreach ($finding in $script:CriticalFindings) {
            Write-Log "  - $finding"
        }
        Write-Log ""
        Write-Log "IMMEDIATE ACTIONS:"
        Write-Log "  1. DISCONNECT from network immediately"
        Write-Log "  2. Do NOT run npm/yarn/node commands"
        Write-Log "  3. Follow the cleanup playbook"
        Write-Log "  4. Rotate ALL credentials listed above"
    } else {
        if ($UseColors) {
            Write-Host "Shai-Hulud Check: INFECTED" -ForegroundColor Red
        } else {
            Write-Log "Shai-Hulud Check: INFECTED"
        }
        foreach ($finding in $script:CriticalFindings) {
            Write-Log "  - $finding"
        }
        Write-Log ""
        Write-Log "Run with -Verbose for details and remediation steps"
    }
} elseif ($script:HighFindings.Count -gt 0) {
    $exitCode = 2
    if ($VerbosePreference -eq 'Continue') {
        Write-Log ""
        if ($UseColors) {
            Write-Host "  STATUS: WARNING - INVESTIGATE" -ForegroundColor Yellow
            Write-Host "========================================" -ForegroundColor Yellow
        } else {
            Write-Log "  STATUS: WARNING - INVESTIGATE"
            Write-Log "========================================"
        }
        Write-Log ""
        Write-Log "HIGH-RISK FINDINGS ($($script:HighFindings.Count)):"
        foreach ($finding in $script:HighFindings) {
            Write-Log "  - $finding"
        }
        Write-Log ""
        Write-Log "RECOMMENDED ACTIONS:"
        Write-Log "  1. Verify if Bun/Trufflehog were installed intentionally"
        Write-Log "  2. If not intentional, treat as potentially infected"
        Write-Log "  3. Investigate further before running any package manager commands"
    } else {
        if ($UseColors) {
            Write-Host "Shai-Hulud Check: WARNING" -ForegroundColor Yellow
        } else {
            Write-Log "Shai-Hulud Check: WARNING"
        }
        foreach ($finding in $script:HighFindings) {
            Write-Log "  - $finding"
        }
        Write-Log ""
        Write-Log "These may be legitimate if you installed them intentionally."
        Write-Log "Run with -Verbose for details or investigate if unexpected."
    }
} else {
    if ($VerbosePreference -eq 'Continue') {
        Write-Log ""
        if ($UseColors) {
            Write-Host "  STATUS: CLEAN" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
        } else {
            Write-Log "  STATUS: CLEAN"
            Write-Log "========================================"
        }
        Write-Log ""
        Write-Log "No active infection indicators detected."
        Write-Log ""
        Write-Log "Next steps:"
        Write-Log "  - Verify your repos don't have compromised packages"
        Write-Log "  - Check your lockfiles for known malicious packages"
    } else {
        if ($UseColors) {
            Write-Host "Shai-Hulud Check: CLEAN" -ForegroundColor Green
        } else {
            Write-Log "Shai-Hulud Check: CLEAN"
        }
    }
}

Write-Log ""

# JSON output
if ($Json) {
    $status = if ($script:CriticalFindings.Count -gt 0) { "INFECTED" }
              elseif ($script:HighFindings.Count -gt 0) { "WARNING" }
              else { "CLEAN" }

    $output = [ordered]@{
        status = $status
        critical_count = $script:CriticalFindings.Count
        high_count = $script:HighFindings.Count
        info_count = $script:InfoFindings.Count
        critical_findings = @($script:CriticalFindings)
        high_findings = @($script:HighFindings)
        info_findings = @($script:InfoFindings)
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }

    $output | ConvertTo-Json -Depth 3
}

exit $exitCode
