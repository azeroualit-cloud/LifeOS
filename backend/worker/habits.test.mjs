import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {spawnSync} from 'node:child_process';
import {mkdtemp,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import worker from '../../worker.js';
import {habitSchedule,habitDue} from './habits.mjs';
import {LocalModel,demoArchive} from './local-model.mjs';
test('civil recurrence agrees with the compiled Swift model across leap years, DST and missed completions',async()=>{
 const schedules=[undefined,{mode:'daily',startDate:'2026-10-20'},{mode:'interval',intervalDays:2,startDate:'2026-10-24'},{mode:'interval',intervalDays:3,startDate:'2028-02-27'},{mode:'weekdays',weekdays:[7,1,1],startDate:'2026-10-01'}];
 const days=['2026-10-18','2026-10-19','2026-10-20','2026-10-24','2026-10-25','2026-10-26','2026-10-27','2028-02-28','2028-02-29','2028-03-01'];
 const fixtures=schedules.flatMap(schedule=>days.map(day=>({routine:schedule?{schedule}:{},day}))),folder=await mkdtemp(join(tmpdir(),'habits-'));
 try{
  await writeFile(join(folder,'main.swift'),`import Foundation
let rows = try JSONDecoder().decode([Record].self, from: FileHandle.standardInput.readDataToEndOfFile())
let result = try rows.map { r in try NativeRoutineSchedule(r.record("routine")["schedule"]).isDue(on: r.text("day")) }
FileHandle.standardOutput.write(try JSONEncoder().encode(result))
`);
  const build=spawnSync(process.env.LIFEOS_SWIFTC||'swiftc',['work/native/Sources/Models.swift','work/native/Sources/NativeModels.swift','work/native/Sources/NativePlatformContract.swift','work/native/Sources/NativeRoutineSchedule.swift',join(folder,'main.swift'),'-module-cache-path',join(folder,'cache'),'-o',join(folder,'model')],{encoding:'utf8'});assert.equal(build.status,0,build.stderr);
  const result=spawnSync(join(folder,'model'),[],{input:JSON.stringify(fixtures),encoding:'utf8'});assert.equal(result.status,0,result.stderr);assert.deepEqual(JSON.parse(result.stdout),fixtures.map(f=>habitDue(f.routine,f.day)));
  assert.equal(habitDue({schedule:schedules[2]},'2026-10-26'),true);assert.equal(habitDue({schedule:schedules[2]},'2026-10-25'),false);
  for(const s of [{mode:'interval',intervalDays:0,startDate:'2026-10-18'},{mode:'weekdays',weekdays:[],startDate:'2026-10-18'},{mode:'weekdays',weekdays:[8],startDate:'2026-10-18'},{mode:'interval',intervalDays:2,startDate:'2026-02-30'},null])assert.throws(()=>habitSchedule(s));
 }finally{await rm(folder,{recursive:true,force:true});}
});
test('actual Worker migrates legacy habits without losing checks and persists schedules atomically',async()=>{
 const sql=new DatabaseSync(':memory:');sql.exec("CREATE TABLE os_routines(id INTEGER PRIMARY KEY,title TEXT NOT NULL,position INTEGER NOT NULL DEFAULT 0);CREATE TABLE os_routine_checks(routine_id INTEGER NOT NULL,day TEXT NOT NULL,PRIMARY KEY(routine_id,day));INSERT INTO os_routines VALUES(1,'Leggere',0);INSERT INTO os_routine_checks VALUES(1,'2026-10-01');");
 const db={prepare(query){let args=[];return {bind(...values){args=values;return this;},async run(){const r=sql.prepare(query).run(...args);return {meta:{changes:Number(r.changes)}};},async first(){return sql.prepare(query).get(...args)??null;},async all(){return {results:sql.prepare(query).all(...args)};}};},async batch(statements){sql.exec('BEGIN');try{const r=[];for(const s of statements)r.push(await s.run());sql.exec('COMMIT');return r;}catch(e){sql.exec('ROLLBACK');throw e;}}};
 const env={DB:db,APP_PASSWORD:'synthetic-habit-password'},today=new Date().toLocaleDateString('sv-SE',{timeZone:'Europe/Rome'});
 async function call(method,args){const r=await worker.fetch(new Request('https://habits.test/api/'+method,{method:'POST',headers:{Origin:'https://habits.test',Authorization:'Basic '+btoa('nas:'+env.APP_PASSWORD)},body:JSON.stringify(args)}),env,{});return {status:r.status,text:await r.text()};}
 const initial=await call('getLifeData',[today.slice(0,7)]);assert.equal(initial.status,200,initial.text);const data=JSON.parse(initial.text);assert.equal(data.routineScheduleVersion,1);assert.equal(data.routines[0].schedule.mode,'daily');
 const schedule={mode:'interval',intervalDays:2,startDate:today};assert.equal((await call('saveRoutine',[{id:1,title:'Lettura',schedule}])).status,200);
 assert.equal((await call('saveRoutine',[{id:1,title:'Leggere ancora'}])).status,200);assert.deepEqual(JSON.parse(sql.prepare('SELECT schedule_json FROM os_routines').get().schedule_json),habitSchedule(schedule));
 assert.equal((await call('setRoutineCheck',[{id:1,day:today,checked:true}])).status,200);assert.equal((await call('setRoutineCheck',[{id:1,day:today,checked:true}])).status,200);assert.equal(sql.prepare('SELECT COUNT(*) n FROM os_routine_checks').get().n,2);
 const tomorrow=new Date(Date.parse(today+'T12:00Z')+86400000).toISOString().slice(0,10);await call('saveRoutine',[{id:1,title:'Futuro',schedule:{...schedule,startDate:tomorrow}}]);assert.equal((await call('setRoutineCheck',[{id:1,day:today,checked:true}])).status,400);
 assert.equal((await call('saveRoutine',[{id:1,title:'Da non salvare',schedule:{mode:'weekdays',weekdays:[],startDate:today}}])).status,400);assert.equal(sql.prepare('SELECT title FROM os_routines').get().title,'Futuro');assert.equal(sql.prepare('SELECT COUNT(*) n FROM os_routine_checks').get().n,2);
 assert.equal((await call('deleteRoutine',[1])).status,200);assert.equal(sql.prepare('SELECT COUNT(*) n FROM os_routine_checks').get().n,0);sql.close();
});
test('local demo retains off-day habits for management and rejects an off-day completion',async()=>{
 const today='2026-10-18',m=new LocalModel(demoArchive(today),today),schedule={mode:'weekdays',weekdays:[1],startDate:'2026-10-01'};
 const r=await m.request('saveRoutine',[{title:'Solo lunedì',schedule}]);await assert.rejects(()=>m.request('setRoutineCheck',[{id:r.id,day:today,checked:true}]),/prevista/);
 assert.ok(m.life('2026-10').routines.some(row=>row.id===r.id));m.today='2026-10-19';assert.equal(habitDue(m.life('2026-10').routines.find(row=>row.id===r.id),m.today),true);
});
