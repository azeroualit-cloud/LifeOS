"""Genera il Worker di rilascio: backend manual/build-75 + UI web aggiornata + metodi Admin.

Scrive solo web/dist/worker-release.js. Non esegue deploy e non tocca Cloudflare.
Il backend build-75 è quello usato dall'app (piani, bollette, destinazione spesa);
web/worker.mjs resta la baseline storica e NON va distribuito al posto di build-75.
"""
from pathlib import Path
import json, re, shutil, subprocess, tempfile

base = Path(__file__).parent
src = (base.parent / 'manual' / 'build-75' / 'worker.js').read_text(encoding='utf-8')
html = (base / 'app.html').read_text(encoding='utf-8')
admin = (base / 'admin-api.js').read_text(encoding='utf-8')

src, count = re.subn(r'var APP_HTML = ".*";', lambda _: 'var APP_HTML = ' + json.dumps(html, ensure_ascii=True) + ';', src, count=1)
assert count == 1, 'APP_HTML non trovato in build-75'
anchor = 'async function getFinanceMeta(env) {'
assert src.count(anchor) == 1, 'ancora getFinanceMeta'
src = src.replace(anchor, admin.strip('\n') + '\n' + anchor)
route = re.compile(r'(if \(method === "getFinanceMeta"\)\s*return response\(await getFinanceMeta\(env\)\);)')
assert len(route.findall(src)) == 1, 'route getFinanceMeta'
src = route.sub(lambda m: m.group(1) + '\n      if (method === "getAdminStatus") return response(await getAdminStatus(env));\n      if (method === "getAdminExport") return response(await getAdminExport(env, args[0], args[1]));', src)

for i, script in enumerate(re.findall(r'<script[^>]*>(.*?)</script>', html, re.S)):
    with tempfile.TemporaryDirectory() as folder:
        target = Path(folder) / f'ui-{i}.js'; target.write_text(script)
        subprocess.run(['node', '--check', str(target)], check=True)
out = base / 'dist' / 'worker-release.mjs'
out.parent.mkdir(exist_ok=True)
out.write_text(src, encoding='utf-8')
subprocess.run(['node', '--check', str(out)], check=True)
print('Worker di rilascio generato (non distribuito):', out, len(src), 'byte')
