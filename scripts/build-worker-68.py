from pathlib import Path
import importlib.util
spec=importlib.util.spec_from_file_location('activity_deployment',Path(__file__).with_name('deploy-unified-activities.py'))
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
base=Path('manual/build-67/worker.js').read_text()
p=Path('manual/build-68/worker.js');p.parent.mkdir(parents=True,exist_ok=True);p.write_text(module.transform(base))
