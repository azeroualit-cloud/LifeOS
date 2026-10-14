"""Add independent savings target and observed forecast data to the two live Workers.
No financial rows are migrated or rewritten. Existing API two-argument callers
remain compatible. Credentials and downloaded source stay in temporary memory.
"""
import email.policy
from email.parser import BytesParser
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request

BASE = 'c8a655fa87f37e27655ecbdf8e452703a871dac7709c1343586e5affeb4e8387'
MARKER = '// LifeOS independent savings target v1'

def once(source, old, new):
    if source.count(old) != 1: raise RuntimeError('Confine della patch inatteso: aggiornamento interrotto.')
    return source.replace(old, new, 1)

def transform(source):
    if MARKER in source: return planning_patch(source)
    if hashlib.sha256(source.encode()).hexdigest() != BASE:
        raise RuntimeError('Worker cambiato: necessario confronto prima della distribuzione.')
    # The setting lives in the same existing source_rows table as the legacy
    # Budget config, in a new sheet; no collision with workbook row numbers.
    source = once(source, '  if (lightweight) return result;', '''  const nativeSettings = c.results.find(r => r.sheet === "LifeOS Settings" && r.row_number === 1);
  const savingsTarget = nativeSettings ? JSON.parse(nativeSettings.values_json)[0] : null;
  if (Number.isFinite(savingsTarget) && savingsTarget > 0) result.planning.savingsTarget = savingsTarget;
  result.forecastHistory = forecastCashHistory(m.results, plan, nowDay());
  if (!lightweight) {
    const y=Number(nowDay().slice(0,4));
    const nextPlan=await getExtraPlan(env,y+1);
    const cycles=new Map([...plan.allocations,...nextPlan.allocations].map(a=>[a.cycle_id+":"+a.month,a]));
    result.forecastPlan={...plan,allocations:[...cycles.values()]};
  }
  if (lightweight) return result;''')
    source = once(source, '      await env.DB.batch(\n        [\n          [13, target],', '''      const statements = [
          [13, target],''')
    source = once(source, '''        }),
      );
      return true;
    }
''', '''        });
      if (args.length >= 3) {
        const savingsTarget = Number(args[2]);
        if (!Number.isFinite(savingsTarget) || savingsTarget <= 0 || savingsTarget > 1000000) throw Error("Obiettivo non valido.");
        statements.push(env.DB.prepare("INSERT INTO source_rows(sheet,row_number,values_json) VALUES ('LifeOS Settings',1,?) ON CONFLICT(sheet,row_number) DO UPDATE SET values_json=excluded.values_json").bind(JSON.stringify([Math.round(savingsTarget*100)/100])));
      }
      await env.DB.batch(statements);
      return true;
    }
''')
    helper = '''
// LifeOS independent savings target v1
function forecastCashHistory(movements, plan, today) {
  const months = Array.from({length:6}, (_,i) => { const d=new Date(today.slice(0,7)+"-01T12:00:00Z"); d.setUTCMonth(d.getUTCMonth()-6+i); return d.toISOString().slice(0,7); });
  const linked = new Map();
  // Deduplicate linked amounts by movement, capped to its actual cash amount.
  for (const link of plan.links || []) if (link.role === 'payment') linked.set(Number(link.movement_source_row),(linked.get(Number(link.movement_source_row)) || 0)+Number(link.attributed_cents || 0)/100);
  return months.map(month => {
    const rows = movements.filter(r => r.account === 'Trade Republic' && r.status === 'Eseguito' && String(r.actual_date).slice(0,7) === month && String(r.actual_date).slice(0,10) < today);
    const net = rows.reduce((s,r) => s+Number(r.amount || 0),0);
    const extraPaid = rows.reduce((s,r) => s+(Number(r.amount)<0 ? Math.min(-Number(r.amount),linked.get(Number(r.source_row)) || 0) : 0),0);
    return {month,observed:rows.length>0,ordinaryNet:Math.round((net+extraPaid)*100)/100,extraPaid};
  });
}
'''
    source = helper + source
    # Web form: independently editable third field, old emergency/saving inputs
    # and old API callers remain supported.
    match = re.search(r'const APP_HTML = (".*");', source)
    html = json.loads(match[1])
    html = once(html, "          '\"></label></div>' +\n          '<div class=\"plan-row\"><span", "          '\"></label><label>Obiettivo patrimonio €<input id=\"target-input\" type=\"number\" min=\"0.01\" max=\"1000000\" step=\"0.01\" inputmode=\"decimal\" value=\"' +\n          (state.planningDraft?.target ?? p.savingsTarget ?? '') + '\"></label></div>' +\n          '<div class=\"plan-row\"><span")
    html = once(html, 'state.planningDraft = { goal: goal.value, saving: saving.value };', 'state.planningDraft = { goal: goal.value, saving: saving.value, target: document.getElementById("target-input")?.value ?? "" };')
    html = once(html, '            document.getElementById("saving-input").value,\n          ]);', '            document.getElementById("saving-input").value,\n            ...(document.getElementById("target-input").value ? [document.getElementById("target-input").value] : []),\n          ]);')
    html = once(html, '            document.getElementById("saving-input"),\n          ];', '            document.getElementById("saving-input"),\n            document.getElementById("target-input"),\n          ];')
    html = once(html, '              updateProjection();\n              const status', '              if (args.length > 2) state.data.planning.savingsTarget = Number(args[2]);\n              updateProjection();\n              const status')
    html = html.replace('e.target.id === "goal-input" || e.target.id === "saving-input"', 'e.target.id === "goal-input" || e.target.id === "saving-input" || e.target.id === "target-input"')
    source = source[:match.start(1)] + json.dumps(html, ensure_ascii=False) + source[match.end(1):]
    return planning_patch(source)

