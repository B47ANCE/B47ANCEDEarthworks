"""Portable offline source structure, case, translation and Workshop checks."""
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src/B47ANCEDEarthworks/42"


def check(condition, message):
    if not condition:
        raise SystemExit("FAIL: " + message)


def main():
    metadata = dict(line.split("=", 1) for line in (SOURCE / "mod.info").read_text().splitlines() if "=" in line)
    check(metadata["id"] == "B47ANCEDEarthworks" and metadata["name"] == "B47ANCE'd Earthworks", "Mod identity changed")
    check(set(metadata["require"].split(",")) == {"B47ANCEDKnowledgeAndWisdom", "CATConstruction"}, "Incorrect required Mod IDs")
    check((ROOT / "WORKSHOP_ID.txt").read_text().strip() == "3788591561", "Workshop item changed")
    files = [path for path in (ROOT / "src").rglob("*") if path.is_file()]
    names = [path.relative_to(ROOT / "src").as_posix() for path in files]
    check(len(names) == len({name.lower() for name in names}), "Case-colliding runtime paths")
    lua = SOURCE / "media/lua"
    modules = {path.relative_to(lua / side).with_suffix("").as_posix() for side in ("shared", "server", "client") for path in (lua / side).rglob("*.lua")}
    english = {path.name: json.loads(path.read_text(encoding="utf-8-sig")) for path in (lua / "shared/Translate/EN").glob("*.json")}
    keys = {key for values in english.values() for key in values}
    for path in (lua / "shared/Translate").glob("*/*.json"):
        values = json.loads(path.read_text(encoding="utf-8-sig"))
        check(path.name in english and set(values) == set(english[path.name]), "Translation/fallback keys differ: " + str(path))
        check(all(isinstance(value, str) and value for value in values.values()), "Empty translation: " + str(path))
    for path in lua.rglob("*.lua"):
        text = path.read_text(encoding="utf-8-sig")
        for module in re.findall(r"\brequire\s*\(?\s*['\"](groundWorks/[^'\"]+)['\"]", text):
            check(module in modules, "Missing or wrong-case import: " + module)
        for key in re.findall(r"getText\s*\(\s*['\"]((?:ContextMenu|IGUI|Sandbox)_groundWorks_[^'\"]+)['\"]", text):
            check(key in keys, "Missing translated player-facing key: " + key)
    sandbox = (SOURCE / "media/sandbox-options.txt").read_text()
    for key in re.findall(r"\btranslation\s*=\s*(groundWorks_\w+)", sandbox):
        check("Sandbox_" + key in keys and "Sandbox_" + key + "_tooltip" in keys, "Missing sandbox name/tooltip: " + key)
    workshop = (ROOT / "workshop.txt").read_text(encoding="utf-8").splitlines()
    check("title=B47ANCE'd Earthworks" in workshop and "visibility=public" in workshop, "Workshop title/visibility changed")
    for key, filename in (("description", "WORKSHOP_DESCRIPTION.txt"), ("changenote", "WORKSHOP_CHANGE_NOTE.txt")):
        mirrored = [line.partition("=")[2] for line in workshop if line.startswith(key + "=")]
        check(mirrored == (ROOT / filename).read_text(encoding="utf-8").splitlines(), key + " mirror/newline mismatch")
    print(f"PASS: identity, exact-case imports, {len(english)} English translation/fallback files, sandbox names/tooltips and Workshop mirrors. STATIC ONLY.")


if __name__ == "__main__":
    main()
