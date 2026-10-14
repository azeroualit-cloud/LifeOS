"""Authorized cutover to the production D1, preserving app changes with guarded SQL."""
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sqlite3
import tempfile
import time
import urllib.error
import urllib.request


def module(name, filename):
    spec=importlib.util.spec_from_file_location(name,Path(__file__).with_name(filename))
    value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value

p=module('setup','provision-lifeos-test.py')
d=module('diagnose','diagnose-lifeos.py')
m=module('merge','shared-merge.py')
BACKUP='lifeos-before-shared-v1'
URL=f'https://{p.TARGET}.a-zeroual-it.workers.dev'


def upload(database, password, original, maintenance=False):
    source_settings=p.api(f'/workers/scripts/{p.SOURCE_WORKER}/settings')
    binding=next(x for x in source_settings['bindings'] if x['name']=='DB')
    p.require(binding.get('id')==p.SOURCE_DB,'Binding principale inatteso.')
    mode='maintenance' if maintenance else 'shared'
    code='''import app from './original-worker.js';
export default { async fetch(request, env, ctx) {
  if (MODE === 'maintenance' && new URL(request.url).pathname.startsWith('/api/'))
    return new Response('Aggiornamento in corso. I movimenti locali restano conservati.', {status:503,headers:{'Cache-Control':'no-store','Retry-After':'30'}});
  const response=await app.fetch(request, env, ctx);
  const headers=new Headers(response.headers);
  headers.set('X-LifeOS-Data-Source', MODE === 'shared' ? 'shared' : 'maintenance');
  return new Response(response.body,{status:response.status,statusText:response.statusText,headers});
}};
'''.replace('MODE',json.dumps(mode))
    metadata={'main_module':'native-gateway.js','compatibility_date':source_settings['compatibility_date'],
              'compatibility_flags':source_settings.get('compatibility_flags',[]),
              'bindings':[{'type':'d1','name':'DB','id':database},
                          {'type':'secret_text','name':'APP_PASSWORD','text':password},
                          {'type':'plain_text','name':'NATIVE_TEST_SOURCE','text':p.SOURCE_DB},
                          {'type':'plain_text','name':'NATIVE_DATA_MODE','text':mode}],
              'observability':{'enabled':False}}
    body,kind=p.multipart([('metadata','application/json',json.dumps(metadata).encode()),('native-gateway.js','application/javascript+module',code.encode()),('original-worker.js','application/javascript+module',original)])
    p.api(f'/workers/scripts/{p.TARGET}','PUT',raw=body,content_type=kind)


