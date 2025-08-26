#!/usr/bin/env zsh -f
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

latest_tag="$(git describe --tags --abbrev=0)"
version="${latest_tag#v}"
IFS='.' read -r major minor patch <<<"$version"
next_version="$major.$minor.$((patch + 1))"

xcrun agvtool new-marketing-version "$next_version"
xcrun agvtool new-version -all

git add "$repo_root/DragonShield.xcodeproj/project.pbxproj"
git commit -m "Bump version to $next_version"
git tag "v$next_version"
