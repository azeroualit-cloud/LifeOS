"""Extract the pinned native baseline and apply the reviewable source overlay."""
from pathlib import Path, PurePosixPath
import shutil, sys, zipfile

def prepare_native(destination):
    root = Path(__file__).resolve().parent.parent
    destination = Path(destination)
    with zipfile.ZipFile(root/'lifeos-native.zip') as archive:
        for name in archive.namelist():
            path = PurePosixPath(name)
            if path.is_absolute() or '..' in path.parts:
                raise ValueError('Invalid archive path')
        archive.extractall(destination)
    overlay = root/'native'
    for path in overlay.rglob('*'):
        if path.is_file() and path.relative_to(overlay).parts[0] in ['Sources','Tests','UITests','project.yml','DESIGN-SYSTEM.md']:
            target = destination/path.relative_to(overlay)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
    return destination

if __name__ == '__main__':
    prepare_native(sys.argv[1])
