#!/usr/bin/env bash
set -euo pipefail

# This script embeds Git metadata (tag/branch/commit) into the built Info.plist.
# Xcode Run Script Phase: add `${SRCROOT}/scripts/embed_git_info.sh` above Compile Sources.

PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
PLISTBUDDY="/usr/libexec/PlistBuddy"

if [[ ! -f "$PLIST" ]]; then
  echo "Info.plist not found at $PLIST"
  exit 0
fi

# Try to read from Git. Fallback to empty if not available.
git_tag=""
git_branch=""
git_commit=""

if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  git_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
  git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "")
fi

set_key() {
  local key="$1"; shift
  local value="$1"; shift
  if "$PLISTBUDDY" -c "Print :$key" "$PLIST" >/dev/null 2>&1; then
    "$PLISTBUDDY" -c "Set :$key $value" "$PLIST" || true
  else
    "$PLISTBUDDY" -c "Add :$key string $value" "$PLIST" || true
  fi
}

if [[ -n "$git_tag" ]]; then
  set_key GIT_TAG "$git_tag"
fi
if [[ -n "$git_branch" ]]; then
  set_key GIT_BRANCH "$git_branch"
fi
if [[ -n "$git_commit" ]]; then
  set_key GIT_COMMIT "$git_commit"
fi

echo "Embedded Git info → tag='$git_tag' branch='$git_branch' commit='$git_commit'"

