#!/usr/bin/env bash
# Common utility functions for migration and archive tools
# Usage: source lib/common.sh

# Logging function: outputs to both stdout and log file
# Usage: log "Message here"
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# CSV escaping: handles quotes and wraps field in quotes
# Usage: csv_escape "field value with \"quotes\""
csv_escape() {
  local s="${1:-}"
  s="${s//\"/\"\"}"  # Escape any embedded quotes
  printf "\"%s\"" "$s"
}

# Count local branches in current directory (bare repo)
# Usage: count_local_heads
# Returns: Number of branches
count_local_heads() {
  git for-each-ref --format='%(refname)' refs/heads | wc -l | tr -d ' '
}

# Count local tags in current directory (bare repo)
# Usage: count_local_tags
# Returns: Number of tags
count_local_tags() {
  git for-each-ref --format='%(refname)' refs/tags | wc -l | tr -d ' '
}

# Count remote branches without cloning
# Usage: count_remote_heads "https://github.com/owner/repo.git"
# Returns: Number of branches, or empty string if query fails
count_remote_heads() {
  # Counts remote heads. If auth is required, this will fail and be handled.
  git ls-remote --heads "$1" 2>/dev/null | wc -l | tr -d ' '
}

# Count remote tags without cloning
# Filters out dereferenced annotated tag lines (ending with ^{})
# Usage: count_remote_tags "https://github.com/owner/repo.git"
# Returns: Number of tags, or empty string if query fails
count_remote_tags() {
  git ls-remote --tags "$1" 2>/dev/null | grep -v '\^{}' | wc -l | tr -d ' '
}

# Verify GitHub CLI is installed and authenticated
# Usage: verify_gh_authenticated
# Returns: 0 if authenticated, 1 if not, exits with error message
verify_gh_authenticated() {
  if ! command -v gh >/dev/null; then
    echo "ERROR: gh (GitHub CLI) not found"
    return 1
  fi
  
  if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: gh not authenticated. Run: gh auth login"
    return 1
  fi
  
  return 0
}

# Verify Git is installed
# Usage: verify_git_installed
# Returns: 0 if installed, 1 if not, exits with error message
verify_git_installed() {
  if ! command -v git >/dev/null; then
    echo "ERROR: git not found"
    return 1
  fi
  
  return 0
}

# Verify input file exists and is readable
# Usage: verify_input_file "repos.txt"
# Returns: 0 if readable, 1 if not, exits with error message
verify_input_file() {
  local input_file="$1"
  
  if [[ ! -f "$input_file" ]]; then
    echo "ERROR: Input file not found: $input_file"
    return 1
  fi
  
  if [[ ! -r "$input_file" ]]; then
    echo "ERROR: Input file not readable: $input_file"
    return 1
  fi
  
  return 0
}

# Ensure log and report directories exist
# Usage: ensure_output_dirs "logs" "reports"
ensure_output_dirs() {
  local log_dir="${1:-logs}"
  local report_dir="${2:-reports}"
  
  mkdir -p "$log_dir" "$report_dir" || {
    echo "ERROR: Failed to create output directories"
    return 1
  }
  
  return 0
}

# Git status check: verify local mirror repository is valid
# Usage: is_git_repo "/path/to/repo.git"
# Returns: 0 if valid git repo, 1 if not
is_git_repo() {
  local repo_path="$1"
  
  if [[ ! -d "$repo_path" ]]; then
    return 1
  fi
  
  git -C "$repo_path" rev-parse --is-bare-repository >/dev/null 2>&1
}

# Cleanup temporary directory (best effort)
# Usage: cleanup_workdir "/path/to/workdir.git"
cleanup_workdir() {
  local workdir="$1"
  
  if [[ -d "$workdir" ]]; then
    rm -rf "$workdir" 2>/dev/null || log "Warning: Could not fully clean up $workdir"
  fi
}

# Parse YES/NO user input with retry
# Usage: ask_confirm "Do you want to continue?"
# Returns: 0 for yes, 1 for no
ask_confirm() {
  local prompt="$1"
  local response
  
  read -p "$prompt (yes/no): " response
  
  case "$response" in
    [yY][eE][sS])
      return 0
      ;;
    [nN][oO])
      return 1
      ;;
    *)
      echo "Please answer yes or no"
      ask_confirm "$prompt"
      ;;
  esac
}

# Format duration in seconds to human-readable string
# Usage: format_duration 125
# Output: 2m 5s
format_duration() {
  local seconds="$1"
  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))
  local secs=$((seconds % 60))
  
  if [[ $hours -gt 0 ]]; then
    echo "${hours}h ${minutes}m ${secs}s"
  elif [[ $minutes -gt 0 ]]; then
    echo "${minutes}m ${secs}s"
  else
    echo "${secs}s"
  fi
}

# Retry command with exponential backoff
# Usage: retry 3 some_command arg1 arg2
# Returns: command exit code
retry() {
  local max_attempts="$1"
  shift
  local attempt=1
  
  while [[ $attempt -le $max_attempts ]]; do
    if "$@"; then
      return 0
    fi
    
    if [[ $attempt -lt $max_attempts ]]; then
      local wait_time=$((2 ** (attempt - 1)))
      log "Attempt $attempt failed. Retrying in ${wait_time}s..."
      sleep "$wait_time"
    fi
    
    attempt=$((attempt + 1))
  done
  
  log "Command failed after $max_attempts attempts"
  return 1
}
