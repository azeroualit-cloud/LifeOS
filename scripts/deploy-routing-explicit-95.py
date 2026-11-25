"""Site expense form: never preselect a goal or fund (EXPENSE-ROUTING-EXPLICIT-2026-11-25).

The page embedded in both Workers (site `lifeos`, app `lifeos-native-test`) preselected the only plan of the
category, even a goal, so an unrelated expense paid and closed it. After this patch the form preselects a
plan only when it is the single candidate and a recurring due (fixed / estimated); otherwise the select starts
on a disabled «Scegli» option and is required. A goal option says that paying closes it.
Every fragment must appear exactly once (escaped page source), otherwise nothing is written. A Worker that
already carries the marker is left as it is. Never logs source or credentials.
"""
from pathlib import Path
import importlib.util

MARKER = 'EXPENSE-ROUTING-EXPLICIT-2026-11-25'
# Fragments as they appear inside the escaped page string of the Worker module.
PATCHES = (
    ('const suggested = plans.length === 1 ? plans[0].id : \\"__ordinary\\";',
     'const suggested = !plans.length ? \\"__ordinary\\" : plans.length === 1 && [\\"fixed\\", \\"estimated\\"].includes(plans[0].kind) ? plans[0].id : \\"\\"; /* ' + MARKER + ' */'),
    ('<select name=\\"routingChoice\\"><option value=\\"__ordinary\\">Budget del mese</option>',
     '<select name=\\"routingChoice\\" required><option value=\\"\\" disabled>Scegli: budget o piano</option><option value=\\"__ordinary\\">Budget del mese</option>'),
    ('Piano \\u00b7 ${escapeHtml(p.name)}${p.availableCents',
     'Piano \\u00b7 ${escapeHtml(p.name)}${p.kind === \\"goal\\" ? \\" \\u00b7 chiude l\\u2019obiettivo\\" : \\"\\"}${p.availableCents'),
)


def transform(source):
    if MARKER in source:
        if all(new in source for _, new in PATCHES):
            print('ROUTING_EXPLICIT_CHECK already=1')
            return source
        raise RuntimeError('Patch della destinazione incompleta; nessuna scrittura.')
    counts = [source.count(old) for old, _ in PATCHES]
    print('ROUTING_EXPLICIT_CHECK ' + ' '.join('p%d=%d' % (i + 1, c) for i, c in enumerate(counts)))
    if any(c != 1 for c in counts):
        raise RuntimeError('Modulo spesa del sito non riconosciuto; nessuna scrittura.')
    for old, new in PATCHES:
        source = source.replace(old, new, 1)
    return source


if __name__ == '__main__':
    spec = importlib.util.spec_from_file_location('deployment', Path(__file__).with_name('deploy-unified-activities.py'))
    deployment = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(deployment)
    deployment.transform = transform
    try:
        deployment.main(label='ROUTING_EXPLICIT_95_DEPLOYED_AND_VERIFIED')
    except Exception as error:
        print('::error title=Deploy destinazione spesa::' + type(error).__name__ + ': ' + str(error)[:300])
        raise SystemExit(1)