def planning_patch(source):
    if '// LifeOS lightweight planning v2' in source: return source
    old = '  const nativeSettings = c.results.find(r => r.sheet === "LifeOS Settings" && r.row_number === 1);\n  const savingsTarget = nativeSettings ? JSON.parse(nativeSettings.values_json)[0] : null;\n  if (Number.isFinite(savingsTarget) && savingsTarget > 0) result.planning.savingsTarget = savingsTarget;'
    source = once(source, old, '  attachSavingsPlanning(result, c.results, nowDay());')
    helper = r'''// LifeOS lightweight planning v2
function attachSavingsPlanning(result, config, day) {
  const cell = row => {
    const record = config.find(r => r.sheet === "Budget" && Number(r.row_number) === row);
    return record ? JSON.parse(record.values_json)[14] : null;
  };
  const rawGoal = cell(13), saving = Number(cell(14));
  result.planning ||= {
    year: Number(day.slice(0,4)),
    goal: rawGoal === null || rawGoal === "" || rawGoal === undefined ? null : Number(rawGoal),
    monthlySaving: Number.isFinite(saving) ? Math.max(0,saving) : 0,
    now: result.summary.budget,
  };
  const setting = config.find(r => r.sheet === "LifeOS Settings" && Number(r.row_number) === 1);
  const target = setting ? JSON.parse(setting.values_json)[0] : null;
  if (Number.isFinite(target) && target > 0) result.planning.savingsTarget = target;
  return result;
}
'''
    return once(source, 'function forecastCashHistory(', helper + 'function forecastCashHistory(')

def check(source):
    with tempfile.TemporaryDirectory() as folder:
        p = Path(folder)/'worker.mjs';p.write_text(source)
        subprocess.run(['node','--check',str(p)],check=True,capture_output=True)
        html = json.loads(re.search(r'const APP_HTML = (".*");',source)[1])
        for i, script in enumerate(re.findall(r'<script[^>]*>(.*?)</script>',html,re.S)):
            p = Path(folder)/f'ui-{i}.js';p.write_text(script)
            subprocess.run(['node','--check',str(p)],check=True,capture_output=True)

