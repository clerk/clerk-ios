#!/usr/bin/env python3
"""Reject ClerkKit HTTP request writers outside generic transport infrastructure."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "Sources" / "ClerkKit"
ALLOWED = {
    "APIRequest.swift",
    "ClientResponse.swift",
    "ClerkAPIClient.swift",
}


def main() -> int:
    leftover = []
    for path in KIT.rglob("*.swift"):
        if path.name in ALLOWED:
            continue
        text = path.read_text()
        if "Request<" not in text:
            continue
        leftover.append(path.relative_to(ROOT))
    print(f"Unexpected request writers: {len(leftover)}")
    for path in leftover:
        print(path)
    return 0 if not leftover else 1


if __name__ == "__main__":
    raise SystemExit(main())
