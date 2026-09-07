#!/usr/bin/env python3
"""Reject new ClerkKit HTTP request writers while tracking the remaining migration."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "Sources" / "ClerkKit"
ALLOWED = {
    "AppAttestHelper.swift",
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
    pending = [path.relative_to(ROOT) for path in KIT.rglob("*.swift")
               if path.name in {"AppAttestHelper.swift"} and "Request<" in path.read_text()]
    print(f"Pending migration: {len(pending)}")
    for path in pending:
        print(path)
    print(f"Unexpected request writers: {len(leftover)}")
    for path in leftover:
        print(path)
    return 0 if not leftover else 1


if __name__ == "__main__":
    raise SystemExit(main())
