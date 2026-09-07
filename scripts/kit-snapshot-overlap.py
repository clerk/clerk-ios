#!/usr/bin/env python3
"""List ClerkKit types that still duplicate generated Snapshots models."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "Sources" / "ClerkKit"
SNAP = ROOT / "Sources" / "ClerkSnapshots" / "Generated"
TYPE_DECL = re.compile(r"^\s*public (?:struct|class|enum|actor) (\w+)\b", re.M)
# Generated Environment is ClerkEnvironment so @_exported ClerkSnapshots
# does not collide with SwiftUI.Environment. Kit still ships Clerk.Environment.
SNAP_CONCEPTUAL_NAMES = {
    "ClerkEnvironment": "Environment",
    "ClerkImage": "ImageResource",
    "TOTP": "TOTPResource",
    "BackupCode": "BackupCodeResource",
    "Role": "RoleResource",
    "Permission": "PermissionResource",
    "Token": "TokenResource",
}


def snapshot_types() -> dict[str, Path]:
    found: dict[str, Path] = {}
    for path in SNAP.rglob("*.swift"):
        if path.parent.name == "methods":
            continue
        for name in TYPE_DECL.findall(path.read_text()):
            if name == path.stem:
                found[name] = path
            conceptual = SNAP_CONCEPTUAL_NAMES.get(name)
            if conceptual:
                found[conceptual] = path
    return found


def kit_twins(snap: dict[str, Path]) -> dict[str, Path]:
    found: dict[str, Path] = {}
    for path in KIT.rglob("*.swift"):
        if path.name.endswith("+JS.swift"):
            continue
        name = path.stem
        if name not in snap:
            continue
        if not re.search(rf"^\s*public (?:struct|class|enum|actor) {re.escape(name)}\b", path.read_text(), re.M):
            continue
        found[name] = path
    return found


def main() -> int:
    snap = snapshot_types()
    kit = kit_twins(snap)
    overlap = sorted(kit)
    print(f"kit={len(kit)} snap={len(snap)} overlap={len(overlap)}")
    for name in overlap:
        print(f"{name}\tkit={kit[name].relative_to(ROOT)}\tsnap={snap[name].relative_to(ROOT)}")
    return 0 if not overlap else 1


if __name__ == "__main__":
    raise SystemExit(main())
