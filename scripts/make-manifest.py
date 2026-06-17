#!/usr/bin/env python3
import hashlib
import json
import re
import sys
from pathlib import Path


def sha256(path):
    digest = hashlib.sha256()

    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)

    return digest.hexdigest()


def main():
    dist = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "dist")

    if not dist.is_dir():
        raise SystemExit("Distribution directory does not exist.")

    pattern = re.compile(r"^privacy-filter-(?P<os>linux|darwin|windows)-(?P<arch>x64|arm64)\.(?P<extension>tar\.gz|zip)$")
    archive_paths = sorted([*dist.glob("privacy-filter-*.tar.gz"), *dist.glob("privacy-filter-*.zip")])
    assets = []
    checksums = []

    for path in archive_paths:
        match = pattern.match(path.name)

        if not match:
            continue

        file_hash = sha256(path)

        assets.append({
            "os": match.group("os"),
            "arch": match.group("arch"),
            "cpuOnly": True,
            "filename": path.name,
            "sha256": file_hash,
        })

        checksums.append(f"{file_hash}  {path.name}")

    assets.sort(key=lambda asset: (asset["os"], asset["arch"]))
    checksums.sort()

    manifest = {
        "schemaVersion": 1,
        "assets": assets,
    }

    (dist / "manifest.json").write_text(json.dumps(manifest, indent=4) + "\n", encoding="utf-8")
    (dist / "checksums.txt").write_text("\n".join(checksums) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
