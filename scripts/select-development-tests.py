"""Bounded CI selection. Unknown/shared changes deliberately expand coverage."""
import argparse,json,re,subprocess
from pathlib import Path

SMOKE = "LifeOSProbeUITests/NativeRevision77UITests/testFourTabsAndDirectHealthAndBloom"
AREAS = {
 "dashboard": ["LifeOSProbeUITests/NativeRevision78UITests/testPrayerSharesDateRowAndOpensAllTimes", "LifeOSProbeUITests/NativeRevision78UITests/testFinanceBudgetAndThumbActionUseTheSameRow", "LifeOSProbeUITests/NativeRevision77UITests/testLargeTextDashboardAndHealth"],
 "nutrition": ["LifeOSProbeUITests/NativeRevision74UITests/testFourTabsAndNutritionCalculation", "LifeOSProbeUITests/NativeNutritionQuickUITests", "LifeOSProbeUITests/NativeRevision77UITests/testCompactMacroDecimalInputAndKeyboardProgression", "LifeOSProbeTests/NativeNutritionEntryTests", "LifeOSProbeTests/NativeNutritionStoreTests", "LifeOSProbeTests/NativeNutritionHealthKitTests"],
 "health": ["LifeOSProbeUITests/NativeRevision78UITests/testHealthUniformRowsAndCompactActions", "LifeOSProbeUITests/NativeRevision78UITests/testHealthAccessibleRowsRemainEqualAndActionsStayCompact", "LifeOSProbeUITests/NativeRevision78UITests/testHealthNutritionQuickAddAndHistoryAreReachable", "LifeOSProbeUITests/NativeRevision78UITests/testMicronutrientPrioritiesOpenWithOtherNutrientsInDetail", "LifeOSProbeUITests/NativeRevision74UITests/testHealthChartsAllowVerticalScrollAndNativeSelection"],
 "bloom": ["LifeOSProbeUITests/NativeRevision74UITests/testMoreDestinationsAndBloomNotePersistsAcrossNavigation", "LifeOSProbeUITests/NativeBloomGridUITests", "LifeOSProbeTests/NativeBloomStoreTests"],
 "finance": ["LifeOSProbeUITests/NativeRevision75UITests"],
 "activities": ["LifeOSProbeUITests/NativeInterfaceTests/testUnifiedActivityEditorPreservesDescriptionWhenAddingAndRemovingDate", "LifeOSProbeUITests/NativeInterfaceTests/testActivityAgendaShowsOnlyRelevantItemsAndFoldsCompleted", "LifeOSProbeTests/NativeActivityStoreTests"],
 "calendar": ["LifeOSProbeUITests/NativeInterfaceTests/testCalendarRepeatedScrollingKeepsMonthAnchorsAndReturnsToToday", "LifeOSProbeUITests/NativeInterfaceTests/testCalendarSelectionUpdatesImmediatelyAndKeepsEventIndex", "LifeOSProbeTests/NativeCalendarPerformanceTests", "LifeOSProbeUITests/NativeRevision71UITests/testDashboardExplicitDayAndCalendarEntryResumeDefaults", "LifeOSProbeUITests/NativeRevision72UITests/testDayHasReachableMonthNavigationAndPinnedEventAction", "LifeOSProbeUITests/NativeRevision73UITests"],
 "shifts": ["LifeOSProbeUITests/NativeInterfaceTests/testVisibleShiftBrushPaintsAndUndoRestoresDay", "LifeOSProbeUITests/NativeInterfaceTests/testShiftExportRemainsReachableFromSettings", "LifeOSProbeTests/NativeRevision71Tests"],
}
# Deliberate allowlist for the first trial. An unclassified change runs the whole suite.
TRIAL_AREAS = {
    "native-next/Resources/generic-foods.json": ("health", "nutrition"),
    **{f"native-next/Sources/{name}.swift": ("health", "nutrition") for name in (
        "NativeFoodPicker", "NativeHealthSummary", "NativeMicronutrients", "NativeNutrition",
        "NativeNutritionQuickEntry",
    )},
    **{f"native-next/Tests/{name}.swift": ("health", "nutrition") for name in (
        "NativeNutritionEntryTests", "NativeNutritionHealthKitTests", "NativeNutritionStoreTests",
    )},
    "native-next/UITests/NativeNutritionQuickUITests.swift": ("health", "nutrition"),
}
VERSION_SETTING = re.compile(r"(?m)^([ \t]*(?:MARKETING_VERSION|CURRENT_PROJECT_VERSION):)[^\n]+")


