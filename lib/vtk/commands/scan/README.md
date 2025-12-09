# VTK Scan Commands

Security scanning commands for detecting Shai-Hulud malware and supply chain compromises.

## Commands

### `vtk scan machine`

Quick check for active malware infection on your developer machine.

```bash
vtk scan machine              # Compact output
vtk scan machine --verbose    # Detailed checks
vtk scan machine --json       # JSON output
vtk scan machine --quiet      # Exit code only
```

**What it checks:**
- `~/.dev-env/` persistence folder (critical indicator)
- Malicious processes (Runner.Listener, SHA1HULUD)
- Malware files (setup_bun.js, bun_environment.js)
- Exfiltration artifacts
- Unexpected Bun/Trufflehog installations

**Exit codes:**
- `0` - Clean
- `1` - Infected (critical indicators found)
- `2` - Warning (needs investigation)

### `vtk scan repo [PATH]`

Scan a repository for compromised npm packages and backdoor workflows.

```bash
vtk scan repo                 # Scan current directory
vtk scan repo /path/to/repo   # Scan specific path
vtk scan repo --refresh       # Force refresh package list
vtk scan repo --json          # JSON output
vtk scan repo --quiet         # Exit code only
```

**What it checks:**
- Lockfiles (package-lock.json, yarn.lock, pnpm-lock.yaml) against 1,600+ known compromised packages
- Backdoor workflows (.github/workflows/discussion.yaml)
- Secrets extraction workflows (.github/workflows/formatter_*.yml)

**Exit codes:**
- `0` - Clean
- `1` - Compromised packages found
- `2` - Backdoor workflow found

## Data Sources

The compromised packages list is fetched from [Cobenian/shai-hulud-detect](https://github.com/Cobenian/shai-hulud-detect) and cached locally for 24 hours.

**Cache location:** `$XDG_CACHE_HOME/vtk/compromised-packages.txt` (defaults to `~/.cache/vtk/`)

## References

- [Datadog: Shai-Hulud 2.0 npm Worm](https://securitylabs.datadoghq.com/articles/shai-hulud-2.0-npm-worm/)
- [Cobenian/shai-hulud-detect](https://github.com/Cobenian/shai-hulud-detect)
