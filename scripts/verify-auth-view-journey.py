#!/usr/bin/env python3
"""Require the named rendered iOS journey and its three screenshot attachments."""
import json
from pathlib import Path
import sys

EXPECTED = "AuthJourneyTests/testEmailCodeErrorRetryAndPrebuiltFinalization()"
SCREENSHOTS = ("01-identifier", "02-invalid-code", "03-completed")


def verify(output):
    report = json.loads((output / "tests.json").read_text())
    cases = []

    def visit(nodes):
        for node in nodes:
            if node["nodeType"] == "Test Case":
                cases.append(node)
            visit(node.get("children", []))

    visit(report["testNodes"])
    if len(cases) != 1 or cases[0].get("nodeIdentifier") != EXPECTED or cases[0].get("result") != "Passed":
        raise ValueError("Expected the exact named UI journey to execute once and pass")
    devices = report["devices"]
    if len(devices) != 1 or devices[0].get("platform") != "iOS Simulator":
        raise ValueError("Expected one iOS Simulator execution")
    manifest = json.loads((output / "attachments/manifest.json").read_text())
    entries = [entry for entry in manifest if entry.get("testIdentifier") == EXPECTED]
    if len(entries) != 1:
        raise ValueError("Missing or duplicate journey attachment records")
    attachments = entries[0]["attachments"]
    for name in SCREENSHOTS:
        matches = [item for item in attachments if item["suggestedHumanReadableName"].startswith(name + "_")]
        if len(matches) != 1:
            raise ValueError(f"Expected exactly one {name} screenshot")
        screenshot = output / "attachments" / matches[0]["exportedFileName"]
        if not screenshot.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError(f"Invalid PNG screenshot: {name}")


if __name__ == "__main__":
    try:
        verify(Path(sys.argv[1]))
    except (OSError, ValueError, KeyError, TypeError, IndexError) as error:
        raise SystemExit(f"iOS auth journey evidence incomplete: {error}") from None
    print("The rendered iOS authentication journey and all three screenshots passed verification.")
