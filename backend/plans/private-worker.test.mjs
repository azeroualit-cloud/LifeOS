// Runs against the complete privately archived Worker; never embeds bank fixtures.
// LIFEOS_PRIVATE_WORKER=/private/worker-plans.mjs node --test --test-isolation=none backend/plans/private-worker.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {pathToFileURL} from 'node:url';

test('Worker completo: autenticazione, adozione, pagamento, saldo e mesi storici', {skip:!process.env.LIFEOS_PRIVATE_WORKER}, async(t)=>{
  let worker=(await import(pathToFileURL(process.env.LIFEOS_PRIVATE_WORKER))).default;
  const sql=new DatabaseSync(':memory:');
  const columns='budget_date actual_date description amount account category movement_type status competence_months baseline counterparty_account notes merchant source_name import_id budget_month competence_end monthly_share actual_month transfer_id'.split(' ');
  sql.exec(`
    CREATE TABLE source_rows(sheet TEXT,row_number INTEGER,values_json TEXT,PRIMARY KEY(sheet,row_number));
    CREATE TABLE os_meta(key TEXT PRIMARY KEY,value TEXT NOT NULL);
    CREATE TABLE movements(source_row INTEGER PRIMARY KEY,${columns.map(c=>c+' '+(['amount','monthly_share'].includes(c)?'REAL':'TEXT')).join(',')});
    CREATE TABLE extraordinary(source_row INTEGER PRIMARY KEY,name TEXT,total REAL,start_month TEXT,month_count INTEGER,monthly_share REAL,end_month TEXT,status TEXT,payment_account TEXT,paid_date TEXT,notes TEXT,repeat_rule TEXT);
    CREATE TABLE extraordinary_cycles(id INTEGER PRIMARY KEY,extraordinary_source_row INTEGER,start_month TEXT,end_month TEXT,total_cents INTEGER,kind TEXT,status TEXT,UNIQUE(extraordinary_source_row,start_month));
    CREATE TABLE extraordinary_allocations(cycle_id INTEGER,month TEXT,amount_cents INTEGER,PRIMARY KEY(cycle_id,month));
    CREATE TABLE extraordinary_movement_links(cycle_id INTEGER,movement_source_row INTEGER,attributed_cents INTEGER,role TEXT,PRIMARY KEY(cycle_id,movement_source_row));
    CREATE TABLE account_balance_snapshots(id INTEGER PRIMARY KEY,account TEXT,as_of_day TEXT,amount_cents INTEGER,event_watermark INTEGER);
    CREATE TABLE account_balance_events(id INTEGER PRIMARY KEY,account TEXT,day TEXT,delta_cents INTEGER,movement_source_row INTEGER,absorbed_snapshot_id INTEGER);
    INSERT INTO account_balance_snapshots VALUES(1,'Trade Republic','2026-10-01',400000,0);
    INSERT INTO extraordinary VALUES(2,'Manutenzione auto',600,'2026-01-01',12,50,'2026-12-01','Programmato','Trade Republic',NULL,'','Annuale');
  `);
  const config=sql.prepare('INSERT INTO source_rows VALUES(?,?,?)');
  const recurring=[['Elettricità',30],['Gas',40],['Acqua',20],['Palestra',25],['Abbonamenti',10],['Benzina',100]];
  for(let i=1;i<=14;i++){const r=Array(15).fill('');if(i>=2&&i<=7){r[0]=recurring[i-2][0];r[1]=recurring[i-2][1];r[2]=i===7?'Libera':'Vincolata';}if(i===2)r[14]=1800;if(i===3)r[14]=575;if(i===4)r[14]=50;config.run('Budget',i,JSON.stringify(r));}
  config.run('Patrimonio',2,JSON.stringify(['Trade Republic',4000,'2026-10-01']));
  config.run('Estratto TR verificato',1,JSON.stringify([{version:2,conflicts:[],rows:[],fixes:[],classifications:[],cashflow:{},from:'2026-10-01',to:'2026-10-01',opening:400000,closing:400000,incoming:0,outgoing:0}]));
  let queryCount=0;const paymentQueries=[];
  const db={prepare(query){let args=[];return {bind(...values){args=values;return this;},async run(){queryCount++;const r=sql.prepare(query).run(...args);return {meta:{changes:Number(r.changes),last_row_id:Number(r.lastInsertRowid)}};},async first(){queryCount++;return sql.prepare(query).get(...args)??null;},async all(){queryCount++;return {results:sql.prepare(query).all(...args)};}};},async batch(statements){sql.exec('BEGIN');try{const result=[];for(const s of statements)result.push(await s.run());sql.exec('COMMIT');return result;}catch(error){sql.exec('ROLLBACK');throw error;}}};
  const env={DB:db,APP_PASSWORD:'synthetic-test-password-at-least-24-chars'};
  const request=(method,args=[],authorized=true)=>new Request('https://test.invalid/api/'+method,{method:'POST',headers:{Origin:'https://test.invalid','X-LifeOS-Plans-Version':'2',...(authorized?{Authorization:'Basic '+Buffer.from('nas:'+env.APP_PASSWORD).toString('base64')}:{})},body:JSON.stringify(args)});
  async function api(method,args=[]){queryCount=0;const response=await worker.fetch(request(method,args),env,{});const value=await response.text();assert.equal(response.status,200,method+': '+value.slice(0,300));if(['getFinanceCategoryOptions','getFinanceData','getFinanceOverview'].includes(method)){assert.ok(queryCount<=50,method+' esegue '+queryCount+' query SQL');t.diagnostic(method+' SQL: '+queryCount);}if(method==='recordFinancePlanPayment'){paymentQueries.push(queryCount);assert.ok(queryCount<=50,'Pagamento esegue '+queryCount+' query SQL');}return JSON.parse(value);}
  assert.equal((await worker.fetch(request('getFinancePlans',[],false),env,{})).status,401);
  const oldRequest=request('getFinanceOverview',[2026,10]);oldRequest.headers.delete('X-LifeOS-Plans-Version');
  const oldResponse=await worker.fetch(oldRequest,env,{});assert.equal(oldResponse.status,200);
  const oldOverview=await oldResponse.json();assert.equal(oldOverview.plansV2.plans.length,0);assert.ok(oldOverview.extraPlan.allocations.length>0);
  assert.equal(sql.prepare('SELECT COUNT(*) n FROM movements').get().n,0);
  const legacyBefore=sql.prepare('SELECT * FROM extraordinary').all();
  const overview=await api('getFinanceOverview',[2026,10]);
  assert.equal(overview.summary.monthlyRemaining,oldOverview.summary.monthlyRemaining);
  assert.deepEqual(sql.prepare('SELECT * FROM extraordinary').all(),legacyBefore);
  assert.equal(sql.prepare('SELECT COUNT(*) n FROM account_balance_events').get().n,0);
  assert.equal(overview.summary.budget,4000);assert.equal(overview.plansV2.version,2);
  assert.equal(overview.plansV2.plans.filter(p=>p.name==='Affitto').length,1);
  assert.equal(overview.summary.monthlyBudgetBreakdown.filter(p=>p.name==='Affitto').length,1);
  assert.equal(overview.extraPlan.allocations.length,0);
  const historical=(await api('getFinanceOverview',[2026,9])).summary.monthlyRemaining;
  const rent=overview.plansV2.plans.find(p=>p.name==='Affitto');
  await api('recordFinancePlanPayment',[{requestId:'full-worker-rent-1',planId:rent.id,amountCents:55000,date:'2026-10-17',cycleMonth:'2026-10'}]);
  await api('recordFinancePlanPayment',[{requestId:'full-worker-rent-1',planId:rent.id,amountCents:55000,date:'2026-10-17',cycleMonth:'2026-10'}]);
  const after=await api('getFinanceOverview',[2026,10]);
  assert.equal(after.summary.budget,3450);assert.equal(after.summary.monthlyRemaining,overview.summary.monthlyRemaining);
  assert.equal(after.summary.committedCurrent,overview.summary.committedCurrent-550);
  assert.equal(sql.prepare('SELECT COUNT(*) n FROM movements').get().n,1);
  assert.equal(sql.prepare('SELECT COUNT(*) n FROM account_balance_events').get().n,1);
  assert.equal((await api('getFinanceOverview',[2026,9])).summary.monthlyRemaining,historical);
  const linked=after.plansV2.payments.find(p=>p.planId===rent.id);
  assert.equal((await worker.fetch(request('deleteMovement',[linked.movementId]),env,{})).status,409);
  assert.equal(sql.prepare('SELECT COUNT(*) n FROM movements').get().n,1);
  await api('saveTransaction',[{requestId:'already-recorded-1',name:'Spesa esistente',type:'Spesa',category:'Altro',account:'Trade Republic',amount:200,date:'2026-10-17',budgetTreatment:'savings'}]);
  const movement=(await api('getFinancePlanMovements',['2026-10'])).movements.find(r=>r.name==='Spesa esistente');
  assert.ok(movement);
  const beforeRecovery=(await api('getFinanceOverview',[2026,10])).summary.budget;
  await api('saveFinancePlan',[{requestId:'existing-recovery-1',kind:'recovery',name:'Recupero spesa esistente',amountCents:20000,startMonth:'2026-11',endMonth:'2026-12',paymentDate:movement.date,movementId:movement.row}]);
  assert.equal((await api('getFinanceOverview',[2026,10])).summary.budget,beforeRecovery);
  assert.equal(sql.prepare('SELECT COUNT(*) n FROM movements').get().n,2);
  assert.equal(sql.prepare('SELECT COUNT(*) n FROM account_balance_events').get().n,2);
  const november=await api('getFinanceOverview',[2026,11]);assert.ok(november.summary.monthlyBudgetBreakdown.some(r=>r.name==='Recupero spesa esistente'&&r.amount===100));
  const beforeBill=await api('getFinanceOverview',[2026,10]);
  const bill={requestId:'quick-gas-bill-01',type:'Spesa',account:'Trade Republic',name:'Bolletta sintetica',category:'Gas',amount:120,date:'2026-10-17',months:2,budgetTreatment:'auto'};
  await api('saveTransaction',[bill]);await api('saveTransaction',[bill]);
  const afterBill=await api('getFinanceOverview',[2026,10]);
  assert.equal(afterBill.summary.budget,beforeBill.summary.budget-120);assert.equal(afterBill.summary.monthlyRemaining,beforeBill.summary.monthlyRemaining);
  assert.equal((await api('getFinanceOverview',[2026,11])).plansV2.plans.find(p=>p.name==='Gas').contributionCents,6000);
  const gas=afterBill.plansV2.plans.find(p=>p.name==='Gas');
  await api('editFinancePlan',[{requestId:'edit-gas-future-01',planId:gas.id,amountCents:7000,fromMonth:'2026-12'}]);
  assert.equal((await api('getFinanceOverview',[2026,10])).summary.monthlyRemaining,afterBill.summary.monthlyRemaining);
  assert.equal((await api('getFinanceOverview',[2026,12])).plansV2.plans.find(p=>p.name==='Gas').contributionCents,7000);
  assert.equal(sql.prepare('SELECT COUNT(*) n FROM movements').get().n,3);
  assert.equal(sql.prepare('SELECT COUNT(*) n FROM account_balance_events').get().n,3);
  const historicalAgain=(await api('getFinanceOverview',[2026,9])).summary.monthlyRemaining;
  assert.equal(historicalAgain,historical);
  await api('getFinanceCategoryOptions');
  const analysis=await api('getFinanceData',[2026,10]);
  await api('getFinanceData',[2026,9]);
  assert.equal(analysis.summary.budget,afterBill.summary.budget);
  assert.equal(analysis.forecastPlan.allocations.filter(r=>r.extraordinary_source_row===2).length,0);
  assert.equal(analysis.plansV2.plans.filter(p=>p.name==='Manutenzione auto').length,1);
  worker=(await import(pathToFileURL(process.env.LIFEOS_PRIVATE_WORKER).href+'?cold-start')).default;
  await api('getFinanceData',[2026,9]);
  const maintenance=analysis.plansV2.plans.find(p=>p.name==='Manutenzione auto');
  await api('recordFinancePlanPayment',[{requestId:'cold-maintenance-01',planId:maintenance.id,amountCents:2500,date:'2026-10-17'}]);
  assert.equal(sql.prepare('SELECT COUNT(*) n FROM account_balance_events').get().n,4);
  t.diagnostic('Query SQL per pagamento (prima registrazione, replay, cold start): '+paymentQueries.join(', '));


});
