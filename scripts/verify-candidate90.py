"""Fail-closed evidence and bundle checks for the manually authorized build 90."""
import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path
from zipfile import ZipFile

TARGETED = [
    "LifeOSProbeUITests/NativeNavigationUITests/testSixVisibleTabsPreserveCalendarFinanceAndDashboardStacks",
    "LifeOSProbeUITests/NativeNavigationUITests/testSixVisibleTabsWithLargeTextAndKeyboard",
    "LifeOSProbeUITests/NativePersonalFoodUITests/testSupplementTabSeparatesFoodsAndSearchesKnownBrands",
]
RELEASE_MODES = ["fresh", "synthetic-upgrade", "synthetic-populated-upgrade", "synthetic-session-upgrade"]

def context():
    sha = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    assert sha == os.environ["GITHUB_SHA"], "Checkout does not match run SHA"
    return {"sourceCommit": sha, "runID": os.environ["GITHUB_RUN_ID"], "runAttempt": os.environ["GITHUB_RUN_ATTEMPT"]}

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def extract_suite(bundle):
    def get(kind):
        return json.loads(subprocess.check_output(["xcrun", "xcresulttool", "get", "test-results", kind, "--path", str(bundle)], text=True))
    summary, tree = get("summary"), get("tests")
    assert summary["failedTests"] == 0 and summary["skippedTests"] == 0, summary
    assert summary.get("expectedFailures", 0) == 0 and summary["result"] == "Passed", summary
    assert summary["totalTestCount"] == summary["passedTests"] > 0, summary
    cases = []
    def visit(node):
        if isinstance(node, dict):
            if node.get("nodeType") == "Test Case":
                assert node.get("result") == "Passed", node
                identifier = node["nodeIdentifierURL"].split("/LifeOSProbe/", 1)[1]
                cases.append(identifier.rstrip("/").removesuffix("()"))
            for value in node.values():
                if isinstance(value, (dict, list)): visit(value)
        elif isinstance(node, list):
            for value in node: visit(value)
    visit(tree)
    assert len(cases) == len(set(cases)) == summary["passedTests"], ("Duplicated or missing test evidence", cases, summary)
    return summary, cases, tree

def verify_test_partition(preflight, remaining):
    assert set(preflight) == set(TARGETED) and len(preflight) == 3, preflight
    assert len(remaining) == len(set(remaining)), "Duplicate remaining test evidence"
    assert remaining and not set(preflight).intersection(remaining), "A preflight case was repeated"
    assert all(not case.startswith("LifeOSProbeUITests/NativeNavigationUITests/") for case in remaining), "Navigation preflight repeated"
    assert any(case.startswith("LifeOSProbeTests/") for case in remaining), "Unit suite missing"
    assert any(case.startswith("LifeOSProbeUITests/") for case in remaining), "Remaining UI suite missing"
    assert len(preflight) + len(remaining) >= 405, "Full regression unexpectedly smaller than the preceding 405-case candidate"

def preflight(build):
    summary, cases, tree = extract_suite(build / "Preflight.xcresult")
    assert set(cases) == set(TARGETED) and len(cases) == 3, cases
    write(build / "candidate90-diagnostics" / "preflight-summary.json", summary)
    write(build / "candidate90-diagnostics" / "preflight-tests.json", tree)
    print("CANDIDATE90_COMPACT_PREFLIGHT_PASSED", context())

def tests(build):
    proof = context()
    before, first, first_tree = extract_suite(build / "Preflight.xcresult")
    after, rest, rest_tree = extract_suite(build / "Final.xcresult")
    verify_test_partition(first, rest)
    proof.update({"targetedDevice": "iPhone SE (3rd generation)", "targeted": before,
                  "remaining": after, "targetedCases": first, "remainingCases": rest,
                  "totalPassed": len(first) + len(rest), "failed": 0, "skipped": 0})
    diagnostics = build / "candidate90-diagnostics"
    write(diagnostics / "preflight-summary.json", before)
    write(diagnostics / "preflight-tests.json", first_tree)
    write(diagnostics / "remaining-summary.json", after)
    write(diagnostics / "remaining-tests.json", rest_tree)
    write(diagnostics / "test-gate.json", proof)
    print("CANDIDATE90_TEST_GATE_PASSED", proof["totalPassed"], "unique cases; targeted compact cases not repeated")

def release(build, launch_dir):
    proof = context()
    assert len(list(launch_dir.glob("*.png"))) >= 4, "Release screenshots missing"
    for mode in RELEASE_MODES:
        assert (launch_dir / (mode + ".png")).is_file(), mode
        assert (launch_dir / (mode + ".log")).is_file(), mode
    log = (build / "release-launch-checks.log").read_text(encoding="utf-8")
    for mode in RELEASE_MODES:
        assert "RELEASE_LAUNCH " + mode + " console_process_alive True" in log, mode
    assert "RELEASE_LAUNCH_SMOKE_PASSED:" in log
    proof.update({"releaseModes": RELEASE_MODES, "launchesPassed": 4})
    write(build / "candidate90-release" / "release-gate.json", proof)
    print("CANDIDATE90_RELEASE_GATE_PASSED", 4)

