"""The split deployment must turn the build 91 Worker into exactly the Worker the tests ran against."""
from pathlib import Path
import importlib.util
import subprocess


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), Path('scripts') / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


split = load('deploy-split-95')
current = Path('manual/build-75/worker.js').read_text(encoding='utf-8')
new_routing = split.routing()
old_routing = subprocess.check_output(['git', 'show', '2f2fd2a:backend/expense-routing/routing.mjs'], text=True, encoding='utf-8').replace('export function createExpenseRouting', 'function createExpenseRouting', 1)
assert current.count(new_routing) == 1, 'build-75 must be generated from the current routing source first'
previous = current.replace(new_routing, old_routing, 1)
assert previous != current
assert split.transform(previous) == current
assert split.transform(current) == current
for tampered in (previous.replace("fail('Importo non valido.')", "fail('Importo errato.')", 1), previous.replace(split.START, '// other', 1)):
    try:
        split.transform(tampered)
    except RuntimeError:
        pass
    else:
        raise AssertionError('A different live routing must be refused')
print('OK')
