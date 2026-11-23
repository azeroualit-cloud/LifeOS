"""Bill competence with a savings part (FUNDING-BLOCK-2026-11-21, build 95).

The competence module sits at the end of both Workers behind its build 75 marker. It is replaced
only when the live tail is one of the known versions (build 75 deploy or the later period fix).
Never logs source or credentials.
"""
from pathlib import Path
import hashlib
import importlib.util
import subprocess

split_spec = importlib.util.spec_from_file_location('split95', Path(__file__).with_name('deploy-split-95.py'))
split = importlib.util.module_from_spec(split_spec)
split_spec.loader.exec_module(split)
spec = importlib.util.spec_from_file_location('deployment', Path(__file__).with_name('deploy-unified-activities.py'))
deployment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deployment)

MARKER = '// LIFEOS_UTILITY_COMPETENCE_75\n'
KNOWN_COMMITS = ('51fd07b', '7a52c33')
KNOWN_SHA256 = {'6597945ef64933b1ca34ea0bed1049a39dba78d7f7c9f693b9a08f10a9c10cfa'}


def strip(text):
    return text.replace('export async function ', 'async function ').replace('export function ', 'function ')


def payload():
    return strip(Path('backend/utilities/competence.mjs').read_text(encoding='utf-8'))


def payload_at(commit):
    return strip(subprocess.check_output(['git', 'show', commit + ':backend/utilities/competence.mjs'], text=True, encoding='utf-8'))


FUNCTION = 'function utilityCompetenceContext('


def function_text(text):
    start = text.index(FUNCTION)
    return text[start:split.function_end(text, start)]


def compact(text):
    return split.compact(text)


def bundled(source):
    """Bundled live Worker (no marker): replace only utilityCompetenceContext, found by name and braces."""
    if source.count(FUNCTION) != 1:
        print('COMPETENCE_FUNCTION %d' % source.count(FUNCTION))
        raise RuntimeError('Modulo competenze non riconosciuto; nessuna scrittura.')
    a = source.index(FUNCTION)
    b = split.function_end(source, a)
    current, replacement = source[a:b], function_text(payload())
    if current == replacement:
        return source
    live = compact(current)
    needles = ("utilityShares(Math.round(-Number(row.amount)*100),period)", "add(payment.movementId,payment.utilityPeriod)",
               "confirmedPendingRow(command,", "command.utilityPeriod)")  # the bundler may rename local variables (id2)
    found = {n: n in live for n in needles}
    print('COMPETENCE_CHECK ' + ' '.join('%s=%d' % (n.split('(')[0][:20], int(v)) for n, v in found.items()) + ' savings=%d' % live.count('utilitySavingsCents'))
    # Required: the plan-payment bills (every deployed version). The ordinary-bill loop may be absent:
    # the live Workers still run the first competence version, which only knew plan payments.
    if not (found[needles[0]] and found[needles[1]]) or 'utilitySavingsCents' in live:
        raise RuntimeError('Versione competenze differente; nessuna scrittura.')
    return source[:a] + replacement + source[b:]


def transform(source):
    wanted = MARKER + payload()
    if source.endswith(wanted):
        return source
    if source.count(MARKER) == 0:
        return bundled(source)
    if source.count(MARKER) != 1:
        print('COMPETENCE_MARKERS %d' % source.count(MARKER))
        raise RuntimeError('Modulo competenze non riconosciuto; nessuna scrittura.')
    offset = source.index(MARKER)
    tail = source[offset:]
    known = set(KNOWN_SHA256) | {hashlib.sha256((MARKER + payload_at(c)).encode()).hexdigest() for c in KNOWN_COMMITS}
    if hashlib.sha256(tail.encode()).hexdigest() not in known:
        print('COMPETENCE_TAIL_UNKNOWN length=%d savings=%d' % (len(tail), tail.count('utilitySavingsCents')))
        raise RuntimeError('Versione competenze differente; nessuna scrittura.')
    if 'utilitySavingsCents' not in wanted:
        raise RuntimeError('Sorgente competenze senza parte dai risparmi; nessuna scrittura.')
    return source[:offset] + wanted


if __name__ == '__main__':
    deployment.transform = transform
    deployment.main(label='UTILITY_COMPETENCE_95_DEPLOYED_AND_VERIFIED')