def trial_selection(base):
    all_tests = ["LifeOSProbeTests", "LifeOSProbeUITests"]
    if not base or not re.fullmatch(r"[0-9a-f]{40}", base):
        return ["all"], all_tests, [], "Base verificata assente"
    if subprocess.run(["git", "merge-base", "--is-ancestor", base, "HEAD"], capture_output=True).returncode:
        return ["all"], all_tests, [], "Base assente dalla cronologia del candidato"
    result = subprocess.check_output(["git", "diff", "--name-only", "--no-renames", base, "HEAD"], text=True)
    paths = [path for path in result.splitlines() if not path.startswith("docs/") and path != "README.md"]
    project = "native-next/project.yml"
    if project in paths and Path(project).is_file():
        previous = subprocess.run(["git", "show", f"{base}:{project}"], text=True, capture_output=True)
        new = Path(project).read_text(encoding="utf-8")
        if previous.returncode == 0 and VERSION_SETTING.sub(r"\1", previous.stdout) == VERSION_SETTING.sub(r"\1", new):
            paths.remove(project)
    unknown = sorted(set(paths) - TRIAL_AREAS.keys())
    if unknown:
        return ["all"], all_tests, paths, "File fuori dalla mappa pilota: " + ", ".join(unknown)
    areas = sorted({area for path in paths for area in TRIAL_AREAS[path]})
    tests = [SMOKE, "LifeOSProbeTests"]
    for area in areas:
        tests.extend(test for test in AREAS[area] if test.startswith("LifeOSProbeUITests/"))
    return areas, list(dict.fromkeys(tests)), paths, "Base e aree del pilota riconosciute"


def select(mode, area, paths):
    if area == "auto":
        selected=set()
        for path in paths:
            name=Path(path).name.lower()
            matches=[key for key in AREAS if key in name or (key == "nutrition" and "macro" in name) or (key == "activities" and "activity" in name) or (key == "shifts" and "shift" in name)]
            if not matches: selected=set(AREAS); break
            selected.update(matches)
        if not selected: selected=set(AREAS)
    else: selected=set(AREAS) if area == "all" else {area}
    tests=[SMOKE]
    for key in sorted(selected): tests.extend(AREAS[key])
    if mode == "focused":
        # XCTest target-wide selection must not coexist with narrower filters for that target.
        tests = [test for test in tests if not test.startswith("LifeOSProbeTests/")]
        tests.append("LifeOSProbeTests")
        if "dashboard" in selected:
            # Cross-area bottom-edge checks cover Dashboard, Health and Bloom.
            tests.extend(["LifeOSProbeUITests/NativeRevision78UITests/testSafeAreaLastContentStandard", "LifeOSProbeUITests/NativeRevision78UITests/testSafeAreaLastContentLargeText"])
        if "bloom" in selected:
            tests.extend(["LifeOSProbeUITests/NativeRevision78UITests/testBloomCancelClosesFilesAndAllowsRetry", "LifeOSProbeUITests/NativeRevision78UITests/testBloomSystemFilesSelectionReachesPreviewAndPersists", "LifeOSProbeUITests/NativeRevision78UITests/testBloomSectionRespondsAtLowerEdgeOf44PointTouchTarget"])
    return sorted(selected),list(dict.fromkeys(tests))
