#!/usr/bin/env python3
"""List ClerkKit types that still duplicate generated Snapshots models."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "Sources" / "ClerkKit"
SNAP = ROOT / "Sources" / "ClerkSnapshots" / "Generated"


def type_files(root: Path, skip_js_extensions: bool = False) -> dict[str, Path]:
    found: dict[str, Path] = {}
    for path in root.rglob("*.swift"):
        if skip_js_extensions and path.name.endswith("+JS.swift"):
            continue
        if path.parent.name == "methods":
            continue
        found[path.stem] = path
    return found


def main() -> int:
    kit = type_files(KIT, skip_js_extensions=True)
    snap = type_files(SNAP)
    overlap = sorted(set(kit) & set(snap))
    print(f"kit={len(kit)} snap={len(snap)} overlap={len(overlap)}")
    for name in overlap:
        print(f"{name}\tkit={kit[name].relative_to(ROOT)}\tsnap={snap[name].relative_to(ROOT)}")
    return 0 if not overlap else 1


if __name__ == "__main__":
    raise SystemExit(main())
