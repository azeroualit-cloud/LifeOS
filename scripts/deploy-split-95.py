"""Context-guarded expense split for expense routing (REVIEW-95 / FUNDING-BLOCK-2026-11-21).

An ordinary expense may be split by the user: the part from the budget is recovered in the chosen
budget months through the existing 'recovery' policy, the rest stays on savings. Only the routing
section between its two fixed markers is replaced, and only when the live section is byte for byte
the savings version deployed in build 91. Both Workers (site and app) are changed together.
Never logs source or credentials.
"""
from pathlib import Path
import hashlib
import importlib.util

spec = importlib.util.spec_from_file_location('deployment', Path(__file__).with_name('deploy-unified-activities.py'))
deployment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deployment)

START = '// Integrates the existing plan service.'
END = '\nconst expenseRouting = createExpenseRouting('
# Routing section deployed by deploy-savings-91 (backend/expense-routing/routing.mjs at 2f2fd2a).
BEFORE_SHA256 = '1f465922b5860813673725187fd3329da8391bd152677b64a31fe2101b816191'


def routing():
    text = Path('backend/expense-routing/routing.mjs').read_text(encoding='utf-8')
    return text.replace('export function createExpenseRouting', 'function createExpenseRouting', 1)


def transform(source):
    if source.count(START) != 1 or source.count(END) != 1:
        # Counts only (never source): tells which marker a bundled Worker spells differently.
        print('ROUTING_MARKERS start=%d end=%d var_end=%d let_end=%d create=%d' % (
            source.count(START), source.count(END), source.count('var expenseRouting = createExpenseRouting('),
            source.count('let expenseRouting = createExpenseRouting('), source.count('function createExpenseRouting(')))
        raise RuntimeError('Contesto routing non riconosciuto; nessuna scrittura.')
    a = source.index(START)
    b = source.index(END, a)
    current, replacement = source[a:b], routing()
    if current == replacement:
        return source
    if hashlib.sha256(current.encode()).hexdigest() != BEFORE_SHA256:
        raise RuntimeError('Routing live differente dalla versione attesa; nessuna scrittura.')
    if 'splitDestination: true' not in replacement or "input.budgetTreatment === 'recovery'" not in replacement:
        raise RuntimeError('Sorgente routing senza ripartizione; nessuna scrittura.')
    return source[:a] + replacement + source[b:]


if __name__ == '__main__':
    deployment.transform = transform
    deployment.main(label='EXPENSE_SPLIT_95_DEPLOYED_AND_VERIFIED')
