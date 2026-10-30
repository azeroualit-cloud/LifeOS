from pathlib import Path
import importlib.util
spec=importlib.util.spec_from_file_location('movement70',Path(__file__).with_name('deploy-movement-creation-70.py'))
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
path=Path('manual/build-70/worker.js');path.parent.mkdir(parents=True,exist_ok=True)
path.write_text(module.transform(Path('manual/build-68/worker.js').read_text()))
