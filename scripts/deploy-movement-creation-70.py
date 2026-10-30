"""Add immutable insertion timestamps; preserve live modules, bindings and auth."""
from pathlib import Path
import importlib.util
import os,json,urllib.request,urllib.error,http.cookiejar,datetime,hashlib,re
from zoneinfo import ZoneInfo
spec = importlib.util.spec_from_file_location('activities68', Path(__file__).with_name('deploy-unified-activities.py'))
base = importlib.util.module_from_spec(spec); spec.loader.exec_module(base)
payload = Path('backend/movement-order/creation.mjs').read_text().replace('export async function ', 'async function ').replace('export function ', 'function ')
marker = '// LIFEOS_MOVEMENT_CREATION_70\n' + payload

def transform(source):
    if '// LIFEOS_MOVEMENT_CREATION_70' in source:
        if not source.endswith(marker): raise RuntimeError('Versione timestamp diversa; nessuna scrittura.')
        return source
    patches = [
      ('async function ensureTrStatement(env) {', 'async function ensureTrStatement(env) {\n  await ensureMovementCreation(env.DB);'),
      ('async function ensureBudgetPolicies(env) {', 'async function ensureBudgetPolicies(env) {\n  await ensureMovementCreation(env.DB);'),
      ('Math.max(1, sheet.getLastRow() - 1), 23).getValues()', 'Math.max(1, sheet.getLastRow() - 1), 24).getValues()'),
      ('        row: number_(row[19]),\n        date:', '        row: number_(row[19]),\n        created_at: row[23] || null,\n        date:'),
      ('  selectedTransactions.sort((a, b) => b.date.localeCompare(a.date));', '  sortMovementCreation(selectedTransactions);'),
      ('    r.financial_category_id\n  ];', '    r.financial_category_id,\n    r.insertion_created_at || null\n  ];'),
      ('"SELECT * FROM movements ORDER BY source_row"', '"SELECT m.*,mc.created_at insertion_created_at FROM movements m LEFT JOIN movement_creation_metadata mc ON mc.movement_source_row=m.source_row ORDER BY m.source_row"'),
      ('"SELECT m.*,c.detail_category resolved_category,c.category_id financial_category_id FROM movements m LEFT JOIN movement_financial_categories c ON c.movement_source_row=m.source_row ORDER BY m.source_row"', '"SELECT m.*,mc.created_at insertion_created_at,c.detail_category resolved_category,c.category_id financial_category_id FROM movements m LEFT JOIN movement_creation_metadata mc ON mc.movement_source_row=m.source_row LEFT JOIN movement_financial_categories c ON c.movement_source_row=m.source_row ORDER BY m.source_row"'),
    ]
    for index,(old,new) in enumerate(patches):
        if source.count(old) != 1: raise RuntimeError('Contesto inserimento movimenti diverso, patch '+str(index)+'; nessuna scrittura.')
        source = source.replace(old,new,1)
    return source + '\n' + marker

