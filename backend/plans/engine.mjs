// Pure financial-plan rules. Money is always integer cents; dates are Rome civil dates.
export class PlanError extends Error { constructor(message, status=422) { super(message); this.status=status; } }
const fail = message => { throw new PlanError(message); };
export const kinds = ['advance','goal','fund','fixed','estimated','recovery'];
export function month(value) {
  if (typeof value !== 'string' || !/^20\d\d-(0[1-9]|1[0-2])$/.test(value)) fail('Scegli mese e anno validi.');
  return value;
}
export function addMonth(value, count) {
  month(value); const [y,m]=value.split('-').map(Number), date=new Date(Date.UTC(y,m-1+count,1));
  return date.toISOString().slice(0,7);
}
export function months(first, last, limit=240) {
  month(first); month(last); if (last < first) fail('L’ultimo mese precede il primo.');
  const count=(Number(last.slice(0,4))-Number(first.slice(0,4)))*12+Number(last.slice(-2))-Number(first.slice(-2))+1;
  if(count>limit) fail('Il piano finito può coprire al massimo 240 mesi; per un fondo usa Senza scadenza.');
  return Array.from({length:count},(_,i)=>addMonth(first,i));
}
export function cents(value) { if (!Number.isSafeInteger(value)||value<=0||value>100000000) fail('Importo non valido.'); return value; }
export function split(total,count) {
  cents(total); if(!Number.isInteger(count)||count<1||count>240) fail('Numero di mesi non valido.');
  return Array.from({length:count},(_,i)=>Math.floor(total/count)+(i<total%count?1:0));
}
export function day(value,today) {
  if(typeof value!=='string'||!/^20\d\d-(0[1-9]|1[0-2])-\d\d$/.test(value)) fail('Data del pagamento non valida.');
  const parsed=new Date(value+'T12:00:00Z');
  if(!Number.isFinite(parsed.getTime())||parsed.toISOString().slice(0,10)!==value||value>today) fail('La data deve essere valida e non futura.');
  return value;
}
export function newPlan(input,today,id) {
  const kind=input.kind, current=month(today.slice(0,7));
  if(!kinds.includes(kind)) fail('Scegli il tipo di piano.');
  const name=String(input.name??'').trim(); if(!name||name.length>120) fail('Inserisci un nome di massimo 120 caratteri.');
  const first=month(input.startMonth); if(first<current) fail('Le quote nuove possono iniziare dal mese corrente.');
  const finite=['advance','goal','recovery'].includes(kind), last=finite?month(input.endMonth):null;
  const amount=cents(input.amountCents), interval=Number(input.intervalMonths??1);
  const category=String(input.category??'Altro').trim();if(!category||category.length>60)fail('Categoria non valida.');
  if(!Number.isInteger(interval)||interval<1||interval>12) fail('Periodicità non valida.');
  if(finite) months(first,last);
  const plan={id,name,category,kind,amountCents:amount,startMonth:first,endMonth:last,intervalMonths:interval,
    createdDay:today,status:'active',stopAfter:null,closedMonth:null,rateChanges:[]};
  if(kind==='advance') {
    plan.beneficiaryMonth=month(input.beneficiaryMonth);
    if(plan.beneficiaryMonth<current||plan.beneficiaryMonth>=first) fail('Il mese beneficiario deve essere aperto e precedere i mesi di recupero.');
  }
  if(kind==='recovery') { plan.paymentDate=day(input.paymentDate,today); if(first<plan.paymentDate.slice(0,7)) fail('Il recupero non può precedere il pagamento.'); plan.status='pendingPayment'; }
  return plan;
}
export function contribution(plan,m) {
  month(m); if(plan.status==='cancelled'||plan.status==='pendingPayment') return 0;
  if(plan.kind==='advance') {
    if(m===plan.beneficiaryMonth) return -plan.amountCents;
  }
  if(m<plan.startMonth||(plan.endMonth&&m>plan.endMonth)||(plan.stopAfter&&m>plan.stopAfter)||(plan.closedMonth&&m>plan.closedMonth)) return 0;
  if(plan.legacySchedule) return Number(plan.legacySchedule[m]??0);
  if(['advance','goal','recovery'].includes(plan.kind)) {
    const range=months(plan.startMonth,plan.endMonth), i=range.indexOf(m); return i<0?0:split(plan.amountCents,range.length)[i];
  }
  if(plan.kind==='fixed') {
    const anchor=plan.intervalAnchor??plan.startMonth;
    const delta=(Number(m.slice(0,4))-Number(anchor.slice(0,4)))*12+Number(m.slice(-2))-Number(anchor.slice(-2));
    let amount=plan.amountCents;for(const rate of plan.rateChanges??[])if(rate.fromMonth<=m)amount=rate.amountCents;
    return amount===0?0:split(amount,plan.intervalMonths)[((delta%plan.intervalMonths)+plan.intervalMonths)%plan.intervalMonths];
  }
  let rate=plan.amountCents;
  for(const change of plan.rateChanges??[]) if(change.fromMonth<=m) rate=change.amountCents;
  return rate;
}
export function adjustment(plans,m) { return -Object.values(plans).reduce((sum,p)=>sum+contribution(p,m),0)||0; }
export function requestKey(value) {
  if(typeof value!=='string'||!/^[a-zA-Z0-9-]{8,80}$/.test(value)) fail('Identificatore operazione non valido.'); return value;
}
export function initialState() { return {version:1,plans:{},payments:{},commands:{}}; }
function fingerprint(input) { return JSON.stringify(Object.fromEntries(Object.entries(input).filter(([k])=>k!=='requestId').sort(([a],[b])=>a.localeCompare(b)))); }
export function command(state,action,input,today) {
  const next=structuredClone(state), key=requestKey(input.requestId), signature=fingerprint({action,...input});
  if(next.commands[key]) {
    if(next.commands[key].signature!==signature) fail('Questa operazione è già stata usata con dati diversi.');
    return {state:next,result:next.commands[key].result};
  }
  let result;
  if(action==='create') {
    const plan=newPlan(input,today,key); next.plans[key]=plan;
    if(plan.kind==='recovery') reservePayment(next,plan,{...input,amountCents:plan.amountCents,date:plan.paymentDate},today,key);
    result={planId:key,paymentId:plan.kind==='recovery'?key:null};
  } else {
    const plan=next.plans[input.planId]; if(!plan) fail('Piano non trovato.');
    if(action==='pay') {
      if(['advance','recovery'].includes(plan.kind)) fail('Questo piano non prevede un nuovo pagamento.');
      if(plan.status!=='active') fail('Il piano non è attivo.');
      reservePayment(next,plan,input,today,key); result={planId:plan.id,paymentId:key};
    } else if(action==='deletePayment') {
      const payment=next.payments[input.paymentId];
      if(!payment||payment.planId!==plan.id)fail('Pagamento non trovato.');
      if(!['posted','deleting','deleted'].includes(payment.status))fail('Completa l’operazione in sospeso prima di eliminare il pagamento.');
      if(Object.values(next.payments).some(p=>p.id!==payment.id&&p.status!=='deleted'&&p.movementId===payment.movementId))fail('Il movimento è condiviso con un altro pagamento.');
      if(payment.status!=='deleted')payment.status='deleting';
      result={planId:plan.id,paymentId:payment.id};
    } else if(action==='edit') {
      if(plan.status!=='active'||['advance','recovery'].includes(plan.kind))fail('Questo piano non è modificabile.');
      const amount=plan.kind==='goal'?cents(input.amountCents):input.amountCents, first=month(input.fromMonth??addMonth(today.slice(0,7),1));
      if(!Number.isSafeInteger(amount)||amount<0||amount>100000000)fail('Quota non valida.');
      if(first<=today.slice(0,7)||first<plan.startMonth)fail('Le modifiche possono decorrere soltanto da un mese futuro del piano.');
      if(plan.kind==='goal') {
        const last=month(input.endMonth), future=months(first,last);
        const oldFuture=plan.endMonth>=first?months(first,plan.endMonth).reduce((n,m)=>n+contribution(plan,m),0):0;
        const matured=plan.amountCents-oldFuture, rest=Math.max(0,amount-matured);
        const schedule={...(plan.legacySchedule??Object.fromEntries(months(plan.startMonth,plan.endMonth).map(m=>[m,contribution(plan,m)])))};
        for(const m of Object.keys(schedule))if(m>=first)delete schedule[m];
        const shares=rest?split(rest,future.length):future.map(()=>0);
        future.forEach((m,i)=>schedule[m]=shares[i]);plan.legacySchedule=schedule;plan.endMonth=last;plan.amountCents=amount;
      } else {
        plan.rateChanges=(plan.rateChanges??[]).filter(c=>c.fromMonth!==first);plan.rateChanges.push({fromMonth:first,amountCents:amount});plan.rateChanges.sort((a,b)=>a.fromMonth.localeCompare(b.fromMonth));
      }
      result={planId:plan.id};
    } else if(action==='stop') {
      if(plan.status!=='active') fail('Il piano non è attivo.');
      if(Object.values(next.payments).some(p=>p.planId===plan.id&&['pending','deleting'].includes(p.status))) fail('Completa il pagamento in sospeso prima di interrompere.');
      if(plan.kind==='advance') {
        if(plan.beneficiaryMonth<today.slice(0,7)) fail('L’anticipo ha già inciso su un mese chiuso: non puoi cancellarne solo il recupero.');
        plan.status='cancelled';
      } else { plan.status='stopped';plan.stopAfter=today.slice(0,7); }
      result={planId:plan.id};
    } else fail('Operazione sconosciuta.');
  }
  next.commands[key]={signature,result};return {state:next,result};
}
function reservePayment(state,plan,input,today,id) {
  const amount=cents(input.amountCents), date=day(input.date,today), covered=Number(input.competenceMonths??1);
  if(!Number.isInteger(covered)||covered<1||covered>12) fail('I mesi coperti devono essere tra 1 e 12.');
  const cycle=month(input.cycleMonth??date.slice(0,7));
  if(cycle>today.slice(0,7)) fail('Non puoi segnare pagata una scadenza futura.');
  if(['fixed','estimated'].includes(plan.kind)&&cycle<plan.startMonth) fail('La scadenza precede l’inizio del piano.');
  const settlement=['goal','recovery'].includes(plan.kind)?'once':['fixed','estimated'].includes(plan.kind)?cycleKey(plan,cycle):id;
  const existingMovementId=input.movementId===undefined?null:Number(input.movementId);
  if(existingMovementId!==null&&(!Number.isSafeInteger(existingMovementId)||existingMovementId<2))fail('Movimento non valido.');
  if(existingMovementId&&Object.values(state.payments).some(p=>p.movementId===existingMovementId||p.existingMovementId===existingMovementId))fail('Questo movimento è già collegato a un piano.');
  if(Object.values(state.payments).some(p=>p.planId===plan.id&&p.status!=='deleted'&&p.settlementKey===settlement)) fail('Pagamento già registrato o in completamento.');
  let recovery=null;
  if(input.recoverDifference) {
    if(plan.kind!=='goal'||amount+Object.values(state.payments).filter(p=>p.planId===plan.id&&p.status==='posted').reduce((n,p)=>n+p.amountCents,0)<=plan.amountCents) fail('Il recupero riguarda soltanto l’eccedenza di un obiettivo finito.');
    recovery=newPlan({kind:'goal',name:('Recupero eccedenza · '+plan.name).slice(0,120),amountCents:amount+Object.values(state.payments).filter(p=>p.planId===plan.id&&p.status==='posted').reduce((n,p)=>n+p.amountCents,0)-plan.amountCents,
      startMonth:input.recoveryStartMonth,endMonth:input.recoveryEndMonth},today,id+'-difference');
    recovery.kind='recovery';recovery.sourcePaymentId=id;
  }
  state.payments[id]={id,planId:plan.id,settlementKey:settlement,status:'pending',amountCents:amount,date,cycleMonth:cycle,
    competenceMonths:covered,recovery,requestId:id,existingMovementId,cashName:input.originalName?String(input.originalName).trim().slice(0,120):null};
}
export function completePayment(state,id,movementId,today) {
  const next=structuredClone(state), payment=next.payments[id];
  if(!payment) fail('Pagamento non trovato.');if(['posted','deleting','deleted'].includes(payment.status))return next;
  if(!Number.isSafeInteger(movementId)||movementId<=0) fail('Il movimento bancario non è stato confermato.');
  const plan=next.plans[payment.planId];payment.status='posted';payment.movementId=movementId;
  if(plan.kind==='goal') { plan.status='closed';plan.closedMonth=today.slice(0,7); }
  if(plan.kind==='recovery') plan.status='active';
  if(payment.recovery) next.plans[payment.recovery.id]=payment.recovery;
  if(plan.kind==='estimated') {
    const history=Object.values(next.payments).filter(p=>p.planId===plan.id&&p.status==='posted').sort((a,b)=>a.date.localeCompare(b.date)).slice(-12);
    const amount=Math.round(history.reduce((sum,p)=>sum+p.amountCents,0)/history.reduce((sum,p)=>sum+p.competenceMonths,0));
    const fromMonth=addMonth(today.slice(0,7),1);
    plan.rateChanges=(plan.rateChanges??[]).filter(c=>c.fromMonth!==fromMonth);
    plan.rateChanges.push({fromMonth,amountCents:Math.max(1,amount)});plan.rateChanges.sort((a,b)=>a.fromMonth.localeCompare(b.fromMonth));
  }
  return next;
}
export function cycleKey(plan,cycle) {
  if(plan.kind!=='fixed'||plan.intervalMonths===1)return cycle;
  const anchor=plan.intervalAnchor??plan.startMonth, delta=(Number(cycle.slice(0,4))-Number(anchor.slice(0,4)))*12+Number(cycle.slice(-2))-Number(anchor.slice(-2));
  return addMonth(anchor,Math.floor(delta/plan.intervalMonths)*plan.intervalMonths);
}
export function completePaymentDeletion(state,id,today) {
  const next=structuredClone(state),payment=next.payments[id];
  if(!payment)fail('Pagamento non trovato.');
  if(payment.status==='deleted')return next;
  if(payment.status!=='deleting')fail('Eliminazione non avviata.');
  payment.status='deleted';payment.deletedDay=today;
  const plan=next.plans[payment.planId];
  // Keep stopped plans stopped. A removed goal settlement reopens the goal.
  if(plan.kind==='goal'&&plan.status==='closed'){plan.status='active';plan.closedMonth=null;}
  if(plan.kind==='recovery')plan.status='cancelled';
  for(const linked of Object.values(next.plans))if(linked.sourcePaymentId===id)linked.status='cancelled';
  if(plan.kind==='estimated') {
    const history=Object.values(next.payments).filter(p=>p.planId===plan.id&&p.status==='posted').sort((a,b)=>a.date.localeCompare(b.date)).slice(-12);
    const rate=history.length?Math.max(1,Math.round(history.reduce((n,p)=>n+p.amountCents,0)/history.reduce((n,p)=>n+p.competenceMonths,0))):plan.amountCents;
    const fromMonth=addMonth(today.slice(0,7),1);
    plan.rateChanges=(plan.rateChanges??[]).filter(c=>c.fromMonth!==fromMonth);plan.rateChanges.push({fromMonth,amountCents:rate});plan.rateChanges.sort((a,b)=>a.fromMonth.localeCompare(b.fromMonth));
  }
  return next;
}
export function balance(state,plan,throughMonth) {
  const last=throughMonth<plan.startMonth?null:throughMonth;
  const saved=(throughMonth>=plan.startMonth?Number(plan.openingBalanceCents??0):0)+(last?months(plan.startMonth,last,1200).reduce((n,m)=>n+Math.max(0,contribution(plan,m)),0):0);
  const spent=Object.values(state.payments).filter(p=>p.planId===plan.id&&['posted','deleting'].includes(p.status)&&p.date.slice(0,7)<=throughMonth&&p.date.slice(0,7)>=plan.startMonth).reduce((n,p)=>n+p.amountCents,0);
  return {contributedCents:saved,paidCents:spent,fundCents:plan.status==='active'&&!['advance','recovery'].includes(plan.kind)?Math.max(0,saved-spent):0,fromGeneralSavingsCents:Math.max(0,spent-saved)};
}
export function project(state,selectedMonth) {
  month(selectedMonth);
  return {version:2,month:selectedMonth,adjustmentCents:adjustment(state.plans,selectedMonth),
    plans:Object.values(state.plans).map(p=>({...p,outstandingCents:Math.max(0,p.amountCents-Object.values(state.payments).filter(x=>x.planId===p.id&&['posted','deleting'].includes(x.status)).reduce((n,x)=>n+x.amountCents,0)),contributionCents:contribution(p,selectedMonth),...balance(state,p,selectedMonth)})),
    payments:Object.values(state.payments).filter(p=>p.status!=='deleted').map(({recovery,...p})=>p)};
}
