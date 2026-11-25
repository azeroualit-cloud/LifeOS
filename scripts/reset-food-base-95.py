"""FOOD-DB-RESET-2026-11-25 (user request: «facciamo che il DB lo rifacciamo da zero», «mantieni tutti i
miei integratori aggiunti da me»; run now: «a me basta non rimanere senza alimenti»). Through the app
gateway only (the CI key cannot query D1 directly):
  1. archiveFoods: backup tables web_foods_backup_20261125 / web_foods_app_backup_20261125 (created once);
  2. imports the curated base (native-next/Resources/base-foods.json) first, so the list is never empty;
  3. deletes every other food except family = supplement (deletions leave tombstones for the phones).
Logs only counts. Repeatable: a second run re-imports the base and finds nothing else to delete.
"""
import os, json, time, urllib.request, urllib.error, http.cookiejar
from pathlib import Path

ORIGIN = 'https://lifeos-native-test.a-zeroual-it.workers.dev'
client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))

def post(path, payload):
    r = urllib.request.Request(ORIGIN + path, data=json.dumps(payload).encode(), method='POST',
        headers={'Origin': ORIGIN, 'Content-Type': 'application/json', 'User-Agent': 'LifeOS-Food-Reset/1.0'})
    with client.open(r, timeout=120) as resp: return json.loads(resp.read())

def api(method, args, tries=4):
    for attempt in range(tries):
        try: return post('/api/' + method, args)
        except urllib.error.HTTPError as e:
            if e.code < 500 or attempt == tries - 1: raise
            time.sleep(3 + attempt * 4)

def main():
    base = json.loads(Path('native-next/Resources/base-foods.json').read_text(encoding='utf-8'))
    assert base and all(f['id'].startswith('base-') and f['family'] != 'supplement' for f in base)
    base_ids = {f['id'] for f in base}
    post('/auth/login', {'user': 'nas', 'password': os.environ['LIFEOS_TEST_PASSWORD']})
    # The gateway with archiveFoods is deployed by the other workflow of the same push: wait for it.
    for attempt in range(40):
        try:
            archive = api('archiveFoods', [], tries=1); break
        except urllib.error.HTTPError as e:
            if attempt == 39: raise
            print('WAIT_GATEWAY HTTP', e.code); time.sleep(30)
    print('ARCHIVE', json.dumps(archive))
    before = api('listFoods', [])['foods']
    assert archive['backup'] >= len([f for f in before if f['id'] not in base_ids]), 'backup smaller than the list: nothing deleted'
    sup_before = [f['id'] for f in before if f.get('family') == 'supplement']
    print('BEFORE total %d supplements %d' % (len(before), len(sup_before)))
    for i in range(0, len(base), 100):
        api('importFoods', [base[i:i + 100]]); time.sleep(0.3)
    doomed = [f['id'] for f in before if f.get('family') != 'supplement' and f['id'] not in base_ids]
    for n, food_id in enumerate(doomed, 1):
        api('deleteFood', [food_id])
        if n % 100 == 0: print('DELETED', n, 'of', len(doomed))
    after = api('listFoods', [])['foods']
    sup_after = {f['id'] for f in after if f.get('family') == 'supplement'}
    base_after = len([f for f in after if f['id'] in base_ids])
    print('AFTER total %d; supplements kept %d of %d; base %d of %d; removed %d' % (len(after), len(sup_after & set(sup_before)), len(sup_before), base_after, len(base), len(doomed)))
    assert set(sup_before) <= sup_after and base_after == len(base)
    print('FOOD_DB_RESET_95_OK')

if __name__ == '__main__':
    main()
