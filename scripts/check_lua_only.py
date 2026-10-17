"""Read-only Java/native dependency gate for the authoritative runtime source.

Historical documents and archives are deliberately outside this scope.
This is an offline source check, not a package or PZ runtime certification.
"""
import argparse
import json
from pathlib import Path
import re
import stat


BLOCKED_SUFFIXES = {
    ".jar", ".class", ".java", ".dll", ".so", ".dylib", ".exe",
    ".zip", ".py", ".js", ".ps1", ".bat", ".cmd",
}
TEXT_SUFFIXES = {".lua", ".txt", ".json", ".info"}
BLOCKED_REFERENCE = re.compile(
    r"FadedJavaLoader(?:Bridge)?|EnableFJLVisibility|FJLVisibility(?:Available|Active)"
    r"|\bluajava\b|\bjava\.lang\b|\bClass\.forName\b",
    re.IGNORECASE,
)


def inspect_source(source):
    errors = []
    checked = 0
    if not source.is_dir():
        return ["runtime source directory is missing"], checked
    if not (source / "42/mod.info").is_file():
        errors.append("42/mod.info is missing")
    for path in sorted(source.rglob("*")):
        relative = path.relative_to(source).as_posix()
        attributes = getattr(path.lstat(), "st_file_attributes", 0)
        if path.is_symlink() or attributes & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400):
            errors.append(f"{relative}: linked runtime content requires separate review")
            continue
        if not path.is_file():
            continue
        checked += 1
        if path.suffix.lower() in BLOCKED_SUFFIXES:
            errors.append(f"{relative}: executable/source/archive is not a Lua runtime asset")
            continue
        data = path.read_bytes()
        # Detect renamed PE/ELF/class/archive payloads as well as their extensions.
        if data.startswith((b"MZ", b"\x7fELF", b"\xca\xfe\xba\xbe", b"PK\x03\x04")):
            errors.append(f"{relative}: executable or archive signature in runtime source")
            continue
        if path.suffix.lower() in TEXT_SUFFIXES:
            try:
                text = data.decode("utf-8-sig")
            except UnicodeDecodeError:
                errors.append(f"{relative}: runtime text is not UTF-8")
                continue
            for number, line in enumerate(text.splitlines(), 1):
                if BLOCKED_REFERENCE.search(line):
                    errors.append(f"{relative}:{number}: retired bridge or Java binding reference")
    return errors, checked


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1] / "src/B47ANCEDEarthworks")
    args = parser.parse_args()
    errors, checked = inspect_source(args.source)
    print(json.dumps({"status": "FAIL" if errors else "PASS", "scope": "authoritative runtime source only", "files_checked": checked, "errors": errors}, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
