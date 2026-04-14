#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Bitbucket Repository Fetcher
# Fetches repositories from a Bitbucket project and generates repos.txt
# =============================================================================

# --- Usage ---
usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Fetch repositories from Bitbucket and generate repos.txt for migration.

OPTIONS:
  -w, --workspace ID              Bitbucket workspace ID (required)
  -p, --project KEY               Bitbucket project key (required)
  -e, --email EMAIL               Atlassian account email (required)
  -t, --token TOKEN               Bitbucket API token (required)
  -o, --output FILE               Output file (default: repos.txt)
  -u, --bitbucket-url URL         Base Bitbucket URL (default: bitbucket.org)
  -g, --github-org ORG            GitHub organization for all repos (optional)
  --validate                      Validate generated repos.txt against API results
  -h, --help                      Show this help message

EXAMPLE:
  $0 \\
    --workspace my-workspace \\
    --project MY-PROJ \\
    --email user@example.com \\
    --token abc123token \\
    --output repos.txt \\
    --github-org my-github-org

EOF
  exit "${1:-0}"
}

# --- Configuration ---
WORKSPACE_ID=""
PROJECT_KEY=""
EMAIL=""
API_TOKEN=""
OUTPUT_FILE="repos.txt"
BITBUCKET_URL="bitbucket.org"
GITHUB_ORG=""
VALIDATE_OUTPUT="false"

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--workspace)
      WORKSPACE_ID="$2"
      shift 2
      ;;
    -p|--project)
      PROJECT_KEY="$2"
      shift 2
      ;;
    -e|--email)
      EMAIL="$2"
      shift 2
      ;;
    -t|--token)
      API_TOKEN="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    -u|--bitbucket-url)
      BITBUCKET_URL="$2"
      shift 2
      ;;
    -g|--github-org)
      GITHUB_ORG="$2"
      shift 2
      ;;
    --validate)
      VALIDATE_OUTPUT="true"
      shift
      ;;
    -h|--help)
      usage 0
      ;;
    *)
      echo "ERROR: Unknown option: $1"
      usage 1
      ;;
  esac
done

# --- Validation ---
[[ -n "$WORKSPACE_ID" ]] || { echo "ERROR: Workspace ID required (-w/--workspace)"; usage 1; }
[[ -n "$PROJECT_KEY" ]] || { echo "ERROR: Project key required (-p/--project)"; usage 1; }
[[ -n "$EMAIL" ]] || { echo "ERROR: Email required (-e/--email)"; usage 1; }
[[ -n "$API_TOKEN" ]] || { echo "ERROR: API token required (-t/--token)"; usage 1; }

command -v jq >/dev/null || { echo "ERROR: jq not found. Install it: brew install jq"; exit 1; }

# --- Helpers ---
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
error() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2; }

