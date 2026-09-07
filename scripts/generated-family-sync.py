#!/usr/bin/env python3
"""Diff Generated files that must match a generator emit directory.

Usage:
  python3 scripts/generated-family-sync.py /tmp/swift-models-ios4
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GENERATED = ROOT / "Sources" / "ClerkSnapshots" / "Generated"

# Root Generated files the generator owns. Method façades stay unpublished.
MUST_MATCH = sorted(path.name for path in GENERATED.glob("*.swift"))


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: generated-family-sync.py <generator-out-dir>", file=sys.stderr)
        return 2
    emitted = Path(sys.argv[1])
    drift = []
    missing = []
    for name in MUST_MATCH:
        kit = GENERATED / name
        gen = emitted / name
        if not kit.exists() or not gen.exists():
            missing.append(name)
            continue
        if kit.read_text() != gen.read_text():
            drift.append(name)
    print(f"match={len(MUST_MATCH) - len(drift) - len(missing)} drift={len(drift)} missing={len(missing)}")
    for name in drift:
        print(f"drift {name}")
    for name in missing:
        print(f"missing {name}")
    return 1 if drift or missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
