#!/usr/bin/env python3
from __future__ import annotations
import json
import subprocess
from pathlib import Path
import sys

DOCS_DIR = Path(__file__).parent
MANIFEST_FILE = DOCS_DIR / "manifest.json"


def list_markdown_files():
    return sorted(p.relative_to(DOCS_DIR) for p in DOCS_DIR.rglob("*.md"))


def blob_sha1(file_path: Path) -> str:
    result = subprocess.run(
        ["git", "hash-object", str(file_path)],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def build_manifest() -> dict:
    docs = [
        {
            "path": str(rel).replace("\\", "/"),
            "sha": blob_sha1(DOCS_DIR / rel),
        }
        for rel in list_markdown_files()
    ]
    return {"docs": docs}


def write_manifest(data: dict) -> None:
    MANIFEST_FILE.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    check_mode = "--check" in sys.argv
    manifest = build_manifest()
    if check_mode:
        if not MANIFEST_FILE.exists():
            print("docs/manifest.json is missing", file=sys.stderr)
            sys.exit(1)
        existing = json.loads(MANIFEST_FILE.read_text(encoding="utf-8"))
        if existing != manifest:
            print("docs/manifest.json is out of date. Run update_manifest.py.", file=sys.stderr)
            sys.exit(1)
    else:
        write_manifest(manifest)


if __name__ == "__main__":
    main()
