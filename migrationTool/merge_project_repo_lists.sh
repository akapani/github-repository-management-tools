#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./merge_project_repo_lists.sh --output OUTPUT_FILE INPUT_FILE [INPUT_FILE ...]

Merges multiple repo list files into one combined file for migrate_repos_by_project.sh.
Project headers are preserved, and duplicate repo lines are removed.

Supported input lines:
  # Bitbucket repositories for project: PROJECT_ALPHA
  https://.../repo.git ORG REPO
  https://.../repo.git ORG REPO PROJECT_KEY

Example:
  ./merge_project_repo_lists.sh \
    --output repos_all_projects.txt \
    repos_AP.txt repos_B2B.txt repos_OPS.txt
EOF
}

OUTPUT_FILE=""
INPUT_FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -o|--output)
      [[ $# -lt 2 ]] && { echo "ERROR: --output requires a file path"; exit 1; }
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        INPUT_FILES+=("$1")
        shift
      done
      ;;
    -*)
      echo "ERROR: Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      INPUT_FILES+=("$1")
      shift
      ;;
  esac
done

[[ -z "$OUTPUT_FILE" ]] && { echo "ERROR: --output is required"; usage; exit 1; }
[[ ${#INPUT_FILES[@]} -eq 0 ]] && { echo "ERROR: At least one input file is required"; usage; exit 1; }

# Resolve relative output path against current working directory.
if [[ ! "$OUTPUT_FILE" = /* ]]; then
  OUTPUT_FILE="$PWD/$OUTPUT_FILE"
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

TMP_OUT="$(mktemp)"
TMP_SEEN="$(mktemp)"

cleanup() {
  rm -f "$TMP_OUT" "$TMP_SEEN"
}
trap cleanup EXIT

echo "# Combined repo list"
echo "# Generated: $(date +'%Y-%m-%d %H:%M:%S')"
echo "# Source files: ${#INPUT_FILES[@]}"
echo "# Format: BITBUCKET_URL GITHUB_ORG GITHUB_REPO [PROJECT_KEY]"
echo

for in_file in "${INPUT_FILES[@]}"; do
  if [[ ! "$in_file" = /* && -f "$SCRIPT_DIR/$in_file" ]]; then
    in_file="$SCRIPT_DIR/$in_file"
  fi

  if [[ ! -f "$in_file" ]]; then
    echo "ERROR: Input file not found: $in_file" >&2
    exit 1
  fi

  echo "# --- begin: $in_file ---" >> "$TMP_OUT"
  current_project=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Preserve project section header used by migrate_repos_by_project.sh.
    if [[ "$line" =~ ^#[[:space:]]*Bitbucket[[:space:]]repositories[[:space:]]for[[:space:]]project:[[:space:]](.+)$ ]]; then
      current_project="${BASH_REMATCH[1]}"
      echo "$line" >> "$TMP_OUT"
      continue
    fi

    # Ignore other comments and blank lines.
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue

    # Parse repository line and normalize whitespace.
    read -r bb_url gh_org gh_repo project_key _extra <<<"$line"
    [[ -z "${bb_url:-}" || -z "${gh_org:-}" || -z "${gh_repo:-}" ]] && continue

    effective_project="${project_key:-$current_project}"
    normalized_line="$bb_url $gh_org $gh_repo"
    [[ -n "$effective_project" ]] && normalized_line+=" $effective_project"

    # Dedupe exact normalized repo lines across all input files.
    if ! grep -Fqx "$normalized_line" "$TMP_SEEN"; then
      echo "$normalized_line" >> "$TMP_SEEN"
      echo "$normalized_line" >> "$TMP_OUT"
    fi
  done < "$in_file"

  echo >> "$TMP_OUT"
done

cat "$TMP_OUT" > "$OUTPUT_FILE"
echo "Wrote combined file: $OUTPUT_FILE"
