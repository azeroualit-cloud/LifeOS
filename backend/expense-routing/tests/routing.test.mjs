import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFile,writeFile,mkdtemp,rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
const temp=await mkdtemp(join(tmpdir(),'lifeos-routing67-'));
const source=await readFile(new URL('../../../manual/build-67/worker.js',import.meta.url),'utf8');
await writeFile(join(temp,'worker.mjs'),source+'\nexport { expenseRouting, D1PlanRepository, PlanService, initialState, balance, monthlyBudgetAmounts, withFinancePlans, PlanError };');
const core=await import(pathToFileURL(join(temp,'worker.mjs')));
process.on('exit',()=>{});
test.after(async()=>rm(temp,{recursive:true,force:true}));
function database() {
 const sqlite=new DatabaseSync(':memory:');
 sqlite.exec(`CREATE TABLE movements(source_row INTEGER PRIMARY KEY,amount REAL,actual_date TEXT,category TEXT,account TEXT,movement_type TEXT,status TEXT,description TEXT,notes TEXT,import_id TEXT);
 CREATE TABLE movement_budget_policies(movement_source_row INTEGER PRIMARY KEY,treatment TEXT,recovery_json TEXT);
 CREATE TABLE extraordinary_movement_links(movement_source_row INTEGER,cycle_id INTEGER);
 CREATE TABLE finance_write_requests(id TEXT PRIMARY KEY,fingerprint TEXT);`);
 const db={prepare(sql) {let params=[];return {bind(...values){params=values;return this;},async first(){return sqlite.prepare(sql).get(...params)??null;},async all(){return {results:sqlite.prepare(sql).all(...params)};},async run(){const r=sqlite.prepare(sql).run(...params);return {meta:{changes:Number(r.changes)}};}};},async batch(statements){sqlite.exec('BEGIN');try {const results=[];for(const s of statements)results.push(await s.run());sqlite.exec('COMMIT');return results;}catch(e){sqlite.exec('ROLLBACK');throw e;}}};
 return {db,sqlite};
}
async function fixture() {
 const {db,sqlite}=database(), repository=new core.D1PlanRepository(db);await repository.initialize();
 const state=core.initialState();state.plans.water={id:'water',name:'Acqua',category:'Acqua',kind:'estimated',status:'active',startMonth:'2026-10',amountCents:2000,rateChanges:[]};
 await repository.compareAndSet(0,state);let count=100,failAfterBank=false,lastCash;
 const recordTransaction=async(_env,p)=>{
  const prior=sqlite.prepare('SELECT source_row FROM movements WHERE import_id=?').get('APP-'+p.requestId);if(prior)return prior.source_row;
  const row=++count;sqlite.prepare('INSERT INTO movements VALUES(?,?,?,?,?,?,?,?,?,?)').run(row,-p.amount,p.date,p.category,'Trade Republic','Spesa','Eseguito',p.name,p.note??'','APP-'+p.requestId);
  sqlite.prepare('INSERT INTO movement_budget_policies VALUES(?,?,?)').run(row,p.budgetTreatment,'[]');sqlite.prepare('INSERT INTO finance_write_requests VALUES(?,?)').run(p.requestId,JSON.stringify(p));return row;
 };
 const cash={async record(p){lastCash=p;const row=await recordTransaction({}, {requestId:p.requestId,amount:p.amountCents/100,date:p.date,category:p.category,name:p.name,note:p.note,budgetTreatment:'savings'});if(failAfterBank){failAfterBank=false;throw new core.PlanError('Simulated lost response',503);}return row;}};
 const service=new core.PlanService(repository,cash,'2026-10-28');
 const ctx={repository,service,db,today:'2026-10-28',recordTransaction,env:{}};
 const payload={requestId:'water-request-0001',expenseDestination:'plan',expenseRoutingVersion:1,planId:'water',type:'Spesa',account:'Trade Republic',category:'Acqua',amount:30,name:'Bolletta acqua',note:'Nota conservata',date:'2026-10-28',competenceMonths:1};
 return {ctx,payload,sqlite,repository,getCash(){return lastCash;},setFailure(){failAfterBank=true;}};
}
test('water preview proposes reserve 20 and savings 10; generic category is not matched',async()=>{
 const {ctx}=await fixture();const r=await core.expenseRouting.preview({...ctx,input:{category:'Acqua',amountCents:3000,date:'2026-10-28'}});
 assert.equal(r.plans.length,1);assert.equal(r.plans[0].fromFundCents,2000);assert.equal(r.plans[0].fromSavingsCents,1000);
 assert.equal((await core.expenseRouting.preview({...ctx,input:{category:'Utenze',amountCents:3000,date:'2026-10-28'}})).plans.length,0);
});
test('plan payment, repeated request and lost response keep one cash movement and its note',async()=>{
 const {ctx,payload,sqlite,repository,setFailure}=await fixture();setFailure();await assert.rejects(core.expenseRouting.save({...ctx,input:payload}),/lost response/);
 assert.equal((await core.expenseRouting.status({...ctx,input:payload})).complete,false);
 await core.expenseRouting.save({...ctx,input:payload});await core.expenseRouting.save({...ctx,input:payload});
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,1);
 assert.equal(sqlite.prepare('SELECT notes FROM movements').get().notes,'Nota conservata');
 const {state}=await repository.read();assert.equal(core.balance(state,state.plans.water,'2026-10').fromGeneralSavingsCents,1000);
 assert.equal((await core.expenseRouting.status({...ctx,input:payload})).complete,true);
});
test('ordinary choice remains ordinary and the request cannot be replayed through another path',async()=>{
 const {ctx,payload,sqlite}=await fixture();const ordinary={...payload,expenseDestination:'ordinary'};delete ordinary.planId;
 await core.expenseRouting.save({...ctx,input:ordinary});await core.expenseRouting.save({...ctx,input:ordinary});
 await assert.rejects(core.expenseRouting.save({...ctx,input:payload}),/budget ordinario/);
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,1);assert.equal(sqlite.prepare('SELECT treatment FROM movement_budget_policies').get().treatment,'ordinary');
});
test('ordinary movement can attach, detach and attach again atomically without changing the bank ledger',async()=>{
 const {ctx,payload,sqlite,repository}=await fixture();const ordinary={...payload,expenseDestination:'ordinary'};delete ordinary.planId;
 await core.expenseRouting.save({...ctx,input:ordinary});const row=sqlite.prepare('SELECT * FROM movements').get();
 const attach={requestId:'attach-existing-0001',movementId:row.source_row,expectedAmountCents:3000,expectedDate:'2026-10-28',expectedCategory:'Acqua',expectedPaymentId:'',expenseDestination:'plan',planId:'water'};
 await core.expenseRouting.change({...ctx,input:attach});await core.expenseRouting.change({...ctx,input:attach});
 assert.equal(sqlite.prepare('SELECT treatment FROM movement_budget_policies').get().treatment,'savings');
 const unlink={requestId:'detach-existing-0001',movementId:row.source_row,expectedAmountCents:3000,expectedDate:'2026-10-28',expectedCategory:'Acqua',expectedPaymentId:attach.requestId+'-attach',expenseDestination:'ordinary'};
 await core.expenseRouting.change({...ctx,input:unlink});
 assert.equal(sqlite.prepare('SELECT treatment FROM movement_budget_policies').get().treatment,'ordinary');
 await core.expenseRouting.change({...ctx,input:{...attach,requestId:'attach-existing-0002'}});
 assert.deepEqual(sqlite.prepare('SELECT * FROM movements').get(),row);
 const {state}=await repository.read();assert.equal(Object.values(state.payments).filter(p=>p.status==='posted').length,1);
});
test('stale destination, wrong category and legacy-linked movement fail without mutation',async()=>{
 const {ctx,payload,sqlite,repository}=await fixture();await core.expenseRouting.save({...ctx,input:payload});const row=sqlite.prepare('SELECT * FROM movements').get();const before=await repository.read();
 await assert.rejects(core.expenseRouting.change({...ctx,input:{requestId:'stale-destination-0001',movementId:row.source_row,expectedAmountCents:3000,expectedDate:'2026-10-28',expectedCategory:'Acqua',expectedPaymentId:'',expenseDestination:'ordinary'}}),/altro dispositivo/);
 assert.deepEqual(await repository.read(),before);
 await assert.rejects(core.expenseRouting.save({...ctx,input:{...payload,requestId:'wrong-category-0001',category:'Gas'}}),/non è più disponibile/);
 sqlite.prepare('INSERT INTO extraordinary_movement_links VALUES(?,?)').run(row.source_row,9);
 await assert.rejects(core.expenseRouting.preview({...ctx,input:{category:'Acqua',amountCents:3000,date:'2026-10-28',movementId:row.source_row}}),/precedente/);
});
test('cancel-before-start leaves a tombstone against delayed offline replay; started payments cannot be cancelled',async()=>{
 const {ctx,payload,sqlite}=await fixture();await core.expenseRouting.cancel({...ctx,input:payload});await core.expenseRouting.cancel({...ctx,input:payload});
 await assert.rejects(core.expenseRouting.save({...ctx,input:payload}),/budget ordinario/);assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,0);
 const next={...payload,requestId:'started-payment-0001'};await core.expenseRouting.save({...ctx,input:next});await assert.rejects(core.expenseRouting.cancel({...ctx,input:next}),/già iniziato/);
});
test('routing endpoints retain POST, origin and login checks',async()=>{
 const worker=core.withFinancePlans({async fetch(){return new Response('{}',{status:401,headers:{'Content-Type':'application/json'}});}});
 for(const method of ['getExpenseRouting','changeExpenseDestination','cancelExpenseRequest']) {
  const url='https://example.test/api/'+method;
  assert.equal((await worker.fetch(new Request(url),{},{})).status,405);
  assert.equal((await worker.fetch(new Request(url,{method:'POST',headers:{Origin:'https://wrong.test'},body:'[]'}),{},{})).status,403);
  assert.equal((await worker.fetch(new Request(url,{method:'POST',headers:{Origin:'https://example.test'},body:'[]'}),{},{})).status,401);
 }
});

