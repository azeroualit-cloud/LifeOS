import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {saveActivity,enrichActivities} from '../activities.mjs';
function fixture(){
 const sqlite=new DatabaseSync(':memory:');sqlite.exec(`CREATE TABLE os_categories(key TEXT PRIMARY KEY);INSERT INTO os_categories VALUES('action');
 CREATE TABLE os_tasks(id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT,notes TEXT,list_kind TEXT,status TEXT DEFAULT 'todo',due_date TEXT,scheduled_date TEXT,scheduled_time TEXT,sort_order INT,updated_at TEXT,completed_at TEXT);
 CREATE TABLE os_events(id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT,notes TEXT,day TEXT,start_time TEXT,end_time TEXT,location TEXT,updated_at TEXT);
 CREATE TABLE os_event_repeat(event_id INTEGER PRIMARY KEY,frequency TEXT,until_day TEXT);
 CREATE TABLE os_event_occurrences(event_id INTEGER,day TEXT,status TEXT,PRIMARY KEY(event_id,day));`);
 const db={prepare(sql){let args=[];return {sql,bind(...p){args=p;return this},async first(){return sqlite.prepare(sql).get(...args)??null},async all(){return {results:sqlite.prepare(sql).all(...args)}},async run(){const r=sqlite.prepare(sql).run(...args);return {meta:{changes:r.changes}}}}},async batch(statements){sqlite.exec('BEGIN');try{const r=[];for(const s of statements)r.push(await s.run());sqlite.exec('COMMIT');return r}catch(e){sqlite.exec('ROLLBACK');throw e}}};
 const p={uid:'activity-one',requestId:'request-one',source:'task',sourceId:0,title:'Unica attività',notes:'Descrizione conservata',list_kind:'action',day:null,due_date:'2026-11-15',location:'Casa',frequency:'weekly'};return {db,sqlite,p};
}
test('lost response retries create one item and changed replay is rejected',async()=>{const {db,sqlite,p}=fixture();await saveActivity(db,p);await saveActivity(db,p);assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM os_tasks').get().n,1);await assert.rejects(()=>saveActivity(db,{...p,title:'Different'}));await assert.rejects(()=>saveActivity(db,{...p,completed:true}));});
test('adding/removing dates preserves identity and fields, leaving one item',async()=>{
 const {db,sqlite,p}=fixture();await saveActivity(db,p);
 const task=sqlite.prepare('SELECT * FROM os_tasks').get();
 await saveActivity(db,{...p,requestId:'request-two',sourceId:task.id,day:'2026-11-01',start_time:'09:00',end_time:'10:00'});
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM os_tasks').get().n,0);
 const event=sqlite.prepare('SELECT * FROM os_events').get();assert.equal(event.notes,p.notes);assert.equal(event.start_time,'09:00');
 const snapshot=await enrichActivities(db,{tasks:[],events:[event],upcomingEvents:[event],activityEvents:[event]});assert.equal(snapshot.events[0].activity_uid,p.uid);assert.equal(snapshot.events[0].due_date,p.due_date);
 await saveActivity(db,{...p,requestId:'request-three',source:'event',sourceId:event.id});
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM os_events').get().n,0);
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM os_event_repeat').get().n,0);
 const identity=sqlite.prepare('SELECT * FROM os_activity_identity').get();assert.equal(identity.uid,p.uid);assert.equal(identity.kind,'task');
});
test('legacy events keep ID and recurrence exceptions on text edit; unsafe conversion rolls back',async()=>{
 const {db,sqlite,p}=fixture();sqlite.exec("INSERT INTO os_events(title,day,notes) VALUES('Legacy','2026-11-01','original');INSERT INTO os_event_repeat VALUES(1,'weekly',NULL);INSERT INTO os_event_occurrences VALUES(1,'2026-11-01','done');");
 const q={...p,uid:'event:1',source:'event',sourceId:1,day:'2026-11-01'};await saveActivity(db,q);assert.equal(sqlite.prepare('SELECT * FROM os_events').get().id,1);
 await assert.rejects(()=>saveActivity(db,{...q,requestId:'request-four',day:null}));assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM os_event_occurrences').get().n,1);assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM os_tasks').get().n,0);
});
test('invalid ranges and missing categories never create rows or receipts',async()=>{const {db,sqlite,p}=fixture();for(const extra of [{day:'2026-02-30'},{day:'2026-11-20'},{start_time:'99:00'},{list_kind:'missing'}])await assert.rejects(()=>saveActivity(db,{...p,...extra}));assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM os_tasks').get().n,0);assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM os_activity_requests').get().n,0);});
test('a failed conversion rolls back the original row and receipt atomically',async()=>{
 const {db,sqlite,p}=fixture();await saveActivity(db,p);
 sqlite.exec("CREATE TRIGGER reject_event BEFORE INSERT ON os_events BEGIN SELECT RAISE(ABORT,'simulated write failure');END;");
 await assert.rejects(()=>saveActivity(db,{...p,requestId:'request-rollback',sourceId:1,day:'2026-11-01'}));
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM os_tasks').get().n,1);
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM os_activity_requests WHERE id=?').get('request-rollback').n,0);
 assert.equal(sqlite.prepare('SELECT kind FROM os_activity_identity').get().kind,'task');
});