def main():
    password=os.environ['LIFEOS_TEST_PASSWORD']
    p.require(len(password)>=24,'Password non valida.')
    settings=p.api(f'/workers/scripts/{p.TARGET}/settings')
    native_db=next(x['id'] for x in settings['bindings'] if x['name']=='DB')
    listing=p.api('/d1/database?per_page=100')
    clone=next(x for x in listing if x['name']==p.TARGET)
    _,parts=p.downloaded_modules(*p.api(f'/workers/scripts/{p.SOURCE_WORKER}/content/v2'))
    p.require(len(parts)==1,'Worker principale con moduli aggiuntivi da verificare.')
    original=parts[0][2]
    p.require(hashlib.sha256(original).hexdigest()=='c8a655fa87f37e27655ecbdf8e452703a871dac7709c1343586e5affeb4e8387','Il codice principale è cambiato: revisione necessaria.')
    if native_db==p.SOURCE_DB:
        upload(p.SOURCE_DB,password,original)
        p.verify(URL,password)
        print('DATI_CONDIVISI_VERIFICATI (configurazione già attiva)',flush=True)
        return
    p.require(native_db==clone['uuid'],'Il server app non usa la copia attesa.')
    locked=False
    try:
        upload(clone['uuid'],password,original,maintenance=True);locked=True
        for attempt in range(15):
            try:
                urllib.request.urlopen(p.public_request(URL,'/api/getLifeData',[]),timeout=45)
            except urllib.error.HTTPError as error:
                if error.code==503: break
                p.require(error.code in [401,403,502,504],'Esito inatteso della pausa temporanea.')
            if attempt==14: raise p.SetupError('Pausa temporanea non propagata: riprova più tardi.')
            time.sleep(2)
        with tempfile.TemporaryDirectory(prefix='lifeos-shared-') as directory:
            folder=Path(directory)
            primary=d.export(folder,p.SOURCE_DB,'liquidita-4-prova')
            copy=d.export(folder,clone['uuid'],p.TARGET)
            provenance=copy.execute(f'SELECT source_id,copied_at FROM {p.quoted(p.MARKER)}').fetchone()
            p.require(provenance['source_id']==p.SOURCE_DB,'Provenienza copia non valida.')
            sql,counts=m.plan_merge(primary,copy,provenance['copied_at'])
            # Simulate the entire merge, including foreign keys, before touching production.
            simulated=sqlite3.connect(':memory:');primary.backup(simulated)
            simulated.executescript('BEGIN;'+sql+'COMMIT;')
            p.require(not simulated.execute('PRAGMA foreign_key_check').fetchall(),'Riferimenti non validi nella simulazione.')
            print('MERGE_SIMULATO',json.dumps(counts,sort_keys=True),flush=True)
            backup=next((x for x in listing if x['name']==BACKUP),None)
            if backup is None:
                p.require(len(listing)<10,'Nessuno spazio nel piano gratuito per il backup.')
                backup=p.api('/d1/database','POST',{'name':BACKUP,'primary_location_hint':'eeur'})
                config={'name':'lifeos-shared-setup','account_id':p.ACCOUNT,'compatibility_date':'2026-10-01','d1_databases':[{'binding':'BACKUP','database_name':BACKUP,'database_id':backup['uuid']}]}
                (folder/'wrangler.json').write_text(json.dumps(config))
                p.wrangler(folder,'d1','execute','BACKUP','--remote','--file',str(folder/(p.SOURCE_DB+'.sql')),'--yes')
                print('Backup separato del principale creato nello stesso account.',flush=True)
            (folder/'merge.sql').write_text(sql)
            config={'name':'lifeos-shared-setup','account_id':p.ACCOUNT,'compatibility_date':'2026-10-01','d1_databases':[{'binding':'SHARED','database_name':'liquidita-4-prova','database_id':p.SOURCE_DB}]}
            (folder/'wrangler.json').write_text(json.dumps(config))
            p.wrangler(folder,'d1','execute','SHARED','--remote','--file',str(folder/'merge.sql'),'--yes')
            print('Modifiche app riconciliate nel principale con precondizioni sulle righe.',flush=True)
            upload(p.SOURCE_DB,password,original);locked=False
        p.verify(URL,password)
        primary_settings=p.api(f'/workers/scripts/{p.SOURCE_WORKER}/settings')
        app_settings=p.api(f'/workers/scripts/{p.TARGET}/settings')
        a=next(x['id'] for x in primary_settings['bindings'] if x['name']=='DB')
        b=next(x['id'] for x in app_settings['bindings'] if x['name']=='DB')
        p.require(a==b==p.SOURCE_DB,'Le due applicazioni non condividono lo stesso D1.')
        print('DATI_CONDIVISI_VERIFICATI: sito e app puntano allo stesso D1 principale.',flush=True)
        with open(os.environ['GITHUB_STEP_SUMMARY'],'a') as report:
            report.write('## Fonte dati unica attiva\n\nWeb e app usano `liquidita-4-prova`. Codice e accesso Cloudflare del sito invariati. Modifiche app riconciliate; copie precedenti conservate come archivi, non come sorgenti attive.\n')
    finally:
        if locked:
            # Restore the original clone binding if cutover did not complete.
            # Use its previous standalone code rather than the shared wrapper.
            metadata={'main_module':'original-worker.js','compatibility_date':'2026-10-01','bindings':[{'type':'d1','name':'DB','id':clone['uuid']},{'type':'secret_text','name':'APP_PASSWORD','text':password},{'type':'plain_text','name':'NATIVE_TEST_SOURCE','text':p.SOURCE_DB}]}
            body,kind=p.multipart([('metadata','application/json',json.dumps(metadata).encode()),('original-worker.js','application/javascript+module',original)])
            p.api(f'/workers/scripts/{p.TARGET}','PUT',raw=body,content_type=kind)
            print('Collegamento precedente ripristinato dopo interruzione.',flush=True)


if __name__=='__main__':
    try:main()
    except (p.SetupError,m.MergeConflict) as e:
        print('::error::'+str(e));raise SystemExit(1)
    except Exception as e:
        print('::error::Unificazione interrotta ('+type(e).__name__+'); dettagli privati non pubblicati.');raise SystemExit(1)
