#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

python3 - <<'PY'
import json, os, re, sys

catalogs = {
    "Sources/ClerkKit": "Sources/ClerkKit/Resources/Localizable.xcstrings",
    "Sources/ClerkKitUI": "Sources/ClerkKitUI/Resources/Localizable.xcstrings",
}
github = bool(os.environ.get("GITHUB_ACTIONS"))
failures = 0


def report(path, line, message):
    global failures
    failures += 1
    if github:
        print(f"::error file={path},line={line}::{message}")
    else:
        print(f"error: {path}:{line}: {message}", file=sys.stderr)


def line_of(text, offset):
    return text.count("\n", 0, offset) + 1


keys = {}
for module, path in catalogs.items():
    raw = open(path).read()
    catalog = json.load(open(path))
    source_language = catalog["sourceLanguage"]
    entries = catalog["strings"]
    locales = set()
    for entry in entries.values():
        locales |= set(entry.get("localizations", {})) - {source_language}
    for key, entry in entries.items():
        if entry.get("shouldTranslate") is False or entry.get("extractionState") == "stale":
            continue
        translated = {
            locale
            for locale, value in entry.get("localizations", {}).items()
            if value.get("stringUnit", {}).get("value") or value.get("variations")
        }
        missing = sorted(locales - translated)
        if missing:
            offset = raw.find(json.dumps(key, ensure_ascii=False) + " :")
            report(path, line_of(raw, max(offset, 0)), f'"{key}" has no translation for {", ".join(missing)}. Add one in every shipped language.')
    keys[module] = set(entries)

format_specifier = r"%(?:\d+\$)?(?:@|l{0,2}[dui]|f|\.\d+f)"


def literal_pattern(literal):
    parts = re.split(r"\\\((?:[^()]|\([^()]*\))*\)", literal)
    unescaped = [bytes(part, "utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8") for part in parts]
    return re.compile(format_specifier.join(re.escape(part) for part in unescaped))


def has_key(module, literal):
    if "\\(" not in literal:
        return bytes(literal, "utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8") in keys[module]
    pattern = literal_pattern(literal)
    return any(pattern.fullmatch(key) for key in keys[module])


def preview_ranges(text):
    ranges = []
    for match in re.finditer(r"^#Preview\b[^{]*", text, re.M):
        start = match.end()
        ranges.append((match.start(), start + len(call_arguments(text, start, "{", "}")) + 2))
    return ranges


def call_arguments(text, open_paren, opener="(", closer=")"):
    depth = 0
    index = open_paren
    in_string = False
    while index < len(text):
        char = text[index]
        if in_string:
            if char == "\\":
                index += 1
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif char == opener:
            depth += 1
        elif char == closer:
            depth -= 1
            if depth == 0:
                return text[open_paren + 1 : index]
        index += 1
    return text[open_paren + 1 :]


looked_up = r"(Text|WarningText|LocalizedStringKey|String\(\s*localizedInClerkUI:|String\(\s*localized:|ClerkClientError\(\s*message:)"
main_bundle_only = r"(Button|Label|Toggle|Section|TextField|SecureField|Link|Picker|Menu|NavigationLink)"
call = re.compile(r"(?<![\w.])(?:" + looked_up + r"|" + main_bundle_only + r")[(\s]\s*\"((?:[^\"\\\n]|\\.)*)\"")

for module in catalogs:
    for directory, _, files in os.walk(module):
        if module == "Sources/ClerkKit" and directory.startswith("Sources/ClerkKitUI"):
            continue
        for name in files:
            if not name.endswith(".swift"):
                continue
            path = os.path.join(directory, name)
            text = open(path).read()
            previews = preview_ranges(text)
            for match in call.finditer(text):
                if any(start <= match.start() < end for start, end in previews):
                    continue
                lookup, ui_title, literal = match.groups()
                lookup = lookup and lookup.split("(")[0]
                line_start = text.rfind("\n", 0, match.start()) + 1
                if text[line_start : match.start()].lstrip().startswith("//") or not literal.strip():
                    continue
                line = line_of(text, match.start())
                arguments = call_arguments(text, text.index("(", match.start()))
                if ui_title:
                    report(path, line, f'{ui_title}("{literal}") looks its title up in the app\'s bundle, so it shows in English. Build the title from Text("{literal}", bundle: .module).')
                    continue
                if lookup in ("Text", "WarningText") and "bundle:" not in arguments:
                    report(path, line, f'{lookup}("{literal}") looks its text up in the app\'s bundle, so it shows in English. Pass bundle: .module.')
                    continue
                if lookup == "ClerkClientError" and "localizationBundle:" not in arguments:
                    report(path, line, f'ClerkClientError(message: "{literal}") is never translated. Pass localizationBundle: .module.')
                    continue
                if not has_key(module, literal):
                    report(path, line, f'"{literal}" has no key in {catalogs[module]}, so it shows in English in every language. Add the key with a translation in every shipped language.')

if failures:
    print(f"Localization check failed with {failures} issue(s).", file=sys.stderr)
    sys.exit(1)
print("Localization check passed.")
PY
