"""Run the native Foundation model regressions on Linux without implying an iOS build."""
from pathlib import Path
import os, shutil, subprocess, tempfile, importlib.util
root = Path(__file__).resolve().parent.parent
sources = ['Models', 'NativeModels', 'DemoData', 'NativeCategoryCatalog', 'NativeCategoryPeriod', 'NativeFinanceModel', 'NativeHomeModel', 'NativeNextTime', 'NativeTaskList', 'NativeCalendarWindow']
tests = ['ModelsTests', 'NativeModelsTests', 'NativeCategoryCatalogTests', 'NativeCategoryPeriodTests', 'NativeFinanceTests', 'NativeHomeTests', 'NativeNextTimeTests', 'NativeTaskListTests']
swift = os.environ.get('SWIFT_BIN', 'swift')
with tempfile.TemporaryDirectory(prefix='lifeos-model-tests-') as folder:
    path = Path(folder)
    spec = importlib.util.spec_from_file_location('prepare_native', root/'scripts/prepare-native.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    native = module.prepare_native(path/'native')
    (path/'Sources/LifeOSProbe').mkdir(parents=True)
    (path/'Tests/LifeOSProbeTests').mkdir(parents=True)
    (path/'Package.swift').write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "LifeOSLocalChecks", targets: [.target(name: "LifeOSProbe"), .testTarget(name: "LifeOSProbeTests", dependencies: ["LifeOSProbe"])], swiftLanguageModes: [.v5])
''')
    for name in sources: shutil.copy2(native/f'Sources/{name}.swift', path/'Sources/LifeOSProbe')
    for name in tests: shutil.copy2(native/f'Tests/{name}.swift', path/'Tests/LifeOSProbeTests')
    env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(path/'module-cache'), SWIFTPM_MODULECACHE_OVERRIDE=str(path/'module-cache'))
    subprocess.run([swift, 'test', '--package-path', folder, '--cache-path', str(path/'cache'), '--config-path', str(path/'config'), '--security-path', str(path/'security'), '--jobs', '2'], env=env, check=True)
