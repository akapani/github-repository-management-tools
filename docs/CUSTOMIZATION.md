# Customization Guide

This guide explains how to extend and customize the migration and archive tools.

## Common Customizations

### 1. Changing Repository Topics

**Migration Tool**: Topics applied to successfully migrated repos.

**Current Behavior**:
```bash
TOPIC_1="topic-example"
TOPIC_2="topic-example"
gh repo edit "$FULL_REPO" --add-topic "$TOPIC_1" --add-topic "$TOPIC_2"
```

**Customize**:
Edit `migrationTool/migrate_repos.sh`:
```bash
# Change these lines:
TOPIC_1="your-topic-1"
TOPIC_2="your-topic-2"
```

Or make topics dynamic based on repo name:
```bash
# Replace the topic assignment section with:
if [[ "$GH_REPO" =~ service$ ]]; then
  gh repo edit "$FULL_REPO" --add-topic "backend" --add-topic "service"
elif [[ "$GH_REPO" =~ ui$ ]]; then
  gh repo edit "$FULL_REPO" --add-topic "frontend" --add-topic "ui"
else
  gh repo edit "$FULL_REPO" --add-topic "api" --add-topic "default"
fi
```

### 2. Assigning Teams After Migration

**Goal**: Automatically grant team access to migrated repositories.

**Add to migrate_repos.sh** after successful migration (around line 140):
```bash
if [[ "$STATUS" == "SUCCESS" ]]; then
  # Add teams with specific roles
  gh repo edit "$FULL_REPO" --add-topic "$TOPIC_1" --add-topic "$TOPIC_2"
  
  # Grant team access
  gh repo add-collaborator "$FULL_REPO" \
    --permission "maintain" \
    --team "platform-team"
    
  log "Added platform-team as maintainers"
fi
```

### 3. Custom Validation Rules

**Goal**: Add extra validation beyond branch/tag parity.

**Example: Require minimum commits**:
```bash
# Add to migrate_repos.sh after destination counts (around line 130)

# Count commits
COMMIT_COUNT=$(git -C "$WORKDIR" rev-list --count --all)
log "Commit count: $COMMIT_COUNT"

if [[ $COMMIT_COUNT -lt 10 ]]; then
  STATUS="FAIL_VALIDATION"
  ERROR_MSG="Insufficient commits ($COMMIT_COUNT < 10)"
  log "Validation FAILED: $ERROR_MSG"
fi
```

**Example: Require specific branch names**:
```bash
# Add after branch/tag validation
REQUIRED_BRANCHES=("main" "develop")
for required_branch in "${REQUIRED_BRANCHES[@]}"; do
  if ! git -C "$WORKDIR" show-ref --verify "refs/heads/$required_branch" >/dev/null 2>&1; then
    STATUS="FAIL_VALIDATION"
    ERROR_MSG="Missing required branch: $required_branch"
    log "Validation FAILED: $ERROR_MSG"
  fi
done
```

### 4. Adding Retry Logic

**Goal**: Retry failed migrations automatically.

**Wrap migration steps** (around line 105):
```bash
RETRY_COUNT=0
MAX_RETRIES=3

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
  {
    # Existing clone, push, validation logic here...
    git clone --mirror "$BB_URL" "$WORKDIR" >/dev/null
    # ... rest of migration steps
    break  # Success, exit loop
  } || {
    RETRY_COUNT=$((RETRY_COUNT + 1))
    log "Attempt $RETRY_COUNT failed, retrying..."
    rm -rf "$WORKDIR" 2>/dev/null || true
    sleep 5
  }
done

if [[ $RETRY_COUNT -eq $MAX_RETRIES ]]; then
  STATUS="FAIL"
  ERROR_MSG="Failed after $MAX_RETRIES attempts"
  log "ERROR: $ERROR_MSG"
fi
```

### 5. Filtering Branches Before Migration

**Goal**: Migrate only certain branches (e.g., skip old release branches).

**Add filter** in archive tool or after clone:
```bash
# After git clone --mirror, before push:

# Remove unwanted refs
git -C "$WORKDIR" for-each-ref "refs/heads/" | while read sha ref; do
  # Skip branches matching pattern
  if [[ $ref =~ release/old ]]; then
    git -C "$WORKDIR" update-ref -d "$ref"
    log "Skipped: $ref"
  fi
done
```

### 6. Parallel Execution

**Goal**: Run migration on multiple repos in parallel (caveat: complex debugging).

**Split repos.txt and run multiple instances**:
```bash
# Create splits
split -l 10 repos.txt repos_batch_

# Run in parallel (background)
for batch in repos_batch_*; do
  ./migrate_repos.sh "$batch" &
done
wait

# Merge CSV reports
echo "run_id,timestamp,bitbucket_url,..." > merged_report.csv
tail -n +2 reports/migration_report_*.csv >> merged_report.csv
```

⚠️ **Warning**: Parallel execution makes debugging harder. Stick to sequential until you understand the scripts.

### 7. Modifying GitHub Repository Settings

**Goal**: Set additional repository configuration after migration.

**Add to migrate_repos.sh** after successful migration:
```bash
if [[ "$STATUS" == "SUCCESS" ]]; then
  # Disable issues if not needed
  gh repo edit "$FULL_REPO" --enable-issues=false
  
  # Disable projects
  gh repo edit "$FULL_REPO" --enable-projects=false
  
  # Set description
  gh repo edit "$FULL_REPO" \
    --description "Migrated from Bitbucket on $(date)"
    
  log "Repository settings configured"
fi
```

### 8. Conditional Actions in Archive Tool

