import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFile,writeFile,mkdtemp,rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
const temp=await mkdtemp(join(tmpdir(),'lifeos-routing67-'));
const source=await readFile(process.env.LIFEOS_ROUTING_WORKER || new URL('../../../manual/build-67/worker.js',import.meta.url),'utf8');
await writeFile(join(temp,'worker.mjs'),source+'\nexport { expenseRouting, D1PlanRepository, PlanService, initialState, balance, monthlyBudgetAmounts, withFinancePlans, PlanError };');
const core=await import(pathToFileURL(join(temp,'worker.mjs')));
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
 const payload={requestId:'water-request-0001',expenseDestination:'plan',expenseRoutingVersion:1,planId:'water',type:'Spesa',account:'Trade Republic',category:'Acqua',amount:30,name:'Bolletta acqua',note:'Nota conservata',date:'2026-10-28',competenceMonths:1,expectedAvailableCents:2000};
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
 const attach={requestId:'attach-existing-0001',movementId:row.source_row,expectedAmountCents:3000,expectedDate:'2026-10-28',expectedCategory:'Acqua',expectedPaymentId:'',expenseDestination:'plan',planId:'water',expectedAvailableCents:2000};
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
 await assert.rejects(core.expenseRouting.change({...ctx,input:{requestId:'atomic-destination-0001',movementId:row.source_row,expectedPaymentId:'',expectedAmountCents:3000,expectedDate:'2026-10-28',expectedCategory:'Acqua',expenseDestination:'plan',planId:'water',expectedAvailableCents:2000}}),/policy failure/);
 assert.deepEqual(await repository.read(),before);assert.equal(sqlite.prepare('SELECT treatment FROM movement_budget_policies').get().treatment,'ordinary');assert.deepEqual(sqlite.prepare('SELECT * FROM movements').get(),row);
});
test('simultaneous ordinary/plan replay has one winner and one bank debit',async()=>{
 const {ctx,payload,sqlite}=await fixture();const ordinary={...payload,expenseDestination:'ordinary'};delete ordinary.planId;
 const outcomes=await Promise.allSettled([core.expenseRouting.save({...ctx,input:ordinary}),core.expenseRouting.save({...ctx,input:payload})]);
 assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,1);
});
test('changed amount and invalid calendar dates cannot be silently accepted',async()=>{
 const {ctx,payload,sqlite}=await fixture();const ordinary={...payload,expenseDestination:'ordinary'};delete ordinary.planId;await core.expenseRouting.save({...ctx,input:ordinary});const row=sqlite.prepare('SELECT * FROM movements').get();
 await assert.rejects(core.expenseRouting.change({...ctx,input:{requestId:'stale-amount-0001',movementId:row.source_row,expectedPaymentId:'',expectedAmountCents:2000,expectedDate:'2026-10-28',expectedCategory:'Acqua',expenseDestination:'plan',planId:'water',expectedAvailableCents:2000}}),/movimento è cambiato/);
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

test('a changed reserve or another pending payment requires a fresh quote before any debit',async()=>{
 const {ctx,payload,sqlite,setFailure}=await fixture();
 await assert.rejects(core.expenseRouting.save({...ctx,input:{...payload,expectedAvailableCents:1000}}),/disponibilità/);
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,0);
 setFailure();await assert.rejects(core.expenseRouting.save({...ctx,input:payload}),/lost response/);
 const pending=await core.expenseRouting.preview({...ctx,input:{category:'Acqua',amountCents:3000,date:'2026-10-28'}});
 // The monthly estimated cycle is already reserved; it cannot be paid twice.
 assert.equal(pending.plans.length,0);
 await core.expenseRouting.save({...ctx,input:payload});assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,1);
});
test('pending fund payments reserve availability before the next payment can start',async()=>{
 const {ctx,payload,sqlite,repository,setFailure}=await fixture();const initial=await repository.read();initial.state.plans.water.kind='fund';await repository.compareAndSet(initial.revision,initial.state);
 setFailure();await assert.rejects(core.expenseRouting.save({...ctx,input:payload}),/lost response/);
 const preview=await core.expenseRouting.preview({...ctx,input:{category:'Acqua',amountCents:3000,date:'2026-10-28'}});
 assert.equal(preview.plans.length,1);assert.equal(preview.plans[0].availableCents,0);
 await assert.rejects(core.expenseRouting.save({...ctx,input:{...payload,requestId:'second-fund-payment-0001'}}),/disponibilità/);
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,1);
 await core.expenseRouting.save({...ctx,input:payload});
});
test('multiple matching plans are returned without choosing one on the server',async()=>{
 const {ctx,payload,repository,sqlite}=await fixture();const initial=await repository.read();initial.state.plans.other={...initial.state.plans.water,id:'other',name:'Acqua seconda'};await repository.compareAndSet(initial.revision,initial.state);
 const preview=await core.expenseRouting.preview({...ctx,input:{category:'Acqua',amountCents:3000,date:'2026-10-28'}});assert.equal(preview.plans.length,2);
 const ambiguous={...payload};delete ambiguous.planId;await assert.rejects(core.expenseRouting.save({...ctx,input:ambiguous}),/non è più disponibile/);assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,0);
});
test('the actual Worker cash bridge preserves blank notes and the bank-snapshot flag',async()=>{
 const {ctx,payload,sqlite,repository}=await fixture();let sent;
 const base={async fetch(){return new Response(JSON.stringify({summary:{monthlyRemaining:900,monthlyCommitted:20},transactions:[]}),{headers:{'Content-Type':'application/json'}});}};
 const worker=core.withFinancePlans(base,{repositoryFactory:()=>repository,clock:()=>ctx.today,recordTransaction:async(env,input)=>{sent=input;return ctx.recordTransaction(env,input);}});
 const input={...payload,note:'',includedInSnapshot:true};
 const request=new Request('https://example.test/api/saveTransaction',{method:'POST',headers:{Origin:'https://example.test','Content-Type':'application/json','X-LifeOS-Plans-Version':'2'},body:JSON.stringify([input])});
 const response=await worker.fetch(request,{DB:ctx.db},{});assert.equal(response.status,200);assert.equal(await response.json(),true);
 assert.equal(sent.includedInSnapshot,true);assert.equal(sqlite.prepare('SELECT notes FROM movements').get().notes,'');
});

