# Contributing

Thank you for your interest in contributing! This document outlines guidelines for developing and maintaining these tools.

## Code Style

### Bash Scripts

- Use `#!/usr/bin/env bash` shebang
- Always use `set -euo pipefail` at the script start:
  - `set -e`: Exit on error
  - `set -u`: Exit on undefined variables
  - `set -o pipefail`: Exit if any command in a pipeline fails
- Quote all variables: `"$var"` not `$var`
- Use 2-space indentation
- Comment complex logic and edge cases

### Shell Linting

Run `shellcheck` on all scripts before committing:

```bash
shellcheck migrationTool/*.sh archiveTool/*.sh
```

Install `shellcheck` if needed:
```bash
# macOS
brew install shellcheck

# Linux
sudo apt-get install shellcheck
```

## Testing

### Manual Testing

1. Create a test `repos.txt` with a small subset of repositories
2. Run with `--dry-run` first to verify behavior
3. Inspect logs in `logs/` and CSV reports in `reports/`  
4. Run the actual command only after validation

### Test Fixtures

Use files in `tests/fixtures/` for consistent test scenarios.

## Modifications & Extensions

Common customizations:

- **Topics**: Edit `TOPIC_1` and `TOPIC_2` variables in `migrate_repos.sh`
- **Topics**: Source from `lib/common.sh` if extending to library
- **Authentication**: Ensure `gh auth login` is run before script execution
- **Parallel Execution**: Wrap repo loop iterations in background jobs (not tested)
- **Custom Validation**: Add validation rules after line ~140 in `migrate_repos.sh`

## Documentation

- Update `README.md` for major feature changes
- Update tool-specific `USAGE.md` for command/flag changes
- Add entries to `CHANGELOG.md` for user-visible changes
- Update `docs/ARCHITECTURE.md` for internal logic changes

## Submitting Changes

1. Create a feature branch: `git checkout -b feature/your-feature-name`
2. Make changes and test thoroughly
3. Run `shellcheck` to validate scripts
4. Update relevant documentation
5. Commit with clear messages
6. Submit a pull request with description

## Reporting Issues

- Describe the problem clearly
- Include steps to reproduce
- Attach log files and CSV reports if relevant
- Note your environment (OS, Git version, gh CLI version)

## Questions?

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) or [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for more information.
