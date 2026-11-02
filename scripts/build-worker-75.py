from pathlib import Path
import importlib.util
spec = importlib.util.spec_from_file_location('utilities75', Path(__file__).with_name('deploy-utilities-75.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
path = Path('manual/build-75/worker.js')
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(module.transform(Path('manual/build-70/worker.js').read_text()))
print('Worker 75 generated from verified baseline with guarded replacements.')
