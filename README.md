# GitHub Repository Management Tools

Shell scripts for two GitHub repository operations:
- Bulk Git mirror migration into GitHub
- Bulk archive / unarchive of existing GitHub repositories

This repository is intentionally simple: plain Bash, `git`, and `gh` with log + CSV output for auditability.

## What This Repo Actually Does

### 1) Migration Tool (`migrationTool/migrate_repos.sh`)

The migration script:
- Reads `SOURCE_URL GITHUB_ORG GITHUB_REPO` from an input file
- Creates destination GitHub repositories if they do not exist (`--private`)
- Runs `git clone --mirror` and `git push --mirror`
- Validates branch and tag counts (source vs destination)
- Applies configured topics only when validation succeeds
- Writes detailed logs and a CSV report

### 2) Archive Tool (`archiveTool/archive_repos.sh`)

The archive script:
- Reads `OWNER REPO` from an input file
- Supports `archive` (default) or `--unarchive`
- Supports `--dry-run` for no-change previews
- Skips repositories already in the requested state
- Writes detailed logs and a CSV report

## What These Tools Do Not Do

- They do not migrate pull requests, issues, permissions, webhooks, or CI settings
- They do not run in parallel (processing is sequential)
- They do not manage credentials for you
- The migration script currently has no `--dry-run` mode

## Prerequisites

- `git`
- GitHub CLI `gh`
- `gh auth login` completed
- Access to source repos (for migration) and GitHub org/repo admin rights (for archive actions)

## Quick Start

### Migration

```bash
cd migrationTool
./migrate_repos.sh repos.txt
```

`repos.txt` format:

```text
SOURCE_CLONE_URL GITHUB_ORG GITHUB_REPO
```

Example:

```text
https://bitbucket.org/workspace/service-a.git my-org service-a
https://gitlab.com/group/service-b.git my-org service-b
```

### Archive / Unarchive

```bash
cd archiveTool

# Preview archive changes
./archive_repos.sh --dry-run repos.txt

# Apply archive
./archive_repos.sh repos.txt

# Preview unarchive
./archive_repos.sh --unarchive --dry-run repos.txt

# Apply unarchive
./archive_repos.sh --unarchive repos.txt
```

`repos.txt` format:

```text
OWNER REPO
```

## Output Artifacts

Both tools generate:
- `logs/<tool>_YYYYMMDD_HHMMSS.log`
- `reports/<tool>_report_YYYYMMDD_HHMMSS.csv`

Run from the script directory or repo root depending on where you want output folders created.

## Status Values

Migration CSV status values:
- `SUCCESS`
- `FAIL`
- `FAIL_VALIDATION`

Archive CSV status values:
- `SUCCESS`
- `FAIL`

## Docs

- Migration usage: [migrationTool/USAGE.md](migrationTool/USAGE.md)
- Archive usage: [archiveTool/USAGE.md](archiveTool/USAGE.md)
- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Customization: [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md)
- Troubleshooting: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- Contributing: [CONTRIBUTING.md](CONTRIBUTING.md)

## License

[MIT](LICENSE)
