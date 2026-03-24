# Repo Migration Tool

**Source-agnostic, script-based utility for migrating Git repositories at scale** with validation, reporting, and governance built in.

## Quick Links

- 🚀 **[Migration Tool Docs](migrationTool/USAGE.md)** – Migrate repos from Bitbucket, GitLab, etc. to GitHub
- 📦 **[Archive Tool Docs](archiveTool/USAGE.md)** – Archive/unarchive repos in bulk
- ❓ **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** – Common issues and solutions
- 🏗️ **[Architecture Guide](docs/ARCHITECTURE.md)** – How the tools work internally
- 🔧 **[Customization Guide](docs/CUSTOMIZATION.md)** – Extend and customize for your needs
- 📋 **[Contributing Guide](CONTRIBUTING.md)** – Development guidelines
- 📄 **[License](LICENSE)** – MIT License
- 📝 **[Changelog](CHANGELOG.md)** – Version history and updates

## Table of Contents

- [Overview](#overview)
- [Key Principles](#key-principles)
- [What Gets Migrated](#what-gets-migrated)
- [What Does Not Get Migrated](#what-does-not-get-migrated)
- [How It Works](#how-it-works-high-level)
- [Security Model](#security-model)
- [Intended Audience](#intended-audience)
- [Tools Included](#tools-included)
- [Getting Started](#getting-started)
- [Customization](#customization)
- [Contributing](#contributing)
- [Disclaimer](#disclaimer)

## Overview

**Repo Migration Tool** is designed for:
- Enterprise repository migrations
- Platform / DevOps automation
- Anyone who wants a deterministic alternative to UI-based imports

The tool is intentionally simple, transparent, and easy to extend.

---

## Key Principles

- ✅ Uses **native Git operations** only
- ✅ Scales to dozens or hundreds of repositories
- ✅ Produces **audit-friendly artifacts** (logs + CSV)
- ✅ Keeps **authentication external** (no secrets stored)
- ✅ Safe to publish and reuse publicly

---

## What Gets Migrated

This tool migrates **Git data only**, including:

- Commits and full history
- All branches
- All tags
- Commit authorship and timestamps

This is the **same Git data** transferred by standard UI-based imports.

---

## What Does *Not* Get Migrated

The following are **not part of Git** and are intentionally excluded:

- Pull requests and reviews
- Issues and comments
- Repository permissions
- Webhooks and integrations
- CI/CD pipelines

These items must be handled separately after migration.

---

## How It Works (High Level)

1. Read repositories from `repos.txt`
2. Create target GitHub repos if missing
3. `git clone --mirror` from source
4. `git push --mirror` to destination
5. Validate branch and tag parity
6. Apply standardized topics
7. Write logs and a CSV report

---

## Security Model

**This repository contains no credentials or secrets.**

Authentication is handled externally via:
- GitHub CLI (`gh auth login`)
- Source SCM credentials (e.g., Bitbucket App Passwords or SSH)

This makes the project safe for public use.

---

## Intended Audience

- DevOps / Platform Engineers
- IT Operations teams
- Open-source users performing SCM migrations
- Anyone who needs repeatable, validated repo migration

---

## Tools Included

### 1. Migration Tool (`migrationTool/migrate_repos.sh`)

Migrate Git repositories from any source to GitHub with full history, branches, and tags.

**Features**:
- Mirror clone with full history preservation
- Branch and tag count validation
- Automatic topic application
- Detailed audit logs and CSV reports
- Idempotent (safe to retry)

**Quick start**: See [migrationTool/USAGE.md](migrationTool/USAGE.md)

### 2. Archive Tool (`archiveTool/archive_repos.sh`)

Archive or unarchive GitHub repositories in bulk based on an explicit list.

**Features**:
- Dry-run mode for safety
- Bulk archive or unarchive operations
- Audit logging and CSV reports
- Idempotent (safe to retry)
- Reversible (archive ↔ unarchive)

**Quick start**: See [archiveTool/USAGE.md](archiveTool/USAGE.md)

---

## Getting Started

See **USAGE.md** for step-by-step instructions and copy-paste examples.

---

## Customization

Common extensions include:
- Assigning GitHub team access post-migration
- Adding retries or parallel execution
- Supporting additional SCM providers
- Custom validation rules

**For detailed customization examples**, see [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md).

The scripts are intentionally readable and designed to be extended.

---

## Troubleshooting

**Common issues**:
- `git not found` – Install Git from https://git-scm.com
- `gh not found` – Install GitHub CLI from https://cli.github.com
- `gh not authenticated` – Run `gh auth login`
- `Permission denied` – Ensure you have access to target organization

**For detailed troubleshooting**, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

---

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Code style and shell best practices
- Testing and validation
- Submitting changes
- Reporting issues

---

## Additional Resources

- **How it works**: [Architecture Guide](docs/ARCHITECTURE.md) explains internals
- **Extending**: [Customization Guide](docs/CUSTOMIZATION.md) has examples
- **Stuck?**: [Troubleshooting Guide](docs/TROUBLESHOOTING.md) covers common issues

---

## Disclaimer

- Migrations are **non-destructive** to source repositories
- Always test with a small set of repos first
- Follow your organization's change-management policies

---

**License**: [MIT](LICENSE)  
**Author**: Generated as part of GitHub repository migration automation
