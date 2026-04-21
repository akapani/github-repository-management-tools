#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT_FILE="${1:-${SCRIPT_DIR}/repos.txt}"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="${SCRIPT_DIR}/logs"
REPORT_DIR="${SCRIPT_DIR}/reports"
LOG_FILE="${LOG_DIR}/migration_${RUN_ID}.log"
CSV_FILE="${REPORT_DIR}/migration_report_${RUN_ID}.csv"

# If a relative input path was provided and doesn't exist in CWD,
# try resolving it relative to the script directory.
if [[ ! "$INPUT_FILE" = /* && ! -f "$INPUT_FILE" && -f "${SCRIPT_DIR}/$INPUT_FILE" ]]; then
  INPUT_FILE="${SCRIPT_DIR}/$INPUT_FILE"
fi

# Ensure output directories exist
mkdir -p "$LOG_DIR" "$REPORT_DIR"

# Topics to apply to every successfully validated repo
TOPIC_1="topic-example"
TOPIC_2="topic-example"
TOPIC_3="topic-example"

# --- Helpers ---
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

csv_escape() {
  # Escape double quotes for CSV and wrap field in quotes
  local s="${1:-}"
  s="${s//\"/\"\"}"
  printf "\"%s\"" "$s"
}

count_local_heads() { git for-each-ref --format='%(refname)' refs/heads | wc -l | tr -d ' '; }
count_local_tags()  { git for-each-ref --format='%(refname)' refs/tags  | wc -l | tr -d ' '; }

count_remote_heads() {
  # Counts remote heads. If auth is required, this will fail and be handled.
  git ls-remote --heads "$1" 2>/dev/null | wc -l | tr -d ' '
}
count_remote_tags() {
  # Counts remote tags. We filter out dereferenced annotated tag lines ending with ^{}
  git ls-remote --tags "$1" 2>/dev/null | grep -v '\^{}' | wc -l | tr -d ' '
}

# --- Preconditions ---
command -v git >/dev/null || { echo "ERROR: git not found"; exit 1; }
command -v gh  >/dev/null || { echo "ERROR: gh (GitHub CLI) not found"; exit 1; }

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh not authenticated. Run: gh auth login"
  exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "ERROR: Input file not found: $INPUT_FILE"
  exit 1
fi

# --- CSV header ---
{
  echo "run_id,timestamp,bitbucket_url,github_repo,repo_created,src_branch_count,dst_branch_count,src_tag_count,dst_tag_count,topics_applied,status,error_message"
} > "$CSV_FILE"

log "Starting migration run_id=$RUN_ID"
log "Input: $INPUT_FILE"
log "Topics: $TOPIC_1, $TOPIC_2, $TOPIC_3"
log "CSV report: $CSV_FILE"

# --- Main loop ---
while read -r BB_URL GH_ORG GH_REPO; do
  # Skip blanks/comments
  [[ -z "${BB_URL:-}" ]] && continue
  [[ "$BB_URL" =~ ^# ]] && continue

  FULL_REPO="${GH_ORG}/${GH_REPO}"
  WORKDIR="${GH_REPO}.git"

  TS="$(date +'%Y-%m-%d %H:%M:%S')"
  REPO_CREATED="false"
  TOPICS_APPLIED="false"
  STATUS="FAIL"
  ERROR_MSG=""

  SRC_BRANCHES=""
  SRC_TAGS=""
  DST_BRANCHES=""
  DST_TAGS=""

  log "------------------------------------------------------------"
  log "Repo: $FULL_REPO"
  log "Source: $BB_URL"

  # Wrap each repo in a subshell so failures don't abort the entire run
  {
    # 1) Create repo if missing
    if gh repo view "$FULL_REPO" >/dev/null 2>&1; then
      log "Repo exists: $FULL_REPO"
    else
      log "Creating repo (private): $FULL_REPO"
      gh repo create "$FULL_REPO" --private --confirm >/dev/null
      REPO_CREATED="true"
      log "Created: $FULL_REPO"
    fi

    # 2) Mirror clone from Bitbucket
    rm -rf "$WORKDIR" 2>/dev/null || true
    log "Cloning mirror..."
    if ! git clone --mirror "$BB_URL" "$WORKDIR" >/dev/null; then
      STATUS="FAIL"
      ERROR_MSG="Failed to clone from $BB_URL"
      log "ERROR: $ERROR_MSG"
    else
      pushd "$WORKDIR" >/dev/null

      # Source counts from local mirror
      SRC_BRANCHES="$(count_local_heads)"
      SRC_TAGS="$(count_local_tags)"
      log "Source counts -> branches=$SRC_BRANCHES tags=$SRC_TAGS"

      # 3) Mirror push to GitHub
      log "Pushing mirror to GitHub..."
      git remote remove github >/dev/null 2>&1 || true
      git remote add github "https://github.com/${FULL_REPO}.git"
      git push --mirror github >/dev/null

      # 4) Destination counts from remote
      DST_BRANCHES="$(count_remote_heads "https://github.com/${FULL_REPO}.git")"
      DST_TAGS="$(count_remote_tags  "https://github.com/${FULL_REPO}.git")"
      log "Dest counts   -> branches=$DST_BRANCHES tags=$DST_TAGS"

      # 5) Validate counts
      if [[ "$SRC_BRANCHES" == "$DST_BRANCHES" && "$SRC_TAGS" == "$DST_TAGS" ]]; then
        log "Validation PASSED (branch/tag counts match)."

        # 6) Apply topics only after validation success
        log "Applying topics: $TOPIC_1, $TOPIC_2, $TOPIC_3"
        gh repo edit "$FULL_REPO" --add-topic "$TOPIC_1" --add-topic "$TOPIC_2" --add-topic "$TOPIC_3" >/dev/null
        TOPICS_APPLIED="true"
        STATUS="SUCCESS"
      else
        STATUS="FAIL_VALIDATION"
        ERROR_MSG="Branch/tag count mismatch: src(branches=$SRC_BRANCHES,tags=$SRC_TAGS) dst(branches=$DST_BRANCHES,tags=$DST_TAGS)"
        log "Validation FAILED: $ERROR_MSG"
      fi

      popd >/dev/null
    fi
  } 2> >(tee -a "$LOG_FILE" >&2) || {
    # Any error inside the subshell ends up here
    STATUS="${STATUS:-FAIL}"
    ERROR_MSG="${ERROR_MSG:-Unexpected error during migration steps (see log)}"
    log "ERROR: $ERROR_MSG"
  }

  # Cleanup (best-effort)
  rm -rf "$WORKDIR" 2>/dev/null || true

  # Write CSV row
  {
    echo -n "$(csv_escape "$RUN_ID"),"
    echo -n "$(csv_escape "$TS"),"
    echo -n "$(csv_escape "$BB_URL"),"
    echo -n "$(csv_escape "$FULL_REPO"),"
    echo -n "$(csv_escape "$REPO_CREATED"),"
    echo -n "$(csv_escape "$SRC_BRANCHES"),"
    echo -n "$(csv_escape "$DST_BRANCHES"),"
    echo -n "$(csv_escape "$SRC_TAGS"),"
    echo -n "$(csv_escape "$DST_TAGS"),"
    echo -n "$(csv_escape "$TOPICS_APPLIED"),"
    echo -n "$(csv_escape "$STATUS"),"
    echo    "$(csv_escape "$ERROR_MSG")"
  } >> "$CSV_FILE"

  log "Result: $FULL_REPO -> $STATUS"

done < "$INPUT_FILE"

log "All done."
log "CSV: $CSV_FILE"
log "Log: $LOG_FILE"
``