test('deletion between lookup and commit cannot produce a false save receipt',async()=>{
 const {db,sqlite,p}=fixture();sqlite.exec("INSERT INTO os_tasks(title,list_kind,status) VALUES('Original','action','todo');");
 const batch=db.batch.bind(db);let deleted=false;
 db.batch=async items=>{if(!deleted&&items.some(s=>s.sql.startsWith('INSERT OR IGNORE INTO os_activity_requests'))){deleted=true;sqlite.exec('DELETE FROM os_tasks WHERE id=1');}return batch(items);};
 await assert.rejects(()=>saveActivity(db,{...p,uid:'task:1',sourceId:1}));
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM os_activity_identity').get().n,0);
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM os_activity_requests').get().n,0);
});
test('completion after an offline create survives replay and reopening',async()=>{
 const {db,sqlite,p}=fixture();await saveActivity(db,p);
 const complete={...p,requestId:'request-complete',statusIntent:true,taskStatus:'done',completed:true};
 await saveActivity(db,complete);await saveActivity(db,complete);
 assert.equal(sqlite.prepare('SELECT status FROM os_tasks').get().status,'done');
 await saveActivity(db,{...p,requestId:'request-reopen',statusIntent:true,taskStatus:'waiting'});
 assert.equal(sqlite.prepare('SELECT status FROM os_tasks').get().status,'waiting');
});
test('a completed single activity can lose its date without losing completion or leaving exceptions',async()=>{
 const {db,sqlite,p}=fixture();await saveActivity(db,{...p,frequency:'none',completed:true,day:'2026-11-01'});
 assert.equal(sqlite.prepare('SELECT status FROM os_event_occurrences').get().status,'done');
 await saveActivity(db,{...p,frequency:'none',requestId:'request-undate'});
 assert.equal(sqlite.prepare('SELECT status FROM os_tasks').get().status,'done');
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM os_event_occurrences').get().n,0);
});

test('legacy task titles up to 160 UTF-16 units survive conversion without truncation',async()=>{
 const {db,sqlite,p}=fixture();const title='🌱'.repeat(80);
 sqlite.prepare("INSERT INTO os_tasks(title,list_kind,status) VALUES(?,'action','todo')").run(title);
 const q={...p,uid:'task:1',sourceId:1,title};await saveActivity(db,q);
 await saveActivity(db,{...q,requestId:'request-title-date',day:'2026-11-01'});
 assert.equal(sqlite.prepare('SELECT title FROM os_events').get().title,title);
 await assert.rejects(()=>saveActivity(db,{...q,requestId:'request-too-long',title:title+'a'}));
});
test('reopening a completed event before removing its date does not resurrect completion',async()=>{
 const {db,sqlite,p}=fixture();await saveActivity(db,{...p,frequency:'none',completed:true,day:'2026-11-01'});
 sqlite.exec('DELETE FROM os_event_occurrences');
 await saveActivity(db,{...p,frequency:'none',requestId:'request-undated-open'});
 assert.equal(sqlite.prepare('SELECT status FROM os_tasks').get().status,'todo');
});
