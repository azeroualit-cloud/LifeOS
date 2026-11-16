"""Context-guarded savings destination for expense routing; every other live module stays intact.

FINANCE-SAVINGS-RESTORE-2026-11-16 / BACKEND-DEPLOY-SAVINGS-2026-11-16. Only the routing
section between its two fixed markers is replaced, and only when the live section is byte
for byte the version this change was written against. Never logs source or credentials.
"""
from pathlib import Path
import hashlib
import importlib.util

spec = importlib.util.spec_from_file_location('deployment', Path(__file__).with_name('deploy-unified-activities.py'))
deployment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deployment)

START = '// Integrates the existing plan service.'
END = '\nconst expenseRouting = createExpenseRouting('
# Routing section of codex/revision77 at 04ad889, the source of build 90.
BEFORE_SHA256 = '1a9968ab12d5204a17c1bf2432944a459edcd02d95510f702bf2f3c74867152c'

def routing():
    return Path('backend/expense-routing/routing.mjs').read_text().replace('export function createExpenseRouting', 'function createExpenseRouting', 1)

def transform(source):
    if source.count(START) != 1 or source.count(END) != 1:
        raise RuntimeError('Contesto routing non riconosciuto; nessuna scrittura.')
    a = source.index(START)
    b = source.index(END, a)
    current, replacement = source[a:b], routing()
    if current == replacement:
        return source
    if hashlib.sha256(current.encode()).hexdigest() != BEFORE_SHA256:
        raise RuntimeError('Routing live differente dalla versione attesa; nessuna scrittura.')
    if "['ordinary','plan','savings']" not in replacement or 'savingsDestination: true' not in replacement:
        raise RuntimeError('Sorgente routing senza destinazione Risparmi; nessuna scrittura.')
    return source[:a] + replacement + source[b:]

if __name__ == '__main__':
    deployment.transform = transform
    deployment.main(label='SAVINGS_DESTINATION_91_DEPLOYED_AND_VERIFIED')
