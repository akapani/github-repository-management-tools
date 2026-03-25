# Architecture Guide

This document explains how the migration and archive tools work internally.

## Overview

Both tools are **simple, deterministic shell scripts** that:
1. Read a manifest file (`repos.txt`)
2. Process each repository with explicit error handling
3. Generate audit-friendly logs and CSV reports
4. Exit with clear error codes

## Migration Tool (`migrate_repos.sh`)

### High-Level Flow

```
1. Parse input (repos.txt)
2. For each repository:
   a. Create GitHub repo if needed
   b. Clone mirror from source (git clone --mirror)
   c. Validate source branch/tag counts
   d. Push mirror to GitHub (git push --mirror)
   e. Validate destination branch/tag counts
   f. Apply topics (only if validation passes)
3. Write CSV report and logs
```

### Key Functions

#### `count_local_heads()` and `count_local_tags()`
- Count branches and tags in local mirror clone
- Used for **source** counts
- Runs inside the mirror directory (`refs/heads`, `refs/tags`)

#### `count_remote_heads()` and `count_remote_tags()`
- Query remote repository without cloning
- Used for **destination** GitHub repository validation
- Uses `git ls-remote --heads` and `git ls-remote --tags`
- Filters annotated tag derefs (`^{}`)

#### Validation Logic
- Compares source branch count with destination branch count
- Compares source tag count with destination tag count
- Only proceeds to `gh repo edit` if both match
- Marks as `FAIL_VALIDATION` if counts don't match (safe fallback)

### Error Handling

- **Subshell wrapping**: Each repo wrapped in `{ ... } 2> >(tee)` to isolate failures
- **Explicit error capture**: `|| { STATUS=FAIL; ... }`
- **Cleanup**: Mirror directories removed after processing (best-effort)
- **Idempotency**: Existing GitHub repos are reused; mirror push is safe to retry

### CSV Report Columns

| Column | Values | Meaning |
|--------|--------|---------|
| `run_id` | `YYYYMMDD_HHMMSS` | Execution timestamp |
| `timestamp` | ISO format | When each repo was processed |
| `bitbucket_url` | URL | Source repository URL |
| `github_repo` | `owner/repo` | Destination repository |
| `repo_created` | `true`/`false` | Was GitHub repo created? |
| `src_branch_count` | number | Branches in source |
| `dst_branch_count` | number | Branches in destination |
| `src_tag_count` | number | Tags in source |
| `dst_tag_count` | number | Tags in destination |
| `topics_applied` | `true`/`false` | Were topics applied? |
| `status` | `SUCCESS`/`FAIL`/`FAIL_VALIDATION` | Final result |
| `error_message` | string | Details if failed |

### Failure Modes

1. **`FAIL`**: Error during clone, push, or GitHub operations
2. **`FAIL_VALIDATION`**: Branch/tag counts don't match
3. **`SUCCESS`**: All steps passed, topics applied

---

## Archive Tool (`archive_repos.sh`)

### High-Level Flow

```
1. Parse flags (--unarchive, --dry-run)
2. Parse input (repos.txt)
3. For each repository:
   a. Query current archive status via GitHub API
   b. Determine if action is needed
   c. Execute action (if not --dry-run)
4. Write CSV report and logs
```

### State Machine

```
Action=archive, IS_ARCHIVED=false  → Execute "gh repo archive"
Action=archive, IS_ARCHIVED=true   → Skip (no-op)
Action=unarchive, IS_ARCHIVED=true → Execute "gh repo unarchive"
Action=unarchive, IS_ARCHIVED=false → Skip (no-op)
```

### Dry-Run Mode

When `--dry-run` is active:
- All state checks run normally
- `EXECUTED` column shows `false`
- No `gh repo archive/unarchive` commands are executed
- Safe to run multiple times for validation

### CSV Report Columns

| Column | Values | Meaning |
|--------|--------|---------|
| `run_id` | `YYYYMMDD_HHMMSS` | Execution timestamp |
| `timestamp` | ISO format | When each repo was processed |
| `owner` | string | Repository owner |
| `repo` | string | Repository name |
| `previous_state` | `true`/`false` | Was archived before? |
| `action` | `archive`/`unarchive` | What we tried to do |
| `executed` | `true`/`false` | Did we actually execute? |
| `status` | `SUCCESS`/`FAIL` | Did it work? |
| `error` | string | Error details if failed |

