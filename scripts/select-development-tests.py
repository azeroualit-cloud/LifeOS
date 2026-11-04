"""Bounded CI selection. Unknown/shared changes deliberately expand coverage."""
import argparse,json,subprocess
from pathlib import Path

SMOKE = "LifeOSProbeUITests/NativeRevision77UITests/testFourTabsAndDirectHealthAndBloom"
AREAS = {
 "dashboard": ["LifeOSProbeUITests/NativeRevision78UITests/testPrayerSharesDateRowAndOpensAllTimes", "LifeOSProbeUITests/NativeRevision78UITests/testFinanceBudgetAndThumbActionUseTheSameRow", "LifeOSProbeUITests/NativeRevision77UITests/testLargeTextDashboardAndHealth"],
 "nutrition": ["LifeOSProbeUITests/NativeRevision77UITests/testCompactMacroDecimalInputAndKeyboardProgression"],
 "health": ["LifeOSProbeUITests/NativeRevision78UITests/testHealthUniformRowsAndCompactActions", "LifeOSProbeUITests/NativeRevision78UITests/testHealthAccessibleRowsRemainEqualAndActionsStayCompact", "LifeOSProbeUITests/NativeRevision74UITests/testHealthChartsAllowVerticalScrollAndNativeSelection"],
 "bloom": ["LifeOSProbeUITests/NativeRevision74UITests/testMoreDestinationsAndBloomNotePersistsAcrossNavigation", "LifeOSProbeUITests/NativeBloomGridUITests", "LifeOSProbeTests/NativeBloomStoreTests"],
 "finance": ["LifeOSProbeUITests/NativeRevision75UITests"],
}
def select(mode, area, paths):
    if area == "auto":
        selected=set()
        for path in paths:
            name=Path(path).name.lower()
            matches=[key for key in AREAS if key in name or (key == "nutrition" and "macro" in name)]
            if not matches: selected=set(AREAS); break
            selected.update(matches)
        if not selected: selected=set(AREAS)
    else: selected=set(AREAS) if area == "all" else {area}
    tests=[SMOKE]
    for key in sorted(selected): tests.extend(AREAS[key])
    if mode == "focused":
        tests.append("LifeOSProbeTests")
        if "bloom" in selected:
            tests.extend(["LifeOSProbeUITests/NativeRevision78UITests/testBloomCancelClosesFilesAndAllowsRetry", "LifeOSProbeUITests/NativeRevision78UITests/testBloomSystemFilesSelectionReachesPreviewAndPersists"])
    return sorted(selected),list(dict.fromkeys(tests))
if __name__ == "__main__":
    p=argparse.ArgumentParser();p.add_argument("--mode",choices=["preview","focused"],default="preview");p.add_argument("--area",choices=["auto","all",*AREAS],default="auto");p.add_argument("--base");p.add_argument("--output",default="app/build/development-selection.json");a=p.parse_args()
    paths=[]
    if a.base and set(a.base) != {"0"}:
        # No shell interpolation of event inputs. A missing base expands, never narrows.
        result=subprocess.run(["git","diff","--name-only",a.base,"HEAD","--","native-next"],text=True,capture_output=True)
        if result.returncode == 0: paths=result.stdout.splitlines()
    areas,tests=select(a.mode,a.area,paths)
    out=Path(a.output);out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps({"mode":a.mode,"areas":areas,"paths":paths,"tests":tests},indent=2)+"\n")
    out.with_suffix(".args").write_text("\n".join("-only-testing:"+t for t in tests)+"\n")
    print(json.dumps({"mode":a.mode,"areas":areas,"test_selectors":len(tests)}))
