 # Embed Git Info in Info.plist (Version, Branch, Commit)
 
 This guide shows how to inject Git metadata into your app’s Info.plist at build time so Settings can display the correct Git tag (Version) and current branch name.
 
 The Settings view reads these keys (if present):
 - `GIT_TAG` — latest tag (e.g., v2.3.1)
 - `GIT_BRANCH` — current branch (e.g., main)
 - `GIT_COMMIT` — short commit hash (e.g., a1b2c3d)
 
 We provide a ready-to-use script at `scripts/embed_git_info.sh`.
 
 ## Steps (Xcode)
 
 1) In Xcode, select the `DragonShield` app target.
 2) Go to the “Build Phases” tab.
 3) Click the `+` button in the top-left and choose “New Run Script Phase”.
 4) Drag the new script phase above “Compile Sources”.
5) Set its shell to `/bin/zsh` (or `/bin/bash`).
6) Paste the following line into the script box:
 
 ```
 ${SRCROOT}/scripts/embed_git_info.sh
 ```
 
7) Ensure the script has execute permission:
 
 ```
 chmod +x scripts/embed_git_info.sh
 ```
 
8) Inputs/Outputs to avoid build warnings and conflicts:

- Input Files (optional, improves dependency tracking):
  - $(SRCROOT)/scripts/embed_git_info.sh
  - $(INFOPLIST_FILE)

- Output Files (declare both so the sandbox allows writes):
  - $(DERIVED_FILE_DIR)/git_info.stamp
  - $(TARGET_BUILD_DIR)/$(INFOPLIST_PATH)

The extra output entry is required so Xcode’s sandbox lets the script edit the built Info.plist. Xcode 15+ no longer raises the “Multiple commands produce … Info.plist” warning for this combination.

Alternatively, uncheck “Based on dependency analysis” to force-run every build.

9) Make sure the script runs for Debug builds:
   - Uncheck “For install builds only” so the phase executes on normal Run/Debug builds as well.

Order: place this Run Script phase towards the end (below “Copy Bundle Resources”), so the built Info.plist exists when the script runs.

That’s it. On each build, the script reads Git details and writes them into the built Info.plist. In Settings, GitInfoProvider will prefer these keys and display:

- Version: Git tag (or marketing version) + build number
- Branch: current Git branch beneath the version

## Script behavior
 
 - Falls back gracefully if not in a Git repo or on CI without tags.
 - Only mutates the built product’s Info.plist (not your source plist).
 - Adds keys if missing, otherwise updates them.
 
If you use CI, make sure the checkout includes `.git` for tags/branches, or set environment variables to provide the values and tweak the script accordingly.

## Version metadata produced by CI

Our GitHub Actions workflow `.github/workflows/version-bump.yml` runs on every push to `main` (typically via PR merges). It:

- bumps the minor component of the repo-root `VERSION` file and resets the patch number to zero;
- captures the latest commit subject into `VERSION_LAST_CHANGE` (truncated to ~140 characters);
- commits those files back to `main` and tags the commit (`v{MAJOR.MINOR.PATCH}`).

At build time `scripts/embed_git_info.sh` supplements the Git metadata by reading these files (or the corresponding `DS_VERSION` / `DS_LAST_CHANGE` environment overrides) and sets the following Info.plist keys:

- `CFBundleShortVersionString` ← semantic version from `VERSION`
- `DS_VERSION` ← duplicate of the semantic version for easy lookup
- `CFBundleVersion` ← Git commit count (or `DS_BUILD_NUMBER` override)
- `DS_BUILD_NUMBER` ← duplicate of the build value
- `DS_LAST_CHANGE` ← short summary from `VERSION_LAST_CHANGE` (for merged PRs we capture the PR title plus the source branch)

`GitInfoProvider.displayVersion` combines all of this into the string shown under **Settings → App Basics**.

## Manual usage (outside Xcode)

If you want to test the script locally without Xcode env vars, pass your built app or Info.plist path:

```
# From repo root, after building in Xcode (Debug scheme)
./scripts/embed_git_info.sh \
  "$HOME/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug/DragonShield.app"

# Or pass the exact Info.plist file
./scripts/embed_git_info.sh \
  "$HOME/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug/DragonShield.app/Contents/Info.plist"
```

The script will log [git-info] lines and update the passed Info.plist accordingly.