**Goal**: Archive repos based on custom conditions.

**Example: Only archive old repos** (modify `archive_repos.sh`):
```bash
# Query repo creation date
CREATED_DATE=$(gh repo view "$FULL_REPO" --json createdAt --jq '.createdAt')

# Calculate days old
DAYS_OLD=$(( ($(date +%s) - $(date -d "$CREATED_DATE" +%s)) / 86400 ))

if [[ $DAYS_OLD -gt 365 ]]; then
  log "Repo created $DAYS_OLD days ago, archiving"
  # Continue with archive...
else
  log "Repo only $DAYS_OLD days old, skipping"
  continue
fi
```

### 9. Integration with Slack/Teams

**Goal**: Notify team of migration progress.

**Add webhook call** (after each migration or at end):
```bash
# Set your webhook URL
WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

notify_webhook() {
  local repo=$1
  local status=$2
  
  curl -X POST "$WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -d "{
      \"text\": \"Repository migration: $repo - $status\",
      \"color\": \"$([ \"$status\" = \"SUCCESS\" ] && echo \"good\" || echo \"danger\")\"
    }"
}

# Call after each repo:
notify_webhook "$FULL_REPO" "$STATUS"
```

### 10. Pre/Post Migration Hooks

**Goal**: Run custom scripts before/after migration.

**Add to migrate_repos.sh**:
```bash
# Before migration
if [[ -x "./hooks/pre-migrate.sh" ]]; then
  log "Running pre-migration hook"
  ./hooks/pre-migrate.sh "$BB_URL" "$FULL_REPO" || log "Pre-hook failed (non-fatal)"
fi

# Perform migration...

# After migration
if [[ -x "./hooks/post-migrate.sh" ]] && [[ "$STATUS" == "SUCCESS" ]]; then
  log "Running post-migration hook"
  ./hooks/post-migrate.sh "$FULL_REPO" || log "Post-hook failed (non-fatal)"
fi
```

**Create `hooks/post-migrate.sh`**:
```bash
#!/usr/bin/env bash
REPO=$1
# Custom setup: configure CI/CD, apply policies, etc.
echo "Post-processing $REPO"
```

---

## Performance Tuning

### 1. Increase Mirror Clone Timeout

If clones time out on large repos, add timeout handling:
```bash
# Wrap clone with timeout
timeout 600 git clone --mirror "$BB_URL" "$WORKDIR" >/dev/null || {
  ERROR_MSG="Clone timeout or failed"
  STATUS="FAIL"
  log "ERROR: $ERROR_MSG"
}
```

### 2. Limit Concurrent Git Operations

If you parallel-execute, limit concurrency:
```bash
MAX_PARALLEL=5
RUNNING=0

for repo in $(cat "$INPUT_FILE"); do
  while [[ $RUNNING -ge $MAX_PARALLEL ]]; do
    wait -n  # Wait for any background job
    RUNNING=$((RUNNING - 1))
  done
  
  migrate_single_repo "$repo" &
  RUNNING=$((RUNNING + 1))
done

wait  # Wait for all remaining jobs
```

---

## Debugging & Development

### 1. Enable Debug Output

Add debug mode to scripts:
```bash
# Add near the top of the script
DEBUG="${DEBUG:-0}"

debug() {
  if [[ "$DEBUG" -eq 1 ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

# Use it:
debug "FULL_REPO=$FULL_REPO"
debug "SOURCE_URL=$BB_URL"

# Run with:
# DEBUG=1 ./migrate_repos.sh repos.txt
```

### 2. Extract Shared Functions

If creating multiple related scripts, extract shared functions to `lib/common.sh`:

```bash
# lib/common.sh
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
csv_escape() { ... }
count_remote_heads() { ... }

# Then source in scripts:
# source lib/common.sh
```

### 3. Test with Single Repository

When developing changes, test with one repo first:
```bash
# Create test_single.txt with just one entry
./migrate_repos.sh test_single.txt

# Review logs before running full batch
cat logs/migration_*.log
cat reports/migration_report_*.csv
```

---

## Adding New Tools

### Template for New Tool

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
INPUT_FILE="${1:-repos.txt}"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="logs"
REPORT_DIR="reports"
LOG_FILE="${LOG_DIR}/tool_${RUN_ID}.log"
CSV_FILE="${REPORT_DIR}/tool_report_${RUN_ID}.csv"

mkdir -p "$LOG_DIR" "$REPORT_DIR"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

csv_escape() {
  local s="${1:-}"
  s="${s//\"/\"\"}"
  printf "\"%s\"" "$s"
}

# Preconditions
command -v gh >/dev/null || { echo "ERROR: gh not found"; exit 1; }
[[ -f "$INPUT_FILE" ]] || { echo "ERROR: $INPUT_FILE not found"; exit 1; }

# CSV header
echo "run_id,timestamp,..." > "$CSV_FILE"

log "Starting tool..."

while read -r OWNER REPO; do
  [[ -z "${OWNER:-}" || "$OWNER" =~ ^# ]] && continue
  
  # Your tool logic here
  
done < "$INPUT_FILE"

log "Complete"
log "Report: $CSV_FILE"
```

---

## Best Practices

1. **Always test with `--dry-run` first** (if applicable)
2. **Test with small dataset before production run**
3. **Preserve logs for audit trail**
4. **Keep customizations in separate files** (don't modify core scripts)
5. **Document your changes** in CHANGELOG.md
6. **Use `shellcheck`** to validate bash syntax
7. **Test error scenarios** (remove network, wrong credentials, etc.)
8. **Version control your `repos.txt`** files for reproducibility
