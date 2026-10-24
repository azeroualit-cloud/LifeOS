"""Pack reviewed native sources, record the build-52 diff, and update the CI digest."""
from pathlib import Path
import difflib
import hashlib
import io
import re
import subprocess
import sys
import zipfile

root = Path(__file__).resolve().parent.parent
source = Path(sys.argv[1]).resolve()
baseline = subprocess.check_output(['git', 'show', '04074bc3bcf81f81da505f0dd155d0e5fe0ff2f3:lifeos-native.zip'], cwd=root)
old = zipfile.ZipFile(io.BytesIO(baseline))
files = sorted(p for p in source.rglob('*') if p.is_file())
allowed = {'Sources', 'Tests', 'UITests', 'Widget', 'Assets.xcassets', 'scripts'}
files = [p for p in files if p.relative_to(source).parts[0] in allowed or p.name in {'project.yml', 'DESIGN-SYSTEM.md'}]
assert (source / 'Sources/NativeStore.swift') in files
parts = []
with zipfile.ZipFile(root / 'lifeos-native.zip', 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for path in files:
        name = path.relative_to(source).as_posix()
        info = zipfile.ZipInfo(name, date_time=(2026, 10, 24, 12, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        archive.writestr(info, path.read_bytes())
        if path.suffix in {'.swift', '.yml', '.py', '.md'}:
            before = old.read(name).decode() if name in old.namelist() else ''
            after = path.read_text()
            if before != after:
                parts.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='a/' + name, tofile='b/' + name))
(root / 'docs/native/LOCAL-FIRST-53.diff').write_text(''.join(parts))
sha = hashlib.sha256((root / 'lifeos-native.zip').read_bytes()).hexdigest()
workflow = root / '.github/workflows/lifeos-build.yml'
text, count = re.subn(r"(hashlib.sha256\(source.read_bytes\(\)\).hexdigest\(\) == ')[a-f0-9]{64}", r'\g<1>' + sha, workflow.read_text())
assert count == 1
workflow.write_text(text)
print('Source ZIP SHA256:', sha)
