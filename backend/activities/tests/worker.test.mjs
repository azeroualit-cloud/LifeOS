import {readFileSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import assert from 'node:assert/strict';
const source=readFileSync(new URL('../../../manual/build-68/worker.js',import.meta.url),'utf8');
const worker=await import('data:text/javascript;base64,'+Buffer.from(source+'\nexport {initializeLife,lifeAction};').toString('base64'));
const sqlite=new DatabaseSync(':memory:');
class Statement {
 constructor(sql,args=[]){this.sql=sql;this.args=args}
 bind(...args){return new Statement(this.sql,args)}
 async run(){const r=sqlite.prepare(this.sql).run(...this.args);return {meta:{changes:r.changes}}}
 async all(){return {results:sqlite.prepare(this.sql).all(...this.args)}}
 async first(){return sqlite.prepare(this.sql).get(...this.args)??null}
}
const env={DB:{prepare:sql=>new Statement(sql),async batch(items){sqlite.exec('BEGIN');try{const rows=[];for(const item of items)rows.push(await item.run());sqlite.exec('COMMIT');return rows}catch(e){sqlite.exec('ROLLBACK');throw e}}}};
await worker.initializeLife(env);
const p={uid:'integration-one',requestId:'integration-request',source:'task',sourceId:0,title:'Salvataggio unificato',notes:'Stessa identità',list_kind:'action',day:null};
assert.equal(await worker.lifeAction(env,'saveActivity',[p]),true);
let life=await worker.lifeAction(env,'getLifeData',['2026-10']);
assert.equal(life.capabilities.unifiedActivities,1);
const task=life.tasks.find(r=>r.activity_uid===p.uid);assert(task);assert.equal(task.notes,p.notes);
await worker.lifeAction(env,'saveActivity',[{...p,requestId:'integration-date',sourceId:task.id,day:'2026-10-30',start_time:'12:00'}]);
life=await worker.lifeAction(env,'getLifeData',['2026-10']);
assert(!life.tasks.some(r=>r.activity_uid===p.uid));
const event=life.events.find(r=>r.activity_uid===p.uid);assert(event);assert.equal(event.notes,p.notes);
await worker.lifeAction(env,'setEventOccurrence',[{id:event.id,day:event.day,status:'done'}]);
life=await worker.lifeAction(env,'getLifeData',['2026-10']);assert.equal(life.events.find(r=>r.activity_uid===p.uid).occurrence_status,'done');
console.log('ACTIVITY_WORKER_INTEGRATION_OK: real migrations, save/read RPC, stable identity, date conversion and completion');
const longTitle='🌱'.repeat(80);
await worker.lifeAction(env,'saveEvent',[{title:longTitle,day:'2026-10-30',frequency:'weekly',notes:'Legacy fields retained'}]);
const series=sqlite.prepare('SELECT * FROM os_events WHERE title=?').get(longTitle);assert(series);
await worker.lifeAction(env,'splitEventSeries',[{id:series.id,split_from:'2026-11-06',day:'2026-11-06',title:longTitle,frequency:'weekly',notes:'Legacy fields retained'}]);
assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM os_events WHERE title=?').get(longTitle).n,2);
console.log('ACTIVITY_LEGACY_TITLE_COMPATIBILITY_OK: creation and explicit series split preserve 160 UTF-16 units');
sqlite.exec("INSERT INTO os_categories(key,label,position) VALUES('test-category','Test',99)");
const dated={uid:'category-series',requestId:'category-create',source:'task',sourceId:0,title:'Categoria e scadenza',day:'2026-10-30',frequency:'weekly',list_kind:'test-category',due_date:'2026-12-01'};
await worker.lifeAction(env,'saveActivity',[dated]);
const parent=sqlite.prepare('SELECT source_id FROM os_activity_identity WHERE uid=?').get(dated.uid);
await worker.lifeAction(env,'splitEventSeries',[{id:parent.source_id,split_from:'2026-11-06',day:'2026-11-06',title:'Nuova parte',frequency:'weekly',notes:'Conservata'}]);
let snapshot=await worker.lifeAction(env,'getLifeData',['2026-11']);
const child=snapshot.events.find(r=>r.title==='Nuova parte');assert(child);assert.equal(child.list_kind,'test-category');assert.equal(child.due_date,'2026-12-01');
await worker.lifeAction(env,'deleteCategory',[{key:'test-category',destination:'action'}]);
snapshot=await worker.lifeAction(env,'getLifeData',['2026-11']);
assert.equal(snapshot.events.find(r=>r.id===child.id).list_kind,'action');
assert.equal(snapshot.events.find(r=>r.title===dated.title).list_kind,'action');
console.log('ACTIVITY_METADATA_COMPATIBILITY_OK: explicit series split and category deletion preserve and move activity metadata');
