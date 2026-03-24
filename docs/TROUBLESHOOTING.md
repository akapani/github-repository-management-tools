# Troubleshooting Guide

This guide covers common issues and their solutions.

## Git-Related Issues

### "ERROR: git not found"
- **Cause**: Git is not installed or not in PATH
- **Solution**: Install Git from https://git-scm.com or via package manager
  ```bash
  # macOS
  brew install git
  
  # Ubuntu/Debian
  sudo apt-get install git
  ```

### "git clone --mirror" fails with authentication errors
- **Cause**: Source repository requires authentication, credentials not provided
- **Solution**:
  1. Ensure you have access to the source repository
  2. Configure Git credentials:
     ```bash
     git config --global user.name "Your Name"
     git config --global user.email "your.email@example.com"
     ```
  3. For SSH: Ensure SSH keys are added to ssh-agent
     ```bash
     ssh-add ~/.ssh/id_rsa
     ```
  4. For HTTPS: Use personal access tokens instead of passwords
  5. Test connectivity before running full migration:
     ```bash
     git ls-remote --heads <SOURCE_URL>
     ```

---

## GitHub CLI Issues

### "ERROR: gh (GitHub CLI) not found"
- **Cause**: GitHub CLI is not installed
- **Solution**: Install from https://cli.github.com or via package manager
  ```bash
  # macOS
  brew install gh
  
  # Ubuntu/Debian
  sudo apt-get install gh
  ```

### "ERROR: gh not authenticated"
- **Cause**: You haven't logged in to GitHub CLI yet
- **Solution**:
  ```bash
  gh auth login
  ```
  Follow the prompts to authenticate. Choose HTTPS or SSH as preferred.

### "Permission denied" errors when creating repos
- **Cause**: Your GitHub token doesn't have sufficient permissions
- **Solution**:
  1. Check your token scopes:
     ```bash
     gh auth status
     ```
  2. If needed, re-authenticate with proper scopes:
     ```bash
     gh auth logout
     gh auth login
     ```
  3. Ensure you have admin access to the target organization

---

## Migration Issues

### "Validation FAILED: Branch/tag count mismatch"
- **Cause**: Source and destination repositories have different branch/tag counts
- **Possible Reasons**:
  - Network interruption during push
  - Source repository was updated during migration
  - Destination repository restrictions (e.g., branch protection rules)
- **Solution**:
  1. Fix the source repository if it was modified
  2. Clean and retry:
     ```bash
     # Remove destination repo (if safe)
     gh repo delete <OWNER>/<REPO>
     
     # Re-run the migration for that repo
     ```
  3. Check logs for specific error details:
     ```bash
     cat logs/migration_*.log | grep -A5 "Repo: <OWNER>/<REPO>"
     ```

### "ERROR: Unexpected error during migration steps"
- **Cause**: Unspecified error in migration process
- **Solution**:
  1. Check the log file for detailed error messages:
     ```bash
     tail -50 logs/migration_*.log
     ```
  2. Verify prerequisites:
     - Source repository is accessible
     - Your GitHub org exists and you have permissions
     - Network connectivity is stable
  3. Try running with a single repository first for debugging
  4. Review the CSV report for the specific error:
     ```bash
     cat reports/migration_report_*.csv
     ```

### First run creates "logs/" and "reports/" directories
- **Expected behavior**: Scripts create these directories if missing
- **Note**: This is by design and ensures scripts are safe to run in any directory

---

## Archive/Unarchive Issues

### "No action needed for <REPO>"
- **Cause**: Repository is already in the requested state
  - Running `--archive` on already-archived repo
  - Running `--unarchive` on an already-active repo
- **Solution**: Check the CSV report to confirm expected state
  ```bash
  cat reports/archive_report_*.csv | grep <REPO>
  ```

### Dry-run shows different results than actual run
- **Cause**: Possible race condition if repo state changed between runs
- **Solution**:
  1. Run dry-run again to confirm state
  2. Update repos.txt if needed
  3. Run the actual command

---

## Output Issues

### CSV report is malformed or hard to read
- **Solution**: Open with a spreadsheet application:
  ```bash
  # macOS
  open reports/archive_report_*.csv
  
  # Linux
  libreoffice reports/archive_report_*.csv
  ```

### Logs are too verbose or truncated
- **Solution**: Filter logs by repository or status:
  ```bash
  # Find all errors for a specific repo
  grep "<REPO>" logs/migration_*.log
  
  # Show only ERROR lines
  grep "ERROR" logs/migration_*.log
  
  # Count SUCCESS vs FAIL
  grep "Result:" logs/migration_*.log | sort | uniq -c
  ```

---

## Performance Issues

### Script runs very slowly with many repositories
- **Cause**: Sequential processing of repos (expected behavior)
- **Cause**: Network latency or GitHub API rate limiting
- **Solution**:
  1. Check your internet connection
  2. GitHub CLI has rate limits; wait 1 hour if you hit the limit
  3. For large migrations, consider:
     - Running during off-peak hours
     - Splitting repos.txt into smaller batches
     - Using `--dry-run` first to estimate time

---

## Getting Help

If you encounter an issue not listed here:

1. **Check the logs**: Most issues provide detailed error messages
   ```bash
   tail logs/migration_*.log
   tail logs/archive_*.log
   ```

2. **Review the CSV report** for structured error data:
   ```bash
   cat reports/migration_report_*.csv
   ```

3. **Check the documentation**:
   - [ARCHITECTURE.md](ARCHITECTURE.md) – How the tools work
   - [CUSTOMIZATION.md](CUSTOMIZATION.md) – How to extend the scripts
   - Tool-specific USAGE.md files

4. **Verify prerequisites** are installed and working:
   ```bash
   git --version
   gh --version
   gh auth status
   ```

5. **Report the issue** with:
   - Steps to reproduce
   - Log and CSV files
   - Output of `git --version` and `gh --version`
   - Your environment (OS, shell type)
