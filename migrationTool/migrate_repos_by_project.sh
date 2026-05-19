#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_usage() {
  cat <<'EOF'
Usage: ./migrate_repos_by_project.sh [INPUT_FILE] [--topics "topic1,topic2"] [--topics-map FILE] [--dry-run]

Input format (space-separated):
  BITBUCKET_URL GITHUB_ORG GITHUB_REPO [PROJECT_KEY]

Topic options:
  --topics "topic1,topic2,..."
      Global fallback topics for repos without a project mapping.
  --topics-map FILE
      Per-project topic mapping file. Format:
        PROJECT_KEY topic1,topic2,topic3
  --dry-run
      Preview actions only. No repo create, clone, push, or topic edits are performed.

Examples:
  ./migrate_repos_by_project.sh repos.txt
  ./migrate_repos_by_project.sh repos.txt --topics "migration,bitbucket"
  ./migrate_repos_by_project.sh repos.txt --topics-map project_topics.txt --topics "migration"
  ./migrate_repos_by_project.sh repos.txt --topics-map project_topics.txt --topics "migration" --dry-run
EOF
}

INPUT_FILE=""
TOPICS_MAP_FILE=""
GLOBAL_TOPICS_CSV=""
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_usage
      exit 0
      ;;
    --topics)
      [[ $# -lt 2 ]] && { echo "ERROR: --topics requires a value"; exit 1; }
      GLOBAL_TOPICS_CSV="$2"
      shift 2
      ;;
    --topics-map)
      [[ $# -lt 2 ]] && { echo "ERROR: --topics-map requires a file path"; exit 1; }
      TOPICS_MAP_FILE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "ERROR: Unknown option: $1"
      print_usage
      exit 1
      ;;
    *)
      if [[ -z "$INPUT_FILE" ]]; then
        INPUT_FILE="$1"
      else
        echo "ERROR: Unexpected argument: $1"
        print_usage
        exit 1
      fi
      shift
      ;;
  esac
done

INPUT_FILE="${INPUT_FILE:-${SCRIPT_DIR}/repos.txt}"
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

# Default topics if --topics is not provided
DEFAULT_TOPICS_CSV="topic-example,topic-example,topic-example"

# --- Helpers ---
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

csv_escape() {
  # Escape double quotes for CSV and wrap field in quotes
  local s="${1:-}"
  s="${s//\"/\"\"}"
  printf "\"%s\"" "$s"
}

normalize_topics() {
  # Convert comma/space-delimited topics to a clean space-delimited list.
  local raw="${1:-}"
  local out=""
  local topic

  raw="${raw//,/ }"
  for topic in $raw; do
    [[ -n "$topic" ]] && out+="${topic} "
  done

  printf "%s" "${out% }"
}

topics_for_project() {
  local project_key="${1:-}"
  local mapping_line=""

  if [[ -n "$project_key" && -n "$TOPICS_MAP_FILE" && -f "$TOPICS_MAP_FILE" ]]; then
    mapping_line="$(awk -v key="$project_key" '
      /^[[:space:]]*#/ { next }
      NF == 0 { next }
      $1 == key {
        $1 = ""
        sub(/^[ \t]+/, "")
        print
      }
    ' "$TOPICS_MAP_FILE" | tail -n1)"
  fi

  if [[ -n "$mapping_line" ]]; then
    normalize_topics "$mapping_line"
  else
    normalize_topics "$GLOBAL_TOPICS_CSV"
  fi
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

if [[ -n "$TOPICS_MAP_FILE" ]]; then
  # If a relative map path was provided and doesn't exist in CWD,
  # try resolving it relative to the script directory.
  if [[ ! "$TOPICS_MAP_FILE" = /* && ! -f "$TOPICS_MAP_FILE" && -f "${SCRIPT_DIR}/$TOPICS_MAP_FILE" ]]; then
    TOPICS_MAP_FILE="${SCRIPT_DIR}/$TOPICS_MAP_FILE"
  fi

  if [[ ! -f "$TOPICS_MAP_FILE" ]]; then
    echo "ERROR: Topics map file not found: $TOPICS_MAP_FILE"
    exit 1
  fi
fi

GLOBAL_TOPICS_CSV="${GLOBAL_TOPICS_CSV:-$DEFAULT_TOPICS_CSV}"

# --- CSV header ---
{
  echo "run_id,timestamp,bitbucket_url,github_repo,project_key,repo_created,src_branch_count,dst_branch_count,src_tag_count,dst_tag_count,topics_used,topics_applied,status,error_message"
} > "$CSV_FILE"

log "Starting migration run_id=$RUN_ID"
log "Input: $INPUT_FILE"
log "Global fallback topics: $(normalize_topics "$GLOBAL_TOPICS_CSV")"
[[ -n "$TOPICS_MAP_FILE" ]] && log "Topics map: $TOPICS_MAP_FILE"
log "Dry-run: $DRY_RUN"
log "CSV report: $CSV_FILE"

# --- Main loop ---
CURRENT_PROJECT_KEY=""
while read -r BB_URL GH_ORG GH_REPO PROJECT_KEY; do
  # Skip blanks/comments
  [[ -z "${BB_URL:-}" ]] && continue

  if [[ "$BB_URL" =~ ^# ]]; then
    if [[ "$BB_URL" =~ ^#[[:space:]]*Bitbucket[[:space:]]repositories[[:space:]]for[[:space:]]project:[[:space:]](.+)$ ]]; then
      CURRENT_PROJECT_KEY="${BASH_REMATCH[1]}"
      log "Detected project section: $CURRENT_PROJECT_KEY"
    fi
    continue
  fi

  if [[ -z "${GH_ORG:-}" || -z "${GH_REPO:-}" ]]; then
    log "Skipping malformed input line: '$BB_URL ${GH_ORG:-} ${GH_REPO:-} ${PROJECT_KEY:-}'"
    continue
  fi

  EFFECTIVE_PROJECT_KEY="${PROJECT_KEY:-$CURRENT_PROJECT_KEY}"

  FULL_REPO="${GH_ORG}/${GH_REPO}"
  WORKDIR="${GH_REPO}.git"
  REPO_TOPICS="$(topics_for_project "$EFFECTIVE_PROJECT_KEY")"
  REPO_TOPICS_CSV="${REPO_TOPICS// /;}"

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
  [[ -n "$EFFECTIVE_PROJECT_KEY" ]] && log "Project key: $EFFECTIVE_PROJECT_KEY"
  log "Topics selected: ${REPO_TOPICS:-<none>}"

  if [[ "$DRY_RUN" == "true" ]]; then
    STATUS="DRY_RUN"
    ERROR_MSG="Preview only: no migration actions executed"
    log "DRY RUN: would ensure repo exists, mirror clone/push, validate counts, and apply topics."
    if [[ -n "$REPO_TOPICS" ]]; then
      log "DRY RUN: would apply topics: $REPO_TOPICS"
    else
      log "DRY RUN: no topics configured for this repo"
    fi
  else

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
          if [[ -n "$REPO_TOPICS" ]]; then
            log "Applying topics: $REPO_TOPICS"
            TOPIC_ARGS=()
            for topic in $REPO_TOPICS; do
              TOPIC_ARGS+=(--add-topic "$topic")
            done
            gh repo edit "$FULL_REPO" "${TOPIC_ARGS[@]}" >/dev/null
            TOPICS_APPLIED="true"
          else
            log "No topics configured for this repo; skipping topic assignment."
          fi

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
  fi

  # Write CSV row
  {
    echo -n "$(csv_escape "$RUN_ID"),"
    echo -n "$(csv_escape "$TS"),"
    echo -n "$(csv_escape "$BB_URL"),"
    echo -n "$(csv_escape "$FULL_REPO"),"
    echo -n "$(csv_escape "$EFFECTIVE_PROJECT_KEY"),"
    echo -n "$(csv_escape "$REPO_CREATED"),"
    echo -n "$(csv_escape "$SRC_BRANCHES"),"
    echo -n "$(csv_escape "$DST_BRANCHES"),"
    echo -n "$(csv_escape "$SRC_TAGS"),"
    echo -n "$(csv_escape "$DST_TAGS"),"
    echo -n "$(csv_escape "$REPO_TOPICS_CSV"),"
    echo -n "$(csv_escape "$TOPICS_APPLIED"),"
    echo -n "$(csv_escape "$STATUS"),"
    echo    "$(csv_escape "$ERROR_MSG")"
  } >> "$CSV_FILE"

  log "Result: $FULL_REPO -> $STATUS"

done < "$INPUT_FILE"

log "All done."
log "CSV: $CSV_FILE"
log "Log: $LOG_FILE"
