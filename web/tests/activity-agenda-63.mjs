import {readFileSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import assert from 'node:assert/strict';
import vm from 'node:vm';

const source = readFileSync(process.argv[2] || 'manual/build-63/worker.js','utf8');
const worker = await import('data:text/javascript;base64,' + Buffer.from(source + '\nexport {initializeLife,lifeAction,lifeRead,APP_HTML}; export function freezeDay(day){nowDay=()=>day;}').toString('base64'));
const today = '2026-10-31';
worker.freezeDay(today);
const day = n => new Date(Date.parse(today+'T12:00:00Z')+n*864e5).toISOString().slice(0,10);
const db = new DatabaseSync(':memory:');
class Statement {
  constructor(sql,values=[]){this.sql=sql;this.values=values;}
  bind(...values){return new Statement(this.sql,values);}
  async run(){const r=db.prepare(this.sql).run(...this.values);return {meta:{changes:Number(r.changes)}};}
  async all(){return {results:db.prepare(this.sql).all(...this.values)};}
  async first(){return db.prepare(this.sql).get(...this.values)??null;}
}
const env={DB:{prepare:sql=>new Statement(sql),async batch(items){db.exec('BEGIN');try{const r=[];for(const s of items)r.push(await s.run());db.exec('COMMIT');return r;}catch(e){db.exec('ROLLBACK');throw e;}}}};
const act=(method,value)=>worker.lifeAction(env,method,[value]);
try {
  await worker.initializeLife(env);
  for(const [title,offset,time] of [['Past',-1],['Today elapsed time',0,'00:01'],['Tomorrow',1],['Week boundary',7],['Outside window',8]]) {
    await act('saveEvent',{title,day:day(offset),start_time:time});
  }
  let data=await worker.lifeRead(env,'2026-10');
  assert.equal(data.events.find(e=>e.title==='Past').occurrence_status,'done');
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM os_event_occurrences').get().n,0,'Past status is inferred without false manual completion');
  data=await worker.lifeRead(env,'2027-05');
  assert.deepEqual(data.activityEvents.map(e=>e.title),['Today elapsed time','Tomorrow','Week boundary'],'Activity week is independent of calendar focus and start time');
  const past=db.prepare("SELECT id FROM os_events WHERE title='Past'").get().id;
  await act('setEventOccurrence',{id:past,day:day(-1),status:'done'});
  await act('saveEvent',{id:past,title:'Past reactivated',day:day(1),frequency:'none'});
  assert((await worker.lifeRead(env,'2026-11')).activityEvents.some(e=>e.id===past&&e.occurrence_status==='open'));
  await act('saveEvent',{title:'Weekly',day:day(-7),frequency:'weekly'});
  data=await worker.lifeRead(env,'2026-10');
  const recurring=data.activityEvents.find(e=>e.title==='Weekly'&&e.day===today);
  await act('setEventOccurrence',{id:recurring.id,day:today,status:'done'});
  data=await worker.lifeRead(env,'2026-10');
  assert(!data.activityEvents.some(e=>e.id===recurring.id&&e.day===today));
  assert(data.activityEvents.some(e=>e.id===recurring.id&&e.day===day(7)),'Completing one occurrence leaves the next one available');
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM os_tasks').get().n,0,'Calendar activity projection creates no task copies');
  for(let n=0;n<55;n++)await act('saveEvent',{title:'Many '+n,day:day(7)});
  assert((await worker.lifeRead(env,'2027-05')).activityEvents.length>48,'The activity list must not inherit the notification cap');
  console.log('AGENDA_63_WORKER_OK: rolling week, independent month focus, passed events, rescheduling and recurrence identity');
} finally { db.close(); }

const html=worker.APP_HTML;
let scripts=0;
for(const match of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)) {
  if(/type\s*=\s*["']application\/json/i.test(match[1])||!match[2].trim())continue;
  new vm.Script(match[2]);scripts++;
}
const start=html.indexOf('function osTaskRow('),end=html.indexOf('/** Editor evento o serie;',start);
assert(start>=0&&end>start);
class FixedDate extends Date {constructor(...args){super(args.length?args[0]:'2026-10-31T12:00:00Z');}}
const task=(id,title,status='todo',scheduled_date='')=>({id,title,status,list_kind:'action',scheduled_date,section_status:'waiting',sort_order:id});
const event=(id,title,n,status='open')=>({id,title,day:day(n),occurrence_status:status});
const state={category:'action',reorder:false,busy:false,data:{categories:[{key:'action',label:'Attività'}],tasks:[task(1,'Undated'),task(2,'Hidden future','todo',day(1)),task(3,'Waiting','waiting'),task(4,'Archived','done')],events:[event(99,'Far calendar month',30)],activityEvents:[event(10,'Today',0),event(11,'Tomorrow',1),event(12,'Week',7),event(13,'Beyond',8),event(14,'Past',-1),event(15,'Done event',0,'done')],upcomingEvents:[]}};
let ordered;
const context=vm.createContext({life:state,Date:FixedDate,Intl,Set,osSafe:x=>String(x??''),osDate:x=>x,osDueBadge:()=>'',osWrite:async(method,payload)=>{ordered=payload.ids;}});
vm.runInContext(html.slice(start,end),context);
const output=vm.runInContext('osTasks()',context);
for(const excluded of ['Hidden future','Far calendar month','Beyond','Past','Done event'])assert(!output.includes(excluded));
assert(output.indexOf('>Today<')<output.indexOf('>Tomorrow<'));
assert(output.indexOf('>Tomorrow<')<output.indexOf('>Undated'));
assert(output.indexOf('>Undated')<output.indexOf('<h3>In attesa</h3>'));
assert(output.indexOf('<h3>In attesa</h3>')<output.indexOf('>Week<'));
assert(output.indexOf('>Waiting')<output.indexOf('>Week<'));
assert(output.includes('<details class="os-completed"><summary>Completate'));
assert(!output.includes('<details class="os-completed" open'));
assert(output.includes('data-life-status="4:waiting"'),'Archive restores the original waiting state');
const orderStart=html.indexOf('async function osCommitOrder('),orderEnd=html.indexOf('let osDrag =',orderStart);
vm.runInContext(html.slice(orderStart,orderEnd),context);
await vm.runInContext('osCommitOrder("action",[1])',context);
assert.deepEqual(Array.from(ordered),[1,2],'Reorder preserves hidden scheduled task IDs');
const openStart=html.indexOf('function osOpenEvent('),openEnd=html.indexOf('/** Chiude il foglio Life OS',openStart);
assert(openStart>=0&&openEnd>openStart);
context.document={getElementById:()=>null,querySelector:()=>null};context.setView=()=>{};
vm.runInContext(html.slice(openStart,openEnd),context);
state.month='2027-05';
vm.runInContext('osOpenEvent(10)',context);
assert.equal(state.month,'2026-10','An activity-only event must open its original month');
assert.equal(state.selected,today);
state.data.tasks=[];state.data.events=[];state.data.activityEvents=[];
assert(!vm.runInContext('osTasks()',context).includes('Completate'));
console.log('AGENDA_63_BROWSER_OK: '+scripts+' scripts parse; priority, scheduled visibility, collapsed archive and complete reorder contract');
