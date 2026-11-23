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
admin = (base / 'admin-api.js').read_text(encoding='utf-8') + '\n' + (base / 'forecast-api.js').read_text(encoding='utf-8') + '\n' + (base / 'life-api.js').read_text(encoding='utf-8')

src, count = re.subn(r'var APP_HTML = ".*";', lambda _: 'var APP_HTML = ' + json.dumps(html, ensure_ascii=True) + ';', src, count=1)
assert count == 1, 'APP_HTML non trovato in build-75'
anchor = 'async function getFinanceMeta(env) {'
assert src.count(anchor) == 1, 'ancora getFinanceMeta'
src = src.replace(anchor, admin.strip('\n') + '\n' + anchor)
route = re.compile(r'(if \(method === "getFinanceMeta"\)\s*return response\(await getFinanceMeta\(env\)\);)')
assert len(route.findall(src)) == 1, 'route getFinanceMeta'
src = route.sub(lambda m: m.group(1) + '\n      if (method === "getAdminStatus") return response(await getAdminStatus(env));\n      if (method === "getAdminExport") return response(await getAdminExport(env, args[0], args[1]));\n      if (method === "getForecastSettings") return response(await getForecastSettings(env));\n      if (method === "saveForecastSettings") return response(await saveForecastSettings(env, args[0]));\n      if (method === "listFoods") return response(await listFoods(env));\n      if (method === "saveFood") return response(await saveFood(env, args[0]));\n      if (method === "deleteFood") return response(await deleteFood(env, args[0]));\n      if (method === "importFoods") return response(await importFoods(env, args[0]));\n      if (method === "getBloom") return response(await getBloom(env));\n      if (method === "getBloomItem") return response(await getBloomItem(env, args[0]));\n      if (method === "saveBloomItem") return response(await saveBloomItem(env, args[0]));\n      if (method === "trashBloomItem") return response(await trashBloomItem(env, args[0], args[1] === true));\n      if (method === "deleteBloomItem") return response(await deleteBloomItem(env, args[0]));\n      if (method === "saveBloomCollection") return response(await saveBloomCollection(env, args[0]));\n      if (method === "deleteBloomCollection") return response(await deleteBloomCollection(env, args[0]));\n      if (method === "importBloom") return response(await importBloom(env, args[0]));\n      if (method === "listFoodDiary") return response(await listFoodDiary(env, args[0]));\n      if (method === "listFoodDiaryDays") return response(await listFoodDiaryDays(env, args[0], args[1]));\n      if (method === "saveFoodDiaryEntry") return response(await saveFoodDiaryEntry(env, args[0]));\n      if (method === "deleteFoodDiaryEntry") return response(await deleteFoodDiaryEntry(env, args[0], args[1]));\n      if (method === "importFoodDiary") return response(await importFoodDiary(env, args[0]));
      if (method === "getSettings") return response(await getSettings(env, args[0]));
      if (method === "saveSettings") return response(await saveSettings(env, args[0], args[1], args[2]));
      if (method === "addAlertLog") return response(await addAlertLog(env, args[0]));
      if (method === "listAlertLog") return response(await listAlertLog(env, args[0]));', src)

for i, script in enumerate(re.findall(r'<script[^>]*>(.*?)</script>', html, re.S)):
    with tempfile.TemporaryDirectory() as folder:
        target = Path(folder) / f'ui-{i}.js'; target.write_text(script)
        subprocess.run(['node', '--check', str(target)], check=True)
out = base / 'dist' / 'worker-release.mjs'
out.parent.mkdir(exist_ok=True)
out.write_text(src, encoding='utf-8')
subprocess.run(['node', '--check', str(out)], check=True)
print('Worker di rilascio generato (non distribuito):', out, len(src), 'byte')
