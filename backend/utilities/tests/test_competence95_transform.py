"""The bill-savings deployment turns a live Worker with an older competence module into the tested one."""
from pathlib import Path
import importlib.util

spec = importlib.util.spec_from_file_location('u95', Path('scripts') / 'deploy-utilities-95.py')
u95 = importlib.util.module_from_spec(spec); spec.loader.exec_module(u95)
current = Path('manual/build-75/worker.js').read_text(encoding='utf-8')
assert current.endswith(u95.MARKER + u95.payload()), 'build-75 must be generated from the current competence source'
head = current[:current.index(u95.MARKER)]
for commit in u95.KNOWN_COMMITS:
    old = head + u95.MARKER + u95.payload_at(commit)
    assert old != current and u95.transform(old) == current
assert u95.transform(current) == current
try:
    u95.transform(head + u95.MARKER + u95.payload_at('7a52c33').replace('Importo della bolletta non valido.', 'Altro.', 1))
except RuntimeError:
    pass
else:
    raise AssertionError('An unknown live competence module must be refused')
# Bundled live Worker without the marker: only utilityCompetenceContext is replaced.
old_fn = u95.function_text(u95.payload_at('7a52c33'))
bundled = head + chr(10) + old_fn.replace("'", '"') + chr(10)
result = u95.transform(bundled)
assert u95.function_text(u95.payload()) in result and old_fn.replace("'", '"') not in result
assert u95.transform(result) == result
print('OK')