test('movement detail exposes the original plan billing period for destination changes',async()=>{
 const {ctx,payload,sqlite,repository}=await fixture();await core.expenseRouting.save({...ctx,input:{...payload,competenceMonths:3}});const row=sqlite.prepare('SELECT * FROM movements').get();
 const base={async fetch(request){return new Response(JSON.stringify(new URL(request.url).pathname==='/api/getMovement'?{...row,competence_months:1}:{summary:{monthlyRemaining:900,monthlyCommitted:20},transactions:[]}),{headers:{'Content-Type':'application/json'}});}};
 const worker=core.withFinancePlans(base,{repositoryFactory:()=>repository,clock:()=>ctx.today});
 const response=await worker.fetch(new Request('https://example.test/api/getMovement',{method:'POST',headers:{Origin:'https://example.test'},body:JSON.stringify([row.source_row])}),{DB:ctx.db},{});
 assert.equal(response.status,200);assert.equal((await response.json()).financePlanCompetenceMonths,3);
 const {state}=await repository.read();assert.equal(state.plans.water.rateChanges[0].amountCents,1000);
});
test('savings choice records one bank movement outside the monthly budget and cannot be replayed through another path',async()=>{
 const {ctx,payload,sqlite}=await fixture();const savings={...payload,expenseDestination:'savings'};delete savings.planId;
 await core.expenseRouting.save({...ctx,input:savings});await core.expenseRouting.save({...ctx,input:savings});
 await assert.rejects(core.expenseRouting.save({...ctx,input:payload}),/appartiene già/);
 await assert.rejects(core.expenseRouting.save({...ctx,input:{...savings,expenseDestination:'ordinary'}}),/dati diversi/);
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,1);assert.equal(sqlite.prepare('SELECT treatment FROM movement_budget_policies').get().treatment,'savings');
 await assert.rejects(core.expenseRouting.save({...ctx,input:{...savings,requestId:'savings-with-plan-0001',planId:'water'}}),/non coerenti/);
 await assert.rejects(core.expenseRouting.save({...ctx,input:{...savings,requestId:'unknown-destination-0001',expenseDestination:'other'}}),/Scegli la destinazione/);
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,1);
});

