# Migration Tool – Usage Guide

Migrate Git repositories from any source (Bitbucket, GitLab, etc.) to GitHub at scale with validation and audit logging.

## Quick Start

For the impatient:

```bash
# 1. Create repos.txt with SOURCE_URL OWNER REPO on each line
# 2. Run dry-run first
./migrate_repos.sh repos.txt --dry-run  # Preview what will happen

# 3. Review logs/migration_*.log and reports/migration_report_*.csv
# 4. Run for real
./migrate_repos.sh repos.txt
```

⏱️ **Typical time per repository**: 30–120 seconds (depends on size and network)

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
github-repository-migration-tools/
├── README.md
├── LICENSE
├── CHANGELOG.md
├── CONTRIBUTING.md
├── .editorconfig
├── .gitignore
│
├── migrationTool/
│   ├── migrate_repos.sh       (Main script)
│   ├── repos.txt              (Your input file)
│   └── USAGE.md
│
├── archiveTool/
│   ├── archive_repos.sh       (Main script)
│   ├── repos.txt              (Your input file)
│   └── USAGE.md
│
├── examples/
│   ├── repos_migration_example.txt
│   ├── repos_archive_example.txt
│   └── repos_unarchive_example.txt
│
├── docs/
│   ├── TROUBLESHOOTING.md      (Common issues)
│   ├── ARCHITECTURE.md         (How it works)
│   └── CUSTOMIZATION.md        (How to extend)
│
├── lib/
│   └── common.sh              (Shared utilities)
│
├── tests/
│   ├── README.md              (Testing guide)
│   └── validate_*.sh          (Output validators)
│
├── logs/                       (Generated on first run)
└── reports/                    (Generated on first run)
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

## Exit Codes

| Code | Meaning |
|------|----------|
| `0` | Success (all repos processed; check CSV for individual status) |
| `1` | Precondition failed (missing tools, no auth, file not found) |

⚠️ **Note**: Individual repo failures don't halt the script. Check CSV/logs for per-repo status.

---

## Troubleshooting

- **Git clone fails**: Check source repo access, SSH keys, or personal access tokens
- **Branch/tag count mismatch**: Network interruption or source repo changed during migration
- **Permission denied**: Ensure `gh auth login` ran and you have access to target org

For detailed troubleshooting, see [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md).

---

## Customization

Common extensions:
- Assign teams with `gh repo add-collaborator`
- Filter branches during migration
- Add retry logic for large/slow repos
- Integrate with Slack/Teams for notifications

See [docs/CUSTOMIZATION.md](../docs/CUSTOMIZATION.md) for examples.

---

## How It Works

For technical details on the migration process, see [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md).
