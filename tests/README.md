# Testing Guide

This directory contains test fixtures and validation scripts for the migration and archive tools.

## Test Fixtures

### `fixtures/sample_migration.txt`

Sample repository list for testing the migration tool. Contains dummy entries for validation.

**Usage**:
```bash
./migrate_repos.sh fixtures/sample_migration.txt --dry-run
```

### `fixtures/sample_archive.txt`

Sample repository list for testing the archive tool with real GitHub repos.

**Usage**:
```bash
./archive_repos.sh --dry-run fixtures/sample_archive.txt
```

## Running Tests

Before running tests, ensure the sample files are configured with real repositories you own or have access to.

### 1. Validate Script Syntax

```bash
# Install shellcheck if needed
brew install shellcheck  # macOS
sudo apt-get install shellcheck  # Ubuntu

# Check scripts for issues
shellcheck migrationTool/migrate_repos.sh
shellcheck archiveTool/archive_repos.sh
shellcheck lib/common.sh
```

### 2. Run with --dry-run

**Always start with dry-run mode**:

```bash
# Test migration (dry-run, no changes)
./migrationTool/migrate_repos.sh tests/fixtures/sample_migration.txt

# Test archive (dry-run, no changes)
./archiveTool/archive_repos.sh --dry-run tests/fixtures/sample_archive.txt

# Review outputs
cat logs/migration_*.log
cat logs/archive_*.log
cat reports/*.csv
```

### 3. Manual Testing Checklist

When testing a new environment or changes:

- [ ] Git is installed: `git --version`
- [ ] GitHub CLI is installed: `gh --version`
- [ ] GitHub CLI is authenticated: `gh auth status`
- [ ] Test with one repository first
- [ ] Verify logs are created: `ls logs/`
- [ ] Verify CSV reports are valid: `cat reports/*.csv`
- [ ] Test idempotency: run the same command twice, should succeed both times
- [ ] Test with invalid input file: should fail gracefully
- [ ] Test without authentication: should fail with clear error

## Integration Tests

For more comprehensive testing, consider:

1. **Test with a staging GitHub org** (create a test org for this)
2. **Test with a small set of test repos** (not production repos)
3. **Validate CSV output** with a spreadsheet application
4. **Check logs for errors** and timestamps

## Performance Testing

For large migrations:

```bash
# Time a test run
time ./migrationTool/migrate_repos.sh test_repos_large.txt

# Monitor system resources
# macOS: Activity Monitor
# Linux: top, htop

# Check script I/O
# macOS: fs_usage ./migrationTool/migrate_repos.sh
# Linux: strace ./migrationTool/migrate_repos.sh
```

## Continuous Integration

Example GitHub Actions workflow (`.github/workflows/test.yml`):

```yaml
name: Lint & Test

on: [push, pull_request]

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install shellcheck
        run: sudo apt-get install shellcheck
      - name: Lint scripts
        run: |
          shellcheck migrationTool/migrate_repos.sh
          shellcheck archiveTool/archive_repos.sh
          shellcheck lib/common.sh
```

## Adding New Tests

To add a new test:

1. Create fixture file in `tests/fixtures/`
2. Document the test scenario
3. Add to the testing checklist above
4. Validate manually first with `--dry-run`

---

For detailed development information, see [CONTRIBUTING.md](../CONTRIBUTING.md).