def metadata_query(sql):
    token = os.environ.get('CLOUDFLARE_API_TOKEN','')
    if not token: raise RuntimeError('Credenziale Cloudflare non disponibile.')
    request = urllib.request.Request('https://api.cloudflare.com/client/v4/accounts/'+base.helpers.ACCOUNT+'/d1/database/'+base.helpers.DATABASE+'/query',data=json.dumps({'sql':sql}).encode(),headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'},method='POST')
    try:
        with urllib.request.urlopen(request,timeout=45) as response: result=json.loads(response.read())
        if not result.get('success') or not result['result'][0].get('success'): raise ValueError('query')
        return result['result'][0]['results']
    except Exception as error: raise RuntimeError('Verifica metadati D1 fallita: '+type(error).__name__) from None

def canonical_trigger(sql):
    return ' '.join(re.sub(r'\bIF NOT EXISTS\s+', '', sql, flags=re.I).strip().rstrip(';').split())

def expected_triggers():
    statements=[json.loads(value) for value in re.findall(r'db\.prepare\(("CREATE TRIGGER[^\n]+")\)',payload)]
    return {re.search(r'TRIGGER IF NOT EXISTS (\w+)',sql)[1]:canonical_trigger(sql) for sql in statements}

def audit_triggers():
    rows=metadata_query("SELECT name,tbl_name,sql FROM sqlite_master WHERE type='trigger' AND name NOT IN ('lifeos_movement_created_v1','lifeos_movement_created_immutable_v1')")
    # The sidecar does not update movements and must preserve every legacy trigger.
    fingerprints={row['name']:hashlib.sha256((row.get('sql') or '').encode()).hexdigest() for row in rows}
    if any(row['tbl_name']=='movement_creation_metadata' for row in rows):
        raise RuntimeError('Trigger dei metadati preesistenti diversi; nessun codice distribuito.')
    owned=metadata_query("SELECT name,sql FROM sqlite_master WHERE type='trigger' AND name IN ('lifeos_movement_created_v1','lifeos_movement_created_immutable_v1')")
    expected=expected_triggers()
    if any(canonical_trigger(row.get('sql') or '') != expected.get(row['name']) for row in owned):
        raise RuntimeError('Trigger creazione preesistenti diversi; nessun codice distribuito.')
    columns=metadata_query('PRAGMA table_info(movement_creation_metadata)')
    if columns and ({row['name'] for row in columns}!={'movement_source_row','created_at'} or not any(row['name']=='created_at' and row['type'].upper()=='TEXT' for row in columns)):
        raise RuntimeError('Metadati creazione preesistenti diversi; nessun codice distribuito.')
    print('MOVEMENT_CREATION_METADATA_AUDIT_OK; legacy triggers preserved, no source or records logged.')
    return fingerprints

def verify_live_contract(original_triggers):
    origin='https://lifeos-native-test.a-zeroual-it.workers.dev'
    client=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    def post(path,payload):
        request=urllib.request.Request(origin+path,data=json.dumps(payload).encode(),method='POST',headers={'Origin':origin,'Content-Type':'application/json','User-Agent':'LifeOS-Native-Check/1.0'})
        with client.open(request,timeout=45) as response:return json.loads(response.read())
    stage='login'
    try:
        password=os.environ['LIFEOS_TEST_PASSWORD'];assert password
        # Login response is intentionally ignored: only session cookies are retained.
        request=urllib.request.Request(origin+'/auth/login',data=json.dumps({'user':'nas','password':password}).encode(),method='POST',headers={'Origin':origin,'Content-Type':'application/json','User-Agent':'LifeOS-Native-Check/1.0'})
        with client.open(request,timeout=45) as response: response.read()
        stage='finance-read'
        now=datetime.datetime.now(ZoneInfo('Europe/Rome'))
        finance=post('/api/getFinanceData',[now.year,now.month])
        assert isinstance(finance.get('transactions'),list)
        rows=finance['transactions']
        assert all('created_at' in row for row in rows)
        order=lambda row:(row.get('created_at') or '',int(row['row']))
        assert rows==sorted(rows,key=order,reverse=True)
        stage='schema'
        assert any(row['name']=='created_at' for row in metadata_query('PRAGMA table_info(movement_creation_metadata)'))
        assert audit_triggers()==original_triggers
        triggers=metadata_query("SELECT name FROM sqlite_master WHERE name IN ('lifeos_movement_created_v1','lifeos_movement_created_immutable_v1') AND type='trigger'")
        assert len(triggers)==2
        print('MOVEMENT_CREATION_LIVE_CONTRACT_OK; no records created, no financial values logged.')
    except Exception as error:
        raise RuntimeError('Contratto movimenti fallito: stage='+stage+' class='+type(error).__name__+' HTTP='+str(getattr(error,'code','n/a'))) from None

if __name__ == '__main__':
    base.transform=transform
    original_triggers=audit_triggers()
    base.main(post_verification=lambda:verify_live_contract(original_triggers),label='MOVEMENT_CREATION_70_DEPLOYED_AND_VERIFIED')
