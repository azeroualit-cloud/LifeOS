"""Check reuse/aggregation gates without credentials, macOS, or network."""
import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("candidate90", Path(__file__).with_name("verify-candidate90.py"))
V = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(V)

def prior():
    summary = {"totalTestCount": 3, "passedTests": 2, "failedTests": 1, "skippedTests": 0, "result": "Failed"}
    tree = {"testNodes": [{"nodeType": "Test Case", "result": "Failed" if case == V.FAILED_PREFLIGHT else "Passed",
                          "nodeIdentifierURL": "test://com.apple.xcode/LifeOSProbe/" + case} for case in V.TARGETED]}
    return summary, tree

class Candidate90ReuseTests(unittest.TestCase):
    def testKeepsOnlyTheTwoActuallyPassingPriorCases(self):
        summary, tree = prior()
        self.assertEqual(V.verify_prior_result(summary, tree), [V.TARGETED[0], V.TARGETED[2]])

    def testRejectsSkippedWrongOrDuplicatePriorCases(self):
        summary, tree = prior()
        for mutate in ("skipped", "wrong_result", "wrong_case", "duplicate"):
            s, t = copy.deepcopy(summary), copy.deepcopy(tree)
            if mutate == "skipped": s["skippedTests"] = 1
            elif mutate == "wrong_result": t["testNodes"][0]["result"] = "Failed"
            elif mutate == "wrong_case": t["testNodes"][0]["nodeIdentifierURL"] += "Other"
            else: t["testNodes"].append(t["testNodes"][0])
            with self.assertRaises(AssertionError, msg=mutate): V.verify_prior_result(s, t)

    def testBalancedMethodMaskPreservesHelpersAndOtherPassingMethods(self):
        before = 'class Tests {\n    func testSixVisibleTabsWithLargeTextAndKeyboard() {\n        let text = "brace }"; if true { action() } // }\n    }\n    private func helper() { same() }\n}\n'
        repaired = before.replace("action()", "repaired()")
        self.assertEqual(V.without_repaired_method(before), V.without_repaired_method(repaired))
        altered_helper = repaired.replace("same()", "different()")
        self.assertNotEqual(V.without_repaired_method(before), V.without_repaired_method(altered_helper))

    def testProductChangeOrAnotherUITestFileRefusesReuse(self):
        for path in ("native-next/Sources/App.swift", "native-next/project.yml", ".github/actions/native-compat76/action.yml",
                     "native-next/UITests/NativePersonalFoodUITests.swift"):
            with patch.object(V.subprocess, "check_output", return_value=path + "\n"):
                with self.assertRaises(AssertionError, msg=path): V.unchanged_reused_product()

    def testOnlyRepairedMethodMayChangeWhenProductIdentical(self):
        before = 'class Tests {\n    func testSixVisibleTabsWithLargeTextAndKeyboard() { old() }\n    private func helper() { stable() }\n}\n'
        after = before.replace("old()", "new()")
        with patch.object(V.subprocess, "check_output", side_effect=["native-next/UITests/NativeNavigationUITests.swift\n", before, after]):
            V.unchanged_reused_product()
        with patch.object(V.subprocess, "check_output", side_effect=["native-next/UITests/NativeNavigationUITests.swift\n", before, after.replace("stable()", "changed()")]):
            with self.assertRaises(AssertionError): V.unchanged_reused_product()

    def testAggregateIsExplicitTwoRetainedPlusOneCurrentAndRejectsWrongSHA(self):
        context = {"sourceCommit": "new-sha", "runID": "current-run", "runAttempt": "1"}
        proof = {**context, "prior": V.PRIOR, "passedCases": [V.TARGETED[0], V.TARGETED[2]],
                 "failedCaseToRerun": V.FAILED_PREFLIGHT, "productAndAssemblyUnchanged": True}
        with tempfile.TemporaryDirectory() as folder, patch.object(V, "context", return_value=context):
            build = Path(folder)
            path = build / "candidate90-diagnostics/reused-preflight/reuse-proof.json"
            V.write(path, proof)
            cases, coverage = V.combined_preflight(build, [V.FAILED_PREFLIGHT])
            self.assertEqual(cases, V.TARGETED)
            self.assertEqual((coverage["currentRunPassed"], coverage["reusedPassed"]), (1, 2))
            with self.assertRaises(AssertionError): V.combined_preflight(build, V.TARGETED)
            proof["sourceCommit"] = "wrong-sha"; V.write(path, proof)
            with self.assertRaises(AssertionError): V.combined_preflight(build, [V.FAILED_PREFLIGHT])

if __name__ == "__main__": unittest.main()

