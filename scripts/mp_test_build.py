"""Prepare/verify a deterministic dedicated-MP diagnostic kit; never deploy or run PZ.

Only standalone Earthworks is packaged. No external runtime dependency is
required. Successful packaging never means native MP acceptance.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import stat
import subprocess
import sys
import zipfile


ROOT = Path(__file__).resolve().parents[1]
MOD = "B47ANCEDEarthworks"
WORKSHOP_ID = "3788591561"
TEXT = {".lua", ".txt", ".json", ".info", ".md", ".xml"}
FORBIDDEN = {".jar", ".java", ".class", ".dll", ".so", ".dylib", ".exe", ".zip", ".log", ".py", ".ps1", ".bat", ".cmd"}


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n").encode()


def digest(value):
    return hashlib.sha256(value).hexdigest()


def contents(path):
    value = path.read_bytes()
    return value.replace(b"\r\n", b"\n") if path.suffix.lower() in TEXT else value


def safe_file(root, path):
    if path.is_symlink() or getattr(path.lstat(), "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400):
        raise ValueError("Linked source entries are not allowed: " + path.name)
    if not path.resolve().is_relative_to(root.resolve()):
        raise ValueError("Source escaped its selected root")


def source_files(source):
    result = {}
    if not source.is_dir():
        raise ValueError("Selected source root is missing")
    safe_file(source, source)
    for path in sorted(source.rglob("*")):
        safe_file(source, path)
        if not path.is_file():
            continue
        name = path.relative_to(source).as_posix()
        value = contents(path)
        empty_marker = path.name == ".keep" and not value.strip() and not any(part.startswith(".") for part in path.relative_to(source).parts[:-1])
        if path.suffix.lower() in FORBIDDEN or (any(part.startswith(".") for part in path.relative_to(source).parts) and not empty_marker):
            raise ValueError("Unexpected executable/archive/private source entry: " + name)
        if value.startswith((b"MZ", b"\x7fELF", b"\xca\xfe\xba\xbe", b"PK\x03\x04")):
            raise ValueError("Executable/archive signature in selected source: " + name)
        if path.suffix.lower() in TEXT and (b"FadedJavaLoaderBridge" in value or b"luajava.bindClass" in value):
            raise ValueError("Custom Java dependency in selected source: " + name)
        result[name] = value
    if len(result) != len({name.lower() for name in result}):
        raise ValueError("Case-colliding source files")
    return result


def metadata(files):
    data = files.get("42/mod.info")
    if data is None:
        raise ValueError("Selected source has no authoritative 42/mod.info")
    return dict(line.split("=", 1) for line in data.decode("utf-8-sig").splitlines() if "=" in line)


def git(root, *args):
    result = subprocess.run(["git", "-c", "core.fsmonitor=false", "-C", str(root), *args], capture_output=True, text=True, timeout=30)
    return result.stdout.strip() if result.returncode == 0 else None


def snapshot(project, mod_id):
    source = project / "src" / mod_id
    if not source.is_dir():
        source = project  # Allows read-only checking of an already assembled mod root.
    files = source_files(source)
    info = metadata(files)
    if info.get("id") != mod_id:
        raise ValueError("Wrong source Mod ID: " + mod_id)
    version = (project / "VERSION").read_text(encoding="utf-8-sig").strip() if (project / "VERSION").is_file() else None
    if version is not None and version != info.get("modversion"):
        raise ValueError("Canonical/metadata version mismatch: " + mod_id)
    record = {
        "mod_id": mod_id,
        "metadata_version": info.get("modversion"),
        "canonical_version": version,
        "source_digest": digest(canonical({name: digest(value) for name, value in files.items()})),
        "file_count": len(files),
        "source_commit": git(project, "rev-parse", "HEAD"),
        "git_clean": git(project, "status", "--porcelain=v1") == "" if git(project, "rev-parse", "--show-toplevel") else None,
    }
    return record, files


def load_lock(path):
    value = json.loads(path.read_text(encoding="utf-8"))
    if value.get("schema") != 1 or value.get("target") != "dedicated-multiplayer":
        raise ValueError("Unsupported test lock/target")
    if value.get("dependencies") != {}:
        raise ValueError("Standalone test lock must not include external dependencies")
    return value


def verify_sources(lock):
    actual, files = snapshot(ROOT, MOD)
    if actual["metadata_version"] != lock["earthworks_version"]:
        raise ValueError("Earthworks version differs from test lock")
    if set(filter(None, metadata(files).get("require", "").split(","))):
        raise ValueError("Standalone Earthworks must not require external mods")
    return actual, files


def package_entries(files):
    prefix = "mods/" + MOD + "/"
    entries = {prefix + name: value for name, value in files.items() if name.startswith(("42/", "common/"))}
    # Keep the B42 version/common layout explicit; no obsolete root mod.info.
    entries[prefix + "common/"] = b""
    return entries


def zip_bytes(entries):
    import io
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_STORED) as archive:
        for name, value in sorted(entries.items()):
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.compress_type = zipfile.ZIP_STORED
            info.external_attr = ((0o40755 if name.endswith("/") else 0o100644) << 16)
            if name.endswith("/"):
                info.external_attr |= 0x10
            archive.writestr(info, value)
    return output.getvalue()


def inspect_archive(path, expected):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or len(names) != len({name.lower() for name in names}):
            raise ValueError("Duplicate/case-colliding archive members")
        for info in archive.infolist():
            member = PurePosixPath(info.filename)
            if member.is_absolute() or ".." in member.parts or "\\" in info.filename or ":" in info.filename:
                raise ValueError("Unsafe archive member")
            if (info.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError("Linked archive member")
            if info.filename not in expected:
                raise ValueError("Unexpected archive member")
            if info.file_size != len(expected[info.filename]):
                raise ValueError("Archive member size differs from source")
            if digest(archive.read(info)) != digest(expected[info.filename]):
                raise ValueError("Archive/source fingerprint mismatch")
        if set(names) != set(expected) or archive.testzip() is not None:
            raise ValueError("Missing archive member or CRC failure")


def write_once(path, data):
    if path.exists():
        if path.read_bytes() != data:
            raise ValueError("Existing build output differs; preserved without overwrite: " + path.name)
    else:
        with path.open("xb") as output:
            output.write(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("lock", "build", "preflight"))
    parser.add_argument("--lock", type=Path, default=ROOT / "docs/MP_TEST_DEPENDENCIES.json")
    parser.add_argument("--output", type=Path, default=ROOT / "dist/mp-tests")
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    if args.command == "lock":
        if args.lock.exists():
            raise ValueError("Existing reviewed lock is preserved; choose a new lock path for review")
        records = {}
        value = {"schema": 1, "target": "dedicated-multiplayer", "earthworks_version": (ROOT / "VERSION").read_text().strip(), "dependencies": records, "runtime_status": "NOT_TESTED", "g7": "BLOCKED / NOT_TESTED", "g8": "BLOCKED"}
        args.lock.parent.mkdir(parents=True, exist_ok=True)
        args.lock.write_bytes(canonical(value))
        print(json.dumps({"lock": str(args.lock), "readiness": "NATIVE_NOT_TESTED", "blockers": []}, indent=2))
        return 0
    lock = load_lock(args.lock)
    for script in ("check_versions.py", "check_lua_only.py", "validate_source.py"):
        subprocess.run([sys.executable, str(ROOT / "scripts" / script)], cwd=ROOT, check=True)
    source, files = verify_sources(lock)
    entries = package_entries(files)
    if args.command == "preflight":
        if args.archive:
            inspect_archive(args.archive, entries)
            if digest(args.archive.read_bytes()) != digest(zip_bytes(entries)):
                raise ValueError("Archive bytes differ from deterministic source build")
        print(json.dumps({"integrity": "PASS", "dedicated_gameplay_readiness": "READY_FOR_NATIVE_TEST", "blockers": [], "g7": "BLOCKED / NOT_TESTED", "g8": "BLOCKED"}, indent=2))
        return 0
    data = zip_bytes(entries)
    revision = git(ROOT, "rev-parse", "HEAD")
    key = digest(canonical({"source": source["source_digest"], "lock": digest(canonical(lock)), "revision": revision,
        "checklist": digest((ROOT / "docs/DEDICATED_TESTING.md").read_bytes()),
        "results": digest((ROOT / "docs/MP_RESULTS_TEMPLATE.json").read_bytes()),
        "builder": digest(Path(__file__).read_bytes())}))[:16]
    if not args.output.resolve().is_relative_to(ROOT.resolve() / "dist"):
        raise ValueError("Build output must stay inside this checkout's dist directory")
    output = args.output / ("earthworks-" + lock["earthworks_version"] + "-dedicated-" + key)
    if output.exists() or output.is_symlink():
        safe_file(ROOT / "dist", output)
    if not output.resolve().is_relative_to(ROOT.resolve() / "dist"):
        raise ValueError("Generated build folder escaped this checkout's dist directory")
    output.mkdir(parents=True, exist_ok=True)
    archive = output / ("Earthworks-" + lock["earthworks_version"] + "-dedicated-test.zip")
    write_once(archive, data)
    inspect_archive(archive, entries)
    manifest = {"schema": 1, "target": "dedicated-multiplayer", "mod_id": MOD, "workshop_id": WORKSHOP_ID, "version": lock["earthworks_version"], "source_commit": revision, "source_dirty": bool(git(ROOT, "status", "--porcelain=v1")), "source_digest": source["source_digest"], "dependency_lock_sha256": digest(canonical(lock)), "archive": archive.name, "archive_sha256": digest(data), "archive_members": len(entries), "runtime_files": len(entries) - 1, "scope": "Standalone Earthworks; no external runtime dependencies", "dedicated_gameplay_readiness": "READY_FOR_NATIVE_TEST", "blockers": [], "g7": "BLOCKED / NOT_TESTED", "g8": "BLOCKED"}
    write_once(output / "build-manifest.json", canonical(manifest))
    write_once(output / "dependencies.lock.json", canonical(lock))
    write_once(output / "DEDICATED_TEST_CHECKLIST.md", (ROOT / "docs/DEDICATED_TESTING.md").read_bytes())
    write_once(output / "results-template.json", (ROOT / "docs/MP_RESULTS_TEMPLATE.json").read_bytes())
    print(json.dumps({"build": "PASS", "output": str(output), **manifest}, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, KeyError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        raise SystemExit("FAIL: " + str(error))
