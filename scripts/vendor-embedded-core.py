#!/usr/bin/env python3
"""Build and vendor the JS-owned embedding entry, or verify the vendored artifact."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
resources = root / "Sources/ClerkJSCore/Resources"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=Path, default=root.parent / "clerk-js-ios-embed")
parser.add_argument("--check", action="store_true", help="Verify the installed bundle against its manifest without building")
args = parser.parse_args()
manifest_path = resources / "embedded-core.json"
bundle_path = resources / "clerk.embedded.js"


def digest(data):
    return hashlib.sha256(data).hexdigest()


if args.check:
    manifest = json.loads(manifest_path.read_text())
    if manifest["protocolVersion"] != 1 or digest(bundle_path.read_bytes()) != manifest["sha256"]:
        raise SystemExit("Embedded bundle does not match its protocol/digest manifest")
    if digest((resources / "clerk.authorization.js").read_bytes()) != manifest["authorizationSha256"]:
        raise SystemExit("Authorization bundle does not match its digest manifest")
    print("Embedded protocol 1 and bundle SHA-256 verified")
else:
    source = args.source.resolve()
    shared = source / "packages/shared"
    clerk_js = source / "packages/clerk-js"
    subprocess.run(["pnpm", "build"], cwd=shared, check=True)
    subprocess.run(["pnpm", "exec", "rspack", "build", "--config", "rspack.config.mjs", "--env", "production", "--env", "variant=clerk.embedded"], cwd=clerk_js, check=True)
    subprocess.run(["pnpm", "exec", "rspack", "build", "--config", "rspack.config.mjs", "--env", "production", "--env", "variant=clerk.authorization"], cwd=clerk_js, check=True)
    authorization = (clerk_js / "dist/clerk.authorization.js").read_bytes()
    bundle = (clerk_js / "dist/clerk.embedded.js").read_bytes()
    source_digest = hashlib.sha256()
    files = [source / "pnpm-lock.yaml", clerk_js / "rspack.config.mjs"]
    for package in [shared, clerk_js]:
        files.append(package / "package.json")
        files.extend(path for path in (package / "src").rglob("*") if path.is_file())
    for path in sorted(files):
        source_digest.update(str(path.relative_to(source)).encode() + b"\0" + path.read_bytes() + b"\0")
    manifest = {
        "protocolVersion": 1,
        "entry": "@clerk/clerk-js/index.embedded",
        "clerkJsVersion": json.loads((clerk_js / "package.json").read_text())["version"],
        "sourceRevision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=source, text=True).strip(),
        "sourceSha256": source_digest.hexdigest(),
        "sha256": digest(bundle),
        "authorizationSha256": digest(authorization),
    }
    bundle_path.write_bytes(bundle)
    (resources / "clerk.authorization.js").write_bytes(authorization)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Vendored {len(bundle)} bytes; SHA-256 {manifest['sha256']}")
