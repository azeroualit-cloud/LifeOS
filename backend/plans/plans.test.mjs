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
test('un nome legacy non viene ricreato e addebitato due volte',async()=>{
  const {repo,cash}=await setup();
  const base={async fetch(){return new Response(JSON.stringify({summary:{budget:1000},transactions:[],extraPlan:{allocations:[{name:'Manutenzione auto',status:'Programmato'}]}}),{headers:{'Content-Type':'application/json'}});}};
  const wrapper=withFinancePlans(base,{repositoryFactory:()=>repo,cashFactory:()=>cash,clock:()=>today});
  const response=await wrapper.fetch(new Request('https://lifeos.invalid/api/saveFinancePlan',{method:'POST',headers:{Origin:'https://lifeos.invalid'},body:JSON.stringify([input('duplicate-001','fund',{name:'Manutenzione auto'})])}),{},{});
  assert.equal(response.status,422);assert.equal(Object.keys((await repo.read()).state.plans).length,0);assert.equal(cash.calls,0);
});
test('un pagamento collegato non può essere modificato o cancellato dalla spesa rapida',async()=>{
  const {repo,cash,service}=await setup();await service.execute('create',input('linked-goal1'));
  await service.execute('pay',{requestId:'linked-pay01',planId:'linked-goal1',amountCents:60000,date:today});
  let edits=0;const base={async fetch(request){if(new URL(request.url).pathname==='/api/editMovement')edits++;
    return new Response(JSON.stringify({summary:{budget:1000},transactions:[]}),{headers:{'Content-Type':'application/json'}});}};
  const wrapper=withFinancePlans(base,{repositoryFactory:()=>repo,cashFactory:()=>cash,clock:()=>today});
  const response=await wrapper.fetch(new Request('https://lifeos.invalid/api/editMovement',{method:'POST',headers:{Origin:'https://lifeos.invalid'},body:JSON.stringify([{row:1,amount:1}])}),{},{});
  assert.equal(response.status,409);assert.equal(edits,0);
});
test('risposta legacy true senza identità non viene spacciata per pagamento confermato',async()=>{
  const {repo}=await setup();const rows=new Map();
  const base={async fetch(request){const method=new URL(request.url).pathname;
    if(method==='/api/saveTransaction') {const [p]=await request.json();rows.set(p.requestId,p);return new Response('true',{headers:{'Content-Type':'application/json'}});}
    return new Response(JSON.stringify({summary:{budget:1000},transactions:[]}),{headers:{'Content-Type':'application/json'}});
  }};
  const wrapper=withFinancePlans(base,{repositoryFactory:()=>repo,clock:()=>today});
  const operation=input('legacy-bool1','recovery',{paymentDate:today});
  for(let i=0;i<2;i++) {
    const response=await wrapper.fetch(new Request('https://lifeos.invalid/api/saveFinancePlan',{method:'POST',headers:{Origin:'https://lifeos.invalid'},body:JSON.stringify([operation])}),{},{});
    assert.equal(response.status,502);
  }
  assert.equal(rows.size,1);assert.equal((await repo.read()).state.payments['legacy-bool1'].status,'pending');
});
test('due dispositivi non possono pagare lo stesso obiettivo con identificatori diversi',async()=>{
  const {service,cash}=await setup();await service.execute('create',input('concurrent-goal'));
  const results=await Promise.allSettled(['concurrent-pay1','concurrent-pay2'].map(requestId=>service.execute('pay',{requestId,planId:'concurrent-goal',amountCents:60000,date:today})));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(cash.rows.size,1);
});

test('Worker 11.63: true risolto mediante APP-requestId, una riga reale anche dopo replay',async()=>{
  const {repo,db}=await setup();
  db.sqlite.exec('CREATE TABLE movements(source_row INTEGER PRIMARY KEY,import_id TEXT UNIQUE,amount REAL,actual_date TEXT,account TEXT,movement_type TEXT,status TEXT)');
  const base={async fetch(request){
    if(new URL(request.url).pathname==='/api/saveTransaction') {
      const [p]=await request.json();
      db.sqlite.prepare("INSERT OR IGNORE INTO movements VALUES (42,?,?,?,'Trade Republic','Spesa','Eseguito')").run('APP-'+p.requestId,-p.amount,p.date);
      return new Response('true',{headers:{'Content-Type':'application/json'}});
    }
    return Response.json({summary:{budget:1000},transactions:[]});
  }};
  const wrapper=withFinancePlans(base,{repositoryFactory:()=>repo,clock:()=>today});
  const operation=input('actual-ledger-01','recovery',{paymentDate:today});
  for(let i=0;i<2;i++) {
    const response=await wrapper.fetch(new Request('https://lifeos.invalid/api/saveFinancePlan',{method:'POST',headers:{Origin:'https://lifeos.invalid'},body:JSON.stringify([operation])}),{DB:db},{});
    assert.equal(response.status,200,await response.text());
  }
  assert.equal(db.sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,1);
  assert.equal((await repo.read()).state.payments['actual-ledger-01'].movementId,42);
  assert.equal((await repo.read()).state.payments['actual-ledger-01'].status,'posted');
});

