"""Site Worker `lifeos`: new web interface and the shared food diary (DEPLOY-WORKERS-93-2026-11-22).

Starts from the live module (never from a local copy of the backend), so everything already
online is kept. Three changes only, each checked before writing:
  1. APP_HTML is replaced by the site interface `site/app.html` (from codex/revision77);
  2. the diary block (`site/diary.js`, the tail of web/life-api.js) is added once behind a marker;
  3. the five diary routes are added next to the Bloom routes.
Bindings, secrets and Cloudflare Access are preserved by the shared deploy helper, which also
rolls back if the upload cannot be verified. Never logs source or credentials.
"""
from pathlib import Path
import importlib.util, json, re

spec = importlib.util.spec_from_file_location('deployment', Path(__file__).with_name('deploy-unified-activities.py'))
deployment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deployment)

MARKER = '// LIFEOS_SITE_DIARY_93'
ANCHOR = 'async function getFinanceMeta(env) {'
ROUTE_AFTER = 'if (method === "importBloom") return response(await importBloom(env, args[0]));'
ROUTES = ''.join('\n      if (method === "%s") return response(await %s(env, %s));' % (m, m, a) for m, a in [
    ('listFoodDiary', 'args[0]'), ('listFoodDiaryDays', 'args[0], args[1]'), ('saveFoodDiaryEntry', 'args[0]'),
    ('deleteFoodDiaryEntry', 'args[0], args[1]'), ('importFoodDiary', 'args[0]')])


def diary_block():
    text = Path('site/diary.js').read_text(encoding='utf-8')
    if not text.startswith('let ndReady = null;') or 'async function saveFoodDiaryEntry(' not in text:
        raise RuntimeError('Blocco del diario non riconosciuto; nessuna scrittura.')
    return MARKER + '\n' + text.rstrip('\n') + '\n'


def transform(source):
    html = Path('site/app.html').read_text(encoding='utf-8')
    if '<html' not in html or 'fdSection' not in html:
        raise RuntimeError('Interfaccia del sito non riconosciuta; nessuna scrittura.')
    source, count = re.subn(r'var APP_HTML = ".*";', lambda _: 'var APP_HTML = ' + json.dumps(html, ensure_ascii=True) + ';', source, count=1)
    if count != 1:
        raise RuntimeError('APP_HTML non trovato nel Worker online; nessuna scrittura.')
    block = diary_block()
    if MARKER in source:
        if block not in source:
            raise RuntimeError('Versione del diario diversa nel Worker online; nessuna scrittura.')
    else:
        for name in ['listFoodDiary', 'saveFoodDiaryEntry', 'ndTables']:
            if re.search(r'\bfunction ' + name + r'\(', source):
                raise RuntimeError('Nome gia presente nel Worker: ' + name + '; nessuna scrittura.')
        if source.count(ANCHOR) != 1:
            raise RuntimeError('Punto di inserimento del diario non riconosciuto; nessuna scrittura.')
        source = source.replace(ANCHOR, block + ANCHOR, 1)
    if 'method === "listFoodDiary"' not in source:
        if source.count(ROUTE_AFTER) != 1:
            raise RuntimeError('Rotte Bloom non trovate; nessuna scrittura.')
        source = source.replace(ROUTE_AFTER, ROUTE_AFTER + ROUTES, 1)
    return source


if __name__ == '__main__':
    deployment.helpers.WORKERS = ['lifeos']
    deployment.transform = transform
    try:
        deployment.main(label='SITE_93_DEPLOYED_AND_VERIFIED')
    except Exception as error:
        # Messages are fixed Italian texts or exception classes: no source, records or credentials.
        print('::error title=Deploy lifeos::' + type(error).__name__ + ': ' + str(error)[:300])
        raise SystemExit(1)
