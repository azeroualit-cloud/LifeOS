"""Assemble the pinned public build-60 archive and the reviewed build-61 overlay."""
import argparse,hashlib,shutil,zipfile
from pathlib import Path

BASELINE_SHA256='b09762b88e4dc017d2c89fa7582ac38daf1fddf5aa0dd12fed94d73f6099ef03'

def prepare(destination: Path, baseline: Path):
    if destination.exists():raise ValueError('La destinazione deve essere nuova; nessun file esistente viene sostituito.')
    if hashlib.sha256(baseline.read_bytes()).hexdigest()!=BASELINE_SHA256:raise ValueError('Archivio baseline inatteso.')
    with zipfile.ZipFile(baseline) as archive:
        for name in archive.namelist():
            path=Path(name)
            if path.is_absolute() or '..' in path.parts:raise ValueError('Percorso ZIP non valido.')
        archive.extractall(destination)
    overlay=Path(__file__).resolve().parent.parent/'native-next'
    for source in overlay.rglob('*'):
        relative=source.relative_to(overlay)
        if source.is_file() and relative.parts[0] in ['Sources','Tests','UITests','project.yml']:
            target=destination/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    return destination

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination',type=Path)
    parser.add_argument('--baseline',type=Path,default=Path('/tmp/lifeos-build60.zip'))
    args=parser.parse_args();print(prepare(args.destination,args.baseline))
