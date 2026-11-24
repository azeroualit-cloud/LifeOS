"""Auto-levelling quota for "Ricorrente stimato" plans (UTILITY-LEVELLING-2026-11-24, build 95).

In both Workers (site `lifeos` and app `lifeos-native-test`) the three functions that rewrite the
estimated quota are renamed to *Base95 and wrapped: the original behaviour runs first, then
`lifeosLevelEstimate95` (backend/utilities/levelling.mjs) writes the levelled quota. Every name must
appear exactly once, otherwise nothing is written. A Worker that already has the current block is left
as it is; an older block behind the marker is replaced. Never logs source or credentials.
"""
from pathlib import Path
import importlib.util

MARKER = '// LIFEOS_LEVEL_ESTIMATE_95'
END = '// LIFEOS_LEVEL_ESTIMATE_95_END\n'
NAMES = ('completePayment', 'completePaymentDeletion', 'refreshUtilityEstimate')
WRAPPERS = '''function completePayment(state, id, movementId, today) {
  const next = completePaymentBase95(state, id, movementId, today), payment = next.payments?.[id];
  if (payment) lifeosLevelEstimate95(next, next.plans[payment.planId], today);
  return next;
}
function completePaymentDeletion(state, id, today) {
  const next = completePaymentDeletionBase95(state, id, today), payment = next.payments?.[id];
  if (payment) lifeosLevelEstimate95(next, next.plans[payment.planId], today);
  return next;
}
function refreshUtilityEstimate(state, planId, today) {
  refreshUtilityEstimateBase95(state, planId, today);
  lifeosLevelEstimate95(state, state.plans?.[planId], today);
}
'''


def block():
    text = Path(__file__).resolve().parent.parent.joinpath('backend/utilities/levelling.mjs').read_text(encoding='utf-8')
    core = text[:text.index('// Wrappers installed')].rstrip() + '\n'
    if not core.startswith(MARKER) or 'export function lifeosLevelEstimate95(' not in core:
        raise RuntimeError('Sorgente del livellamento non riconosciuta; nessuna scrittura.')
    return core.replace('export function ', 'function ') + WRAPPERS + END


def transform(source):
    wanted = block()
    if MARKER in source:
        if source.count(MARKER + ' (') != 1 or source.count(END) != 1:
            raise RuntimeError('Blocco livellamento non riconosciuto; nessuna scrittura.')
        a = source.index(MARKER + ' (')
        b = source.index(END) + len(END)
        return source if source[a:b] == wanted else source[:a] + wanted + source[b:]
    # Real declarations start a line; the embedded page (APP_HTML) holds its own copies inside a string.
    counts = {n: source.count('\nfunction %s(' % n) for n in NAMES}
    bases = sum(source.count('function %sBase95(' % n) for n in NAMES)
    print('LEVELLING_CHECK ' + ' '.join('%s=%d' % (n, c) for n, c in counts.items()) + ' base=%d' % bases)
    if any(c != 1 for c in counts.values()) or bases or 'lifeosLevelEstimate95' in source:
        raise RuntimeError('Funzioni dei piani non riconosciute; nessuna scrittura.')
    for n in NAMES:
        source = source.replace('\nfunction %s(' % n, '\nfunction %sBase95(' % n, 1)
    anchor = '\nfunction completePaymentBase95('
    return source.replace(anchor, '\n' + wanted + anchor[1:], 1)


if __name__ == '__main__':
    spec = importlib.util.spec_from_file_location('deployment', Path(__file__).with_name('deploy-unified-activities.py'))
    deployment = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(deployment)
    deployment.transform = transform
    try:
        deployment.main(label='LEVELLING_95_DEPLOYED_AND_VERIFIED')
    except Exception as error:
        print('::error title=Deploy livellamento::' + type(error).__name__ + ': ' + str(error)[:300])
        raise SystemExit(1)
