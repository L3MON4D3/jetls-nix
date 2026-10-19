"""Restore metadata omitted by nixpkgs' project.py for unregistered overrides.

Do not resolve again: keep withPackages' Julia-version-specific dependency graph.
"""
from pathlib import Path
import sys
import toml

manifest_path = Path(sys.argv[1]) / "Manifest.toml"
manifest = toml.load(manifest_path)
for entries in manifest["deps"].values():
    for entry in entries:
        if "path" not in entry:
            continue
        project = toml.load(Path(entry["path"]) / "Project.toml")
        weakdeps = project.get("weakdeps", {})
        deps = [name for name in project.get("deps", {}) if name not in weakdeps]
        if deps:
            entry["deps"] = deps
        for key in ("version", "weakdeps", "extensions"):
            if key in project:
                entry[key] = project[key]
with manifest_path.open("w") as output:
    toml.dump(manifest, output)
