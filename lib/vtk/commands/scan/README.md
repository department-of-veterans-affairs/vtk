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
vtk scan repo                      # Scan current directory
vtk scan repo /path/to/repo        # Scan specific path
vtk scan repo -r                   # Recursive scan (default depth: 5)
vtk scan repo -r --depth=10        # Recursive with custom depth
vtk scan repo -r --depth=0         # Recursive with unlimited depth
vtk scan repo -v                   # Verbose output (show each lockfile)
vtk scan repo --refresh            # Force refresh package list
vtk scan repo --json               # JSON output
vtk scan repo -r --json            # JSONL output (streaming)
vtk scan repo --quiet              # Exit code only
```

**What it checks:**
- Lockfiles (package-lock.json, yarn.lock, pnpm-lock.yaml) against 1,600+ known compromised packages
- Backdoor workflows (.github/workflows/discussion.yaml)
- Secrets extraction workflows (.github/workflows/formatter_*.yml)

**Exit codes:**
- `0` - Clean
- `1` - Compromised packages found
- `2` - Backdoor workflow found

**Output formats:**

JSON (`--json`) - Single JSON object for non-recursive scans:
```json
{"path":"/repo","status":"CLEAN","packages_scanned":2595,"compromised_packages":[],...}
```

JSONL (`-r --json`) - One JSON line per lockfile as scanned (streaming):
```
{"lockfile":"/repo/yarn.lock","packages_scanned":2595,"status":"CLEAN","compromised_packages":[]}
{"lockfile":"/repo/app/package-lock.json","packages_scanned":100,"status":"CLEAN","compromised_packages":[]}
{"type":"summary","status":"CLEAN","total_packages_scanned":2695,...}
```

## Data Sources

The compromised packages list is fetched from [Cobenian/shai-hulud-detect](https://github.com/Cobenian/shai-hulud-detect) and cached locally for 24 hours.

**Cache location:** `$XDG_CACHE_HOME/vtk/compromised-packages.txt` (defaults to `~/.cache/vtk/`)

## Standalone Scripts

Both scan commands are available as standalone shell scripts that work without vtk installed. These are useful for CI/CD pipelines or machines without Ruby.

```bash
# Machine scan
./scripts/shai-hulud-machine-check.sh
./scripts/shai-hulud-machine-check.sh --json

# Repo scan
./scripts/shai-hulud-repo-check.sh /path/to/repo
./scripts/shai-hulud-repo-check.sh -r ~/Code    # Scan all projects
./scripts/shai-hulud-repo-check.sh -r --json    # JSONL output
```

## Known Limitations

- **pnpm-lock.yaml** - Parsing tested with pnpm v6/v7/v9; other versions may vary
- **node_modules** - Not scanned directly; lockfile is the source of truth (by design)
- **Short flags** - Cannot be combined in shell script (use `-r -j` not `-rj`)

## References

- [Datadog: Shai-Hulud 2.0 npm Worm](https://securitylabs.datadoghq.com/articles/shai-hulud-2.0-npm-worm/)
- [Cobenian/shai-hulud-detect](https://github.com/Cobenian/shai-hulud-detect)
- [VA Cleanup Playbook](https://department-of-veterans-affairs.github.io/eert/shai-hulud-dev-machine-cleanup-playbook)
