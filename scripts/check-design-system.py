#!/usr/bin/env python3
"""Design-system ratchet (UI-FRAMEWORK-92).

Screens must not draw their own colours, shapes, button looks or bar spacing:
those live in native-next/Sources/DesignSystem/ and NativeDesign.swift. Older
screens still contain some of these; their counts are frozen in
docs/design-system-baseline.json and may only go down. A line ending with
`// DS-EXCEPTION: <reason>` is allowed and reported.

Usage: check-design-system.py [--update-baseline]
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "native-next/Sources"
BASELINE = ROOT / "docs/design-system-baseline.json"
ALLOWED = {"NativeDesign.swift", "NativeComponents.swift", "LifeOSShiftPalette.swift"}
RULES = {
    "raw-color": r"Color\((red|white|hue):|UIColor\((red|white):|Color\(uiColor: UIColor \{",
    "fixed-font-size": r"\.font\(\.system\(size:",
    "shadow": r"\.shadow\(",
    "glass-effect": r"\.glassEffect\(",
    "bottom-bar-inset": r"\.safeAreaInset\(edge: \.bottom|\.safeAreaPadding\(\.bottom|\.overlay\(alignment: \.bottom\)",
    "literal-radius": r"cornerRadius: [0-9]",
    "system-button-look": r"\.buttonStyle\(\.(bordered|borderedProminent|glassProminent)\)",
    "hand-drawn-surface": r"\.background\([^)]*, in: (RoundedRectangle|Capsule|Circle)",
}

def scan():
    counts, exceptions = {}, []
    for path in sorted(SOURCES.rglob("*.swift")):
        rel = path.relative_to(SOURCES).as_posix()
        if rel.startswith("DesignSystem/") or path.name in ALLOWED:
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if "// DS-EXCEPTION:" in line:
                exceptions.append(f"{rel}:{number}: {line.split('// DS-EXCEPTION:', 1)[1].strip()}")
                continue
            for rule, pattern in RULES.items():
                hits = len(re.findall(pattern, line))
                if hits:
                    key = f"{rel}|{rule}"
                    counts[key] = counts.get(key, 0) + hits
    return counts, exceptions

def main():
    counts, exceptions = scan()
    if "--update-baseline" in sys.argv:
        BASELINE.write_text(json.dumps(dict(sorted(counts.items())), indent=1) + "\n", encoding="utf-8")
        print(f"baseline written: {sum(counts.values())} legacy occurrences in {len(counts)} file/rule pairs")
        return 0
    baseline = json.loads(BASELINE.read_text(encoding="utf-8")) if BASELINE.exists() else {}
    grown = {k: (baseline.get(k, 0), v) for k, v in counts.items() if v > baseline.get(k, 0)}
    shrunk = {k: (v, counts.get(k, 0)) for k, v in baseline.items() if counts.get(k, 0) < v}
    for line in exceptions:
        print("DS_EXCEPTION " + line)
    if shrunk:
        print(f"DS_IMPROVED {len(shrunk)} file/rule pairs below baseline (run --update-baseline to lock it in)")
    if grown:
        for key, (old, new) in sorted(grown.items()):
            file, rule = key.split("|")
            print(f"DS_VIOLATION {file}: {rule} {old} -> {new}. Use a component from Sources/DesignSystem or NativeDesign tokens.")
        return 1
    print(f"DS_OK legacy={sum(counts.values())} exceptions={len(exceptions)}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
