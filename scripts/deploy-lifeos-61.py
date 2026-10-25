"""Apply reviewed, context-guarded Life OS changes while preserving live finance/auth.
Credentials and original modules remain in memory; logs never include private responses.
"""
import email.policy
from email.parser import BytesParser
import hashlib,json,os,subprocess,tempfile,urllib.request,uuid
from pathlib import Path

ACCOUNT='1728c3b1b852eb6285646842db7256de'
DATABASE='a90a8c6d-d6eb-4dc6-8fdb-382e4ad4485a'
WORKERS=['lifeos','lifeos-native-test']

def transform(source, patches):
    for index, patch in enumerate(patches):
        old,new=patch['before'],patch['after']
        if source.count(old)==1: source=source.replace(old,new,1)
        elif source.count(new)==1: continue
        else: raise RuntimeError('Contesto backend diverso dal previsto: patch %d; nessuna sostituzione automatica.' % index)
    return source

def modules(payload,headers):
    content_type=headers.get('Content-Type','')
    entry=headers.get('cf-entrypoint') or headers.get('cf-entrypoint-name')
    if content_type.startswith('multipart/'):
        parsed=BytesParser(policy=email.policy.default).parsebytes(('Content-Type: '+content_type+'\r\nMIME-Version: 1.0\r\n\r\n').encode()+payload)
        parts=[]
        for part in parsed.iter_parts():
            name=part.get_filename() or part.get_param('name',header='Content-Disposition')
            data=part.get_payload(decode=True)
            if name=='metadata': entry=entry or json.loads(data).get('main_module')
            else: parts.append((name,part.get_content_type(),data))
        if entry is None and len(parts)==1:entry=parts[0][0]
    else:
        entry=entry or 'worker.js';parts=[(entry,'application/javascript+module',payload)]
    if not entry or not any(n==entry for n,_,_ in parts):raise RuntimeError('Entrypoint non riconosciuto.')
    return entry,parts

def multipart(parts):
    boundary='lifeos-'+uuid.uuid4().hex;data=bytearray()
    for name,kind,content in parts:
        data.extend(('--'+boundary+'\r\nContent-Disposition: form-data; name="'+name+'"; filename="'+name+'"\r\nContent-Type: '+kind+'\r\n\r\n').encode());data.extend(content);data.extend(b'\r\n')
    data.extend(('--'+boundary+'--\r\n').encode())
    return bytes(data),'multipart/form-data; boundary='+boundary

def main():
    token=os.environ.get('CLOUDFLARE_API_TOKEN','')
    if not token:raise RuntimeError('CLOUDFLARE_API_TOKEN non disponibile nel workflow.')
    patches=json.loads(Path(__file__).with_name('lifeos-backend-61-patches.json').read_text())
    def api(path, method='GET', data=None, kind=None):
        req=urllib.request.Request('https://api.cloudflare.com/client/v4/accounts/'+ACCOUNT+path,data=data,method=method,headers={'Authorization':'Bearer '+token,**({'Content-Type':kind} if kind else {})})
        try:
            with urllib.request.urlopen(req,timeout=90) as response:
                raw=response.read()
                if 'json' in response.headers.get('Content-Type',''):
                    result=json.loads(raw)
                    if not result.get('success'):raise RuntimeError('Richiesta Cloudflare rifiutata.')
                    return result.get('result')
                return raw,response.headers
        except Exception as error:raise RuntimeError('Cloudflare: '+type(error).__name__) from None
    prepared=[]
    for name in WORKERS:
        settings=api('/workers/scripts/'+name+'/settings')
        db=next((x for x in settings['bindings'] if x.get('name')=='DB'),{})
        if db.get('id')!=DATABASE:raise RuntimeError('Binding database inatteso; distribuzione interrotta.')
        entry,original=modules(*api('/workers/scripts/'+name+'/content/v2'))
        changed=[];found=0
        for filename,kind,data in original:
            if b'async function lifeAction(' in data:
                found+=1;text=transform(data.decode(),patches)
                with tempfile.TemporaryDirectory() as folder:
                    path=Path(folder)/'worker.mjs';path.write_text(text)
                    subprocess.run(['node','--check',str(path)],check=True,capture_output=True)
                data=text.encode()
            changed.append((filename,kind,data))
        if found!=1:raise RuntimeError('Modulo Life OS non univoco.')
        prepared.append((name,settings,entry,original,changed))
    if os.environ.get("LIFEOS_BACKEND_AUDIT_ONLY") == "1":
        print("LIVE_BACKEND_CONTEXT_VERIFIED; no code or database writes.")
        return
    def upload(item,parts):
        name,settings,entry,_,_=item
        metadata={k:settings[k] for k in ['compatibility_date','compatibility_flags','observability','limits','placement'] if k in settings}
        metadata.update(main_module=entry,bindings=[b for b in settings['bindings'] if b['type']!='secret_text'],keep_bindings=['secret_text'])
        raw,kind=multipart([('metadata','application/json',json.dumps(metadata).encode()),*parts])
        api('/workers/scripts/'+name,'PUT',raw,kind)
    changed_workers=[]
    try:
        for item in prepared:
            if item[3]!=item[4]:upload(item,item[4]);changed_workers.append(item)
        for item in prepared:
            _,actual=modules(*api('/workers/scripts/'+item[0]+'/content/v2'))
            signature=lambda parts:sorted((n,hashlib.sha256(d).hexdigest()) for n,_,d in parts)
            if signature(actual)!=signature(item[4]):raise RuntimeError('Verifica del codice distribuito fallita.')
        print('BACKEND_61_DEPLOYED_AND_VERIFIED; auth, bindings and unrelated live code preserved.')
    except Exception:
        for item in reversed(changed_workers):upload(item,item[3])
        raise

if __name__=='__main__':
    try: main()
    except Exception as error:
        print('::error::'+str(error) if isinstance(error,RuntimeError) else '::error::Distribuzione interrotta ('+type(error).__name__+'); risposta privata omessa.')
        raise SystemExit(1)
