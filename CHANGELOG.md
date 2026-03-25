# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Enhanced error handling with standardized bash flags (`set -euo pipefail`)
- Automatic creation of `logs/` and `reports/` directories
- Folder name consistency fix: `achiveTool/` → `archiveTool/`
- Documentation improvements (CONTRIBUTING.md, .editorconfig)
- Example repository configurations
- Shared library functions in `lib/common.sh`
- Comprehensive troubleshooting and architecture documentation
- Test fixtures and validation scripts

### Changed
- Standardized directory structure across tools
- Improved bash script consistency

### Fixed
- Typo in tools directory naming

## [1.0.0] - 2025-03-24

### Added
- Initial release
- `migrate_repos.sh` for Git repository migrations
- `archive_repos.sh` for bulk archiving/unarchiving of repositories
- Audit logging and CSV reporting
- Validation for branch and tag parity
- Support for dry-run execution
