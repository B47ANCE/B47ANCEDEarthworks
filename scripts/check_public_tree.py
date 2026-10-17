"""Audit Git's selected public files and source hashes without printing secrets."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[1]
MARKERS = (
    re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(rb"github_pat_[A-Za-z0-9_]{30,}"),
    re.compile(rb"gh[pousr]_[A-Za-z0-9]{30,}"),
    re.compile(rb"AKIA[A-Z0-9]{16}"),
    re.compile(rb"xox[baprs]-[A-Za-z0-9-]{20,}"),
)
FORBIDDEN_PARTS = {".agents", ".codex", "dist", "contents", "__pycache__", "node_modules", "local-history", "historical", "logs", "diagnostics"}
FORBIDDEN_SUFFIXES = {".log", ".jar", ".class", ".java", ".dll", ".so", ".zip", ".7z", ".pem", ".ppk", ".pfx", ".key", ".p12", ".db", ".sav"}


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staged", action="store_true")
    staged = parser.parse_args().staged
    names = [name for name in git("ls-files", "-z").decode().split("\0") if name]
    if not names:
        raise SystemExit("FAIL: no selected public files")
    inventory = json.loads((ROOT / "docs/SOURCE_INVENTORY.json").read_text(encoding="utf-8"))
    allowed_root = set(inventory["public_root_files"])
    allowed_docs = set(inventory["public_documents"])
    issues = []
    if len({name.lower() for name in names}) != len(names):
        issues.append("Case-colliding public paths")
    def content(name):
        return git("show", ":" + name) if staged else (ROOT / name).read_bytes()
    for name in names:
        path = Path(name)
        parts = {part.lower() for part in path.parts}
        if path.is_absolute() or ".." in path.parts or ":" in name or "\\" in name:
            issues.append(name + ": unsafe public path")
            continue
        if FORBIDDEN_PARTS & parts or path.suffix.lower() in FORBIDDEN_SUFFIXES or path.name.lower() in {"local.settings.json", "console.txt", "server-console.txt", "id_rsa", "id_ed25519", ".steamcmd-last-upload.sha256", "sha256sums.txt"} or path.name.startswith(".env"):
            issues.append(name + ": private/generated/historical artifact")
            continue
        if path.parts[0] == "docs" and name not in allowed_docs:
            issues.append(name + ": document outside public inventory")
        elif len(path.parts) == 1 and name not in allowed_root:
            issues.append(name + ": root file outside public inventory")
        elif len(path.parts) > 1 and path.parts[0] not in {"docs", "src", "tests", "scripts", ".github"}:
            issues.append(name + ": unexpected public directory")
        if (ROOT / path).is_symlink() or not (ROOT / path).resolve().is_relative_to(ROOT.resolve()):
            issues.append(name + ": linked/outside-workspace file")
            continue
        data = content(name)
        if any(marker.search(data) for marker in MARKERS):
            issues.append(name + ": credential marker (value suppressed)")
    for entry in git("ls-files", "--stage", "-z").decode().split("\0"):
        if entry and entry.startswith("120000 "):
            issues.append(entry.partition("\t")[2] + ": linked index entry")
    provenance = json.loads(content("docs/SOURCE_PROVENANCE_CURRENT.json"))
    expected_paths = set(provenance["files_sha256"])
    actual_paths = {name for name in names if name.startswith("src/")}
    if expected_paths != actual_paths:
        issues.append("Current source provenance inventory differs from selected runtime source")
    for name, expected in provenance["files_sha256"].items():
        if name not in actual_paths:
            continue
        data = content(name)
        if Path(name).suffix.lower() != ".png":
            data = data.replace(b"\r\n", b"\n")
        if hashlib.sha256(data).hexdigest() != expected:
            issues.append(name + ": current source fingerprint mismatch")
    if issues:
        raise SystemExit("\n".join(issues))
    print(f"PASS: {len(names)} public files; {len(actual_paths)} source hashes; credential/artifact heuristic. Manual diff review remains required.")


if __name__ == "__main__":
    main()
