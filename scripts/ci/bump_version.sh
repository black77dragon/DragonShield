#!/usr/bin/env bash
set -euo pipefail

# Bumps the minor component of VERSION and records the latest change summary.
# Designed for CI but safe to run locally for testing.

ROOT_DIR=$(git rev-parse --show-toplevel)
VERSION_FILE=${VERSION_FILE:-"$ROOT_DIR/VERSION"}
LAST_CHANGE_FILE=${LAST_CHANGE_FILE:-"$ROOT_DIR/VERSION_LAST_CHANGE"}

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "VERSION file not found. Seeding with 0.0.0." >&2
  printf '0.0.0\n' > "$VERSION_FILE"
fi

RAW_VERSION=$(<"$VERSION_FILE")
RAW_VERSION=${RAW_VERSION//$'\r'/}
RAW_VERSION=${RAW_VERSION//$'\n'/}
RAW_VERSION=${RAW_VERSION//$'\t'/}
RAW_VERSION=${RAW_VERSION// /}

if [[ ! "$RAW_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "Invalid semantic version in $VERSION_FILE: '$RAW_VERSION'" >&2
  exit 1
fi

MAJOR=${BASH_REMATCH[1]}
MINOR=${BASH_REMATCH[2]}
PATCH=${BASH_REMATCH[3]}

NEW_MINOR=$((MINOR + 1))
NEW_VERSION="${MAJOR}.${NEW_MINOR}.0"

printf '%s\n' "$NEW_VERSION" > "$VERSION_FILE"

echo "Bumped version: ${MAJOR}.${MINOR}.${PATCH} → $NEW_VERSION"

if [[ ! -f "$LAST_CHANGE_FILE" ]]; then
  touch "$LAST_CHANGE_FILE"
fi

LATEST_DESC=${LAST_CHANGE_OVERRIDE:-}
if [[ -z "$LATEST_DESC" ]]; then
  commit_subject=$(git log -1 --pretty=%s 2>/dev/null || echo "")
  commit_body=$(git log -1 --pretty=%b 2>/dev/null || echo "")
  commit_body=${commit_body//$'\r'/\n}
  commit_body_trimmed=$(printf '%s\n' "$commit_body" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sed -n '/./{p;q;}')

  if [[ "$commit_subject" =~ ^Merge\ pull\ request\ \#([0-9]+)\ from\ ([^[:space:]]+)\/([^[:space:]]+) ]]; then
    pr_number="${BASH_REMATCH[1]}"
    pr_head_owner="${BASH_REMATCH[2]}"
    pr_head_branch="${BASH_REMATCH[3]}"
    if [[ -n "$commit_body_trimmed" ]]; then
      LATEST_DESC="$commit_body_trimmed (PR #$pr_number from $pr_head_branch)"
    else
      LATEST_DESC="PR #$pr_number from $pr_head_branch"
    fi
  else
    LATEST_DESC="$commit_subject"
  fi
fi

LATEST_DESC=${LATEST_DESC//$'\r'/ }
LATEST_DESC=${LATEST_DESC//$'\n'/ }
LATEST_DESC=$(printf '%s\n' "$LATEST_DESC" | awk '{$1=$1; print}')
if [[ -z "$LATEST_DESC" ]]; then
  LATEST_DESC="Update for $NEW_VERSION"
fi
if [[ ${#LATEST_DESC} -gt 140 ]]; then
  LATEST_DESC="${LATEST_DESC:0:137}..."
fi
printf '%s\n' "$LATEST_DESC" > "$LAST_CHANGE_FILE"

echo "Recorded last change summary: $LATEST_DESC"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    printf 'NEW_VERSION=%s\n' "$NEW_VERSION"
    printf 'LAST_CHANGE=%s\n' "$LATEST_DESC"
  } >> "$GITHUB_ENV"
fi
