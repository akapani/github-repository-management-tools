# Usage Guide

This guide provides **copy-paste examples** to help new users quickly migrate repositories using this tool.

---

## Prerequisites

Ensure the following are installed:

- **Git** (2.x or newer)
- **GitHub CLI (`gh`)**
- Access to source repositories
- Permission to create repositories in the target GitHub org

Authenticate to GitHub:

```bash
gh auth login
```

---

## Repository Layout

```text
repo-migration-tool/
├── migrate_repos.sh
├── repos.txt
├── logs/
├── reports/
├── README.md
└── USAGE.md
```

---

## Step 1: Create `repos.txt`

Each line represents **one repository migration**.

### Format

```text
SOURCE_CLONE_URL GITHUB_ORG GITHUB_REPO
```

### Example (dummy data)

```text
https://example-user@bitbucket.org/example-workspace/order-service.git example-org order-service
https://example-user@bitbucket.org/example-workspace/payment-service.git example-org payment-service
```

Notes:
- Space-separated values
- Lines starting with `#` are ignored
- Source and destination repo names do not have to match

---

## Step 2: Make the Script Executable

```bash
chmod +x migrate_repos.sh
```

---

## Step 3: Run the Migration

```bash
./migrate_repos.sh repos.txt
```

During execution:
- You may be prompted for source SCM credentials
- GitHub authentication is handled via `gh auth`

---

## Step 4: Review Outputs

After completion, two artifacts are generated:

### Logs
```text
logs/migration_YYYYMMDD_HHMMSS.log
```

### CSV Report
```text
reports/migration_report_YYYYMMDD_HHMMSS.csv
```

The CSV includes:
- Source repo
- Destination repo
- Branch and tag counts (source vs destination)
- Status: `SUCCESS`, `FAIL`, or `FAIL_VALIDATION`

---

## Validation Behavior

A repo is marked **SUCCESS** only if:
- Migration completes
- Branch counts match
- Tag counts match

Failures are documented in both the log and CSV.

---

## Re-running the Script

The script is **idempotent**:
- Existing GitHub repos are reused
- Mirror pushes safely overwrite refs
- Failed repos can be fixed and re-run

---

## Common Customizations

Users often customize:
- Topics applied to repos
- Validation rules
- Target GitHub org
- Access assignment (teams/collaborators)

See `README.md` for design details.