test('atomic destination transaction rolls back plan state if policy write fails',async()=>{
 const {ctx,payload,sqlite,repository}=await fixture();const ordinary={...payload,expenseDestination:'ordinary'};delete ordinary.planId;await core.expenseRouting.save({...ctx,input:ordinary});
 const row=sqlite.prepare('SELECT * FROM movements').get(),before=await repository.read();
 sqlite.exec("CREATE TRIGGER policy_failure BEFORE UPDATE ON movement_budget_policies BEGIN SELECT RAISE(ABORT,'simulated policy failure'); END");
 await assert.rejects(core.expenseRouting.change({...ctx,input:{requestId:'atomic-destination-0001',movementId:row.source_row,expectedPaymentId:'',expectedAmountCents:3000,expectedDate:'2026-10-28',expectedCategory:'Acqua',expenseDestination:'plan',planId:'water'}}),/policy failure/);
 assert.deepEqual(await repository.read(),before);assert.equal(sqlite.prepare('SELECT treatment FROM movement_budget_policies').get().treatment,'ordinary');assert.deepEqual(sqlite.prepare('SELECT * FROM movements').get(),row);
});
test('simultaneous ordinary/plan replay has one winner and one bank debit',async()=>{
 const {ctx,payload,sqlite}=await fixture();const ordinary={...payload,expenseDestination:'ordinary'};delete ordinary.planId;
 const outcomes=await Promise.allSettled([core.expenseRouting.save({...ctx,input:ordinary}),core.expenseRouting.save({...ctx,input:payload})]);
 assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,1);
});
test('changed amount and invalid calendar dates cannot be silently accepted',async()=>{
 const {ctx,payload,sqlite}=await fixture();const ordinary={...payload,expenseDestination:'ordinary'};delete ordinary.planId;await core.expenseRouting.save({...ctx,input:ordinary});const row=sqlite.prepare('SELECT * FROM movements').get();
 await assert.rejects(core.expenseRouting.change({...ctx,input:{requestId:'stale-amount-0001',movementId:row.source_row,expectedPaymentId:'',expectedAmountCents:2000,expectedDate:'2026-10-28',expectedCategory:'Acqua',expenseDestination:'plan',planId:'water'}}),/movimento è cambiato/);
 await assert.rejects(core.expenseRouting.preview({...ctx,input:{category:'Acqua',amountCents:3000,date:'2026-02-31'}}),/Data non valida/);
});

