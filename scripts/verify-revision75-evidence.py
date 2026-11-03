"""Reuse simulator evidence only for byte-identical production sources."""
from pathlib import Path
import json, re, shutil, subprocess
BASE = '39bef52dd498acfe629917c12bc1546da10eb732'
paths = ['native-next', 'backend', 'web', 'scripts/build-worker-68.py', 'scripts/build-worker-70.py', 'scripts/build-worker-75.py', 'scripts/deploy-utilities-75.py', 'scripts/deploy-unified-activities.py', 'scripts/verify-native-package.py']
changed = subprocess.check_output(['git', 'diff', '--name-only', BASE, 'HEAD', '--', *paths], text=True).splitlines()
assert changed == ['native-next/UITests/NativeInterfaceTests.swift'], changed
root = Path('prior75')
def one(name):
    matches = list(root.rglob(name)); assert len(matches) == 1, (name, len(matches)); return matches[0]
for name, total, failures in [('native74-tests.log', 5, 0), ('focused-tests.log', 16, 0), ('regression-tests.log', 245, 0), ('compact.log', 21, 1)]:
    text = one(name).read_text()
    counts = [(int(a), int(b)) for a,b in re.findall(r'Executed (\d+) tests, with (\d+) failures?', text)]
    assert (total, failures) in counts, (name, counts)
    if name == 'regression-tests.log': assert (5, 0) in counts
    failed = re.findall(r"Test Case '([^']+)' failed", text)
    if failures:
        assert failed == ['-[LifeOSProbeUITests.NativeInterfaceTests testExpenseAutomaticallyOffersWaterFundAndCanChangeExistingDestination]'], failed
    else: assert not failed, (name, failed)
    print('PRIOR_SYNTHETIC_EVIDENCE', name, total, failures)
for name,total,failures in [('Native74.xcresult',5,0),('Focused.xcresult',16,0),('Regression.xcresult',250,0),('Compact.xcresult',21,1)]:
    summary=json.loads(subprocess.check_output(['xcrun','xcresulttool','get','test-results','summary','--path',str(one(name))],text=True))
    assert summary['totalTestCount']==total and summary['failedTests']==failures, (name,summary.get('totalTestCount'),summary.get('failedTests'))
    if failures:
        assert 'testExpenseAutomaticallyOffersWaterFundAndCanChangeExistingDestination' in json.dumps(summary.get('testFailures')), summary.get('testFailures')
    else: assert not summary.get('testFailures'), name
build=Path('app/build');build.mkdir(parents=True,exist_ok=True)
shutil.copy2(one('LifeOS-75-flussi.mp4'),build/'LifeOS-75-flussi.mp4')
for name in ['Native74.xcresult','Focused.xcresult','Regression.xcresult','Compact.xcresult']:
    shutil.copytree(one(name),build/('Prior-'+name))
for name in ['native74-tests.log','focused-tests.log','regression-tests.log','compact.log']:
    shutil.copy2(one(name),build/('prior-'+name))
(build/'revision75-evidence.json').write_text(json.dumps({'productionSource':BASE,'verificationSource':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'priorRun':41551009765,'unitPassed':245,'uiPreviouslyPassed':46,'requiredRetry':'NativeInterfaceTests/testExpenseAutomaticallyOffersWaterFundAndCanChangeExistingDestination','productionSourcesUnchanged':True},indent=2))
print('PRODUCTION_SOURCES_IDENTICAL; 245 unit tests and 46 UI passes retained; the corrected compact regression must pass before deployment or packaging.')
