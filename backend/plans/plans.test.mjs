import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {initialState,command,completePayment,project,contribution,split} from './engine.mjs';
import {D1PlanRepository,PlanService} from './service.mjs';
import {withFinancePlans,augmentFinance,romeToday} from './worker-adapter.mjs';
const today='2026-10-17';
const input=(id,kind='goal',extra={})=>({requestId:id,kind,name:'Esempio',amountCents:60000,startMonth:'2026-10',endMonth:'2026-12',...extra});
function d1(sqlite=new DatabaseSync(':memory:')) {
  return {sqlite,prepare(sql) { let values=[];return {bind(...args){values=args;return this;},async run(){const r=sqlite.prepare(sql).run(...values);return {meta:{changes:Number(r.changes)}};},async first(){return sqlite.prepare(sql).get(...values);}};}};
}
async function setup(day=today) {
  const db=d1(), repo=new D1PlanRepository(db);await repo.initialize();
  const cash={calls:0,rows:new Map(),failAfterWrite:false,async record(p) {
    this.calls++;if(!this.rows.has(p.requestId))this.rows.set(p.requestId,{...p,id:this.rows.size+1});
    if(this.failAfterWrite){this.failAfterWrite=false;throw Error('Synthetic timeout after committing cash');}
    return this.rows.get(p.requestId).id;
  }};
  return {db,repo,cash,service:new PlanService(repo,cash,day)};
}
const make=(state,id,kind,extra={})=>command(state,'create',input(id,kind,extra),today).state;
const pay=(state,id,planId,amountCents,extra={})=>command(state,'pay',{requestId:id,planId,amountCents,date:today,...extra},today).state;

