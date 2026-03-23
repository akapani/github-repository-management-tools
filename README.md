# Repo Migration Tool

## Overview

**Repo Migration Tool** is a source-agnostic, script-based utility for migrating Git repositories at scale with **validation, reporting, and governance** built in.

It is designed for:
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

## Getting Started

See **USAGE.md** for step-by-step instructions and copy-paste examples.

---

## Customization

Common extensions include:
- Assigning GitHub team access post-migration
- Adding retries or parallel execution
- Supporting additional SCM providers
- Custom validation rules

The script is intentionally readable and hackable.

---

## Disclaimer

- Migrations are **non-destructive** to source repositories
- Always test with a small set of repos first
- Follow your organization’s change-management policies
