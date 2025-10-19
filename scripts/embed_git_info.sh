#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${APP_SANDBOX_CONTAINER_ID:-}" ]]; then
  echo "[git-info] Detected App Sandbox context; skipping Git metadata embed."
  exit 0
fi

# This script embeds Git metadata (tag/branch/commit) into the built Info.plist.
# Xcode Run Script Phase: add `${SRCROOT}/scripts/embed_git_info.sh` above Compile Sources.

# Determine target Info.plist path.
# Priority:
# 1) Positional argument pointing to .app bundle or Info.plist file
# 2) Xcode env vars TARGET_BUILD_DIR + INFOPLIST_PATH
# If neither available, exit with guidance.

PLIST_ARG_PATH="${1:-}"

if [[ -n "$PLIST_ARG_PATH" ]]; then
  if [[ -d "$PLIST_ARG_PATH" && "$PLIST_ARG_PATH" == *.app ]]; then
    PLIST="$PLIST_ARG_PATH/Contents/Info.plist"
  else
    PLIST="$PLIST_ARG_PATH"
  fi
else
  TB_DIR="${TARGET_BUILD_DIR:-}"
  IP_PATH="${INFOPLIST_PATH:-}"
  if [[ -n "$TB_DIR" && -n "$IP_PATH" ]]; then
    PLIST="$TB_DIR/$IP_PATH"
  else
    echo "[git-info] No Info.plist path. Pass an .app bundle or Info.plist as argument, or run from Xcode with TARGET_BUILD_DIR/INFOPLIST_PATH set."
    exit 2
  fi
fi

PLISTBUDDY="/usr/libexec/PlistBuddy"

echo "[git-info] CONFIGURATION=${CONFIGURATION:-"(unset)"} TARGET_BUILD_DIR=${TARGET_BUILD_DIR:-"(unset)"}"
echo "[git-info] SRCROOT=${SRCROOT:-"(unset)"}"
echo "[git-info] INFO PLIST: $PLIST"

if [[ ! -f "$PLIST" ]]; then
  echo "[git-info] Info.plist not found at $PLIST"
  exit 0
fi

restore_mode=false
original_mode=""
if [[ ! -w "$PLIST" ]]; then
  original_mode=$(stat -f '%OLp' "$PLIST" 2>/dev/null || echo "")
  if chmod u+w "$PLIST" 2>/dev/null; then
    restore_mode=true
  else
    echo "[git-info] Info.plist at $PLIST is not writable and chmod failed; skipping embed."
    exit 0
  fi
fi

if [[ "$restore_mode" == true ]]; then
  trap '[[ -n "$original_mode" ]] && chmod "$original_mode" "$PLIST" 2>/dev/null || true' EXIT
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
  local key="$1"
  local value="$2"
  local escaped=${value//"/\\"}
  if "$PLISTBUDDY" -c "Print :$key" "$PLIST" >/dev/null 2>&1; then
    "$PLISTBUDDY" -c "Set :$key \"$escaped\"" "$PLIST" || true
  else
    "$PLISTBUDDY" -c "Add :$key string \"$escaped\"" "$PLIST" || true
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

# Embed semantic version/build metadata and the latest change summary if available.
version_source="${DS_VERSION_FILE:-${SRCROOT:-$PWD}/VERSION}"
ds_version="${DS_VERSION:-}"
if [[ -z "$ds_version" && -r "$version_source" ]]; then
  ds_version=$(<"$version_source")
fi
ds_version=$(printf '%s' "$ds_version" | tr -d '\r' | tr -d '\n')
ds_version=$(printf '%s' "$ds_version" | awk '{$1=$1; print}')
if [[ -n "$ds_version" ]]; then
  set_key CFBundleShortVersionString "$ds_version"
  set_key DS_VERSION "$ds_version"
fi

build_number="${DS_BUILD_NUMBER:-}"
if [[ -z "$build_number" && "$git_ok" == true ]]; then
  build_number=$(git -C "$workdir" rev-list --count HEAD 2>/dev/null || echo "")
fi
build_number=$(printf '%s' "$build_number" | tr -d '\r' | tr -d '\n')
build_number=$(printf '%s' "$build_number" | awk '{$1=$1; print}')
if [[ -n "$build_number" ]]; then
  set_key CFBundleVersion "$build_number"
  set_key DS_BUILD_NUMBER "$build_number"
fi

last_change_source="${DS_LAST_CHANGE_FILE:-${SRCROOT:-$PWD}/VERSION_LAST_CHANGE}"
last_change="${DS_LAST_CHANGE:-}"
if [[ -z "$last_change" && -r "$last_change_source" ]]; then
  last_change=$(<"$last_change_source")
elif [[ -z "$last_change" && "$git_ok" == true ]]; then
  last_change=$(git -C "$workdir" log -1 --pretty=%s 2>/dev/null || echo "")
fi
last_change=$(printf '%s' "$last_change" | tr -d '\r' | tr -d '\n')
last_change=$(printf '%s' "$last_change" | awk '{$1=$1; print}')
if [[ -n "$last_change" ]]; then
  set_key DS_LAST_CHANGE "$last_change"
fi

echo "[git-info] Embedded Git info → tag='$git_tag' branch='$git_branch' commit='$git_commit'"
if [[ -n "$ds_version" ]]; then
  echo "[git-info] Embedded semantic version '$ds_version'"
fi
if [[ -n "$build_number" ]]; then
  echo "[git-info] Embedded build number '$build_number'"
fi
if [[ -n "$last_change" ]]; then
  echo "[git-info] Embedded last change '$last_change'"
fi

echo "[git-info] Verifying keys in built Info.plist:"
"$PLISTBUDDY" -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "(no CFBundleShortVersionString)"
"$PLISTBUDDY" -c "Print :CFBundleVersion" "$PLIST" 2>/dev/null || echo "(no CFBundleVersion)"
"$PLISTBUDDY" -c "Print :DS_LAST_CHANGE" "$PLIST" 2>/dev/null || echo "(no DS_LAST_CHANGE)"
"$PLISTBUDDY" -c "Print :GIT_TAG" "$PLIST" 2>/dev/null || echo "(no GIT_TAG)"
"$PLISTBUDDY" -c "Print :GIT_BRANCH" "$PLIST" 2>/dev/null || echo "(no GIT_BRANCH)"
"$PLISTBUDDY" -c "Print :GIT_COMMIT" "$PLIST" 2>/dev/null || echo "(no GIT_COMMIT)"

# Emit a stamp file so the phase can declare a unique output (avoids multiple producers for Info.plist)
STAMP_DIR="${DERIVED_FILE_DIR:-${TARGET_BUILD_DIR:-$(dirname "$PLIST")}}"
STAMP_FILE="$STAMP_DIR/git_info.stamp"
mkdir -p "$STAMP_DIR" || true
echo "tag=$git_tag branch=$git_branch commit=$git_commit" > "$STAMP_FILE"
echo "[git-info] Wrote stamp file: $STAMP_FILE"
