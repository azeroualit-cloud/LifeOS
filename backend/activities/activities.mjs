// A stable identity spans the legacy task/calendar storage. Requests commit atomically.
export async function activitySchema(db) {
 await db.batch([
  db.prepare(`CREATE TABLE IF NOT EXISTS os_activity_identity(uid TEXT PRIMARY KEY,kind TEXT NOT NULL,source_id INTEGER NOT NULL,metadata TEXT NOT NULL,UNIQUE(kind,source_id))`),
  db.prepare(`CREATE TABLE IF NOT EXISTS os_activity_requests(id TEXT PRIMARY KEY,fingerprint TEXT NOT NULL,token TEXT NOT NULL)`),
 ]);
}
function checkDay(v) {if(v==null||v==='')return null;if(typeof v!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(v)||new Date(v+'T12:00:00Z').toISOString().slice(0,10)!==v)throw Error('Data non valida.');return v;}
function clock(v){if(v==null||v==='')return null;if(typeof v!=='string'||!/^([01]\d|2[0-3]):[0-5]\d$/.test(v))throw Error('Orario non valido.');return v;}
export async function saveActivity(db,input) {
 await activitySchema(db);
 const p={uid:String(input.uid||''),source:String(input.source||'task'),sourceId:Number(input.sourceId||0),title:String(input.title||'').trim(),notes:String(input.notes||''),day:checkDay(input.day),due_date:checkDay(input.due_date),list_kind:String(input.list_kind||'action'),location:String(input.location||''),start_time:clock(input.start_time),end_time:clock(input.end_time),scheduled_time:clock(input.scheduled_time),frequency:input.frequency||'none',until_day:checkDay(input.until_day),statusIntent:input.statusIntent===true,taskStatus:input.taskStatus||'todo'};
 const requestId=String(input.requestId||'');
 if(!/^[\w:-]{1,100}$/.test(p.uid)||!/^[-\w]{8,100}$/.test(requestId)||!['task','event'].includes(p.source)||!Number.isSafeInteger(p.sourceId)||p.sourceId<0||!p.title||p.title.length>140||p.notes.length>1000||p.location.length>160||!['none','weekly','monthly','yearly'].includes(p.frequency)||!['todo','waiting','done'].includes(p.taskStatus))throw Error('Attività non valida.');
 if(p.end_time&&!p.start_time||p.start_time&&p.end_time&&p.end_time<p.start_time||p.until_day&&p.day&&p.until_day<p.day||p.due_date&&p.day&&p.due_date<p.day)throw Error('Controlla inizio e fine.');
 if(!await db.prepare('SELECT key FROM os_categories WHERE key=?').bind(p.list_kind).first())throw Error('Categoria non trovata.');
 const signature=JSON.stringify(p), prior=await db.prepare('SELECT fingerprint FROM os_activity_requests WHERE id=?').bind(requestId).first();
 if(prior){if(prior.fingerprint!==signature)throw Error('Identificativo richiesta già usato.');return true;}
 let identity=await db.prepare('SELECT * FROM os_activity_identity WHERE uid=?').bind(p.uid).first();
 const source=identity?.kind??p.source,id=identity?.source_id??p.sourceId;
 const old=id?await db.prepare(`SELECT * FROM ${source==='task'?'os_tasks':'os_events'} WHERE id=?`).bind(id).first():null;
 if(id&&!old)throw Error('Attività non trovata.');
 const target=p.day?'event':'task',convert=old&&source!==target;
 // A recurrence with exceptions requires the existing explicit split-series flow.
 let eventDone=false;
 if(old&&source==='event'){
  const exceptions=await db.prepare('SELECT COUNT(*) AS n FROM os_event_occurrences WHERE event_id=?').bind(id).first();
  const repeat=await db.prepare('SELECT frequency FROM os_event_repeat WHERE event_id=?').bind(id).first();
  const occurrence=await db.prepare('SELECT status FROM os_event_occurrences WHERE event_id=? AND day=?').bind(id,old.day).first();
  eventDone=occurrence?.status==='done';
  if(exceptions.n&&((convert&&(repeat?.frequency??'none')!=='none')||(!convert&&(old.day!==p.day||(repeat?.frequency??'none')!==p.frequency))))throw Error('La serie ha uno storico: usa «Modifica da questa occorrenza» prima di cambiare la regola o rimuovere la data.');
 }
 const token=crypto.randomUUID(),gate='EXISTS(SELECT 1 FROM os_activity_requests WHERE id=? AND token=?)';
 let expected=identity?'EXISTS(SELECT 1 FROM os_activity_identity WHERE uid=? AND kind=? AND source_id=?)':'NOT EXISTS(SELECT 1 FROM os_activity_identity WHERE uid=?)';
 const expectedArgs=identity?[p.uid,identity.kind,identity.source_id]:[p.uid];
 if(old){expected+=` AND EXISTS(SELECT 1 FROM ${source==='task'?'os_tasks':'os_events'} WHERE id=?)`;expectedArgs.push(id);}
 const args=[requestId,token],steps=[db.prepare(`INSERT OR IGNORE INTO os_activity_requests(id,fingerprint,token) SELECT ?,?,? WHERE ${expected}`).bind(requestId,signature,token,...expectedArgs)];
 const previous=identity?JSON.parse(identity.metadata):{};
 const status=p.statusIntent?p.taskStatus:(old?.status??(eventDone||input.completed?'done':previous.task_status??'todo'));
 if(target==='task'){
  if(old&&!convert)steps.push(db.prepare(`UPDATE os_tasks SET title=?,notes=?,list_kind=?,due_date=?,scheduled_date=NULL,scheduled_time=?,status=?,completed_at=CASE WHEN ?='done' THEN COALESCE(completed_at,CURRENT_TIMESTAMP) ELSE NULL END,updated_at=CURRENT_TIMESTAMP WHERE id=? AND ${gate}`).bind(p.title,p.notes,p.list_kind,p.due_date,p.scheduled_time,status,status,id,...args));
  else steps.push(db.prepare(`INSERT INTO os_tasks(title,notes,list_kind,status,due_date,scheduled_date,scheduled_time,sort_order) SELECT ?,?,?,?,?,NULL,?,(SELECT COALESCE(MAX(sort_order),0)+1 FROM os_tasks) WHERE ${gate}`).bind(p.title,p.notes,p.list_kind,status,p.due_date,p.scheduled_time,...args));
 }else{
  if(old&&!convert)steps.push(db.prepare(`UPDATE os_events SET title=?,notes=?,day=?,start_time=?,end_time=?,location=?,updated_at=CURRENT_TIMESTAMP WHERE id=? AND ${gate}`).bind(p.title,p.notes,p.day,p.start_time,p.end_time,p.location,id,...args));
  else steps.push(db.prepare(`INSERT INTO os_events(title,notes,day,start_time,end_time,location) SELECT ?,?,?,?,?,? WHERE ${gate}`).bind(p.title,p.notes,p.day,p.start_time,p.end_time,p.location,...args));
 }
 const targetID=old&&!convert?id:null;
 steps.push(db.prepare(`INSERT INTO os_activity_identity(uid,kind,source_id,metadata) SELECT ?,?,${targetID?'?':'last_insert_rowid()'},? WHERE ${gate} ON CONFLICT(uid) DO UPDATE SET kind=excluded.kind,source_id=excluded.source_id,metadata=excluded.metadata`).bind(p.uid,target,...(targetID?[targetID]:[]),JSON.stringify({...p,task_status:status}),...args));
 if(target==='event'){
  steps.push(db.prepare(`INSERT INTO os_event_repeat(event_id,frequency,until_day) SELECT source_id,?,? FROM os_activity_identity WHERE uid=? AND ${gate} ON CONFLICT(event_id) DO UPDATE SET frequency=excluded.frequency,until_day=excluded.until_day`).bind(p.frequency,p.until_day,p.uid,...args));
  if((convert||!old||p.statusIntent)&&status==='done')steps.push(db.prepare(`INSERT OR REPLACE INTO os_event_occurrences(event_id,day,status) SELECT source_id,?,'done' FROM os_activity_identity WHERE uid=? AND ${gate}`).bind(p.day,p.uid,...args));
 }
 if(target==='event'&&p.statusIntent&&status!=='done')steps.push(db.prepare(`DELETE FROM os_event_occurrences WHERE event_id=(SELECT source_id FROM os_activity_identity WHERE uid=?) AND day=? AND ${gate}`).bind(p.uid,p.day,...args));
 if(convert){
  if(source==='event')steps.push(db.prepare(`DELETE FROM os_event_occurrences WHERE event_id=? AND ${gate}`).bind(id,...args));
  if(source==='event')steps.push(db.prepare(`DELETE FROM os_event_repeat WHERE event_id=? AND ${gate}`).bind(id,...args));
  steps.push(db.prepare(`DELETE FROM ${source==='task'?'os_tasks':'os_events'} WHERE id=? AND ${gate}`).bind(id,...args));
 }
 await db.batch(steps);
 const receipt=await db.prepare('SELECT fingerprint FROM os_activity_requests WHERE id=?').bind(requestId).first();
 if(receipt?.fingerprint!==signature)throw Error('Richiesta concorrente diversa.');
 return true;
}
export async function enrichActivities(db,life){
 await activitySchema(db);
 const identities=(await db.prepare('SELECT * FROM os_activity_identity').all()).results;
 const map=new Map(identities.map(r=>[r.kind+':'+r.source_id,r]));
 const enrich=(r,kind)=>{const m=map.get(kind+':'+r.id);return {...(m?JSON.parse(m.metadata):{}),...r,activity_uid:m?.uid??kind+':'+r.id,activity_source:kind};};
 return {...life, tasks:life.tasks.map(r=>enrich(r,'task')),events:life.events.map(r=>enrich(r,'event')),upcomingEvents:life.upcomingEvents.map(r=>enrich(r,'event')),activityEvents:(life.activityEvents??[]).map(r=>enrich(r,'event')),capabilities:{...life.capabilities,unifiedActivities:1}};
}