test('Worker 11.63: riga con import_id corretto ma importo errato non conferma il pagamento',async()=>{
  const {repo,db}=await setup();
  db.sqlite.exec("CREATE TABLE movements(source_row INTEGER,import_id TEXT,amount REAL,actual_date TEXT,account TEXT,movement_type TEXT,status TEXT); INSERT INTO movements VALUES(42,'APP-wrong-ledger-01',-1,'2026-10-17','Trade Republic','Spesa','Eseguito')");
  const base={async fetch(request){return new URL(request.url).pathname==='/api/saveTransaction'?Response.json(true):Response.json({summary:{budget:1000},transactions:[]});}};
  const wrapper=withFinancePlans(base,{repositoryFactory:()=>repo,clock:()=>today});
  const response=await wrapper.fetch(new Request('https://lifeos.invalid/api/saveFinancePlan',{method:'POST',headers:{Origin:'https://lifeos.invalid'},body:JSON.stringify([input('wrong-ledger-01','recovery',{paymentDate:today})])}),{DB:db},{});
  assert.equal(response.status,502);assert.equal((await repo.read()).state.payments['wrong-ledger-01'].status,'pending');
});

test('funzione saveTransaction originale conservata: timeout dopo commit, ripresa e un solo delta saldo',async()=>{
  const {readFile}=await import('node:fs/promises');
  const source=await readFile(new URL('../worker-reference/save-transaction.mjs',import.meta.url),'utf8');
  const columns='source_row budget_date actual_date description amount account category movement_type status competence_months baseline counterparty_account notes merchant source_name import_id budget_month competence_end monthly_share actual_month transfer_id'.split(' ');
  const {repo,db}=await setup();
  db.sqlite.exec(`CREATE TABLE movements(${columns.map(c=>c==='source_row'?'source_row INTEGER PRIMARY KEY':c==='amount'?'amount REAL':c+' TEXT').join(',')});
    CREATE UNIQUE INDEX unique_import ON movements(import_id);
    CREATE TABLE finance_write_requests(id TEXT PRIMARY KEY,fingerprint TEXT);
    CREATE TABLE account_balance_events(id INTEGER PRIMARY KEY,account TEXT,day TEXT,delta_cents INTEGER,movement_source_row INTEGER,absorbed_snapshot_id INTEGER);
    CREATE TABLE movement_budget_policies(movement_source_row INTEGER PRIMARY KEY,treatment TEXT,recovery_json TEXT);`);
  db.batch=async statements=>{
    db.sqlite.exec('BEGIN');
    try {const result=[];for(const statement of statements)result.push(await statement.run());db.sqlite.exec('COMMIT');return result;}
    catch(error){db.sqlite.exec('ROLLBACK');throw error;}
  };
  const original=new Function('ensureBudgetPolicies','validCents','validDate','nowDay','validatedBudgetPolicy','MOVEMENT_COLUMNS','crypto',source+'\nreturn saveTransaction;')(
    async()=>{},amount=>Math.round(amount*100),value=>value,()=>today,()=>({treatment:'savings',recovery:[]}),columns,globalThis.crypto);
  let loseResponse=true;
  const base={async fetch(request){
    if(new URL(request.url).pathname==='/api/saveTransaction') {
      const [p]=await request.json();const result=await original({DB:db},p);
      if(loseResponse){loseResponse=false;return new Response('Synthetic response loss',{status:503});}
      return Response.json(result);
    }
    return Response.json({summary:{budget:1000},transactions:[]});
  }};
  const wrapper=withFinancePlans(base,{repositoryFactory:()=>repo,clock:()=>today});
  const request=()=>new Request('https://lifeos.invalid/api/saveFinancePlan',{method:'POST',headers:{Origin:'https://lifeos.invalid'},body:JSON.stringify([input('original-sql-01','recovery',{paymentDate:today})])});
  assert.equal((await wrapper.fetch(request(),{DB:db},{})).status,503);
  assert.equal((await repo.read()).state.payments['original-sql-01'].status,'pending');
  assert.equal((await wrapper.fetch(request(),{DB:db},{})).status,200);
  assert.equal(db.sqlite.prepare('SELECT COUNT(*) n FROM movements').get().n,1);
  assert.deepEqual({...db.sqlite.prepare('SELECT COUNT(*) n,SUM(delta_cents) delta FROM account_balance_events').get()},{n:1,delta:-60000});
  assert.equal((await repo.read()).state.payments['original-sql-01'].movementId,2);
});

