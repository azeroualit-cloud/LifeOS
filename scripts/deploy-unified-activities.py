"""Prepare a small patch against the active live module; never log source or credentials."""
from pathlib import Path
import importlib.util,re,posixpath,os,json,urllib.request,subprocess,tempfile,hashlib
spec=importlib.util.spec_from_file_location('deployment_helpers',Path(__file__).with_name('deploy-lifeos-61.py'))
helpers=importlib.util.module_from_spec(spec);spec.loader.exec_module(helpers)
module=Path('backend/activities/activities.mjs').read_text().replace('export async function','async function')

def active_module(entry,parts):
    sources={name:data.decode() for name,kind,data in parts if 'javascript' in kind or name.endswith(('.js','.mjs'))}
    distances={entry:0};queue=[entry]
    while queue:
        name=queue.pop(0)
        for target in re.findall(r'(?:from\s*|import\s*)[\'\"]([^\'\"]+)[\'\"]',sources.get(name,'')):
            resolved=posixpath.normpath(posixpath.join(posixpath.dirname(name),target)) if target.startswith('.') else target
            if resolved in sources and resolved not in distances:distances[resolved]=distances[name]+1;queue.append(resolved)
    candidates=[name for name in distances if 'async function lifeAction(' in sources.get(name,'') and all(field in sources[name] for field in ['scheduled_time','section_status','activityEvents'])]
    if not candidates:raise RuntimeError('Implementazione attività attiva non riconosciuta; nessuna scrittura.')
    closest=min(distances[name] for name in candidates)
    candidates=[name for name in candidates if distances[name]==closest]
    if len(candidates)!=1:raise RuntimeError('Implementazione attività ambigua; nessuna scrittura.')
    return candidates[0]

def transform(source):
    expected='// LIFEOS_UNIFIED_ACTIVITIES_68\n'+module+'\n'
    if '// LIFEOS_UNIFIED_ACTIVITIES_68' in source:
        if not source.startswith(expected):raise RuntimeError('Versione attività diversa; nessuna scrittura.')
        return source
    substitutions=[
      (r'if \(method === "getLifeData"\) return lifeRead\(env, x\);','if (method === "getLifeData") return enrichActivities(env.DB, await lifeRead(env, x));'),
      (r'(await ensureLife\(env\);\s*)(if \(method === "setRoutineCheck"\))',r'\1if (method === "saveActivity") return saveActivity(env.DB, x);\n  \2'),
      (r'("saveTask",\s*"setEventOccurrence")','"saveActivity",\n      \\1'),
    ]
    for pattern,replacement in substitutions:
        source,count=re.subn(pattern,replacement,source)
        if count!=1:raise RuntimeError('Contesto attività inatteso; nessuna scrittura.')
    start=source.index('async function lifeAction(')
    following=re.search(r'\n(?:async )?function \w+\(',source[start+1:])
    if following is None:raise RuntimeError('Confine attività non riconosciuto; nessuna scrittura.')
    end=start+1+following.start()
    body=source[start:end]
    body,count=re.subn(r'\.slice\(0,\s*140\)', '.slice(0, 160)',body)
    if count!=2:raise RuntimeError('Limiti eventi inattesi; nessuna scrittura.')
    category_pattern=r'(env\.DB\.prepare\(\s*"UPDATE os_tasks SET list_kind=\? WHERE list_kind=\?"\s*\)\.bind\(destination,\s*key\),)'
    category_sql="UPDATE os_activity_identity SET metadata=json_set(metadata,'$.list_kind',?) WHERE json_extract(metadata,'$.list_kind')=?"
    body,count=re.subn(category_pattern,lambda match:match[0]+'\n      env.DB.prepare('+json.dumps(category_sql)+').bind(destination, key),',body)
    if count!=1:raise RuntimeError('Spostamento categoria non riconosciuto; nessuna scrittura.')
    a=body.index('  if (method === "splitEventSeries") {');b=body.index('  if (method === "deleteEvent") {',a)
    split=body[a:b]
    split,count=re.subn(r'await env\.DB\.batch\(\[', 'const activity = await splitActivityFields(env.DB, x);\n    await env.DB.batch([',split,count=1)
    if count!=1:raise RuntimeError('Transazione serie non riconosciuta; nessuna scrittura.')
    identity_sql="INSERT INTO os_activity_identity(uid,kind,source_id,metadata) VALUES (?,'event',last_insert_rowid(),?)"
    split,count=re.subn(r'(\)\.bind\(frequency,\s*until\))(\s*\]\);)',lambda match:match[1]+',\n      env.DB.prepare('+json.dumps(identity_sql)+').bind(activity.uid, activity.metadata)'+match[2],split)
    if count!=1:raise RuntimeError('Identità nuova serie non riconosciuta; nessuna scrittura.')
    body=body[:a]+split+body[b:]
    body=body.replace('  await ensureLife(env);','  await ensureLife(env);\n  if (["splitEventSeries", "deleteCategory"].includes(method)) await activitySchema(env.DB);',1)
    source=source[:start]+body+source[end:]
    return expected+source

