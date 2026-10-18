"""Export only the public native DemoData fixture; --check prevents fixture drift."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parent.parent
native = Path(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1] != '--check' else root / 'work/native'
target = root / 'shared/demo-data.json'
provenance = root / 'shared/demo-data.source.json'
inputs = {name: hashlib.sha256((native / 'Sources' / name).read_bytes()).hexdigest() for name in ['DemoData.swift', 'NativeModels.swift']}
if '--check' in sys.argv:
    saved = json.loads(provenance.read_text())
    if saved['inputs'] != inputs or saved['sha256'] != hashlib.sha256(target.read_bytes()).hexdigest():
        raise SystemExit('Native demo fixture changed: run scripts/generate-demo.py after extracting the current ZIP.')
else:
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder)
        (path / 'main.swift').write_text('import Foundation\nFileHandle.standardOutput.write(try JSONEncoder().encode(DemoData.make()))\n')
        sources = ['Models', 'NativeModels', 'NativePlanModel', 'NativePlanDemo', 'NativePlatformContract', 'DemoData']
        subprocess.run([os.environ.get('LIFEOS_SWIFTC', 'swiftc'), *[str(native / 'Sources' / (name + '.swift')) for name in sources], str(path / 'main.swift'), '-module-cache-path', str(path / 'cache'), '-o', str(path / 'export')], check=True)
        value = json.loads(subprocess.check_output([str(path / 'export')]))
        target.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + '\n')
    provenance.write_text(json.dumps({'inputs': inputs, 'sha256': hashlib.sha256(target.read_bytes()).hexdigest()}, indent=2) + '\n')
print('NATIVE_DEMO_FIXTURE_OK')
