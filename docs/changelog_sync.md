# Changelog Sync Workflow

This guide keeps `CHANGELOG.md` in sync with implemented items in `new_features.md`.

## What the script does

- Reads implemented items (`[x]`) from `new_features.md`.
- Maps them to releases based on Git tag dates (earliest tag date >= implementation date).
- Writes `CHANGELOG.md` for the v1.x line.
- Writes `Archive/CHANGELOG-ARCHIVE.md` for non-v1 tags.
- Uses GitHub PR data and release bodies when available (best effort).

## Requirements

- Python 3
- Git available in PATH
- Optional: `GITHUB_TOKEN` for higher GitHub API rate limits

## Usage

```bash
python3 scripts/sync_changelog.py
```

Optional flags:

- `--no-github` Skip GitHub API lookups.
- `--strict-dates` Do not carry forward dates when an entry is missing one.
- `--dry-run` Print output instead of writing files.

## Run from the app (System → Settings)

Use **Release Notes Sync** in Settings to run the script from the GUI. The button:

- runs `scripts/sync_changelog.py` with python3
- optionally uses GitHub release/PR data
- requires a local repo checkout with `scripts/` present

## Release checklist (recommended)

1) Ensure implemented items in `new_features.md` have dates.
2) Bump `VERSION`.
3) Tag the release (example): `git tag -a v1.34.0 -m "Release 1.34.0"`
4) Run the sync script.
5) Review `CHANGELOG.md` and publish the GitHub Release.

## Notes on dates

- If an entry has no date, the script will:
  - use the PR close date (GitHub), or
  - use the latest commit date mentioning the DS-ID, or
  - use the previous dated entry (unless `--strict-dates` is set).
- Entries after the latest tag remain under `[Unreleased]`.
