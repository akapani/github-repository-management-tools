#!/usr/bin/env bash
set -euo pipefail

# Defaults
ACTION="archive"
DRY_RUN=false
INPUT_FILE="repos.txt"

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --unarchive)
      ACTION="unarchive"
      shift
      ;;
    *)
      INPUT_FILE="$1"
      shift
      ;;
  esac
done

RUN_ID="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="logs"
REPORT_DIR="reports"
LOG_FILE="${LOG_DIR}/archive_${RUN_ID}.log"
CSV_FILE="${REPORT_DIR}/archive_report_${RUN_ID}.csv"

mkdir -p "$LOG_DIR" "$REPORT_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

csv_escape() {
  local s="${1:-}"
  s="${s//\"/\"\"}"
  printf "\"%s\"" "$s"
}

# Preconditions
command -v gh >/dev/null || { echo "ERROR: gh CLI not found"; exit 1; }
gh auth status >/dev/null || { echo "ERROR: gh not authenticated"; exit 1; }
[[ -f "$INPUT_FILE" ]] || { echo "ERROR: $INPUT_FILE not found"; exit 1; }

# CSV header
echo "run_id,timestamp,owner,repo,previous_state,action,executed,status,error" > "$CSV_FILE"

log "Starting repo $ACTION run"
log "Dry-run mode: $DRY_RUN"
log "Input file: $INPUT_FILE"

while read -r OWNER REPO; do
  [[ -z "${OWNER:-}" || "$OWNER" =~ ^# ]] && continue

  FULL_REPO="${OWNER}/${REPO}"
  TS="$(date '+%Y-%m-%d %H:%M:%S')"
  STATUS="SUCCESS"
  ERROR_MSG=""
  EXECUTED="false"

  IS_ARCHIVED=$(gh repo view "$FULL_REPO" --json isArchived --jq '.isArchived')

  log "Repo: $FULL_REPO (archived=$IS_ARCHIVED)"

  SHOULD_ACT=false
  if [[ "$ACTION" == "archive" && "$IS_ARCHIVED" == "false" ]]; then
    SHOULD_ACT=true
  elif [[ "$ACTION" == "unarchive" && "$IS_ARCHIVED" == "true" ]]; then
    SHOULD_ACT=true
  fi

  if [[ "$SHOULD_ACT" == "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log "[DRY-RUN] Would $ACTION $FULL_REPO"
    else
      if gh repo "$ACTION" "$FULL_REPO" --yes >>"$LOG_FILE" 2>&1; then
        log "$ACTION completed for $FULL_REPO"
        EXECUTED="true"
      else
        STATUS="FAIL"
        ERROR_MSG="$ACTION failed"
        log "ERROR: $ACTION failed for $FULL_REPO"
      fi
    fi
  else
    log "No action needed for $FULL_REPO"
  fi

  {
    echo -n "$(csv_escape "$RUN_ID"),"
    echo -n "$(csv_escape "$TS"),"
    echo -n "$(csv_escape "$OWNER"),"
    echo -n "$(csv_escape "$REPO"),"
    echo -n "$(csv_escape "$IS_ARCHIVED"),"
    echo -n "$(csv_escape "$ACTION"),"
    echo -n "$(csv_escape "$EXECUTED"),"
    echo -n "$(csv_escape "$STATUS"),"
    echo    "$(csv_escape "$ERROR_MSG")"
  } >> "$CSV_FILE"

done < "$INPUT_FILE"

log "Run complete"
log "CSV report: $CSV_FILE"
``