fetch_repo_names_for_project() {
  local start_url="$1"
  local project_key="$2"
  local url="$start_url"
  local response http_code body page_names
  local collected=""

  # Follow Bitbucket pagination via the "next" URL until all pages are read.
  while [[ -n "$url" ]]; do
    response=$(curl -s --request GET \
      --url "$url" \
      --user "${EMAIL}:${API_TOKEN}" \
      -w "\n%{http_code}" 2>&1)

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" != "200" ]]; then
      error "API request failed with HTTP $http_code"
      error "Response: $body"
      return 1
    fi

    # Project key match is intentionally case-sensitive (e.g., BT != bt).
    page_names=$(echo "$body" | jq -r --arg project_key "$project_key" '
      .values[]?
      | select((.project.key // "") == $project_key)
      | .name
    ')

    if [[ -n "$page_names" ]]; then
      collected+="$page_names"$'\n'
    fi

    url=$(echo "$body" | jq -r '.next // empty')
  done

  printf "%s" "$collected"
}

validate_output_file() {
  local api_names file_names missing_in_file extra_in_file

  # Compare only repo names; URL/org columns are intentionally ignored here.
  api_names="$(printf "%s\n" "$REPO_NAMES" | sed '/^$/d' | sort -u)"
  file_names="$(awk '!/^#/ && NF>=3 {print $3}' "$OUTPUT_FILE" | sed '/^$/d' | sort -u)"

  missing_in_file="$(comm -23 <(printf "%s\n" "$api_names") <(printf "%s\n" "$file_names"))"
  extra_in_file="$(comm -13 <(printf "%s\n" "$api_names") <(printf "%s\n" "$file_names"))"

  log "Validation summary for $OUTPUT_FILE"
  log "  API repo count:  $(printf "%s\n" "$api_names" | sed '/^$/d' | wc -l | tr -d ' ')"
  log "  File repo count: $(printf "%s\n" "$file_names" | sed '/^$/d' | wc -l | tr -d ' ')"

  if [[ -z "$missing_in_file" && -z "$extra_in_file" ]]; then
    log "VALIDATION PASSED: repos.txt matches Bitbucket API repo list."
    return 0
  fi

  log "VALIDATION FAILED: repos.txt does not match Bitbucket API repo list."

  if [[ -n "$missing_in_file" ]]; then
    log "Missing in repos.txt:"
    printf "%s\n" "$missing_in_file" | sed 's/^/  - /'
  fi

  if [[ -n "$extra_in_file" ]]; then
    log "Extra in repos.txt:"
    printf "%s\n" "$extra_in_file" | sed 's/^/  - /'
  fi

  return 1
}

# --- Fetch Repositories ---
log "Fetching repositories from Bitbucket..."
log "Workspace: $WORKSPACE_ID"
log "Project: $PROJECT_KEY"

FILTERED_API_URL="https://api.bitbucket.org/2.0/repositories/${WORKSPACE_ID}?q=project.key%3D%22${PROJECT_KEY}%22&pagelen=100"
UNFILTERED_API_URL="https://api.bitbucket.org/2.0/repositories/${WORKSPACE_ID}?pagelen=100"

log "Fetching repos using project filter..."
if ! REPO_NAMES="$(fetch_repo_names_for_project "$FILTERED_API_URL" "$PROJECT_KEY")"; then
  exit 1
fi

REPO_COUNT="$(printf "%s\n" "$REPO_NAMES" | awk 'NF { c++ } END { print c+0 }')"

if [[ "$REPO_COUNT" -eq 0 ]]; then
  # Some workspaces can behave inconsistently with server-side q filtering.
  # Fallback to full workspace scan and local project key filtering.
  log "No repos returned from direct project filter. Retrying with workspace fetch + local project-key match..."
  if ! REPO_NAMES="$(fetch_repo_names_for_project "$UNFILTERED_API_URL" "$PROJECT_KEY")"; then
    exit 1
  fi
  REPO_COUNT="$(printf "%s\n" "$REPO_NAMES" | awk 'NF { c++ } END { print c+0 }')"
fi

# --- Parse JSON Response ---
log "Parsing response..."

if [[ $REPO_COUNT -eq 0 ]]; then
  error "No repositories found for project $PROJECT_KEY"
  error "Tip: project key matching is case-sensitive. Confirm exact project key casing in Bitbucket."
  exit 1
fi

log "Found $REPO_COUNT repositories"

# --- Generate repos.txt ---
log "Generating $OUTPUT_FILE..."
{
  echo "# Bitbucket repositories for project: $PROJECT_KEY"
  echo "# Generated: $(date +'%Y-%m-%d %H:%M:%S')"
  echo "# Format: BITBUCKET_URL GITHUB_ORG GITHUB_REPO_NAME"
  echo "#"

  while IFS= read -r repo_name; do
    if [[ -z "$repo_name" ]]; then
      continue
    fi

    # Construct Bitbucket clone URL
    bb_url="https://${BITBUCKET_URL}/${WORKSPACE_ID}/${repo_name}.git"

    # Determine GitHub org (use provided or prompt)
    if [[ -n "$GITHUB_ORG" ]]; then
      gh_org="$GITHUB_ORG"
    else
      gh_org="<GITHUB_ORG>"
    fi

    # Use repo name as GitHub repo name
    gh_repo="$repo_name"

    echo "$bb_url $gh_org $gh_repo"
  done <<< "$REPO_NAMES"
} > "$OUTPUT_FILE"

# --- Output Summary ---
log "✓ Successfully generated $OUTPUT_FILE"
log ""
log "Summary:"
log "  Repositories: $REPO_COUNT"
log "  Output file: $(pwd)/$OUTPUT_FILE"
log ""
echo "Repositories found:"
echo "$REPO_NAMES" | sed 's/^/  - /'
echo ""

if [[ -z "$GITHUB_ORG" ]]; then
  log "NOTE: GitHub organization is not set. Edit $OUTPUT_FILE and replace <GITHUB_ORG> with your org."
fi

if [[ "$VALIDATE_OUTPUT" == "true" ]]; then
  log "Running optional validation..."
  validate_output_file || exit 1
fi

log "Next step: Run 'migrationTool/migrate_repos.sh $OUTPUT_FILE'"