def package_inputs(directory):
    expected = context()
    test = json.loads((directory / "tests" / "test-gate.json").read_text(encoding="utf-8"))
    launch = json.loads((directory / "release" / "release-gate.json").read_text(encoding="utf-8"))
    for name, evidence in [("tests", test), ("release", launch)]:
        assert all(evidence.get(k) == v for k, v in expected.items()), (name, expected, evidence)
    assert test["failed"] == test["skipped"] == 0
    verify_test_partition(test["targetedCases"], test["remainingCases"])
    assert test["totalPassed"] == len(test["targetedCases"]) + len(test["remainingCases"])
    assert launch["launchesPassed"] == 4 and launch["releaseModes"] == RELEASE_MODES
    return {"version": "0.10.28", "build": 90, **expected,
            "testsPassed": test["totalPassed"], "releaseLaunchesPassed": 4,
            "backendDeployment": False, "physicalAcceptance": False}

def ipa(path):
    expected = {
        "generic-foods": None, "branded-foods": 2893, "branded-supplements": 7,
        "italian-brands": 23, "open-food-facts-italy": 1000, "cocktails": 30,
        "supplements": None,
    }
    with ZipFile(path) as archive:
        app = "Payload/LifeOSProbe.app/"
        for name, count in expected.items():
            actual = json.loads(archive.read(app + name + ".json"))
            source = json.loads(Path("native-next/Resources/" + name + ".json").read_text(encoding="utf-8-sig"))
            assert actual == source, "Packaged catalog differs from tested checkout: " + name
            assert count is None or len(actual) == count, (name, len(actual), count)
            assert len({f["id"] for f in actual}) == len(actual), name
        foods = {f["id"]: f for f in json.loads(archive.read(app + "generic-foods.json"))}
        assert len(foods) >= 280 and foods["ciqual-24001"]["detail"] == "Generic"
        cocktails = json.loads(archive.read(app + "cocktails.json"))
        assert {"cocktail-gin-tonic", "cocktail-sex-on-the-beach", "cocktail-long-island"} <= {f["id"] for f in cocktails}
    print("CANDIDATE90_CATALOGS_IDENTICAL_TO_TESTED_SHA", hashlib.sha256(path.read_bytes()).hexdigest())

def authorization():
    assert os.environ["GITHUB_REPOSITORY"] == "azeroualit-cloud/LifeOS"
    assert os.environ["GITHUB_REF"] == "refs/heads/codex/revision77"
    assert os.environ["GITHUB_EVENT_NAME"] == "workflow_dispatch"
    data = json.loads(Path("docs/USER-DECISIONS.json").read_text(encoding="utf-8-sig"))
    rules = []
    def visit(value):
        if isinstance(value, dict):
            if value.get("id"): rules.append(value)
            for v in value.values(): visit(v)
        elif isinstance(value, list):
            for v in value: visit(v)
    visit(data)
    for identifier in ("IPA-DELIVERY-2026-11-13", "SIX-TABS-KEYBOARD-REPAIR-2026-11-13"):
        assert any(r.get("id") == identifier and r.get("status") == "ACTIVE" for r in rules), identifier
    for selector in TARGETED:
        _, cls, method = selector.split("/")
        paths = list(Path("native-next/UITests").glob("*.swift"))
        assert any(re.search(r"\bfunc\s+" + re.escape(method) + r"\s*\(", p.read_text(encoding="utf-8-sig")) for p in paths), selector
    print("CANDIDATE90_AUTHORIZATION_AND_CHECKOUT", context())

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["authorize", "preflight", "tests", "release", "package-inputs", "ipa"])
    parser.add_argument("--build-dir", type=Path, default=Path("app/build"))
    parser.add_argument("--launch-dir", type=Path, default=Path("app/release-launch"))
    parser.add_argument("--evidence-dir", type=Path, default=Path("candidate90-evidence"))
    parser.add_argument("--ipa", type=Path)
    args = parser.parse_args()
    if args.mode == "authorize": authorization()
    elif args.mode == "preflight": preflight(args.build_dir)
    elif args.mode == "tests": tests(args.build_dir)
    elif args.mode == "release": release(args.build_dir, args.launch_dir)
    elif args.mode == "package-inputs": write(args.evidence_dir / "BUILD-PROVENANCE.json", package_inputs(args.evidence_dir))
    else:
        assert args.ipa
        ipa(args.ipa)