test('REVIEW-95: an ordinary expense split between savings and chosen budget months keeps one movement',async(t)=>{
 const {ctx,payload,sqlite}=await fixture();
 // Older generated Workers (build 67 baseline) predate the split: nothing to verify there.
 if (!(await core.expenseRouting.preview({...ctx,input:{category:'Acqua',amountCents:3000,date:'2026-10-28'}})).splitDestination) { t.skip('Worker without expense split'); return; }
 const split={...payload,requestId:'split-request-0001',expenseDestination:'ordinary',budgetTreatment:'recovery',recoveryMonths:'2026-10, 2026-11',recoveryAmount:20};delete split.planId;
 await assert.rejects(core.expenseRouting.save({...ctx,input:{...split,requestId:'split-bad-0001',recoveryMonths:'2026-09'}}),/mesi di budget/);
 await assert.rejects(core.expenseRouting.save({...ctx,input:{...split,requestId:'split-bad-0002',recoveryAmount:31}}),/parte dal budget/);
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,0,'invalid splits write nothing');
 await core.expenseRouting.save({...ctx,input:split});await core.expenseRouting.save({...ctx,input:split});
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,1);
 assert.equal(sqlite.prepare('SELECT treatment FROM movement_budget_policies').get().treatment,'recovery');
 const written=JSON.parse(sqlite.prepare('SELECT fingerprint FROM finance_write_requests').get().fingerprint);
 assert.equal(written.recoveryMonths,'2026-10, 2026-11');assert.equal(written.recoveryAmount,20);
});

test('REFERENCE-GAPS-95: a bill paid with a plan sends part of the uncovered amount to chosen budget months',async(t)=>{
 const {ctx,payload,sqlite}=await fixture();
 if (!(await core.expenseRouting.preview({...ctx,input:{category:'Acqua',amountCents:3000,date:'2026-10-28'}})).planSplitDestination) { t.skip('Worker without plan split'); return; }
 const bad={...payload,requestId:'plan-split-bad-0001',budgetTreatment:'recovery',recoveryMonths:'2026-10',recoveryAmount:11};
 await assert.rejects(core.expenseRouting.save({...ctx,input:bad}),/parte non coperta/);
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,0,'nothing paid when the split is invalid');
 const ok={...payload,requestId:'plan-split-0001',budgetTreatment:'recovery',recoveryMonths:'2026-11, 2026-10',recoveryAmount:6};
 await core.expenseRouting.save({...ctx,input:ok});await core.expenseRouting.save({...ctx,input:ok});
 assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,1);
 const policy=sqlite.prepare('SELECT * FROM movement_budget_policies').get();
 assert.equal(policy.treatment,'recovery');
 assert.deepEqual(JSON.parse(policy.recovery_json),[{month:'2026-10',amount_cents:300},{month:'2026-11',amount_cents:300}]);
});
test('REFERENCE-GAPS-95: the difference of a posted plan payment can be split afterwards',async(t)=>{
 const {ctx,payload,sqlite}=await fixture();
 if (!(await core.expenseRouting.preview({...ctx,input:{category:'Acqua',amountCents:3000,date:'2026-10-28'}})).planSplitDestination) { t.skip('Worker without plan split'); return; }
 await core.expenseRouting.save({...ctx,input:payload});
 const row=sqlite.prepare('SELECT source_row FROM movements').get().source_row;
 const split={requestId:'split-after-0001',movementId:row,expenseDestination:'budgetSplit',recoveryMonths:'2026-10',recoveryAmount:10};
 await assert.rejects(core.expenseRouting.change({...ctx,input:{...split,recoveryAmount:10.01}}),/parte non coperta/);
 await core.expenseRouting.change({...ctx,input:split});
 const policy=sqlite.prepare('SELECT * FROM movement_budget_policies').get();
 assert.equal(policy.treatment,'recovery');assert.deepEqual(JSON.parse(policy.recovery_json),[{month:'2026-10',amount_cents:1000}]);
});

