"""Add immutable insertion timestamps; preserve live modules, bindings and auth."""
from pathlib import Path
import importlib.util
import os,json,urllib.request,urllib.error,http.cookiejar,datetime,re
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
      ('    r.financial_category_id\n  ];', '    r.financial_category_id,\n    r.created_at || null\n  ];'),
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

def audit_triggers():
    rows=metadata_query("SELECT name,sql FROM sqlite_master WHERE type='trigger' AND tbl_name='movements'")
    for row in rows:
        if row['name'] in ['lifeos_movement_created_v1','lifeos_movement_created_immutable_v1']: continue
        sql=row.get('sql') or ''
        # Timestamp stamping must never invoke an unreviewed generic update hook.
        if re.search(r'\bUPDATE\b',sql,re.I):
            raise RuntimeError('Trigger di aggiornamento movimenti da verificare; nessun codice distribuito.')
    columns=metadata_query('PRAGMA table_info(movements)')
    if any(row['name']=='created_at' and row['type'].upper()!='TEXT' for row in columns):
        raise RuntimeError('Tipo timestamp inatteso; nessun codice distribuito.')
    print('MOVEMENT_CREATION_METADATA_AUDIT_OK; no source or records logged.')

def verify_live_contract():
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
        assert any(row['name']=='created_at' for row in metadata_query('PRAGMA table_info(movements)'))
        triggers=metadata_query("SELECT name FROM sqlite_master WHERE name IN ('lifeos_movement_created_v1','lifeos_movement_created_immutable_v1') AND type='trigger'")
        assert len(triggers)==2
        print('MOVEMENT_CREATION_LIVE_CONTRACT_OK; no records created, no financial values logged.')
    except Exception as error:
        raise RuntimeError('Contratto movimenti fallito: stage='+stage+' class='+type(error).__name__+' HTTP='+str(getattr(error,'code','n/a'))) from None

if __name__ == '__main__':
    base.transform=transform
    audit_triggers()
    base.main(post_verification=verify_live_contract,label='MOVEMENT_CREATION_70_DEPLOYED_AND_VERIFIED')