// Legacy fixtures are synthetic. Adoption leaves original tables untouched.
const {adoptLegacy,replacement}=await import('./legacy.mjs');
function legacyContext() {
  return {overview:{summary:{budget:4000,committedCurrent:650,monthlyRemaining:1000,monthlyCommitted:800,monthlyBudgetBreakdown:[{name:'Affitto',amount:550},{name:'Condominio',amount:25},{name:'Gas',amount:50},{name:'Accantonamenti e straordinarie',amount:25}],recurringCommitments:[{name:'Affitto',remaining:550},{name:'Condominio',remaining:25},{name:'Gas',remaining:50},{name:'Straordinarie e auto',remaining:25}]},recurring:[{name:'Condominio',estimate:25,treatment:'Vincolata'},{name:'Gas',estimate:50,nextEstimate:80,treatment:'Vincolata'}],extraPlan:{allocations:[]}},cycles:[],allocations:[],links:[],movements:[]};
}
test('adozione affitto, condominio e utenze mantiene una sola quota e il saldo',()=>{
  const context=legacyContext(),state=adoptLegacy(initialState(),context,today),view=project(state,'2026-10');
  assert.equal(Object.keys(state.plans).length,3);assert.equal(replacement(context.overview,view),62500);
  const result=augmentFinance(context.overview,view,view);
  assert.equal(result.summary.monthlyCommitted,800);assert.equal(result.summary.monthlyRemaining,1000);assert.equal(result.summary.committedCurrent,650);assert.equal(result.summary.budget,4000);
  assert.equal(result.summary.monthlyBudgetBreakdown.filter(r=>r.name==='Affitto').length,1);
  assert.equal(project(state,'2026-11').plans.find(p=>p.name==='Gas').contributionCents,8000);
  assert.deepEqual(adoptLegacy(state,context,today),state);
});
test('adozione non riscrive mesi precedenti e interruzione non riattiva la quota legacy',()=>{
  const context=legacyContext();let state=adoptLegacy(initialState(),context,today);
  assert.equal(replacement(context.overview,project(state,'2026-09')),0);assert.equal(project(state,'2026-09').adjustmentCents,0);
  state=command(state,'stop',{requestId:'stop-legacy-rent',planId:'legacy-recurring-0'},today).state;
  const november={...context.overview,extraPlan:{allocations:[]}};
  const result=augmentFinance(november,project(state,'2026-11'),project(state,'2026-10'),context.overview);
  assert.equal(result.summary.monthlyRemaining,1520); // rent released, gas +30 from normalized bills
});
test('pagamento affitto già presente viene adottato senza nuovo addebito',()=>{
  const context=legacyContext();context.movements=[{source_row:42,amount:-550,actual_date:today,account:'Trade Republic',movement_type:'Spesa',status:'Eseguito',category:'Affitto',competence_months:1}];
  const state=adoptLegacy(initialState(),context,today);
  assert.equal(state.payments['legacy-cash-42'].movementId,42);assert.equal(project(state,'2026-10').plans.find(p=>p.name==='Affitto').fundCents,0);
  assert.deepEqual(adoptLegacy(state,context,today),state);
  assert.throws(()=>command(state,'pay',{requestId:'rent-paid-again',planId:'legacy-recurring-0',amountCents:55000,date:today},today));
});
test('manutenzione annuale diventa un fondo che conserva l’accumulato e continua dopo il pagamento',()=>{
  const context=legacyContext();context.cycles=[{id:1,extraordinary_source_row:4,name:'Manutenzione auto',kind:'expense',status:'Programmato',repeat_rule:'Annuale',start_month:'2026-01',end_month:'2026-12',total_cents:60000}];
  context.allocations=Array.from({length:12},(_,i)=>({cycle_id:1,month:'2026-'+String(i+1).padStart(2,'0'),amount_cents:5000}));
  let state=adoptLegacy(initialState(),context,today);
  assert.equal(project(state,'2026-10').plans.find(p=>p.id==='legacy-extra-4').fundCents,50000);
  state=command(state,'pay',{requestId:'maintenance-pay1',planId:'legacy-extra-4',amountCents:30000,date:today},today).state;
  state=completePayment(state,'maintenance-pay1',50,today);
  assert.equal(state.plans['legacy-extra-4'].status,'active');assert.equal(project(state,'2026-11').plans.find(p=>p.id==='legacy-extra-4').fundCents,25000);
  assert.equal(project(state,'2027-01').plans.find(p=>p.id==='legacy-extra-4').contributionCents,5000);
});
test('obiettivo legacy con pagamento parziale può saldare solo il residuo e chiudere le quote future',()=>{
  const context=legacyContext();context.cycles=[{id:1,extraordinary_source_row:4,name:'Progetto casa',kind:'expense',status:'Programmato',repeat_rule:'No',start_month:'2026-09',end_month:'2026-12',total_cents:60000}];
  context.allocations=['09','10','11','12'].map(m=>({cycle_id:1,month:'2026-'+m,amount_cents:15000}));
  context.links=[{cycle_id:1,movement_source_row:10,attributed_cents:50000,actual_date:'2026-09-20'}];
  let state=adoptLegacy(initialState(),context,today);
  assert.equal(project(state,'2026-10').plans.find(p=>p.id==='legacy-extra-4').outstandingCents,10000);
  state=command(state,'pay',{requestId:'legacy-remainder',planId:'legacy-extra-4',amountCents:10000,date:today},today).state;
  state=completePayment(state,'legacy-remainder',50,today);
  assert.equal(project(state,'2026-11').plans.find(p=>p.id==='legacy-extra-4').contributionCents,0);assert.equal(project(state,'2026-10').plans.find(p=>p.id==='legacy-extra-4').contributionCents,15000);
});
test('pagamento annuale non ripetibile spostando il mese dentro la stessa ricorrenza',()=>{
  let state=make(initialState(),'annual-rent1','fixed',{intervalMonths:12});
  state=pay(state,'annual-pay1','annual-rent1',60000);
  assert.throws(()=>command(state,'pay',{requestId:'annual-pay2',planId:'annual-rent1',amountCents:60000,date:'2026-11-17',cycleMonth:'2026-11'},'2026-11-17'));
});
test('modifica di quota e obiettivo decorre dal futuro e conserva il mese corrente',()=>{
  let state=make(initialState(),'edited-fund','fund',{amountCents:5000});
  state=command(state,'edit',{requestId:'edit-fund-01',planId:'edited-fund',amountCents:8000,fromMonth:'2026-11'},today).state;
  assert.equal(project(state,'2026-10').adjustmentCents,-5000);assert.equal(project(state,'2026-11').adjustmentCents,-8000);
  assert.throws(()=>command(state,'edit',{requestId:'edit-fund-02',planId:'edited-fund',amountCents:8000,fromMonth:'2026-10'},today));
  state=make(initialState(),'edited-goal');
  state=command(state,'edit',{requestId:'edit-goal-01',planId:'edited-goal',amountCents:80000,fromMonth:'2026-11',endMonth:'2026-12'},today).state;
  assert.equal(project(state,'2026-10').adjustmentCents,-20000);assert.equal(project(state,'2026-11').adjustmentCents,-30000);assert.equal(project(state,'2026-12').adjustmentCents,-30000);
});