def modules(payload, headers):
    kind=headers.get('Content-Type','')
    entry=headers.get('cf-entrypoint') or headers.get('cf-entrypoint-name')
    if kind.startswith('multipart/'):
        message=BytesParser(policy=email.policy.default).parsebytes(('Content-Type: '+kind+'\r\nMIME-Version: 1.0\r\n\r\n').encode()+payload)
        parts=[]
        for part in message.iter_parts():
            name=part.get_filename() or part.get_param('name',header='Content-Disposition')
            if name=='metadata':entry=entry or json.loads(part.get_payload(decode=True)).get('main_module');continue
            parts.append((name,part.get_content_type(),part.get_payload(decode=True)))
        if entry is None and len(parts)==1:entry=parts[0][0]
    else:entry=entry or 'worker.js';parts=[(entry,'application/javascript+module',payload)]
    if not entry or not any(n==entry for n,_,_ in parts):raise RuntimeError('Entrypoint sconosciuto.')
    financial=[d for _,_,d in parts if b'async function loadFinance(' in d]
    if len(financial)!=1 or not all(x in financial[0] for x in [b'APP_PASSWORD',b'ACCESS_EMAIL',b'/auth/login',b'validSession']):raise RuntimeError('Contratto autenticazione inatteso.')
    main=next(d for n,_,d in parts if n==entry)
    if main!=financial[0] and not all(x in main for x in [b"import app from './original-worker.js'",b'await app.fetch(request, env, ctx)',b'X-LifeOS-Data-Source']):raise RuntimeError('Gateway inatteso.')
    return entry,parts

def main():
    spec=importlib.util.spec_from_file_location('setup',Path(__file__).with_name('provision-lifeos-test.py'))
    p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
    def api(path, method='GET', data=None, content_type=None):
        if method != 'GET' and path not in [f'/workers/scripts/{p.SOURCE_WORKER}',f'/workers/scripts/{p.TARGET}']:
            raise RuntimeError('Scrittura fuori ambito.')
        req=urllib.request.Request(p.API+path,data=data,method=method,headers={'Authorization':'Bearer '+os.environ['CLOUDFLARE_API_TOKEN'], **({'Content-Type':content_type} if content_type else {})})
        try:
            with urllib.request.urlopen(req,timeout=90) as response:
                body=response.read()
                if 'json' in response.headers.get('Content-Type',''):
                    parsed=json.loads(body)
                    if not parsed.get('success'):raise RuntimeError('Cloudflare ha rifiutato la richiesta.')
                    return parsed.get('result')
                return body,response.headers
        except Exception as error:
            raise RuntimeError('Operazione Cloudflare non riuscita: '+type(error).__name__) from None
    prepared=[]
    for worker in [p.TARGET,p.SOURCE_WORKER]:
        settings=api(f'/workers/scripts/{worker}/settings')
        if next(x for x in settings['bindings'] if x['name']=='DB').get('id') != p.SOURCE_DB:raise RuntimeError('Binding DB inatteso.')
        entry,parts=modules(*api(f'/workers/scripts/{worker}/content/v2'))
        originals=parts
        changed=[]
        for name,kind,data in parts:
            text=data.decode()
            if 'async function loadFinance(' in text:
                text=transform(text);check(text)
            changed.append((name,kind,text.encode()))
        if not any(MARKER.encode() in data for _,_,data in changed):raise RuntimeError('Modulo finanziario assente.')
        prepared.append((worker,settings,entry,originals,changed))
    def upload(item,parts):
        worker,settings,entry,_,_=item
        metadata={k:settings[k] for k in ['compatibility_date','compatibility_flags','observability','limits','placement'] if k in settings}
        metadata.update(main_module=entry,bindings=[x for x in settings['bindings'] if x['type']!='secret_text'],keep_bindings=['secret_text'])
        body,kind=p.multipart([('metadata','application/json',json.dumps(metadata).encode()),*parts])
        api(f'/workers/scripts/{worker}','PUT',body,kind)
    deployed=[]
    try:
        for item in prepared:
            if item[3]!=item[4]:upload(item,item[4]);deployed.append(item)
        # Verify deployed bytes, without modifying any user's financial settings.
        for item in prepared:
            _,parts=modules(*api(f'/workers/scripts/{item[0]}/content/v2'))
            if sorted((n,hashlib.sha256(d).hexdigest()) for n,_,d in parts) != sorted((n,hashlib.sha256(d).hexdigest()) for n,_,d in item[4]):raise RuntimeError('Verifica sorgenti distribuiti fallita.')
        print('WORKERS_FINANCE_V1_VERIFICATI; impostazioni e movimenti reali non modificati.')
    except Exception:
        for item in reversed(deployed):upload(item,item[3])
        raise

if __name__=='__main__':main()
