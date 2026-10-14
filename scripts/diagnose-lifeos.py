"""Read-only database comparison and API timing; output contains no personal values."""
import datetime
import importlib.util
import json
import os
from pathlib import Path
import sqlite3
import tempfile
import time
import urllib.request
import http.cookiejar

spec = importlib.util.spec_from_file_location('setup', Path(__file__).with_name('provision-lifeos-test.py'))
p = importlib.util.module_from_spec(spec); spec.loader.exec_module(p)


def export(folder, identifier, name):
    config = {'name': 'lifeos-diagnostics', 'account_id': p.ACCOUNT, 'compatibility_date': '2026-10-01',
              'd1_databases': [{'binding': 'READONLY_SOURCE', 'database_name': name, 'database_id': identifier}]}
    (folder / 'wrangler.json').write_text(json.dumps(config))
    target = folder / (identifier + '.sql')
    p.wrangler(folder, 'd1', 'export', 'READONLY_SOURCE', '--remote', '--output', str(target))
    db = sqlite3.connect(':memory:'); db.row_factory = sqlite3.Row
    db.executescript(target.read_text())
    return db


def records(db, table):
    columns = db.execute(f'PRAGMA table_info({p.quoted(table)})').fetchall()
    keys = [x['name'] for x in sorted(columns, key=lambda x: x['pk']) if x['pk']]
    if not keys:
        keys = [x['name'] for x in columns]
    return {tuple(row[k] for k in keys): dict(row) for row in db.execute(f'SELECT * FROM {p.quoted(table)}')}


def main():
    listing = p.api('/d1/database?per_page=100')
    clone = next(x for x in listing if x['name'] == p.TARGET)
    with tempfile.TemporaryDirectory(prefix='lifeos-readonly-') as directory:
        folder = Path(directory)
        primary = export(folder, p.SOURCE_DB, 'liquidita-4-prova')
        copy = export(folder, clone['uuid'], p.TARGET)
        copied_at = datetime.datetime.fromisoformat(copy.execute(f'SELECT copied_at FROM {p.quoted(p.MARKER)}').fetchone()[0])
        def moment(value):
            parsed = datetime.datetime.fromisoformat(str(value).replace('Z', '+00:00'))
            return parsed.replace(tzinfo=datetime.timezone.utc) if parsed.tzinfo is None else parsed
        tables = [x[0] for x in primary.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%'")]
        for table in tables:
            a, b = records(primary, table), records(copy, table)
            added = b.keys() - a.keys(); removed = a.keys() - b.keys()
            changed = [k for k in a.keys() & b.keys() if a[k] != b[k]]
            if added or removed or changed:
                print(f'DIFF {table}: solo_copia={len(added)} solo_principale={len(removed)} diversi={len(changed)}', flush=True)
            for key in changed:
                fields = [field for field in a[key] if a[key][field] != b[key].get(field)]
                print('CHANGED_FIELDS', table, ','.join(fields), flush=True)
                if 'updated_at' in a[key]:
                    print('AFTER_SNAPSHOT', table, 'primary='+str(moment(a[key]['updated_at'])>copied_at), 'copy='+str(moment(b[key]['updated_at'])>copied_at), flush=True)
            if table == 'os_tasks':
                for key in removed:
                    row = a[key]
                    expired = row.get('status') == 'done' and row.get('completed_at') and moment(row['completed_at']) <= datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(days=5)
                    print('MISSING_TASK_EXPIRED', bool(expired), flush=True)
        print('CONFRONTO_COMPLETATO', flush=True)
    if os.environ.get('DIAGNOSTICS_COMPARE_ONLY') == 'true': return
    source = p.api(f'/workers/scripts/{p.SOURCE_WORKER}/content/v2')
    _, modules = p.downloaded_modules(*source)
    import hashlib
    for name, _, data in modules:
        print('WORKER_MODULO_SHA256', hashlib.sha256(data).hexdigest(), flush=True)
    url = f'https://{p.TARGET}.a-zeroual-it.workers.dev'
    jar = http.cookiejar.CookieJar(); client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    with client.open(p.public_request(url, '/auth/login', {'user':'nas','password':os.environ['LIFEOS_TEST_PASSWORD']}), timeout=45) as r:
        p.require(r.status == 200, 'Login non riuscito.')
    now = datetime.datetime.now(datetime.timezone.utc)
    for method, args in [('getLifeData',[now.strftime('%Y-%m')]), ('getFinanceData',[now.year,now.month]), ('getFinanceOverview',[now.year,now.month]), ('getExtraPlan',[now.year])]:
        for sample in range(2):
            start = time.monotonic()
            with client.open(p.public_request(url, '/api/'+method, args), timeout=90) as r:
                data = r.read(); value = json.loads(data)
            print(f'TIMING {method} sample={sample+1} seconds={time.monotonic()-start:.3f} bytes={len(data)}', flush=True)
            if method.startswith('getFinance'):
                print('FINANCE_KEYS', method, ','.join(sorted(value.keys())), flush=True)


if __name__ == '__main__':
    try: main()
    except Exception as e:
        print('::error::Diagnosi interrotta: ' + (str(e) if isinstance(e,p.SetupError) else type(e).__name__))
        raise SystemExit(1)
