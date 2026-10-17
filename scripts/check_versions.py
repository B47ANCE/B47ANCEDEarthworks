"""Validate canonical SemVer and exact current mirrors; history stays historical."""
import argparse
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    number = r"(?:0|[1-9][0-9]*)"
    pattern = rf"{number}\.{number}\.{number}(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    matched = re.fullmatch(pattern, version)
    if not matched or (matched.group(1) and any(part.isdigit() and len(part) > 1 and part.startswith("0") for part in matched.group(1).split("."))):
        raise SystemExit("FAIL: VERSION must contain one valid Semantic Version")
    mirrors = json.loads((ROOT / "docs/VERSION_MIRRORS.json").read_text(encoding="utf-8"))
    errors = []
    for mirror in mirrors:
        path = Path(mirror["path"])
        if path.is_absolute() or ".." in path.parts or ":" in mirror["path"]:
            errors.append("Unsafe mirror path")
            continue
        text = (ROOT / path).read_text(encoding="utf-8-sig")
        found = re.search(mirror["pattern"], text, re.M)
        if not found or found.group(1) != version:
            errors.append(mirror["path"])
    if errors:
        raise SystemExit("FAIL: missing/mismatched current mirrors: " + ", ".join(errors))
    print(f"PASS: VERSION {version}; {len(mirrors)} current mirrors. Historical evidence excluded.")
    if args.release:
        raise SystemExit("G8 BLOCKED: no current release artifact/provenance workflow or dedicated G7 PASS. Source consistency is not release approval.")


if __name__ == "__main__":
    main()