if __name__ == "__main__":
    p=argparse.ArgumentParser();p.add_argument("--mode",choices=["preview","focused","trial","nutrition-render","calendar-render","health-render","health-detail-render"],default="preview");p.add_argument("--area",choices=["auto","all",*AREAS],default="auto");p.add_argument("--base");p.add_argument("--output",default="app/build/development-selection.json");a=p.parse_args()
    paths=[]
    if a.mode != "trial" and a.base and set(a.base) != {"0"}:
        # No shell interpolation of event inputs. A missing base expands, never narrows.
        result=subprocess.run(["git","diff","--name-only",a.base,"HEAD","--","native-next"],text=True,capture_output=True)
        if result.returncode == 0: paths=result.stdout.splitlines()
    reason = None
    if a.mode == "trial":
        areas, tests, paths, reason = trial_selection(a.base)
    elif a.mode == "health-detail-render":
        areas = ["health", "nutrition"]
        tests = ["LifeOSProbeUITests/NativeRevision78UITests/testRenderHealthDiaryOmegaAndRankedCatalog"]
    elif a.mode == "health-render":
        areas = ["health", "nutrition", "dashboard", "bloom"]
        tests = [
            "LifeOSProbeTests/NativeHealthTests",
            "LifeOSProbeTests/NativeNutritionEntryTests",
            "LifeOSProbeTests/NativeNutritionHealthKitTests",
            "LifeOSProbeUITests/NativeRevision78UITests/testRenderHealthWeekAndDashboardAndBloom",
            "LifeOSProbeUITests/NativeRevision78UITests/testMicronutrientPrioritiesOpenWithOtherNutrientsInDetail",
            "LifeOSProbeUITests/NativeRevision78UITests/testHealthUniformRowsAndCompactActions",
            "LifeOSProbeUITests/NativeRevision78UITests/testHealthAccessibleRowsRemainEqualAndActionsStayCompact",
            "LifeOSProbeUITests/NativeInterfaceTests/testHealthScenarioCanBeEditedWithoutAddingNavigationTab",
            "LifeOSProbeUITests/NativeNutritionQuickUITests/testRenderCocktailAndBoneInPortions",
            "LifeOSProbeUITests/NativeNutritionQuickUITests/testRenderPersonalFoodEditorAndSave",
            "LifeOSProbeUITests/NativeNutritionQuickUITests/testLargeTextCaloriesRemainReadableAboveActionWithKeyboard",
            "LifeOSProbeUITests/NativeNutritionQuickUITests/testQuickSheetCalculatesAndSavesThenResets",
        ]
    elif a.mode == "calendar-render":
        areas = ["calendar"]
        tests = [
            "LifeOSProbeUITests/NativeRevision73UITests",
            "LifeOSProbeUITests/NativeRevision72UITests/testDayHasReachableMonthNavigationAndPinnedEventAction",
            "LifeOSProbeUITests/NativeRevision72UITests/testLongEventIsCompactAndContainsItsInnerEventAndDayScrollReachesMidnight",
            "LifeOSProbeUITests/NativeRevision71UITests/testAllDayEventsUseCompactChipsWithinTheDayScroll",
        ]
    elif a.mode == "nutrition-render":
        areas = ["health", "nutrition"]
        tests = [
            "LifeOSProbeUITests/NativeNutritionQuickUITests/testRenderCocktailAndBoneInPortions",
            "LifeOSProbeUITests/NativeNutritionQuickUITests/testRenderPersonalFoodEditorAndSave",
            "LifeOSProbeUITests/NativeRevision78UITests/testMicronutrientPrioritiesOpenWithOtherNutrientsInDetail",
            "LifeOSProbeTests/NativeNutritionHealthKitTests",
            "LifeOSProbeTests/NativeNutritionEntryTests",
        ]
    else:
        areas, tests = select(a.mode, a.area, paths)
    out=Path(a.output);out.parent.mkdir(parents=True,exist_ok=True)
    details = {"mode": a.mode, "areas": areas, "paths": paths, "tests": tests}
    if reason is not None:
        details.update(base=a.base, reason=reason)
    out.write_text(json.dumps(details, indent=2) + "\n", encoding="utf-8")
    out.with_suffix(".args").write_text("\n".join("-only-testing:" + test for test in tests) + "\n", encoding="utf-8")
    print(json.dumps({"mode": a.mode, "areas": areas, "test_selectors": len(tests), "reason": reason}))
