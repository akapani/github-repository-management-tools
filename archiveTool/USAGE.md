# Archive Tool – Usage Guide

Archive or unarchive GitHub repositories in bulk with safety controls and audit logging.

## Quick Start

For the impatient:

```bash
# 1. Create repos.txt with OWNER REPO on each line
# 2. Run dry-run first
./archive_repos.sh --dry-run repos.txt  # Preview what will happen

# 3. Review logs/archive_*.log and reports/archive_report_*.csv
# 4. Archive for real
./archive_repos.sh repos.txt

# Or unarchive:
./archive_repos.sh --unarchive repos.txt
```

⏱️ **Typical time per repository**: 1–2 seconds

---

## Prerequisites

Before running the script, ensure:

- GitHub CLI (`gh`) is installed
- You are authenticated:
  ```bash
  gh auth login
  ```
- You have admin permissions on the target repositories

---

## Repository Structure

Key files in the project:

```text
github-repository-migration-tools/
├── archiveTool/
│   ├── archive_repos.sh    ← This script
│   ├── repos.txt           ← Your input file
│   └── USAGE.md
├── examples/               ← Template repos.txt files
├── docs/                   ← Guides (ARCHITECTURE, CUSTOMIZATION, etc.)
├── README.md
└── [other root files]
```

Outputs are created automatically:
- `logs/archive_*.log` – Detailed execution logs
- `reports/archive_report_*.csv` – Summary in CSV format

---

## Input File: `repos.txt`

The script operates **only** on repositories listed in `repos.txt`.

### Format

```text
OWNER REPO
```

### Example

```text
apptium b2bmp-test1
apptium appdemo-blank
apptium axidlg-blank
```

Notes:
- One repository per line
- Lines starting with `#` are ignored
- Repositories not listed will never be touched

---

## Dry-Run Mode (Recommended First)

```bash
./archive_repos.sh --dry-run repos.txt
```

What this does:
- Reads all repos from `repos.txt`
- Checks whether each repo is currently archived
- Prints what **would** happen
- Writes logs and a CSV report
- **Makes no changes in GitHub**

---

## Archive Repositories

```bash
./archive_repos.sh repos.txt
```

Behavior:
- Repos that are already archived are skipped
- Active repos in the list are archived
- Logs and a CSV report are generated

---

## Unarchive Repositories

### Dry‑run unarchive
```bash
./archive_repos.sh --unarchive --dry-run repos.txt
```

### Execute unarchive
```bash
./archive_repos.sh --unarchive repos.txt
```

---

## Output Files

Each run produces:

```text
logs/archive_YYYYMMDD_HHMMSS.log
reports/archive_report_YYYYMMDD_HHMMSS.csv
```

These outputs can be used for:
- audit evidence
- change records
- internal review

---

## Safety Guarantees

- No repository is modified unless explicitly listed
- `--dry-run` is always available
- The script is idempotent and safe to re‑run
- Archiving is reversible via `--unarchive`

---

## Recommended Workflow

1. Prepare `repos.txt`
2. Run `--dry-run`
3. Review logs and CSV
4. Run the real command
5. Store outputs as evidence

---

## Exit Codes

| Code | Meaning |
|------|----------|
| `0` | Success (all repos processed; check CSV for individual status) |
| `1` | Precondition failed (missing GitHub CLI, not authenticated, file not found) |

⚠️ **Note**: Individual repo failures don't halt the script (idempotent). Check CSV/logs for per-repo status.

---

## Troubleshooting

- **"No action needed"**: Repo is already in the requested state
- **Permission denied**: Ensure `gh auth login` ran and you have admin access
- **Command failed**: Check logs for specific errors

For detailed troubleshooting, see [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md).

---

## How It Works

For technical details on the archive process, see [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md).
