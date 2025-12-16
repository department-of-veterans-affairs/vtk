<#
.SYNOPSIS
    Shai-Hulud Repository Scanner for Windows

.DESCRIPTION
    Scans a repository (or directory tree) for compromised npm packages
    and backdoor GitHub workflow files associated with the Shai-Hulud attack.

    WHAT THIS CHECKS:

      Lockfiles (package-lock.json, yarn.lock, pnpm-lock.yaml):
        - Compares installed packages against known compromised package list
        - Supports recursive scanning for monorepos

      Backdoor Workflows (.github\workflows\):
        - discussion.yaml: Self-hosted runner with unescaped discussion body
        - formatter_[0-9]*.yml: Timestamp-based secrets extraction workflows

    EXIT CODES:
      0 - Clean (no issues found)
      1 - INFECTED (compromised packages found)
      2 - WARNING (backdoor workflows found, but no compromised packages)

.PARAMETER Path
    Directory to scan (default: current directory)

.PARAMETER Recursive
    Recursively scan subdirectories (default depth: 5)

.PARAMETER Depth
    Max directory depth for recursive scan (default: 5, 0=unlimited)

.PARAMETER Quiet
    Exit code only, no output

.PARAMETER Json
    Output results as JSON

.PARAMETER Refresh
    Force refresh of compromised packages list

.PARAMETER Verbose
    Show each lockfile path as it's scanned

.EXAMPLE
    .\shai-hulud-repo-check.ps1
    Scan current directory

.EXAMPLE
    .\shai-hulud-repo-check.ps1 -Path C:\Code\my-project
    Scan specific directory

.EXAMPLE
    .\shai-hulud-repo-check.ps1 -Recursive
    Recursive scan with default depth

.EXAMPLE
    .\shai-hulud-repo-check.ps1 -Json
    JSON output

.NOTES
    Author: Eric Boehs / EERT (with Claude Code)
    Version: 1.0.0
    Date: December 2025
    Requires: PowerShell 5.1+

    References:
      - https://department-of-veterans-affairs.github.io/eert/shai-hulud-dev-machine-cleanup-playbook
#>

[CmdletBinding()]
param(
    [string]$Path = ".",
    [switch]$Recursive,
    [int]$Depth = 5,
    [switch]$Quiet,
    [switch]$Json,
    [switch]$Refresh,
    [switch]$Help
)

# Handle help
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# Configuration
$CompromisedPackagesUrl = "https://raw.githubusercontent.com/Cobenian/shai-hulud-detect/main/compromised-packages.txt"
$CacheDir = Join-Path $env:LOCALAPPDATA "vtk"
$CacheFile = Join-Path $CacheDir "compromised-packages.txt"
$CacheTTL = 86400  # 24 hours in seconds
$MinExpectedPackages = 500
$ExpectedHeader = "Shai-Hulud NPM Supply Chain Attack"
$PlaybookUrl = "https://department-of-veterans-affairs.github.io/eert/shai-hulud-dev-machine-cleanup-playbook"

# Resolve path
try {
    $ScanPath = (Resolve-Path $Path -ErrorAction Stop).Path
} catch {
    Write-Error "ERROR: Directory not found: $Path"
    exit 1
}

# Results tracking
$script:CompromisedFindings = [System.Collections.ArrayList]::new()
$script:BackdoorFindings = [System.Collections.ArrayList]::new()
$script:Warnings = [System.Collections.ArrayList]::new()
$script:LockfilesScanned = [System.Collections.ArrayList]::new()
$script:TotalPackagesScanned = 0
$script:CompromisedPackagesList = @()

# Color support
$UseColors = -not $Quiet -and -not $Json -and $Host.UI.SupportsVirtualTerminal

function Write-Log {
    param([string]$Message)
    if (-not $Quiet -and -not $Json) {
        Write-Host $Message
    }
}

function Write-Status {
    param([string]$Message)
    if (-not $Quiet -and -not $Json) {
        Write-Host $Message -NoNewline
    }
}

###########################################
# CACHE MANAGEMENT
###########################################

function Ensure-CacheDir {
    if (-not (Test-Path $CacheDir -PathType Container)) {
        New-Item -Path $CacheDir -ItemType Directory -Force | Out-Null
    }
}

function Test-CacheStale {
    if (-not (Test-Path $CacheFile -PathType Leaf)) {
        return $true
    }

    $fileInfo = Get-Item $CacheFile
    $fileAge = ((Get-Date) - $fileInfo.LastWriteTime).TotalSeconds
    return $fileAge -gt $CacheTTL
}