def main(post_verification=None, label="ACTIVITIES_68_DEPLOYED_AND_VERIFIED"):
    token=os.environ.get('CLOUDFLARE_API_TOKEN','')
    if not token:raise RuntimeError('Credenziale Cloudflare non disponibile.')
    def api(path,method='GET',data=None,kind=None):
        req=urllib.request.Request('https://api.cloudflare.com/client/v4/accounts/'+helpers.ACCOUNT+path,data=data,method=method,headers={'Authorization':'Bearer '+token,**({'Content-Type':kind} if kind else {})})
        try:
            with urllib.request.urlopen(req,timeout=90) as response:
                raw=response.read()
                if 'json' in response.headers.get('Content-Type',''):
                    result=json.loads(raw)
                    if not result.get('success'):raise RuntimeError('Richiesta rifiutata.')
                    return result.get('result')
                return raw,response.headers
        except Exception as error:raise RuntimeError('Cloudflare: '+type(error).__name__) from None
    prepared=[]
    for name in helpers.WORKERS:
        settings=api('/workers/scripts/'+name+'/settings')
        if next((b.get('id') for b in settings['bindings'] if b.get('name')=='DB'),None)!=helpers.DATABASE:raise RuntimeError('Database inatteso; nessuna scrittura.')
        entry,original=helpers.modules(*api('/workers/scripts/'+name+'/content/v2'))
        target=active_module(entry,original)
        changed=[]
        for filename,kind,data in original:
            if filename==target:
                data=transform(data.decode()).encode()
                with tempfile.TemporaryDirectory() as folder:
                    path=Path(folder)/'worker.mjs';path.write_bytes(data)
                    subprocess.run(['node','--check',str(path)],check=True,capture_output=True)
            changed.append((filename,kind,data))
        prepared.append((name,settings,entry,original,changed))
    if os.environ.get('LIFEOS_BACKEND_AUDIT_ONLY')=='1':
        print('LIVE_ACTIVITY_CONTEXT_VERIFIED; no source, records or credentials logged; no writes.')
        return
    def upload(item,parts):
        name,settings,entry,_,_=item
        metadata={k:settings[k] for k in ['compatibility_date','compatibility_flags','observability','limits','placement'] if k in settings}
        metadata.update(main_module=entry,bindings=[b for b in settings['bindings'] if b['type']!='secret_text'],keep_bindings=['secret_text'])
        raw,kind=helpers.multipart([('metadata','application/json',json.dumps(metadata).encode()),*parts])
        api('/workers/scripts/'+name,'PUT',raw,kind)
    changed_workers=[]
    try:
        for item in prepared:
            if item[3]!=item[4]:changed_workers.append(item);upload(item,item[4])
        signature=lambda parts:sorted((n,hashlib.sha256(d).hexdigest()) for n,_,d in parts)
        for item in prepared:
            _,actual=helpers.modules(*api('/workers/scripts/'+item[0]+'/content/v2'))
            if signature(actual)!=signature(item[4]):raise RuntimeError('Verifica upload fallita.')
        if post_verification is not None: post_verification()
        print(label + '; unrelated modules, auth and bindings preserved.')
    except Exception:
        for item in reversed(changed_workers):upload(item,item[3])
        raise

if __name__=='__main__':main()
