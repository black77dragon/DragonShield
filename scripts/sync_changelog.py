#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


CATEGORY_MAP = {
    "new_features": "Added",
    "changes": "Changed",
    "bugs": "Fixed",
}

DS_RE = re.compile(r"\bDS-\d+\b", re.IGNORECASE)
DATE_IN_TITLE_RE = re.compile(r"\((\d{4}-\d{2}-\d{2})\)")


def run_git(args):
    return subprocess.check_output(["git"] + args, text=True).strip()


def git_root():
    return run_git(["rev-parse", "--show-toplevel"])


def load_tags():
    lines = run_git(
        [
            "for-each-ref",
            "--format=%(refname:short) %(creatordate:iso-strict)",
            "refs/tags",
        ]
    ).splitlines()
    tags = []
    for line in lines:
        if not line.strip():
            continue
        name, ts = line.split(" ", 1)
        dt = datetime.fromisoformat(ts.strip().replace("Z", "+00:00"))
        tags.append({"name": name, "datetime": dt})
    tags.sort(key=lambda t: t["datetime"])
    return tags


def fetch_github_releases(use_github, token):
    if not use_github:
        return {}
    url = "https://api.github.com/repos/black77dragon/DragonShield/releases"
    headers = {"User-Agent": "DragonShield-Changelog"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = Request(url, headers=headers)
    with urlopen(req, timeout=20) as resp:
        data = json.load(resp)
    releases = {}
    for rel in data:
        tag = rel.get("tag_name")
        if not tag:
            continue
        published = rel.get("published_at") or rel.get("created_at")
        published_date = None
        if published:
            published_date = datetime.fromisoformat(published.replace("Z", "+00:00"))
        releases[tag] = {
            "name": rel.get("name") or "",
            "body": rel.get("body") or "",
            "published": published_date,
        }
    return releases


def extract_release_notes(body):
    notes = []
    for raw in body.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith(("-", "*")):
            line = line[1:].strip()
        notes.append(line)
    return notes


def categorize_without_tag(title):
    lowered = title.lower()
    if any(word in lowered for word in ["fix", "bug", "error", "issue"]):
        return "Fixed"
    if any(word in lowered for word in ["add", "introduce", "new"]):
        return "Added"
    if any(word in lowered for word in ["remove", "drop", "delete"]):
        return "Removed"
    return "Changed"


def parse_new_features(path, carry_forward_date):
    items = []
    last_date_seen = None
    pattern = re.compile(
        r"^- \[x\](?: \[([^\]]+)\])? \*\*(.*?)\*\*(?: \((\d{4}-\d{2}-\d{2})\))?\s*(.*)$"
    )
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n").replace("<mark>", "").replace("</mark>", "")
            match = pattern.match(line)
            if not match:
                continue
            raw_tag, title, impl_date, trailing = (
                match.group(1),
                match.group(2),
                match.group(3),
                match.group(4),
            )

            combined = f"{title} {trailing or ''}"
            ds_match = DS_RE.search(combined)
            ds_id = ds_match.group(0).upper() if ds_match else None

            if ds_id:
                title = title.replace(ds_id, "")
            title = title.replace("[]", "")
            title = re.sub(r"\s+", " ", title).strip()
            title = re.sub(r"^\[\s*\]", "", title).strip()

            title_date = None
            title_date_match = DATE_IN_TITLE_RE.search(title)
            if title_date_match:
                title_date = title_date_match.group(1)
                title = DATE_IN_TITLE_RE.sub("", title).strip()

            trailing = (trailing or "").strip()
            if not title and trailing:
                title = trailing

            category = CATEGORY_MAP.get((raw_tag or "").strip().lower())
            if not category:
                category = categorize_without_tag(title)

            impl_str = impl_date or title_date
            if not impl_str and carry_forward_date and last_date_seen:
                impl_str = last_date_seen

            impl = None
            if impl_str:
                impl = datetime.strptime(impl_str, "%Y-%m-%d").date()
                last_date_seen = impl_str

            items.append(
                {
                    "raw_tag": (raw_tag or "").strip(),
                    "category": category,
                    "title": title,
                    "ds_id": ds_id,
                    "impl_date": impl,
                    "impl_date_str": impl_str,
                }
            )
    return items


def search_pr_info_github(ds_id, token):
    url = (
        "https://api.github.com/search/issues?"
        f"q=repo:black77dragon/DragonShield+\"{ds_id}\"+type:pr"
    )
    headers = {"User-Agent": "DragonShield-Changelog"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = Request(url, headers=headers)
    try:
        with urlopen(req, timeout=20) as resp:
            data = json.load(resp)
    except (HTTPError, URLError, TimeoutError, json.JSONDecodeError):
        return None
    items = data.get("items") or []
    if not items:
        return None
    item = items[0]
    return {
        "number": item.get("number"),
        "closed_at": item.get("closed_at"),
        "created_at": item.get("created_at"),
    }


def search_pr_number_git(ds_id):
    if not ds_id:
        return None
    try:
        out = run_git(["log", "-n", "20", f"--grep={ds_id}", "--pretty=%s"])
    except subprocess.CalledProcessError:
        return None
    for line in out.splitlines():
        match = re.search(r"#(\d+)", line)
        if match:
            return int(match.group(1))
        match = re.search(r"Merge pull request #(\d+)", line, re.IGNORECASE)
        if match:
            return int(match.group(1))
    return None


def infer_impl_date_git(ds_id):
    if not ds_id:
        return None
    try:
        out = run_git(["log", "-n", "1", f"--grep={ds_id}", "--format=%cI"])
    except subprocess.CalledProcessError:
        return None
    if not out:
        return None
    return datetime.fromisoformat(out.replace("Z", "+00:00")).date()


def tag_grouped(tags, releases):
    grouped = {}
    for tag in tags:
        rel = releases.get(tag["name"])
        dt = rel["published"] if rel and rel.get("published") else tag["datetime"]
        day = dt.date()
        grouped.setdefault(day, []).append({"name": tag["name"], "datetime": dt})
    for day, items in grouped.items():
        items.sort(key=lambda t: t["datetime"])
    return grouped


def select_tag_for_date(grouped, target_date):
    for day in sorted(grouped.keys()):
        if day >= target_date:
            return grouped[day][-1]["name"]
    return None


def assign_items_to_tags(items, tags, releases):
    grouped = tag_grouped(tags, releases)
    latest_tag_date = max(grouped.keys()) if grouped else None
    assignments = {}
    unreleased = []
    for item in items:
        if not item["impl_date"]:
            unreleased.append(item)
            continue
        if latest_tag_date and item["impl_date"] > latest_tag_date:
            unreleased.append(item)
            continue
        tag = select_tag_for_date(grouped, item["impl_date"])
        if not tag:
            unreleased.append(item)
            continue
        assignments.setdefault(tag, []).append(item)
    return assignments, unreleased


def render_entry(item, pr_number=None):
    parts = []
    if item.get("ds_id"):
        parts.append(f"[{item['ds_id']}]")
    if item.get("title"):
        parts.append(item["title"])
    text = " ".join(parts).strip()
    if item.get("impl_date_str"):
        text += f" (implemented {item['impl_date_str']})"
    if pr_number:
        text += f" (#{pr_number})"
    return f"- {text}"


def build_sections(tags, assignments, releases, pr_map, include_release_notes):
    sections = []
    sorted_tags = sorted(tags, key=lambda t: t["datetime"], reverse=True)
    for tag in sorted_tags:
        tag_name = tag["name"]
        rel = releases.get(tag_name)
        dt = rel["published"] if rel and rel.get("published") else tag["datetime"]
        header_date = dt.date().isoformat()
        sections.append(f"## [{tag_name.lstrip('v')}] - {header_date}")
        items = assignments.get(tag_name, [])
        buckets = {}
        for item in items:
            buckets.setdefault(item["category"], []).append(item)
        if include_release_notes and rel and rel.get("body"):
            notes = extract_release_notes(rel["body"])
            if notes:
                buckets.setdefault("Notes", []).extend(
                    {"category": "Notes", "title": note} for note in notes
                )
        for category in ["Added", "Changed", "Fixed", "Removed", "Notes"]:
            entries = buckets.get(category, [])
            if not entries:
                continue
            sections.append("")
            sections.append(f"### {category}")
            for entry in entries:
                if category == "Notes" and "ds_id" not in entry:
                    sections.append(f"- {entry['title']}")
                    continue
                ds_id = entry.get("ds_id")
                pr_number = pr_map.get(ds_id) if ds_id else None
                sections.append(render_entry(entry, pr_number))
        sections.append("")
    return "\n".join(sections).rstrip() + "\n"


def build_changelog(main_tags, archive_tags, items, releases, pr_map, include_release_notes):
    assignments, unreleased = assign_items_to_tags(items, main_tags + archive_tags, releases)
    unreleased_lines = ["## [Unreleased]"]
    buckets = {}
    for item in unreleased:
        buckets.setdefault(item["category"], []).append(item)
    for category in ["Added", "Changed", "Fixed", "Removed", "Notes"]:
        entries = buckets.get(category, [])
        if not entries:
            continue
        unreleased_lines.append("")
        unreleased_lines.append(f"### {category}")
        for entry in entries:
            ds_id = entry.get("ds_id")
            pr_number = pr_map.get(ds_id) if ds_id else None
            unreleased_lines.append(render_entry(entry, pr_number))
    unreleased_block = "\n".join(unreleased_lines).rstrip() + "\n\n"

    main_body = build_sections(main_tags, assignments, releases, pr_map, include_release_notes)
    archive_body = build_sections(
        archive_tags, assignments, releases, pr_map, include_release_notes
    )
    return unreleased_block, main_body, archive_body


def write_file(path, content, dry_run):
    if dry_run:
        print(f"--- {path} ---")
        print(content)
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)


def latest_main_tag(tags):
    main_tags = [t for t in tags if t["name"].startswith("v1.") and "-ios" not in t["name"]]
    if not main_tags:
        return None
    return max(main_tags, key=lambda t: t["datetime"])


def main():
    parser = argparse.ArgumentParser(description="Sync CHANGELOG.md from new_features.md.")
    parser.add_argument("--new-features", default="new_features.md")
    parser.add_argument("--changelog", default="CHANGELOG.md")
    parser.add_argument("--archive", default="Archive/CHANGELOG-ARCHIVE.md")
    parser.add_argument("--version-file", default="VERSION")
    parser.add_argument("--no-github", action="store_true", help="Skip GitHub API lookups.")
    parser.add_argument("--strict-dates", action="store_true", help="Do not carry dates forward.")
    parser.add_argument("--dry-run", action="store_true", help="Print output instead of writing files.")
    args = parser.parse_args()

    root = git_root()
    new_features_path = os.path.join(root, args.new_features)
    changelog_path = os.path.join(root, args.changelog)
    archive_path = os.path.join(root, args.archive)
    version_path = os.path.join(root, args.version_file)

    if not os.path.exists(new_features_path):
        print(f"new_features.md not found at {new_features_path}", file=sys.stderr)
        sys.exit(1)

    tags = load_tags()
    token = os.environ.get("GITHUB_TOKEN")
    releases = fetch_github_releases(not args.no_github, token)
    items = parse_new_features(new_features_path, carry_forward_date=not args.strict_dates)

    ds_ids = sorted({item["ds_id"] for item in items if item.get("ds_id")})
    pr_info_map = {}
    if not args.no_github:
        for ds_id in ds_ids:
            pr_info = search_pr_info_github(ds_id, token)
            if pr_info:
                pr_info_map[ds_id] = pr_info
            time.sleep(0.2)

    for item in items:
        if item["impl_date"] is not None:
            continue
        ds_id = item.get("ds_id")
        if not ds_id:
            continue
        pr_info = pr_info_map.get(ds_id)
        date_source = None
        if pr_info:
            date_source = pr_info.get("closed_at") or pr_info.get("created_at")
        inferred = None
        if date_source:
            inferred = datetime.fromisoformat(date_source.replace("Z", "+00:00")).date()
        if not inferred:
            inferred = infer_impl_date_git(ds_id)
        if inferred:
            item["impl_date"] = inferred
            item["impl_date_str"] = inferred.isoformat()

    pr_map = {}
    for ds_id, pr_info in pr_info_map.items():
        if pr_info.get("number"):
            pr_map[ds_id] = pr_info["number"]
    for ds_id in ds_ids:
        if ds_id in pr_map:
            continue
        pr = search_pr_number_git(ds_id)
        if pr:
            pr_map[ds_id] = pr

    main_tags = [t for t in tags if t["name"].startswith("v1.") and "-ios" not in t["name"]]
    archive_tags = [t for t in tags if t not in main_tags]

    unreleased, main_body, archive_body = build_changelog(
        main_tags, archive_tags, items, releases, pr_map, include_release_notes=not args.no_github
    )

    header = (
        "# Changelog\n\n"
        "All notable changes to this project will be documented in this file.\n\n"
        "The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),\n"
        "and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).\n\n"
        "Each pull request must add a one-line, user-facing entry under **Unreleased** in the appropriate category, including the PR number.\n"
        "When applicable, include the feature reference ID and implementation date in ISO format (YYYY-MM-DD), for example:\n"
        "- [DS-068] Fix release notes accuracy (implemented 2025-12-25) (#PR_NUMBER)\n\n"
    )

    main_content = (
        header
        + unreleased
        + main_body
        + "\nHistorical entries and non-v1 releases have been moved to `Archive/CHANGELOG-ARCHIVE.md`.\n"
    )
    archive_header = (
        "# Changelog Archive\n\n"
        "Historical changelog entries for non-v1 releases are archived here.\n\n"
    )
    archive_content = archive_header + archive_body

    write_file(changelog_path, main_content, args.dry_run)
    write_file(archive_path, archive_content, args.dry_run)

    latest = latest_main_tag(tags)
    if os.path.exists(version_path):
        version = open(version_path, "r", encoding="utf-8").read().strip()
        if latest and f"v{version}" != latest["name"]:
            print(
                f"Warning: VERSION is {version} but latest tag is {latest['name']}.",
                file=sys.stderr,
            )
            print(
                "Entries newer than the latest tag will stay under [Unreleased].",
                file=sys.stderr,
            )


if __name__ == "__main__":
    main()