test('packaging collega il registro originale direttamente dopo autenticazione, senza riclassificazione HTTP',async()=>{
  const {repo,db}=await setup();
  db.sqlite.exec('CREATE TABLE movements(source_row INTEGER PRIMARY KEY,import_id TEXT UNIQUE,amount REAL,actual_date TEXT,account TEXT,movement_type TEXT,status TEXT)');
  let legacyWrites=0, directWrites=0;
  const base={async fetch(request){if(new URL(request.url).pathname==='/api/saveTransaction'){legacyWrites++;return new Response('Not expected',{status:500});}return Response.json({summary:{budget:1000},transactions:[]});}};
  const wrapper=withFinancePlans(base,{repositoryFactory:()=>repo,clock:()=>today,recordTransaction:async(env,p)=>{
    directWrites++;env.DB.sqlite.prepare("INSERT OR IGNORE INTO movements VALUES(42,?,?,?,'Trade Republic','Spesa','Eseguito')").run('APP-'+p.requestId,-p.amount,p.date);return true;
  }});
  const operation=input('direct-ledger-01','recovery',{paymentDate:today});
  const request=()=>new Request('https://lifeos.invalid/api/saveFinancePlan',{method:'POST',headers:{Origin:'https://lifeos.invalid'},body:JSON.stringify([operation])});
  assert.equal((await wrapper.fetch(request(),{DB:db},{})).status,200);
  assert.equal((await wrapper.fetch(request(),{DB:db},{})).status,200);
  assert.equal(directWrites,1);assert.equal(legacyWrites,0);assert.equal((await repo.read()).state.payments['direct-ledger-01'].movementId,42);
});
