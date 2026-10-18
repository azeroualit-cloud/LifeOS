import test from 'node:test';
import assert from 'node:assert/strict';
import {LocalModel,demoArchive,snapshotArchive} from './local-model.mjs';
const today='2026-10-17',month='2026-10';
const make=()=>new LocalModel(demoArchive(today),today);
test('demo uses the native fixture and preserves category, habit and task flows',async()=>{
 const m=make(),initial=await m.request('getLifeData',[month]);assert.deepEqual(initial.categories.map(c=>c.label),['Attività','Desideri','Giochi','Letture']);assert.equal(initial.today,today);
 const c=await m.request('addCategory',[{label:'Progetti'}]);
 const t=await m.request('saveTask',[{title:'Attività demo',list_kind:c.key}]);await m.request('setTaskStatus',[{id:t.id,status:'waiting'}]);assert.equal(m.archive.life.tasks.find(r=>r.id===t.id).status,'waiting');
 await m.request('deleteCategory',[{key:c.key,destination:'action'}]);assert.equal(m.archive.life.tasks.find(r=>r.id===t.id).list_kind,'action');
 await m.request('setTaskStatus',[{id:t.id,status:'done'}]);await m.request('deleteCompletedTasks',[{category:'action'}]);assert.ok(!m.archive.life.tasks.some(r=>r.id===t.id));
 const routine=await m.request('saveRoutine',[{title:'Acqua'}]);await m.request('setRoutineCheck',[{id:routine.id,day:today,checked:true}]);assert.equal(m.archive.life.routines.find(r=>r.id===routine.id).checked,1);
 await assert.rejects(()=>m.request('setRoutineCheck',[{id:routine.id,day:'2026-10-16',checked:true}]));
});
test('calendar recurrence, occurrence status, painting and future split preserve history',async()=>{
 const m=make();await m.request('paintShift',[{day:today,kind:'night'}]);assert.equal(m.life(month).shifts.find(r=>r.day===today).kind,'night');
 const e=await m.request('saveEvent',[{title:'Evento',day:today,frequency:'weekly',start_time:'12:00'}]);assert.ok(m.life(month).events.some(r=>r.id===e.id&&r.day==='2026-10-24'));
 await m.request('setEventOccurrence',[{id:e.id,day:today,status:'done'}]);assert.equal(m.life(month).events.find(r=>r.id===e.id&&r.day===today).occurrence_status,'done');
 await assert.rejects(()=>m.request('saveEvent',[{...e,day:'2026-10-18'}]),/Modifica da qui/);
 const next=await m.request('splitEventSeries',[{...e,split_from:'2026-10-24',day:'2026-10-24',title:'Nuovo evento'}]);assert.notEqual(next.id,e.id);assert.equal(m.archive.life.events.find(r=>r.id===e.id).until_day,'2026-10-23');
});
test('demo movements, transfers and legacy actual payments preserve one cash effect',async()=>{
 const m=make(),before=m.archive.finance.summary.budget;
 const p={requestId:'synthetic-movement-1',name:'Spesa',amount:25,date:today,type:'Spesa',account:'Trade Republic',category:'Casa'};
 const row=await m.request('saveTransaction',[p]);await m.request('saveTransaction',[p]);assert.equal(m.archive.finance.summary.budget,before-25);
 await m.request('editMovement',[{...p,row,amount:30}]);assert.equal(m.archive.finance.summary.budget,before-30);
 await m.request('deleteMovement',[row]);assert.equal(m.archive.finance.summary.budget,before);
 await m.request('saveTransaction',[{...p,requestId:'synthetic-transfer-1',type:'Trasferimento',account:'Revolut',counterpart:'Trade Republic',amount:40}]);assert.equal(m.archive.finance.summary.budget,before+40);
 const transfer=m.archive.finance.transactions.find(r=>r.requestId==='synthetic-transfer-1');await m.request('deleteMovement',[transfer.row]);assert.equal(m.archive.finance.summary.budget,before);
 const legacy=await m.request('getExtraCycleDetail',[1]);assert.equal(legacy.name,'Manutenzione auto');
 await m.request('recordExtraPayment',[{cycleId:1,requestId:'synthetic-legacy-1',name:legacy.name,amount:200,date:today}]);await m.request('recordExtraPayment',[{cycleId:1,requestId:'synthetic-legacy-1',name:legacy.name,amount:200,date:today}]);assert.equal(m.archive.finance.summary.budget,before-200);
});
test('demo plans use the actual server engine: zero-cash advance, one goal payment and continuous fund',async()=>{
 const m=make(),cash=m.archive.finance.summary.budget;
 await m.request('saveFinancePlan',[{requestId:'synthetic-advance-1',kind:'advance',name:'Anticipo',amountCents:25000,beneficiaryMonth:month,startMonth:'2026-11',endMonth:'2026-12'}]);assert.equal(m.finance(month).plansV2.adjustmentCents,25000);assert.equal(m.finance('2026-11').plansV2.adjustmentCents,-12500);assert.equal(m.archive.finance.summary.budget,cash);
 const goal={requestId:'synthetic-goal-1',kind:'goal',name:'Obiettivo',amountCents:60000,startMonth:month,endMonth:'2026-12'};await m.request('saveFinancePlan',[goal]);
 const payment={requestId:'synthetic-payment-1',planId:goal.requestId,amountCents:50000,date:today};await m.request('recordFinancePlanPayment',[payment]);await m.request('recordFinancePlanPayment',[payment]);assert.equal(m.archive.finance.summary.budget,cash-500);assert.equal(m.finance(month).plansV2.plans.find(p=>p.id===goal.requestId).status,'closed');
 const fund={requestId:'synthetic-fund-1',kind:'fund',name:'Fondo',amountCents:5000,startMonth:month};await m.request('saveFinancePlan',[fund]);await m.request('recordFinancePlanPayment',[{requestId:'synthetic-fund-payment-1',planId:fund.requestId,amountCents:4000,date:today}]);assert.equal(m.finance(month).plansV2.plans.find(p=>p.id===fund.requestId).status,'active');
});
test('snapshots preserve finance fields and reject incomplete or malformed input',()=>{
 const finance=make().finance(month),snapshot=snapshotArchive(finance);assert.deepEqual(snapshot.finance,finance);assert.equal(snapshot.financeMonth,month);assert.equal(snapshot.demo,false);
 assert.throws(()=>snapshotArchive({summary:{budget:1},transactions:[]}));assert.throws(()=>snapshotArchive({...finance,transactions:[{row:1,amount:'wrong'}]}));
 const row={row:1,amount:-10,name:'Voce',date:'2026-09-12'};
 assert.equal(snapshotArchive({summary:finance.summary,transactions:[row]}).financeMonth,'2026-09');
 assert.throws(()=>snapshotArchive({...finance,transactions:[row,row]}));assert.throws(()=>snapshotArchive({...finance,transactions:[{...row,date:'2026-02-30'}]}));
});
