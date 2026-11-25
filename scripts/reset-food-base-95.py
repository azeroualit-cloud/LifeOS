"""FOOD-DB-RESET-2026-11-25 (user request: «facciamo che il DB lo rifacciamo da zero», «mantieni tutti i
miei integratori aggiunti da me»). One run:
  1. backup tables web_foods_backup_20261125 / web_foods_app_backup_20261125 (created once, never overwritten);
  2. removes every food except family = supplement (the deletion trigger leaves tombstones, so phones remove them);
  3. imports the curated base (native-next/Resources/base-foods.json) through the app gateway.
Logs only counts. Idempotent: a second run finds the base already there and only re-imports it.
"""
import os, json, time, urllib.request, http.cookiejar
from pathlib import Path

ACCOUNT = '1728c3b1b852eb6285646842db7256de'; DATABASE = 'a90a8c6d-d6eb-4dc6-8fdb-382e4ad4485a'
ORIGIN = 'https://lifeos-native-test.a-zeroual-it.workers.dev'
SUFFIX = '20261125'

def d1(sql, params=None):
    body = {'sql': sql}
    if params: body['params'] = params
    r = urllib.request.Request('https://api.cloudflare.com/client/v4/accounts/' + ACCOUNT + '/d1/database/' + DATABASE + '/query',
        data=json.dumps(body).encode(), headers={'Authorization': 'Bearer ' + os.environ['CLOUDFLARE_API_TOKEN'].strip(), 'Content-Type': 'application/json'}, method='POST')
    with urllib.request.urlopen(r, timeout=90) as resp:
        data = json.loads(resp.read())
    if not data.get('success'): raise RuntimeError('D1 query failed')
    return data['result'][0]['results']

client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
def api(method, args):
    r = urllib.request.Request(ORIGIN + '/api/' + method, data=json.dumps(args).encode(), method='POST',
        headers={'Origin': ORIGIN, 'Content-Type': 'application/json', 'User-Agent': 'LifeOS-Food-Reset/1.0'})
    with client.open(r, timeout=120) as resp: return json.loads(resp.read())

def count(where=''):
    return d1('SELECT family = \'supplement\' AS sup, COUNT(*) AS n FROM web_foods ' + where + ' GROUP BY 1')

def main():
    base = json.loads(Path('native-next/Resources/base-foods.json').read_text(encoding='utf-8'))
    assert base and all(f['id'].startswith('base-') and f['family'] != 'supplement' for f in base)
    req = urllib.request.Request(ORIGIN + '/auth/login', data=json.dumps({'user': 'nas', 'password': os.environ['LIFEOS_TEST_PASSWORD']}).encode(), method='POST',
        headers={'Origin': ORIGIN, 'Content-Type': 'application/json', 'User-Agent': 'LifeOS-Food-Reset/1.0'})
    with client.open(req, timeout=90) as resp: resp.read()
    api('listFoodChanges', [None])  # makes sure tables, index and deletion trigger exist
    triggers = [r['name'] for r in d1("SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'web_foods_%'")]
    assert 'web_foods_tombstone' in triggers, 'deletion trigger missing'
    print('BEFORE', json.dumps(count()))
    tables = {r['name'] for r in d1("SELECT name FROM sqlite_master WHERE type='table'")}
    for src in ['web_foods', 'web_foods_app']:
        dst = src + '_backup_' + SUFFIX
        if dst not in tables:
            d1('CREATE TABLE ' + dst + ' AS SELECT * FROM ' + src)
        print('BACKUP', dst, d1('SELECT COUNT(*) AS n FROM ' + dst)[0]['n'])
    if d1('SELECT COUNT(*) AS n FROM web_foods_backup_' + SUFFIX)[0]['n'] < d1("SELECT COUNT(*) AS n FROM web_foods WHERE id NOT LIKE 'base-%'")[0]['n']:
        raise SystemExit('Backup smaller than the current list: nothing deleted.')
    d1("DELETE FROM web_foods WHERE family <> 'supplement' AND id NOT LIKE 'base-%'")
    d1('DELETE FROM web_foods_app WHERE id NOT IN (SELECT id FROM web_foods)')
    for i in range(0, len(base), 100):
        api('importFoods', [base[i:i + 100]]); time.sleep(0.5)
    after = count()
    print('AFTER', json.dumps(after))
    sup_before = next((r['n'] for r in d1('SELECT family = \'supplement\' AS sup, COUNT(*) AS n FROM web_foods_backup_' + SUFFIX + ' GROUP BY 1') if r['sup'] == 1), 0)
    sup_after = next((r['n'] for r in after if r['sup'] == 1), 0)
    base_now = d1("SELECT COUNT(*) AS n FROM web_foods WHERE id LIKE 'base-%'")[0]['n']
    print('SUPPLEMENTS kept %d of %d; BASE %d of %d; TOMBSTONES %d' % (sup_after, sup_before, base_now, len(base), d1('SELECT COUNT(*) AS n FROM web_food_tombstones')[0]['n']))
    assert sup_after >= sup_before and base_now == len(base)
    print('FOOD_DB_RESET_95_OK')

if __name__ == '__main__':
    main()
