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
