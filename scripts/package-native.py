"""Assemble a local source package without replacing the public baseline archive."""
from pathlib import Path
import hashlib, importlib.util, tempfile, zipfile
root = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('prepare_native', root/'scripts/prepare-native.py')
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
output = root/'native/build/lifeos-native-52.zip'
output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='lifeos-package-') as folder:
    source = module.prepare_native(folder)
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source.rglob('*')):
            if not path.is_file(): continue
            entry = zipfile.ZipInfo(path.relative_to(source).as_posix(), date_time=(2026,10,25,12,0,0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, path.read_bytes())
print('LOCAL_NATIVE_SOURCE_ZIP_OK', hashlib.sha256(output.read_bytes()).hexdigest())
