"""Bloom and personal foods for the app gateway (lifeos-native-test), build 93.

BUILD93-REQUEST-2026-11-21: the app reads and writes Bloom and personal foods on the server,
in the same D1 tables the site already uses (web_foods, web_bloom_*). Only lifeos-native-test
is changed; the site Worker already serves these tables. The module is prepended once behind a
fixed marker and one dispatch line is added before writeAction. Never logs source or credentials.
"""
from pathlib import Path
import importlib.util, re

spec = importlib.util.spec_from_file_location('deployment', Path(__file__).with_name('deploy-unified-activities.py'))
deployment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deployment)

MARKER = '// LIFEOS_BLOOM_FOODS_93'
HOOK_BEFORE = '      const result = await writeAction(env, method, args);'
HOOK = '      const bloomFoods = await bloomFoodsAction(env, method, args);\n      if (bloomFoods !== undefined) return response(bloomFoods);\n'

def module():
    text = Path('backend/bloom-foods/bloomfoods.mjs').read_text()
    text = re.sub(r'^export (async function|function)', r'\1', text, flags=re.M)
    if not text.startswith(MARKER + '\n'):
        raise RuntimeError('Modulo Bloom e alimenti senza marcatore; nessuna scrittura.')
    return text

def transform(source):
    block = module() + '\n'
    if MARKER in source:
        if not source.startswith(block) or HOOK not in source:
            raise RuntimeError('Versione Bloom e alimenti diversa; nessuna scrittura.')
        return source
    if source.count(HOOK_BEFORE) != 1:
        raise RuntimeError('Punto di aggancio API non riconosciuto; nessuna scrittura.')
    for name in ['bloomFoodsAction', 'nbTables', 'listFoods', 'getBloom']:
        if re.search(r'\bfunction ' + name + r'\(', source):
            raise RuntimeError('Nome gia presente nel Worker: ' + name + '; nessuna scrittura.')
    return block + source.replace(HOOK_BEFORE, HOOK + HOOK_BEFORE, 1)

if __name__ == '__main__':
    deployment.helpers.WORKERS = ['lifeos-native-test']
    deployment.transform = transform
    try:
        deployment.main(label='BLOOM_FOODS_93_DEPLOYED_AND_VERIFIED')
    except Exception as error:
        # Messages are fixed Italian texts or exception classes: no source, records or credentials.
        print('::error title=Deploy lifeos-native-test::' + type(error).__name__ + ': ' + str(error)[:300])
        raise SystemExit(1)