function Test-PackageListValid {
    param([string]$Content)

    # Check for expected header
    if ($Content -notmatch [regex]::Escape($ExpectedHeader)) {
        Write-Warning "Downloaded file missing expected header - possible MITM or corrupted file"
        return $false
    }

    # Count packages (non-comment lines with colons)
    $packageCount = ($Content -split "`n" | Where-Object { $_ -notmatch "^#" -and $_ -match ":" }).Count

    if ($packageCount -lt $MinExpectedPackages) {
        Write-Warning "Downloaded file has only $packageCount packages (expected $MinExpectedPackages+)"
        return $false
    }

    return $true
}

function Get-CompromisedPackages {
    if (-not $Quiet -and -not $Json) {
        Write-Host "Fetching compromised packages list..." -ForegroundColor DarkGray
    }

    try {
        $content = Invoke-WebRequest -Uri $CompromisedPackagesUrl -UseBasicParsing -UserAgent "vtk-security-scanner" -ErrorAction Stop
        $contentText = $content.Content

        if (-not (Test-PackageListValid $contentText)) {
            return $false
        }

        $contentText | Out-File -FilePath $CacheFile -Encoding UTF8 -Force

        $count = ($contentText -split "`n" | Where-Object { $_ -notmatch "^#" -and $_ -match ":" }).Count
        if (-not $Quiet -and -not $Json) {
            Write-Host "Cached $count compromised packages" -ForegroundColor DarkGray
        }

        return $true
    } catch {
        Write-Warning "Failed to fetch compromised packages list: $_"
        return $false
    }
}

function Initialize-CompromisedPackages {
    Ensure-CacheDir

    if ($Refresh -or (Test-CacheStale)) {
        $success = Get-CompromisedPackages
        if (-not $success) {
            if (-not (Test-Path $CacheFile -PathType Leaf)) {
                Write-Error "ERROR: No compromised packages list available. Check your network connection."
                exit 1
            }
            Write-Warning "Using cached version"
        }
    }

    if (-not (Test-Path $CacheFile -PathType Leaf)) {
        Write-Error "ERROR: No compromised packages list available."
        exit 1
    }

    # Load into memory for fast lookups
    $script:CompromisedPackagesList = Get-Content $CacheFile |
        Where-Object { $_ -notmatch "^#" -and $_ -match ":" } |
        ForEach-Object { $_.Trim() }
}

function Test-Compromised {
    param([string]$Package)
    return $script:CompromisedPackagesList -contains $Package
}

###########################################
# LOCKFILE PARSING
###########################################

function Find-Lockfiles {
    $lockfiles = @()

    if ($Recursive) {
        $depthParam = @{}
        if ($Depth -gt 0) {
            $depthParam["Depth"] = $Depth
        }

        $lockfiles += Get-ChildItem -Path $ScanPath -Include "package-lock.json", "yarn.lock", "pnpm-lock.yaml" -Recurse @depthParam -ErrorAction SilentlyContinue |
            Sort-Object FullName
    } else {
        foreach ($name in @("package-lock.json", "yarn.lock", "pnpm-lock.yaml")) {
            $filePath = Join-Path $ScanPath $name
            if (Test-Path $filePath -PathType Leaf) {
                $lockfiles += Get-Item $filePath
            }
        }
    }

    return $lockfiles
}

function Parse-PackageLock {
    param([string]$FilePath)

    $packages = @()
    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue

    if (-not $content) { return $packages }

    # Extract packages from v2/v3 format (node_modules/*)
    $matches = [regex]::Matches($content, '"node_modules/([^"]+)":\s*\{[^}]*"version":\s*"([^"]+)"')
    foreach ($match in $matches) {
        $packages += "$($match.Groups[1].Value):$($match.Groups[2].Value)"
    }

    # Extract from v1 format (dependencies)
    $matches = [regex]::Matches($content, '"([^"]+)":\s*\{\s*"version":\s*"(\d+\.\d+\.\d+[^"]*)"')
    foreach ($match in $matches) {
        $name = $match.Groups[1].Value
        if ($name -notmatch "node_modules") {
            $packages += "$name`:$($match.Groups[2].Value)"
        }
    }

    return $packages | Select-Object -Unique
}

function Parse-YarnLock {
    param([string]$FilePath)

    $packages = @()
    $content = Get-Content $FilePath -ErrorAction SilentlyContinue

    if (-not $content) { return $packages }

    $currentPkg = ""
    foreach ($line in $content) {
        # Package header line - check scoped packages (@scope/name) FIRST to avoid false matches
        if ($line -match '^"?(@[^/]+/[^@"]+)@' -or $line -match '^"?([^@][^"@]*)@') {
            $currentPkg = $matches[1]
        }
        # Version line
        elseif ($line -match '^\s+version\s+"?([^"]+)"?' -and $currentPkg) {
            $packages += "$currentPkg`:$($matches[1])"
            $currentPkg = ""
        }
    }

    return $packages | Select-Object -Unique
}

