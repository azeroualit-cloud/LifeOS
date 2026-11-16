"""The savings deployment must turn the previous Worker into exactly the Worker the tests ran against."""
from pathlib import Path
import importlib.util
import subprocess

def load(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), Path('scripts') / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

savings = load('deploy-savings-91')
current = Path('manual/build-75/worker.js').read_text()
new_routing = savings.routing()
old_routing = subprocess.check_output(['git', 'show', '04ad889:backend/expense-routing/routing.mjs'], text=True).replace('export function createExpenseRouting', 'function createExpenseRouting', 1)
assert current.count(new_routing) == 1, 'build-75 must be generated from the current routing source first'
previous = current.replace(new_routing, old_routing, 1)
assert previous != current
# Previous live source becomes the tested source, byte for byte.
assert savings.transform(previous) == current
# Applying it again changes nothing.
assert savings.transform(current) == current
# Any other live routing is refused without producing output.
for tampered in (previous.replace("fail('Importo non valido.')", "fail('Importo errato.')", 1), previous.replace(savings.START, '// other', 1)):
    try:
        savings.transform(tampered)
    except RuntimeError:
        pass
    else:
        raise AssertionError('A different live routing must be refused')
print('OK')
