# Release Versioning

This document describes how the project version is automatically incremented after merges to `main`.

## Process

1. `scripts/bump_version.zsh` reads the latest tag, increments the patch number, and updates the Xcode project using `xcrun agvtool new-marketing-version` and `new-version -all`.
2. The script commits the modified `DragonShield.xcodeproj/project.pbxproj` and creates a new tag with the updated version.
3. A GitHub Actions workflow runs this script on pushes to `main` and pushes the commit and tag back to the repository.

## Manual Usage

Run the script locally when needed:

```
scripts/bump_version.zsh
```
