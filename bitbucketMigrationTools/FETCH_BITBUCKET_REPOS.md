# Bitbucket Repository Fetcher

Fetches repositories from a Bitbucket project and automatically generates `repos.txt` for the migration tool.

## Behavior Notes

- Project key matching is case-sensitive (`BT` and `bt` are different).
- The script follows Bitbucket pagination and reads all pages (`pagelen=100` per page).
- If the direct API project filter returns no repos, the script retries by fetching workspace repos and applying project-key filtering locally.

## Prerequisites

- `bash` 4.0+
- `curl`
- `jq` (install via `brew install jq` on macOS)
- Valid Bitbucket account with API token

## Setup

### 1. Generate Bitbucket API Token

1. Go to https://bitbucket.org/account/settings/app-passwords/
2. Click "Create app password"
3. Give it a name (e.g., "Migration Tool")
4. Grant permissions: `repository:read`
5. Copy the token

### 2. Make Script Executable

```bash
chmod +x bitbucketMigrationTools/fetch_bitbucket_repos.sh
```

## Usage

### Basic Usage

```bash
./bitbucketMigrationTools/fetch_bitbucket_repos.sh \
  --workspace <workspace-id> \
  --project <project-key> \
  --email <atlassian-email> \
  --token <api-token>
```

### With GitHub Organization

```bash
./bitbucketMigrationTools/fetch_bitbucket_repos.sh \
  --workspace my-workspace \
  --project MY-PROJ \
  --email user@example.com \
  --token abc123token \
  --github-org my-github-org \
  --output repos.txt
```

### All Options

| Option | Short | Required | Description |
|--------|-------|----------|-------------|
| `--workspace` | `-w` | ✓ | Bitbucket workspace ID |
| `--project` | `-p` | ✓ | Bitbucket project key |
| `--email` | `-e` | ✓ | Atlassian account email |
| `--token` | `-t` | ✓ | Bitbucket API token |
| `--output` | `-o` |  | Output file (default: `repos.txt`) |
| `--github-org` | `-g` |  | GitHub organization (auto-fills in repos.txt) |
| `--bitbucket-url` | `-u` |  | Base Bitbucket URL (default: `bitbucket.org`) |
| `--validate` |  |  | Validates that generated repos.txt matches API repo list |
| `--help` | `-h` |  | Show help message |

### Optional Validation Step

Use `--validate` to confirm that the generated `repos.txt` contains exactly the same repository names returned by the Bitbucket API.

```bash
./bitbucketMigrationTools/fetch_bitbucket_repos.sh \
  --workspace my-workspace \
  --project MY-PROJ \
  --email user@example.com \
  --token abc123token \
  --github-org my-github-org \
  --validate
```

Validation output includes:
- API repo count
- File repo count
- Missing repo names in `repos.txt` (if any)
- Extra repo names in `repos.txt` (if any)

## Example Workflow

### 1. Fetch Repositories

```bash
cd /path/to/github-repository-management-tools
./bitbucketMigrationTools/fetch_bitbucket_repos.sh \
  --workspace acme-corp \
  --project PLATFORM \
  --email dev@acme.com \
  --token your_token_here \
  --github-org acme-github
```

Output:
```
[2026-03-29 14:22:15] Fetching repositories from Bitbucket...
[2026-03-29 14:22:15] Workspace: acme-corp
[2026-03-29 14:22:15] Project: PLATFORM
[2026-03-29 14:22:16] Parsing response...
[2026-03-29 14:22:16] Found 5 repositories
[2026-03-29 14:22:16] Generating repos.txt...
[2026-03-29 14:22:16] ✓ Successfully generated repos.txt

Summary:
  Repositories: 5
  Output file: /path/to/repos.txt

Repositories found:
  - api-server
  - web-ui
  - data-processor
  - auth-service
  - analytics-lib

Next step: Run 'migrationTool/migrate_repos.sh repos.txt'
```

### 2. Review Generated File

```bash
cat repos.txt
```

Output:
```
# Bitbucket repositories for project: PLATFORM
# Generated: 2026-03-29 14:22:16
# Format: BITBUCKET_URL GITHUB_ORG GITHUB_REPO_NAME
#
https://bitbucket.org/acme-corp/api-server.git acme-github api-server
https://bitbucket.org/acme-corp/web-ui.git acme-github web-ui
https://bitbucket.org/acme-corp/data-processor.git acme-github data-processor
https://bitbucket.org/acme-corp/auth-service.git acme-github auth-service
https://bitbucket.org/acme-corp/analytics-lib.git acme-github analytics-lib
```

### 3. Run Migration

```bash
cd migrationTool
../bitbucketMigrationTools/fetch_bitbucket_repos.sh --workspace ... --project ... --email ... --token ... -o repos.txt
./migrate_repos.sh repos.txt
```

Or specify a different output location:

```bash
./bitbucketMigrationTools/fetch_bitbucket_repos.sh --workspace ... --project ... --email ... --token ... -o migrationTool/repos.txt
cd migrationTool
./migrate_repos.sh repos.txt
```

## Generated repos.txt Format

Each line contains:
```
<bitbucket_clone_url> <github_organization> <github_repo_name>
```

Example:
```
https://bitbucket.org/workspace/repo-name.git my-github-org repo-name
```

### Manual Edits

You can manually edit `repos.txt` before running migration:
- Change GitHub organization for specific repos
- Rename repos on GitHub (use different `<github_repo_name>`)
- Remove repos (delete the line)
- Add/modify repos (add new lines)

## Troubleshooting

### API Authentication Error

```
ERROR: API request failed with HTTP 401
```

**Solution:** Verify email and API token are correct.

### No Repositories Found

```
ERROR: No repositories found for project <key>
```

**Solutions:**
- Verify project key spelling (case-sensitive)
- Ensure API token has `repository:read` permissions
- Verify workspace has access to the project

### jq Not Found

```
ERROR: jq not found. Install it: brew install jq
```

**Solution:** Install jq with `brew install jq`

### Invalid JSON Response

```
ERROR: Failed to parse JSON response
```

**Solutions:**
- Verify Bitbucket API is accessible
- Check network connectivity
- Ensure API endpoint is correct

## Integration with migrate_repos.sh

This tool is designed as a separate, reusable module:

```
bitbucketMigrationTools/fetch_bitbucket_repos.sh → repos.txt → migrationTool/migrate_repos.sh
```

Benefits:
- ✓ Separation of concerns
- ✓ Fetch independently from migration
- ✓ Reusable for multiple projects
- ✓ Can be integrated into CI/CD pipelines

## Security Notes

- **Never commit** API tokens to version control
- Use environment variables for tokens in scripts:
  ```bash
  ./bitbucketMigrationTools/fetch_bitbucket_repos.sh \
    --workspace "$BB_WORKSPACE" \
    --project "$BB_PROJECT" \
    --email "$BB_EMAIL" \
    --token "$BB_TOKEN" \
    --github-org "$GH_ORG"
  ```
- Rotate API tokens regularly
- Use Bitbucket IP allowlisting if available

## Related Documents

- [Migration Tool Usage](../migrationTool/USAGE.md)
- [Architecture Overview](../docs/ARCHITECTURE.md)