### Error Handling

- **Early validation**: Check `gh` exists and is authenticated before loop
- **Per-repo error capture**: Errors don't halt other repos
- **Explicit state checking**: Query before acting (safe for idempotency)
- **Dry-run safety**: All checks run, but no mutations

---

## Shared Patterns

### Error Detection

Both scripts use:
```bash
set -euo pipefail
```

- `set -e`: Exit on any error
- `set -u`: Fail on undefined variables
- `set -o pipefail`: Return non-zero if ANY command in pipeline fails

### Logging

```bash
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
```

- Logs to both **stdout** (visible during run) and **file** (persistent)
- Timestamps every message for audit trail

### CSV Escaping

```bash
csv_escape() {
  local s="${1:-}"
  s="${s//\"/\"\"}"  # Escape quotes
  printf "\"%s\"" "$s"  # Wrap in quotes
}
```

- Handles embedded quotes in error messages
- Prevents CSV format breakage

### Directory Structure

```
logs/               ← All script logs
reports/            ← All CSV reports
migrationTool/      ← Migration scripts and repos.txt
archiveTool/        ← Archive scripts and repos.txt
examples/           ← Template repos.txt files
```

---

## Input File Format

### `repos.txt` Parsing

Both scripts:
1. Read lines sequentially
2. Skip blank lines: `[[ -z "${FIELD:-}" ]]`
3. Skip comments: `[[ "$FIELD" =~ ^# ]]`
4. Split on whitespace: `read -r FIELD1 FIELD2 ...`

### Migration repos.txt
```
SOURCE_URL GITHUB_ORG GITHUB_REPO
https://bitbucket.org/example/repo.git   my-org   my-repo
# Comments are ignored
```

### Archive repos.txt
```
OWNER REPO
my-org legacy-repo
# Comments are ignored
```

---

## Git Operations

### Mirror Operations

**Mirror Clone** (`git clone --mirror`):
- Creates bare repository with all refs
- Preserves `.git/config` from source
- Efficient for bulk migration

**Mirror Push** (`git push --mirror`):
- Pushes all refs (branches, tags, notes)
- Atomic (all-or-nothing push)
- Overwrites destination safely

### Remote Queries

**`git ls-remote --heads`**:
- Lists all branches without cloning
- Output: `SHA1 refs/heads/BRANCH_NAME`

**`git ls-remote --tags`**:
- Lists all tags without cloning
- Includes annotated tag derefs (`SHA1 refs/tags/TAG_NAME^{}`)
- Filtered with `grep -v '\^{}'` to count actual tags

---

## GitHub API Integration

### Authentication

Scripts rely on **GitHub CLI authentication**:
```bash
gh auth status  # Verify authenticated
```

- Token stored in `~/.config/gh/hosts.yml`
- No secrets in repo
- User responsible for authentication setup

### Operations

**Create Repository**:
```bash
gh repo create OWNER/REPO --private --confirm
```

**Check Repository Exists**:
```bash
gh repo view OWNER/REPO  # Returns 0 if exists
```

**Query Repository State**:
```bash
gh repo view OWNER/REPO --json isArchived --jq '.isArchived'
```

**Add Topics**:
```bash
gh repo edit OWNER/REPO --add-topic TOPIC1 --add-topic TOPIC2
```

**Archive/Unarchive**:
```bash
gh repo archive OWNER/REPO --yes
gh repo unarchive OWNER/REPO --yes
```

---

## Performance Characteristics

### Time Complexity

- **Migration**: O(N × T) where N = number of repos, T = time per repo
  - T includes: clone time + push time + API calls
  - T typically 30-120 seconds per repo depending on size
  
- **Archive**: O(N × T) where T is much smaller (~1-2 seconds per repo)
  - Just API queries and state changes

### Scaling

- **Sequential processing**: No parallelization (safe, auditable)
- **Idempotent**: Can resume failed repos without side effects
- **Batch-friendly**: Can split `repos.txt` for parallel execution (multiple script instances)

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success (all repos processed) |
| `1` | Precondition failed (missing tools, no auth, file not found) |

Note: Individual repo failures don't halt the script. Check CSV/logs for specific repo status.
