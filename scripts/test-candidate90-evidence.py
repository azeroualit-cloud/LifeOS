"""Behavioral checks of fresh candidate gates; no credentials, Xcode, or network."""
import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from zipfile import ZipFile

SPEC = importlib.util.spec_from_file_location("candidate90", Path(__file__).with_name("verify-candidate90.py"))
V = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(V)


def suite(cases):
    summary = {"totalTestCount": len(cases), "passedTests": len(cases), "failedTests": 0,
               "skippedTests": 0, "expectedFailures": 0, "result": "Passed"}
    tree = {"testNodes": [{"nodeType": "Test Case", "result": "Passed",
                          "nodeIdentifierURL": "test://com.apple.xcode/LifeOSProbe/" + case} for case in cases]}
    return summary, tree


class Candidate90EvidenceTests(unittest.TestCase):
    def testFreshPreflightRequiresAllUniqueCasesAndNeverReuses(self):
        cases, coverage = V.combined_preflight(Path("unused"), V.TARGETED[:])
        self.assertEqual(cases, V.TARGETED)
        self.assertEqual(coverage, {"passedCases": len(V.TARGETED), "currentRunPassed": len(V.TARGETED), "reusedPassed": 0})
        for bad in (V.TARGETED[:-1], V.TARGETED + V.TARGETED[:1], ["LifeOSProbeUITests/Wrong/testCase"]):
            with self.assertRaises(AssertionError): V.combined_preflight(Path("unused"), bad)

    def testExtractSuiteAcceptsRealIdentifierFormat(self):
        summary, tree = suite(V.TARGETED)
        with patch.object(V.subprocess, "check_output", side_effect=[json.dumps(summary), json.dumps(tree)]):
            actual, cases, _ = V.extract_suite(Path("fixture.xcresult"))
        self.assertEqual(cases, V.TARGETED)
        self.assertEqual(actual["passedTests"], len(V.TARGETED))

    def testExtractSuiteRejectsFailuresSkipsExpectedFailuresAndMissingEvidence(self):
        for change in ("failedTests", "skippedTests", "expectedFailures", "missing", "duplicate", "failed_node"):
            summary, tree = suite(V.TARGETED)
            if change in summary: summary[change] = 1
            elif change == "missing": tree["testNodes"].pop()
            elif change == "duplicate": tree["testNodes"].append(copy.deepcopy(tree["testNodes"][0]))
            else: tree["testNodes"][0]["result"] = "Failed"
            with patch.object(V.subprocess, "check_output", side_effect=[json.dumps(summary), json.dumps(tree)]):
                with self.assertRaises(AssertionError, msg=change): V.extract_suite(Path("fixture.xcresult"))

    def testPartitionRejectsRepeatedPreflightMissingUnitOrSmallSuite(self):
        units = ["LifeOSProbeTests/Fixture/test" + str(i) for i in range(405)]
        ui = ["LifeOSProbeUITests/Other/testAnother"]
        V.verify_test_partition(V.TARGETED, units + ui)
        for bad in (units + ui + V.TARGETED[:1], ui * 2, units, ui):
            with self.assertRaises(AssertionError): V.verify_test_partition(V.TARGETED, bad)

    def testTargetedCoverageRequiresCorrectCasesOnBothOriginalDevices(self):
        compact, compact_tree = suite(V.COMPACT_TARGETED)
        primary, primary_tree = suite(V.PRIMARY_TARGETED)
        compact["devicesAndConfigurations"] = [{"device": {"modelName": "iPhone SE (3rd generation)"}}]
        primary["devicesAndConfigurations"] = [{"device": {"modelName": "iPhone 15 Pro"}}]
        with patch.object(V, "extract_suite", side_effect=[(compact, V.COMPACT_TARGETED, compact_tree), (primary, V.PRIMARY_TARGETED, primary_tree)]):
            result = V.targeted_results(Path("fixture"))
        self.assertEqual(result[-1]["passedCases"], len(V.TARGETED))
        for wrong in ("device", "case"):
            bad = copy.deepcopy(primary)
            cases = V.PRIMARY_TARGETED[:]
            if wrong == "device": bad["devicesAndConfigurations"][0]["device"]["modelName"] = "iPhone SE (3rd generation)"
            else: cases[0] = V.COMPACT_TARGETED[0]
            with patch.object(V, "extract_suite", side_effect=[(compact, V.COMPACT_TARGETED, compact_tree), (bad, cases, primary_tree)]):
                with self.assertRaises(AssertionError, msg=wrong): V.targeted_results(Path("fixture"))

    def evidence(self):
        context = {"sourceCommit": "exact-sha", "runID": "current-run", "runAttempt": "1"}
        rest = ["LifeOSProbeTests/Fixture/test" + str(i) for i in range(405)] + ["LifeOSProbeUITests/Other/testAnother"]
        total = len(V.TARGETED) + len(rest)
        test = {**context, "failed": 0, "skipped": 0, "targetedCases": V.TARGETED[:], "remainingCases": rest,
                "targetedAggregate": {"currentRunPassed": len(V.TARGETED), "reusedPassed": 0, "passedCases": len(V.TARGETED),
                    "devices": {"compactPassed": len(V.COMPACT_TARGETED), "primaryPassed": len(V.PRIMARY_TARGETED)}},
                "totalPassed": total, "reusedTestsPassed": 0, "executedThisRun": total}
        release = {**context, "launchesPassed": 4, "releaseModes": V.RELEASE_MODES[:]}
        return context, test, release

    def testPackagingRequiresExactSourceRunAttemptAndFreshCompleteEvidence(self):
        context, test, release = self.evidence()
        with tempfile.TemporaryDirectory() as folder, patch.object(V, "context", return_value=context):
            root = Path(folder)
            V.write(root / "tests/test-gate.json", test); V.write(root / "release/release-gate.json", release)
            proof = V.package_inputs(root)
            self.assertEqual(proof["testsExecutedThisRun"], proof["testsPassed"])
            self.assertEqual(proof["reusedTestsPassed"], 0)
            self.assertFalse(proof["physicalAcceptance"])
            for key in ("sourceCommit", "runID", "runAttempt"):
                bad = copy.deepcopy(test); bad[key] = "wrong"
                V.write(root / "tests/test-gate.json", bad)
                with self.assertRaises(AssertionError, msg=key): V.package_inputs(root)
            for field in ("failed", "skipped", "reusedTestsPassed"):
                bad = copy.deepcopy(test); bad[field] = 1
                V.write(root / "tests/test-gate.json", bad)
                with self.assertRaises(AssertionError, msg=field): V.package_inputs(root)
            V.write(root / "tests/test-gate.json", test)
            bad = copy.deepcopy(release); bad["launchesPassed"] = 3
            V.write(root / "release/release-gate.json", bad)
            with self.assertRaises(AssertionError): V.package_inputs(root)

    def testPackagedCatalogMustMatchTestedCheckout(self):
        resources = Path("native-next/Resources")
        names = ("generic-foods", "branded-foods", "branded-supplements", "italian-brands", "open-food-facts-italy", "cocktails", "supplements")
        with tempfile.TemporaryDirectory() as folder:
            for mutate in (False, True):
                ipa = Path(folder) / ("bad.ipa" if mutate else "good.ipa")
                with ZipFile(ipa, "w") as z:
                    for name in names:
                        content = (resources / (name + ".json")).read_bytes()
                        if mutate and name == "open-food-facts-italy": content = b"[]"
                        z.writestr("Payload/LifeOSProbe.app/" + name + ".json", content)
                if mutate:
                    with self.assertRaises(AssertionError): V.ipa(ipa)
                else: V.ipa(ipa)


if __name__ == "__main__": unittest.main()
