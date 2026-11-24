"""Bills never change past months (BILL-PAST-MONTHS-2026-11-24, build 95).

Three functions are replaced in both Workers, each found by its name and braces, and only when the live
text is the known previous version (commit 7c24f3f) or already the new one:
  - createExpenseRouting (backend/expense-routing/routing.mjs): months for the excess, whole bill from savings;
  - utilityCompetenceContext and utilityMonthlyCost (backend/utilities/competence.mjs): new bills add their
    excess to the chosen months; older bills keep their competence shares.
The levelling block (backend/utilities/levelling.mjs) is updated through deploy-levelling-95.py.
Anything unknown: nothing is written. Never logs source or credentials.
"""
from pathlib import Path
import importlib.util
import subprocess
import hashlib
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
PREVIOUS = '7c24f3f'


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, HERE / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


split = load('split95', 'deploy-split-95.py')
levelling = load('levelling95', 'deploy-levelling-95.py')


def strip(text):
    return text.replace('export async function ', 'async function ').replace('export function ', 'function ')


def normal(text):
    # The bundler renames locals with a numeric suffix (month -> month2) and wraps single arrow parameters in parentheses.
    text = re.sub(r'(?<![\w$)])\(([A-Za-z_$][\w$]*)\)\s*=>', r'\1=>', text)
    return re.sub(r'(?<![\w$])([A-Za-z_$][A-Za-z_$]*)\d+(?![\w$])', r'\1', split.compact(text))


def function(text, name):
    head = '\nfunction %s(' % name
    if text.count(head) != 1:
        raise RuntimeError('Funzione %s non trovata una sola volta; nessuna scrittura.' % name)
    start = text.index(head) + 1
    return start, split.function_end(text, start)


def source_at(commit, path):
    if commit is None:
        return strip((ROOT / path).read_text(encoding='utf-8'))
    return strip(subprocess.check_output(['git', 'show', commit + ':' + path], text=True, encoding='utf-8', cwd=ROOT))


TARGETS = [('createExpenseRouting', 'backend/expense-routing/routing.mjs'),
           ('utilityCompetenceContext', 'backend/utilities/competence.mjs'),
           ('utilityMonthlyCost', 'backend/utilities/competence.mjs')]


def transform(source):
    for name, path in TARGETS:
        old_text, new_text = source_at(PREVIOUS, path), source_at(None, path)
        a, b = function('\n' + old_text, name)
        old = ('\n' + old_text)[a:b]
        a, b = function('\n' + new_text, name)
        new = ('\n' + new_text)[a:b]
        a, b = function(source, name)
        live = source[a:b]
        if live == new:
            print('BILLS95B %s=current' % name)
            continue
        if normal(live) != normal(old):
            known = {}
            for c in ('51fd07b', '7a52c33', '7c24f3f', 'bd425c7'):
                text = '\n' + source_at(c, path)
                known[hashlib.md5(normal(text[slice(*function(text, name))]).encode()).hexdigest()[:8]] = c
            fingerprint = hashlib.md5(normal(live).encode()).hexdigest()[:8]
            print('BILLS95B %s=unknown fingerprint=%s matches=%s' % (name, fingerprint, known.get(fingerprint, 'none')))
            raise RuntimeError('Versione di %s differente; nessuna scrittura.' % name)
        print('BILLS95B %s=replaced' % name)
        source = source[:a] + new + source[b:]
    return levelling.transform(source)


if __name__ == '__main__':
    deployment = load('deployment', 'deploy-unified-activities.py')
    deployment.transform = transform
    try:
        deployment.main(label='BILLS_95B_DEPLOYED_AND_VERIFIED')
    except Exception as error:
        print('::error title=Deploy bollette::' + type(error).__name__ + ': ' + str(error)[:300])
        raise SystemExit(1)
