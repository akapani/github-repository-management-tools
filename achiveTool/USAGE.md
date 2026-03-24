# Archive Repositories – Usage Guide

This tool allows you to **archive or unarchive GitHub repositories in bulk** using an explicit input list, with safety controls and audit output.

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

## Dry‑Run Mode (Recommended First)

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