test('planned expense preserves the already-in-bank-snapshot flag through reservation and resume',async()=>{
 const {ctx,payload,getCash}=await fixture();await core.expenseRouting.save({...ctx,input:{...payload,includedInSnapshot:true}});
 assert.equal(getCash().includedInSnapshot,true);
});

test('detached movement becomes editable and available in the existing plan picker',async()=>{
 const {ctx,payload,sqlite,repository}=await fixture();await core.expenseRouting.save({...ctx,input:payload});const row=sqlite.prepare('SELECT * FROM movements').get();
 await core.expenseRouting.change({...ctx,input:{requestId:'detach-for-edit-0001',movementId:row.source_row,expectedPaymentId:payload.requestId,expectedAmountCents:3000,expectedDate:'2026-10-28',expectedCategory:'Acqua',expenseDestination:'ordinary'}});
 let editReached=false;
 const base={async fetch(request){if(new URL(request.url).pathname==='/api/editMovement'){editReached=true;return new Response('true',{headers:{'Content-Type':'application/json'}});}return new Response(JSON.stringify({summary:{monthlyRemaining:900,monthlyCommitted:20},transactions:[]}),{headers:{'Content-Type':'application/json'}});}};
 const worker=core.withFinancePlans(base,{repositoryFactory:()=>repository,clock:()=>ctx.today});
 function request(method,args){return new Request('https://example.test/api/'+method,{method:'POST',headers:{Origin:'https://example.test','Content-Type':'application/json'},body:JSON.stringify(args)});}
 const edited=await worker.fetch(request('editMovement',[{row:row.source_row}]),{DB:ctx.db},{});assert.equal(edited.status,200);assert.equal(editReached,true);
 const picker=await worker.fetch(request('getFinancePlanMovements',['2026-10']),{DB:ctx.db},{});assert.equal(picker.status,200);assert.equal((await picker.json()).movements[0].row,row.source_row);
});