function Parse-PnpmLock {
    param([string]$FilePath)

    $packages = @()
    $content = Get-Content $FilePath -ErrorAction SilentlyContinue

    if (-not $content) { return $packages }

    foreach ($line in $content) {
        # pnpm format: /@scope/pkg@1.2.3: or /pkg@1.2.3:
        if ($line -match "^\s+'?/?(@?[^@:]+)@([^:']+)") {
            $packages += "$($matches[1]):$($matches[2])"
        }
    }

    return $packages | Select-Object -Unique
}

function Parse-Lockfile {
    param([string]$FilePath)

    $fileName = Split-Path $FilePath -Leaf

    switch ($fileName) {
        "package-lock.json" { return Parse-PackageLock $FilePath }
        "yarn.lock" { return Parse-YarnLock $FilePath }
        "pnpm-lock.yaml" { return Parse-PnpmLock $FilePath }
        default { return @() }
    }
}

function Check-Lockfiles {
    $lockfiles = Find-Lockfiles

    if ($lockfiles.Count -eq 0) {
        [void]$script:Warnings.Add("No lockfiles found (package-lock.json, yarn.lock, or pnpm-lock.yaml)")
        return
    }

    $total = $lockfiles.Count
    $count = 0

    foreach ($lockfile in $lockfiles) {
        $count++
        $relPath = $lockfile.FullName.Replace($ScanPath, "").TrimStart("\", "/")

        # Progress display
        if ($VerbosePreference -eq 'Continue' -and -not $Quiet -and -not $Json) {
            Write-Host "[$count/$total] $($lockfile.FullName)"
        } elseif (-not $Quiet -and -not $Json) {
            Write-Host "`r[$count/$total] $relPath" -NoNewline
        }

        $packages = Parse-Lockfile $lockfile.FullName
        $pkgCount = $packages.Count

        # Track compromised for this lockfile
        $lockfileCompromised = @()

        $pkgScanned = 0
        foreach ($pkg in $packages) {
            if (-not $pkg) { continue }
            $pkgScanned++

            if (Test-Compromised $pkg) {
                [void]$script:CompromisedFindings.Add([PSCustomObject]@{
                    Package = $pkg
                    Lockfile = $lockfile.FullName
                })
                $lockfileCompromised += $pkg
            }
        }

        $script:TotalPackagesScanned += $pkgScanned

        [void]$script:LockfilesScanned.Add([PSCustomObject]@{
            Path = $lockfile.FullName
            PackagesScanned = $pkgScanned
            Compromised = $lockfileCompromised
        })
    }

    # Clear progress line
    if (-not $Quiet -and -not $Json -and $VerbosePreference -ne 'Continue') {
        Write-Host "`rScanned $total lockfiles ($($script:TotalPackagesScanned) packages).                    "
    }
}

###########################################
# BACKDOOR WORKFLOW DETECTION
###########################################

function Find-WorkflowDirs {
    if ($Recursive) {
        $depthParam = @{}
        if ($Depth -gt 0) {
            $depthParam["Depth"] = $Depth
        }
        return Get-ChildItem -Path $ScanPath -Directory -Filter "workflows" -Recurse @depthParam -ErrorAction SilentlyContinue |
            Where-Object { $_.Parent.Name -eq ".github" }
    } else {
        $dir = Join-Path $ScanPath ".github\workflows"
        if (Test-Path $dir -PathType Container) {
            return Get-Item $dir
        }
    }
    return @()
}

function Check-DiscussionBackdoor {
    param([string]$WorkflowsDir)

    foreach ($filename in @("discussion.yaml", "discussion.yml")) {
        $workflowPath = Join-Path $WorkflowsDir $filename
        if (-not (Test-Path $workflowPath -PathType Leaf)) { continue }

        $content = Get-Content $workflowPath -Raw -ErrorAction SilentlyContinue

        # Check for malicious pattern
        if ($content -match "discussion" -and $content -match "self-hosted" -and $content -match '\$\{\{\s*github\.event\.discussion\.body\s*\}\}') {
            [void]$script:BackdoorFindings.Add([PSCustomObject]@{
                File = $workflowPath
                Type = "discussion_backdoor"
            })
        }
    }
}

function Check-FormatterBackdoor {
    param([string]$WorkflowsDir)

    # Match timestamp-based formatter files (formatter_ + digits) per Wiz report
    # This reduces false positives on legitimate files like formatter_config.yml
    $formatterFiles = Get-ChildItem -Path $WorkflowsDir -Filter "formatter_[0-9]*.yml" -ErrorAction SilentlyContinue

    foreach ($file in $formatterFiles) {
        [void]$script:BackdoorFindings.Add([PSCustomObject]@{
            File = $file.FullName
            Type = "secrets_extraction"
        })
    }
}

function Check-BackdoorWorkflows {
    $workflowDirs = Find-WorkflowDirs

    foreach ($dir in $workflowDirs) {
        Check-DiscussionBackdoor $dir.FullName
        Check-FormatterBackdoor $dir.FullName
    }
}

###########################################
# OUTPUT
###########################################

function Report-Text {
    Write-Log ""

    # Report compromised packages
    if ($script:CompromisedFindings.Count -gt 0) {
        if ($UseColors) {
            Write-Host "COMPROMISED PACKAGES FOUND:" -ForegroundColor Red
        } else {
            Write-Log "COMPROMISED PACKAGES FOUND:"
        }
        foreach ($finding in $script:CompromisedFindings) {
            Write-Log "   $($finding.Package)"
            Write-Log "   in $($finding.Lockfile)"
        }
        Write-Log ""
    }

    # Report backdoors
    if ($script:BackdoorFindings.Count -gt 0) {
        if ($UseColors) {
            Write-Host "BACKDOOR WORKFLOWS FOUND:" -ForegroundColor Red
        } else {
            Write-Log "BACKDOOR WORKFLOWS FOUND:"
        }
        foreach ($finding in $script:BackdoorFindings) {
            Write-Log "   $($finding.File)"
            Write-Log "   Type: $($finding.Type)"
        }
        Write-Log ""
    }

    # Report warnings
    if ($script:CompromisedFindings.Count -eq 0 -and $script:BackdoorFindings.Count -eq 0 -and $script:Warnings.Count -gt 0) {
        foreach ($warning in $script:Warnings) {
            if ($UseColors) {
                Write-Host "WARNING: $warning" -ForegroundColor Yellow
            } else {
                Write-Log "WARNING: $warning"
            }
        }
        Write-Log ""
    }

    # Status
    if ($script:CompromisedFindings.Count -gt 0) {
        if ($UseColors) {
            Write-Host "Status: INFECTED - Compromised packages found" -ForegroundColor Red
        } else {
            Write-Log "Status: INFECTED - Compromised packages found"
        }
    } elseif ($script:BackdoorFindings.Count -gt 0) {
        if ($UseColors) {
            Write-Host "Status: WARNING - Backdoor workflows found" -ForegroundColor Yellow
        } else {
            Write-Log "Status: WARNING - Backdoor workflows found"
        }
    } else {
        if ($UseColors) {
            Write-Host "Status: CLEAN" -ForegroundColor Green
        } else {
            Write-Log "Status: CLEAN"
        }
    }

    if ($script:CompromisedFindings.Count -gt 0 -or $script:BackdoorFindings.Count -gt 0) {
        Write-Log ""
        Write-Log "See cleanup playbook:"
        Write-Log "  $PlaybookUrl"
    }
}

function Report-Json {
    $status = if ($script:CompromisedFindings.Count -gt 0) { "INFECTED - Compromised packages found" }
              elseif ($script:BackdoorFindings.Count -gt 0) { "WARNING - Backdoor workflows found" }
              else { "CLEAN" }

    $lockfilesJson = @()
    foreach ($lf in $script:LockfilesScanned) {
        $lockfilesJson += [PSCustomObject]@{
            path = $lf.Path
            packages_scanned = $lf.PackagesScanned
        }
    }

    $compromisedJson = @()
    foreach ($finding in $script:CompromisedFindings) {
        $compromisedJson += [PSCustomObject]@{
            package = $finding.Package
            lockfile = $finding.Lockfile
        }
    }

    $backdoorsJson = @()
    foreach ($finding in $script:BackdoorFindings) {
        $backdoorsJson += [PSCustomObject]@{
            file = $finding.File
            type = $finding.Type
        }
    }

    $output = [ordered]@{
        path = $ScanPath
        status = $status
        packages_scanned = $script:TotalPackagesScanned
        lockfiles_scanned = $lockfilesJson
        compromised_packages = $compromisedJson
        backdoors = $backdoorsJson
        warnings = @($script:Warnings)
    }

    $output | ConvertTo-Json -Depth 4
}

###########################################
# MAIN
###########################################

# Show scan info
if (-not $Quiet -and -not $Json) {
    if ($Recursive) {
        if ($Depth -eq 0) {
            Write-Log "Scanning: $ScanPath (recursive, unlimited depth)"
        } else {
            Write-Log "Scanning: $ScanPath (recursive, max depth: $Depth)"
        }
    } else {
        Write-Log "Scanning: $ScanPath"
    }
}

# Load compromised packages
Initialize-CompromisedPackages

# Run checks
Check-Lockfiles
Check-BackdoorWorkflows

# Output results
if (-not $Quiet) {
    if ($Json) {
        Report-Json
    } else {
        Report-Text
    }
}

# Exit code
if ($script:CompromisedFindings.Count -gt 0) {
    exit 1
} elseif ($script:BackdoorFindings.Count -gt 0) {
    exit 2
} else {
    exit 0
}