test('250 euro da novembre a ottobre: somma zero e nessuna uscita bancaria',async()=>{
  const {service,cash}=await setup();await service.execute('create',input('advance-0001','advance',{amountCents:25000,startMonth:'2026-11',endMonth:'2026-11',beneficiaryMonth:'2026-10'}));
  assert.equal((await service.view('2026-10')).adjustmentCents,25000);
  assert.equal((await service.view('2026-11')).adjustmentCents,-25000);
  assert.equal((await service.view('2026-12')).adjustmentCents,0);assert.equal(cash.calls,0);
});
test('250 euro divisi tra novembre e dicembre e centesimi esatti',()=>{
  const state=make(initialState(),'advance-0002','advance',{amountCents:25000,startMonth:'2026-11',beneficiaryMonth:'2026-10'});
  assert.equal(project(state,'2026-11').adjustmentCents,-12500);assert.equal(project(state,'2026-12').adjustmentCents,-12500);
  assert.equal(['2026-10','2026-11','2026-12'].reduce((n,m)=>n+project(state,m).adjustmentCents,0),0);
  for(let total=1;total<=1000;total+=7)for(let count=1;count<=24;count++)assert.equal(split(total,count).reduce((n,x)=>n+x,0),total);
});
test('anticipo non valido non scrive alcun piano',()=>{
  for(const extra of [{beneficiaryMonth:'2026-11',startMonth:'2026-11'},{beneficiaryMonth:'2026-09',startMonth:'2026-11'}])assert.throws(()=>make(initialState(),'advance-0003','advance',extra));
});
test('obiettivo pagato meno del previsto: un pagamento e cancellazione quote future',async()=>{
  const {service,repo,cash}=await setup();await service.execute('create',input('goal-000001'));
  await service.execute('pay',{requestId:'payment-0001',planId:'goal-000001',amountCents:50000,date:today});
  const state=(await repo.read()).state;
  assert.equal(state.plans['goal-000001'].status,'closed');assert.equal(cash.rows.size,1);
  assert.equal(project(state,'2026-10').adjustmentCents,-20000);assert.equal(project(state,'2026-11').adjustmentCents,0);
  assert.equal(project(state,'2026-10').plans[0].fundCents,0);assert.equal(Object.keys(state.plans).length,1);
});
test('eccedenza opzionale recupera soltanto 100 su novembre e dicembre',async()=>{
  const {service,repo,cash}=await setup();await service.execute('create',input('goal-000002'));
  await service.execute('pay',{requestId:'payment-0002',planId:'goal-000002',amountCents:70000,date:today,recoverDifference:true,recoveryStartMonth:'2026-11',recoveryEndMonth:'2026-12'});
  const state=(await repo.read()).state;
  assert.equal(project(state,'2026-11').adjustmentCents,-5000);assert.equal(project(state,'2026-12').adjustmentCents,-5000);assert.equal(cash.rows.size,1);
  assert.equal(Object.values(state.plans).find(p=>p.kind==='recovery').amountCents,10000);
});
test('eccedenza senza recupero non genera altre quote',async()=>{
  const {service,repo}=await setup();await service.execute('create',input('goal-000003'));
  await service.execute('pay',{requestId:'payment-0003',planId:'goal-000003',amountCents:70000,date:today});
  assert.equal(Object.keys((await repo.read()).state.plans).length,1);assert.equal((await service.view('2026-11')).adjustmentCents,0);
});
test('manutenzione continuativa: paga, continua, interrompi senza altre uscite',async()=>{
  const {service,repo,cash}=await setup();await service.execute('create',input('fund-000001','fund',{amountCents:5000}));
  await service.execute('pay',{requestId:'payment-0004',planId:'fund-000001',amountCents:3000,date:today});
  assert.equal((await service.view('2026-10')).plans[0].fundCents,2000);
  assert.equal((await service.view('2026-11')).adjustmentCents,-5000);
  await service.execute('stop',{requestId:'stop-0000001',planId:'fund-000001'});
  assert.equal((await service.view('2026-10')).adjustmentCents,-5000);assert.equal((await service.view('2026-11')).adjustmentCents,0);
  assert.equal((await service.view('2026-10')).plans[0].fundCents,0);assert.equal(cash.rows.size,1);assert.equal(Object.values((await repo.read()).state.payments).length,1);
});
test('fondo dura oltre venti anni senza ereditare il limite dei piani finiti',()=>{
  const state=make(initialState(),'fund-000002','fund',{amountCents:5000});
  assert.equal(project(state,'2055-12').adjustmentCents,-5000);
});
test('affitto: scadenza pagata, piano attivo e nessun secondo pagamento stesso mese',async()=>{
  const {service,repo,cash}=await setup();await service.execute('create',input('rent-000001','fixed'));
  const payment={requestId:'payment-rent1',planId:'rent-000001',amountCents:60000,date:today,cycleMonth:'2026-10'};
  await service.execute('pay',payment);await service.execute('pay',payment);
  assert.equal(cash.rows.size,1);assert.equal((await repo.read()).state.plans['rent-000001'].status,'active');
  await assert.rejects(service.execute('pay',{...payment,requestId:'payment-rent2'}));
  assert.equal((await service.view('2026-11')).adjustmentCents,-60000);
});
test('utenze: media per mese coperto e nessuna riscrittura delle quote passate',()=>{
  let state=make(initialState(),'utility-0001','estimated',{amountCents:8000});
  state=pay(state,'utility-pay1','utility-0001',16000,{competenceMonths:2});state=completePayment(state,'utility-pay1',1,today);
  assert.equal(project(state,'2026-10').adjustmentCents,-8000);assert.equal(project(state,'2026-11').adjustmentCents,-8000);
  state=command(state,'pay',{requestId:'utility-pay2',planId:'utility-0001',amountCents:24000,date:'2026-11-17',cycleMonth:'2026-11',competenceMonths:2},'2026-11-17').state;
  state=completePayment(state,'utility-pay2',2,'2026-11-17');
  assert.equal(project(state,'2026-10').adjustmentCents,-8000);assert.equal(project(state,'2026-11').adjustmentCents,-8000);
  assert.equal(project(state,'2026-12').adjustmentCents,-10000);
});
test('rateizzazione spesa: uscita unica, recuperi futuri e nessun secondo Paga',async()=>{
  const {service,cash,repo}=await setup();await service.execute('create',input('recovery-001','recovery',{amountCents:30000,startMonth:'2026-11',paymentDate:today}));
  assert.equal(cash.rows.size,1);assert.equal((await service.view('2026-10')).adjustmentCents,0);assert.equal((await service.view('2026-11')).adjustmentCents,-15000);
  await assert.rejects(service.execute('pay',{requestId:'payment-wrong',planId:'recovery-001',amountCents:30000,date:today}));
  assert.equal(Object.keys((await repo.read()).state.payments).length,1);
});
test('timeout dopo scrittura bancaria: ripresa con lo stesso id senza doppia spesa',async()=>{
  const {service,cash,repo}=await setup();cash.failAfterWrite=true;
  const operation=input('recovery-002','recovery',{amountCents:30000,startMonth:'2026-11',paymentDate:today});
  await assert.rejects(service.execute('create',operation));
  assert.equal((await service.view('2026-11')).adjustmentCents,0);assert.equal(cash.rows.size,1);
  await service.execute('create',operation);assert.equal(cash.rows.size,1);assert.equal((await service.view('2026-11')).adjustmentCents,-15000);
  assert.equal((await repo.read()).state.payments['recovery-002'].status,'posted');
});
test('richieste concorrenti e riavvio conservano un piano e un pagamento',async()=>{
  const {service,cash,db}=await setup();const operation=input('recovery-003','recovery',{startMonth:'2026-11',paymentDate:today});
  await Promise.all([service.execute('create',operation),service.execute('create',operation)]);
  const restarted=new PlanService(new D1PlanRepository(db),cash,today);
  await restarted.execute('create',operation);assert.equal(cash.rows.size,1);assert.equal((await restarted.view('2026-11')).plans.length,1);
  await assert.rejects(restarted.execute('create',{...operation,amountCents:100}));
});
test('anticipo di mese chiuso non cancellabile; annullamento mese aperto conserva somma zero',()=>{
  let state=make(initialState(),'advance-0004','advance',{startMonth:'2026-11',beneficiaryMonth:'2026-10'});
  assert.throws(()=>command(state,'stop',{requestId:'stop-advance1',planId:'advance-0004'},'2026-11-01'));
  state=command(state,'stop',{requestId:'stop-advance2',planId:'advance-0004'},today).state;
  assert.equal(project(state,'2026-10').adjustmentCents,0);assert.equal(project(state,'2026-11').adjustmentCents,0);
});
test('date, centesimi, importi e recuperi invalidi non producono pagamenti',()=>{
  for(const amountCents of [0,-1,1.1,NaN,Infinity,100000001])assert.throws(()=>make(initialState(),'invalid-0001','goal',{amountCents}));
  for(const paymentDate of ['2026-02-31','2026-10-18'])assert.throws(()=>make(initialState(),'invalid-0002','recovery',{paymentDate}));
  assert.throws(()=>make(initialState(),'invalid-0003','goal',{startMonth:'2026-09'}));
  const state=make(initialState(),'goal-000004','goal');
  assert.throws(()=>pay(state,'invalid-pay1','goal-000004',70000,{recoverDifference:true,recoveryStartMonth:'2026-12',recoveryEndMonth:'2026-11'}));
});
test('integrazione budget: quote e anticipi cambiano budget, non saldo',()=>{
  const state=make(initialState(),'advance-0005','advance',{amountCents:25000,startMonth:'2026-11',beneficiaryMonth:'2026-10'});
  const base={summary:{budget:4000,committedCurrent:500,remainingFree:3500,monthlyCommitted:1000,monthlyRemaining:800}};
  const result=augmentFinance(base,project(state,'2026-10'),project(state,'2026-10'));
  assert.equal(result.summary.monthlyRemaining,1050);assert.equal(result.summary.monthlyCommitted,750);assert.equal(result.summary.budget,4000);assert.equal(base.summary.monthlyRemaining,800);
});
test('wrapper nega origine errata o sessione mancante prima di creare tabelle',async()=>{
  let touched=false;const wrapper=withFinancePlans({fetch:async()=>new Response('Accesso richiesto',{status:401})},{repositoryFactory:()=>{touched=true;throw Error();}});
  for(const origin of ['https://wrong.invalid','https://lifeos.invalid']) {
    const response=await wrapper.fetch(new Request('https://lifeos.invalid/api/saveFinancePlan',{method:'POST',headers:{Origin:origin},body:'[{}]'}),{},{});
    assert.equal(response.status,origin.includes('wrong')?403:401);
  }
  assert.equal(touched,false);
});
test('wrapper preserva autenticazione e route esistenti, aggiorna overview e rispetta Roma',async()=>{
  const {repo,cash}=await setup();const base={async fetch(req) {
    if(new URL(req.url).pathname==='/api/getFinanceOverview')return new Response(JSON.stringify({summary:{budget:4000,committedCurrent:0,monthlyCommitted:1000,monthlyRemaining:800},transactions:[]}),{headers:{'Content-Type':'application/json'}});
    return new Response('legacy-route');
  }};
  const wrapper=withFinancePlans(base,{repositoryFactory:()=>repo,cashFactory:()=>cash,clock:()=>today});
  const request=(method,args)=>new Request('https://lifeos.invalid/api/'+method,{method:'POST',headers:{Origin:'https://lifeos.invalid'},body:JSON.stringify(args)});
  assert.equal((await wrapper.fetch(request('saveFinancePlan',[input('advance-0006','advance',{amountCents:25000,startMonth:'2026-11',beneficiaryMonth:'2026-10'})]),{},{})).status,200);
  const view=await (await wrapper.fetch(request('getFinanceOverview',[2026,10]),{},{})).json();assert.equal(view.summary.monthlyRemaining,1050);
  assert.equal(await (await wrapper.fetch(request('unrelated',[]),{},{})).text(),'legacy-route');
  assert.equal(romeToday(new Date('2026-10-17T22:30:00Z')),'2026-10-18');
});
