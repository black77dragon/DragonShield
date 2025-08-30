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
 
 That’s it. On each build, the script reads Git details and writes them into the built Info.plist. In Settings, `GitInfoProvider` will prefer these keys and display:
 
 - Version: Git tag (or marketing version) + build number
 - Branch: current Git branch beneath the version
 
 ## Script behavior
 
 - Falls back gracefully if not in a Git repo or on CI without tags.
 - Only mutates the built product’s Info.plist (not your source plist).
 - Adds keys if missing, otherwise updates them.
 
 If you use CI, make sure the checkout includes `.git` for tags/branches, or set environment variables to provide the values and tweak the script accordingly.
