"""Read-only check of the live Workers for the site category move (26/11/2026: «Sposta ... nulla è stato spostato»).
Downloads the live modules of both Workers and prints, per Worker, how many times key fragments appear.
Never prints source, records or credentials; writes nothing.
"""
import importlib.util, json, os, urllib.request
from pathlib import Path

spec = importlib.util.spec_from_file_location('helpers', Path(__file__).with_name('deploy-lifeos-61.py'))
helpers = importlib.util.module_from_spec(spec); spec.loader.exec_module(helpers)
token = os.environ['CLOUDFLARE_API_TOKEN'].strip()

def api(path):
    r = urllib.request.Request('https://api.cloudflare.com/client/v4/accounts/' + helpers.ACCOUNT + path, headers={'Authorization': 'Bearer ' + token})
    with urllib.request.urlopen(r, timeout=90) as resp: return resp.read(), resp.headers

FRAGMENTS = {
    'case_classify': 'case "classifyMovement"',
    'fn_classify': 'function classifyMovement(',
    'manual_note': '[Categoria manuale]',
    'ensure_after_writes': '"classifyMovement",',
    'ensure_fn': 'function ensureFinanceCategories(',
    'manual_skip_rules': 'includes("[Categoria manuale]")',
    'site_cat_move': 'classifyMovement", [row, to]',
    'site_cat_scan': 'getFinanceData", [y, m]',
    'fingerprint_fn': 'function movementCategoryFingerprint(',
}
for name in helpers.WORKERS:
    entry, parts = helpers.modules(*api('/workers/scripts/' + name + '/content/v2'))
    total = {k: 0 for k in FRAGMENTS}
    for filename, kind, data in parts:
        if 'source-map' in kind or filename.endswith('.map'): continue
        text = data.decode('utf-8', 'ignore')
        for k, f in FRAGMENTS.items():
            total[k] += text.count(f) + text.count(f.replace('"', '\\"'))
    print('LIVE', name, json.dumps(total))
