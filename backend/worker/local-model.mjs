import fixture from '../../shared/demo-data.json' with {type:'json'};
import {initialState,project,addMonth,month,day,months,split} from '../plans/engine.mjs';
import {PlanService} from '../plans/service.mjs';
import {expandEvents} from './events.mjs';
const copy=structuredClone;
const addDay=(value,n)=>new Date(Date.parse(value+'T12:00:00Z')+n*86400000).toISOString().slice(0,10);
const nextID=(rows,key='id')=>Math.max(0,...rows.map(r=>Number(r[key])||0))+1;
const title=(s)=>{s=String(s||'').trim();if(!s||s.length>160)throw Error('Inserisci un nome valido.');return s;};
export function demoArchive(today){
  const source=fixture.life.today,delta=Math.round((Date.parse(today)-Date.parse(source))/86400000),monthOffset=(Number(today.slice(0,4))-Number(source.slice(0,4)))*12+Number(today.slice(5,7))-Number(source.slice(5,7));
  function translate(value){
    if(typeof value==='string'&&/^20\d\d-\d\d-\d\d$/.test(value))return addDay(value,delta);
    if(typeof value==='string'&&/^20\d\d-\d\d$/.test(value))return addMonth(value,monthOffset);
    if(Array.isArray(value))return value.map(translate);
    if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,translate(v)]));
    return value;
  }
  const archive=translate(copy(fixture));
  archive.finance.yearly=(archive.finance.yearly||[]).map((row,i)=>({...row,month:today.slice(0,4)+'-'+String(i+1).padStart(2,'0')}));
  return {...archive,demo:true,pending:[],routineDay:today};
}
export function snapshotArchive(raw,fallbackMonth=new Date().toLocaleDateString('sv-SE',{timeZone:'Europe/Rome'}).slice(0,7)){
  const finance=raw?.current?.finance||raw?.finance||raw;
  if(!finance||!finance.summary||!['budget','committedCurrent','remainingFree'].every(k=>Number.isFinite(finance.summary[k]))||!Array.isArray(finance.transactions))throw Error('Snapshot finanziario non valido.');
  const ids=new Set();
  for(const r of finance.transactions){if(!Number.isFinite(r.amount)||!Number.isSafeInteger(r.row)||r.row<=0||ids.has(r.row)||typeof r.name!=='string'||!r.name)throw Error('Il JSON contiene un movimento non valido.');day(r.date,'2099-12-31');ids.add(r.row);}
  const dates=[...new Set(finance.transactions.map(r=>r.date.slice(0,7)))];
  const candidate=finance.key||raw?.current?.financeMonth||raw?.financeMonth;
  const key=/^20\d\d-(0[1-9]|1[0-2])$/.test(candidate)?candidate:dates.length===1?dates[0]:fallbackMonth;
  month(key);
  return {finance:copy(finance),life:{today:key+'-01',categories:[{key:'action',label:'Attività',position:0}],tasks:[],routines:[],shifts:[],events:[],occurrences:{}},plan:copy(finance.extraPlan||{}),pending:[],demo:false,imported:true,financeMonth:key,calendarMonth:key};
}
export class LocalModel {
  constructor(archive,today,persist=()=>{}){this.archive=copy(archive);this.today=today;this.persist=persist;this.planState=initialState();this.revision=0;}
  save(){this.persist(this);}
  finance(selected){
    const d=copy(this.archive.finance),v=project(this.planState,selected),current=project(this.planState,this.today.slice(0,7));
    const s=d.summary;d.key=selected;d.year=Number(selected.slice(0,4));d.month=Number(selected.slice(-2));d.updatedAt='Demo locale';d.extraPlan=copy(this.archive.plan);d.plansV2=v;
    s.monthlyRemaining=(s.monthlyRemaining||0)+v.adjustmentCents/100;s.monthlyCommitted=(s.monthlyCommitted||0)-v.adjustmentCents/100;s.committedCurrent+=current.plans.reduce((n,p)=>n+p.fundCents,0)/100;s.remainingFree=s.budget-s.committedCurrent;
    return d;
  }
  life(selected){
    const d=copy(this.archive.life),low=addMonth(selected,-1)+'-01',high=addMonth(selected,2)+'-01';
    const state=e=>({...e,occurrence_status:d.occurrences?.[`${e.id}:${e.day}`]||'open'});
    d.events=expandEvents(d.events||[],low,high).map(state).filter(e=>e.occurrence_status!=='skipped');
    d.upcomingEvents=expandEvents(this.archive.life.events||[],this.today,addDay(this.today,7)).map(state).filter(e=>e.occurrence_status==='open');d.today=this.today;d.month=selected;
    if(this.archive.routineDay!==this.today){for(const r of this.archive.life.routines||[])r.checked=0;this.archive.routineDay=this.today;d.routines=copy(this.archive.life.routines);this.save();}
    return d;
  }
  adjustMoney(next,old){
    const s=this.archive.finance.summary,contribution=(r,account)=>r?.account===account?r.amount:0;
    s.budget=Math.round((s.budget+contribution(next,'Trade Republic')-contribution(old,'Trade Republic'))*100)/100;s.remainingFree=s.budget-s.committedCurrent;
    s.revolutBalance=(s.revolutBalance||0)+contribution(next,'Revolut')-contribution(old,'Revolut');
    const ordinary=r=>r&&['Spesa','Rimborso'].includes(r.type)&&!['savings','planned','recovery'].includes(r.budgetTreatment)&&r.date.slice(0,7)===this.today.slice(0,7)?-r.amount:0;
    const delta=ordinary(next)-ordinary(old);s.monthlySpent=(s.monthlySpent||0)+delta;s.monthlyRemaining=(s.monthlyRemaining||0)-delta;
  }
  movement(p,editing=false){
    const rows=this.archive.finance.transactions;
    if(!editing&&p.requestId){const prior=rows.filter(r=>r.requestId===p.requestId).sort((a,b)=>a.row-b.row)[0];if(prior)return prior.row;}
    const amount=Number(p.amount);if(!Number.isFinite(amount)||amount<=0||amount>1000000||Math.abs(amount*100-Math.round(amount*100))>1e-6)throw Error('Importo non valido.');
    day(p.date,this.today);const name=title(p.name),type=p.type||'Spesa',account=p.account||'Trade Republic';
    const old=editing?rows.find(r=>r.row===Number(p.row)):null;if(editing&&!old)throw Error('Movimento non trovato.');
    if(editing&&Object.values(this.planState.payments).some(x=>x.movementId===old.row))throw Error('Gestisci il pagamento dal piano collegato.');
    const signed=type==='Trasferimento'&&old?.amount>0?amount:['Spesa','Trasferimento'].includes(type)?-amount:amount;
    const row={...p,row:old?.row||nextID(rows,'row'),amount:signed,name,type,account,months:Number(p.months)||1};
    if(type==='Trasferimento'){
      if(!p.counterpart||p.counterpart===account)throw Error('Scegli due conti diversi.');
      const pair=old?.transfer_id?rows.find(r=>r.transfer_id===old.transfer_id&&r.row!==old.row):null;
      if(old&&!pair)throw Error('Mantieni entrambi i conti del trasferimento.');
      row.transfer_id=old?.transfer_id||p.requestId||crypto.randomUUID();
      const other={...row,row:pair?.row||Math.max(nextID(rows,'row'),row.row+1),amount:-signed,account:p.counterpart,counterpart:account,name:'Trasferimento da '+account};
      if(pair)rows[rows.indexOf(pair)]=other;else rows.push(other);this.adjustMoney(other,pair);
    }
    if(old)rows[rows.indexOf(old)]=row;else rows.push(row);this.adjustMoney(row,old);return row.row;
  }
  async request(method,args=[]){
    const p=args[0]||{},id=Number(p.id??args[0]),life=this.archive.life,finance=this.archive.finance;
    const remove=(key)=>life[key]=life[key].filter(r=>r.id!==id);
    const update=(key,value,identity='id')=>{const rows=life[key],index=rows.findIndex(r=>r[identity]===value[identity]);if(index>=0)rows[index]={...rows[index],...value};else rows.push(value);return value;};
    if(method==='getLifeData')return this.life(args[0]||this.today.slice(0,7));
    if(['getFinanceData','getFinanceOverview','getFinanceExtras'].includes(method))return this.finance(`${args[0]}-${String(args[1]).padStart(2,'0')}`);
    if(method==='getFinancePlans')return project(this.planState,args[0]||this.today.slice(0,7));
    if(method==='getExtraPlan')return copy(this.archive.plan);
    if(method==='getExtraCycleDetail'){const row=this.archive.plan.allocations?.find(r=>r.cycle_id===Number(args[0]));if(!row)throw Error('Piano non trovato.');return {...copy(row),id:row.cycle_id,account:row.payment_account,links:copy((this.archive.plan.links||[]).filter(l=>l.cycle_id===row.cycle_id))};}
    if(method==='getMovement'){const r=finance.transactions.find(r=>r.row===Number(args[0]));if(!r)throw Error('Movimento non trovato.');return {...copy(r),source_row:r.row,description:r.name,actual_date:r.date,movement_type:r.type,competence_months:r.months||1,notes:r.note||''};}
    if(method==='getFinancePlanMovements')return {movements:finance.transactions.filter(r=>r.amount<0&&r.account==='Trade Republic'&&r.date.startsWith(args[0])&&!Object.values(this.planState.payments).some(p=>p.movementId===r.row)).map(r=>({row:r.row,name:r.name,date:r.date,amountCents:Math.round(-r.amount*100)}))};
    const actions={saveFinancePlan:'create',recordFinancePlanPayment:'pay',editFinancePlan:'edit',stopFinancePlan:'stop'};
    if(actions[method]||method==='resumeFinancePlanPayment'){
      const repo={read:async()=>({revision:this.revision,state:copy(this.planState)}),compareAndSet:async(revision,state)=>{if(revision!==this.revision)return false;this.planState=state;this.revision++;this.save();return true;}};
      const cash={record:async p=>{if(p.existingMovementId){const row=finance.transactions.find(r=>r.row===p.existingMovementId);if(!row||Math.round(-row.amount*100)!==p.amountCents||row.date!==p.date)throw Error('Movimento non compatibile.');if(!['savings','planned','recovery'].includes(row.budgetTreatment))this.adjustMoney({...row,budgetTreatment:'savings'},row);row.budgetTreatment='savings';this.save();return row.row;}const id=this.movement({...p,type:'Spesa',amount:p.amountCents/100,budgetTreatment:'savings',account:'Trade Republic',months:p.competenceMonths});this.save();return id;}};
      const service=new PlanService(repo,cash,this.today);if(method==='resumeFinancePlanPayment')await service.finish(p.paymentId);else await service.execute(actions[method],p);return {ok:true};
    }
    let result=true;
    switch(method){
      case 'saveTask':result=update('tasks',{...p,id:id||nextID(life.tasks),title:title(p.title),status:life.tasks.find(r=>r.id===id)?.status||'todo',sort_order:life.tasks.find(r=>r.id===id)?.sort_order||nextID(life.tasks,'sort_order')});break;
      case 'setTaskStatus':if(!['todo','waiting','done'].includes(p.status))throw Error('Stato non valido.');update('tasks',{...life.tasks.find(r=>r.id===id),id,status:p.status});break;
      case 'deleteTask':remove('tasks');break;
      case 'deleteCompletedTasks':life.tasks=life.tasks.filter(t=>t.list_kind!==p.category||t.status!=='done');break;
      case 'reorderTasks':life.tasks.forEach(t=>{const i=p.ids.indexOf(t.id);if(i>=0)t.sort_order=i+1;});break;
      case 'addCategory':{const label=title(p.label);if(life.categories.some(c=>c.label.toLowerCase()===label.toLowerCase()))throw Error('La categoria esiste già.');result=update('categories',{key:'custom-'+crypto.randomUUID(),label,position:life.categories.length},'key');break;}
      case 'renameCategory':result=update('categories',{...p,label:title(p.label)},'key');break;
      case 'reorderCategories':life.categories.forEach(c=>c.position=p.keys.indexOf(c.key));break;
      case 'deleteCategory':if(p.key===p.destination||!life.categories.some(c=>c.key===p.destination))throw Error('Scegli dove spostare le attività.');life.categories=life.categories.filter(c=>c.key!==p.key);life.tasks.forEach(t=>{if(t.list_kind===p.key)t.list_kind=p.destination;});break;
      case 'saveRoutine':if(!id&&life.routines.length>=8)throw Error('Massimo otto routine.');result=update('routines',{...p,id:id||nextID(life.routines),title:title(p.title),checked:life.routines.find(r=>r.id===id)?.checked||0});break;
      case 'deleteRoutine':remove('routines');break;
      case 'setRoutineCheck':if(p.day!==this.today)throw Error('È iniziato un nuovo giorno. Aggiorna le routine.');result=update('routines',{...life.routines.find(r=>r.id===id),id,checked:p.checked?1:0});break;
      case 'paintShift':life.shifts=life.shifts.filter(r=>r.day!==p.day);if(p.kind!=='erase')life.shifts.push(p);break;
      case 'saveEvent':{const old=life.events.find(e=>e.id===id);if(old&&(old.day!==p.day||old.frequency!==p.frequency)&&Object.keys(life.occurrences||{}).some(k=>k.startsWith(id+':')))throw Error('Usa Modifica da qui per preservare le occorrenze segnate.');result=update('events',{...p,id:id||nextID(life.events),title:title(p.title)});break;}
      case 'splitEventSeries':{const old=life.events.find(e=>e.id===id);if(!old)throw Error('Serie non trovata.');if(Object.keys(life.occurrences||{}).some(k=>k.startsWith(id+':')&&k.slice(-10)>=p.split_from))throw Error('Riapri prima le occorrenze future già segnate.');old.until_day=addDay(p.split_from,-1);result=update('events',{...p,id:nextID(life.events),title:title(p.title)});break;}
      case 'setEventOccurrence':life.occurrences??={};if(p.status==='open')delete life.occurrences[`${id}:${p.day}`];else life.occurrences[`${id}:${p.day}`]=p.status;break;
      case 'deleteEvent':remove('events');break;
      case 'saveTransaction':case 'editMovement':result=this.movement(p,method==='editMovement');break;
      case 'deleteMovement':{const row=finance.transactions.find(r=>r.row===id);if(Object.values(this.planState.payments).some(p=>p.movementId===id))throw Error('Gestisci il pagamento dal piano collegato.');const removed=finance.transactions.filter(r=>r.row===id||row?.transfer_id&&r.transfer_id===row.transfer_id);finance.transactions=finance.transactions.filter(r=>!removed.includes(r));removed.forEach(r=>this.adjustMoney(null,r));break;}
      case 'saveEstimate':{const row=finance.recurring.find(r=>r.name===args[0]);if(!row||Number(args[1])<=0)throw Error('Stima non valida.');row.estimate=Number(args[1]);break;}
      case 'savePlanningSettings':if(args.some(n=>!Number.isFinite(Number(n)))||Number(args[0])<0||Number(args[2])<=0)throw Error('Impostazioni non valide.');finance.planning={...finance.planning,goal:Number(args[0]),monthlySaving:Number(args[1]),savingsTarget:Number(args[2])};break;
      case 'updateExtraPlan':{
        const plan=this.archive.plan,old=plan.allocations.find(r=>r.cycle_id===Number(p.cycleId));if(!old)throw Error('Piano non trovato.');const range=months(p.month,p.endMonth,60),cents=Math.round(Number(p.amount)*100),shares=split(cents,range.length),linked=(plan.links||[]).filter(l=>l.cycle_id===old.cycle_id).reduce((n,l)=>n+l.attributed_cents,0);if(cents<linked)throw Error('Il piano non può scendere sotto quanto già attribuito.');plan.allocations=plan.allocations.filter(r=>r.cycle_id!==old.cycle_id);range.forEach((m,i)=>plan.allocations.push({...old,name:title(p.name),month:m,start_month:p.month,end_month:p.endMonth,total_cents:cents,amount_cents:shares[i],notes:p.note||''}));break;
      }
      case 'recordExtraPayment':case 'markExtraPaid':case 'cancelExtraCycle':case 'deleteExtraPlan':{
        const plan=this.archive.plan,cycle=Number(p.cycleId),row=plan.allocations.find(r=>r.cycle_id===cycle);if(!row)throw Error('Piano non trovato.');
        if(method==='deleteExtraPlan'){if(row.status!=='Annullato'||(plan.links||[]).some(l=>l.cycle_id===cycle))throw Error('Annulla prima il piano e conserva i pagamenti collegati.');plan.allocations=plan.allocations.filter(r=>r.cycle_id!==cycle);break;}
        if(method==='recordExtraPayment'&&row.status!=='Pagato'){
          const movement=this.movement({...p,requestId:p.requestId||'legacy-payment-'+cycle,type:'Spesa',name:p.name||row.name,category:'Straordinarie',budgetTreatment:'savings',account:'Trade Republic'}),actual=Math.round(Number(p.amount)*100);
          plan.links??=[];plan.settlements??=[];plan.links.push({cycle_id:cycle,movement_source_row:movement,attributed_cents:Math.min(actual,row.total_cents),role:'payment'});plan.settlements.push({cycle_id:cycle,movement_source_row:movement,actual_cents:actual,planned_cents:row.total_cents});
        }
        plan.allocations.forEach(r=>{if(r.cycle_id===cycle)r.status=method==='cancelExtraCycle'?'Annullato':'Pagato';});break;
      }
      case 'linkExtraMovement':case 'unlinkExtraMovement':{
        const plan=this.archive.plan,cycle=Number(p.cycleId),movement=Number(p.movementId),row=plan.allocations.find(r=>r.cycle_id===cycle);if(!row)throw Error('Piano non trovato.');plan.links??=[];
        if(method==='unlinkExtraMovement')plan.links=plan.links.filter(l=>l.cycle_id!==cycle||l.movement_source_row!==movement);
        else{const cash=finance.transactions.find(r=>r.row===movement),amount=Math.round(Number(p.amount)*100),used=plan.links.filter(l=>l.movement_source_row===movement).reduce((n,l)=>n+l.attributed_cents,0),paid=plan.links.filter(l=>l.cycle_id===cycle).reduce((n,l)=>n+l.attributed_cents,0);if(!cash||cash.amount>=0||cash.budgetTreatment==='recovery'||['Pagato','Annullato'].includes(row.status)||amount<=0||amount+used>Math.round(-cash.amount*100)||amount+paid>row.total_cents||plan.links.some(l=>l.cycle_id===cycle&&l.movement_source_row===movement))throw Error('Movimento o importo non compatibile con il piano.');plan.links.push({cycle_id:cycle,movement_source_row:movement,attributed_cents:amount,role:'payment'});}
        const paid=plan.links.filter(l=>l.cycle_id===cycle).reduce((n,l)=>n+l.attributed_cents,0);plan.allocations.forEach(r=>{if(r.cycle_id===cycle)r.status=paid>=row.total_cents?'Pagato':'Programmato';});break;
      }
      default:throw Error('Questa azione richiede il server collegato.');
    }
    this.save();return copy(result);
  }
}