test('FUNDING-BLOCK build 95: bills never get a recovery on top of their competence months',async(t)=>{
 const {ctx,payload}=await fixture();
 if (!(await core.expenseRouting.preview({...ctx,input:{category:'Acqua',amountCents:3000,date:'2026-10-28'}})).billSavingsDestination) { t.skip('Worker without bill savings'); return; }
 const bill={...payload,requestId:'bill-recovery-0001',competenceStartMonth:'2026-09',competenceEndMonth:'2026-10',utilityCompetenceVersion:1,budgetTreatment:'recovery',recoveryMonths:'2026-10',recoveryAmount:5};
 await assert.rejects(core.expenseRouting.save({...ctx,input:bill}),/periodo di competenza|Prossimi mesi/);
 const ordinary={...bill,expenseDestination:'ordinary'};delete ordinary.planId;
 await assert.rejects(core.expenseRouting.save({...ctx,input:ordinary}),/periodo di competenza|Prossimi mesi/);
});
test('FUNDING-BLOCK build 95: the savings part of a bill is kept on the command or on the plan payment',async(t)=>{
 const {ctx,payload,repository}=await fixture();
 if (!(await core.expenseRouting.preview({...ctx,input:{category:'Acqua',amountCents:3000,date:'2026-10-28'}})).billSavingsDestination) { t.skip('Worker without bill savings'); return; }
 const base={...payload,competenceStartMonth:'2026-09',competenceEndMonth:'2026-10',utilityCompetenceVersion:1};
 const ordinary={...base,requestId:'bill-savings-0001',expenseDestination:'ordinary',utilitySavingsCents:1200};delete ordinary.planId;
 await assert.rejects(core.expenseRouting.save({...ctx,input:{...ordinary,requestId:'bill-savings-bad',utilitySavingsCents:3001}}),/risparmi della bolletta/);
 await core.expenseRouting.save({...ctx,input:ordinary});
 let {state}=await repository.read();assert.equal(state.expenseRoutingCommands['bill-savings-0001'].utilitySavingsCents,1200);
 const planned={...base,requestId:'bill-savings-0002',utilitySavingsCents:400};
 await assert.rejects(core.expenseRouting.save({...ctx,input:{...planned,requestId:'bill-savings-bad2',utilitySavingsCents:1001}}),/risparmi della bolletta/);
 await core.expenseRouting.save({...ctx,input:planned});
 ({state}=await repository.read());assert.equal(state.payments['bill-savings-0002'].utilitySavingsCents,400);
});
test('BILL-PAST-MONTHS: a bill keeps the chosen months for its excess and what the plan covered',async(t)=>{
 const {ctx,payload,repository}=await fixture();
 if (!(await core.expenseRouting.preview({...ctx,input:{category:'Acqua',amountCents:3000,date:'2026-10-28'}})).billMonthsDestination) { t.skip('Worker without bill months'); return; }
 const base={...payload,competenceStartMonth:'2026-08',competenceEndMonth:'2026-10',utilityCompetenceVersion:1};
 const ordinary={...base,requestId:'bill-months-0001',expenseDestination:'ordinary',utilitySavingsCents:3000};delete ordinary.planId;
 await core.expenseRouting.save({...ctx,input:ordinary});
 let {state}=await repository.read();assert.equal(state.expenseRoutingCommands['bill-months-0001'].utilitySavingsCents,3000,'the whole bill may stay on savings');
 assert.equal(state.expenseRoutingCommands['bill-months-0001'].billRule,2);
 await assert.rejects(core.expenseRouting.save({...ctx,input:{...ordinary,requestId:'bill-months-bad',utilitySavingsCents:0,billBudgetMonths:['2026-09']}}),/dal mese corrente/);
 const planned={...base,requestId:'bill-months-0002',utilitySavingsCents:200,billBudgetMonths:['2026-11','2026-10']};
 await core.expenseRouting.save({...ctx,input:planned});
 ({state}=await repository.read());const paid=state.payments['bill-months-0002'];
 assert.deepEqual([paid.billRule,paid.coveredCents,paid.utilitySavingsCents,paid.billBudgetMonths],[2,2000,200,['2026-10','2026-11']]);
});
