#!/usr/bin/env bash
set -euo pipefail

# This script embeds Git metadata (tag/branch/commit) into the built Info.plist.
# Xcode Run Script Phase: add `${SRCROOT}/scripts/embed_git_info.sh` above Compile Sources.

PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
PLISTBUDDY="/usr/libexec/PlistBuddy"

echo "[git-info] CONFIGURATION=$CONFIGURATION TARGET_BUILD_DIR=$TARGET_BUILD_DIR"
echo "[git-info] SRCROOT=${SRCROOT:-"(unset)"}"
echo "[git-info] INFO PLIST: $PLIST"

if [[ ! -f "$PLIST" ]]; then
  echo "[git-info] Info.plist not found at $PLIST"
  exit 0
fi

# Try to read from Git. Fallback to empty if not available.
git_tag=""
git_branch=""
git_commit=""

workdir="${SRCROOT:-$PWD}"

git_ok=false
if command -v git >/dev/null 2>&1; then
  if git -C "$workdir" rev-parse --git-dir >/dev/null 2>&1; then
    git_tag=$(git -C "$workdir" describe --tags --abbrev=0 2>/dev/null || echo "")
    git_branch=$(git -C "$workdir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    git_commit=$(git -C "$workdir" rev-parse --short HEAD 2>/dev/null || echo "")
    git_ok=true
  fi
fi

# Allow CI/environment overrides if git metadata is unavailable
if [[ -z "$git_tag" && -n "${GIT_TAG:-}" ]]; then git_tag="$GIT_TAG"; fi
if [[ -z "$git_branch" && -n "${GIT_BRANCH:-}" ]]; then git_branch="$GIT_BRANCH"; fi
if [[ -z "$git_commit" && -n "${GIT_COMMIT:-}" ]]; then git_commit="$GIT_COMMIT"; fi

if [[ "$git_ok" == true ]]; then
  echo "[git-info] git repo detected. tag='$git_tag' branch='$git_branch' commit='$git_commit'"
else
  echo "[git-info] no git repo detected; skipping git commands"
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

echo "[git-info] Embedded Git info → tag='$git_tag' branch='$git_branch' commit='$git_commit'"

echo "[git-info] Verifying keys in built Info.plist:"
"$PLISTBUDDY" -c "Print :GIT_TAG" "$PLIST" 2>/dev/null || echo "(no GIT_TAG)"
"$PLISTBUDDY" -c "Print :GIT_BRANCH" "$PLIST" 2>/dev/null || echo "(no GIT_BRANCH)"
"$PLISTBUDDY" -c "Print :GIT_COMMIT" "$PLIST" 2>/dev/null || echo "(no GIT_COMMIT)"

# Emit a stamp file so the phase can declare a unique output (avoids multiple producers for Info.plist)
STAMP_DIR="${DERIVED_FILE_DIR:-$TARGET_BUILD_DIR}"
STAMP_FILE="$STAMP_DIR/git_info.stamp"
mkdir -p "$STAMP_DIR" || true
echo "tag=$git_tag branch=$git_branch commit=$git_commit" > "$STAMP_FILE"
echo "[git-info] Wrote stamp file: $STAMP_FILE"
