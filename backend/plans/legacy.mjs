import {completePayment,cycleKey} from './engine.mjs';

const money=n=>Math.round(Number(n||0)*100);
const utility=new Set(['Elettricità','Gas','Acqua']);
const active=p=>p.status!=='Annullato';

// Adoption is additive: original records and bank events are never changed.
// Each source gets one stable identity and a cutover month. Historical budgets
// continue to use the original engine; only overlapping quotas are replaced.
export function adoptLegacy(state,context,today) {
  const next=structuredClone(state), current=today.slice(0,7);
  if(!next.legacyAdoption) {
    next.legacyAdoption={version:1,fromMonth:current};
    const fixed=[{name:'Affitto',estimate:context.overview.summary.monthlyBudgetBreakdown?.find(r=>r.name==='Affitto')?.amount??0},
      ...(context.overview.recurring??[]).filter(r=>r.treatment==='Vincolata'&&r.name!=='Benzina')];
    for(const [index,r] of fixed.entries()) {
      if(!r.name||money(r.estimate)<0)continue;
      const id='legacy-recurring-'+index;
      next.plans[id]={id,name:r.name,category:r.name,kind:utility.has(r.name)?'estimated':'fixed',amountCents:money(r.estimate),
        startMonth:current,endMonth:null,intervalMonths:1,status:'active',createdDay:today,rateChanges:[],
        legacy:{type:'recurring',name:r.name,fromMonth:current}};
      if(utility.has(r.name)&&Number.isFinite(r.nextEstimate)&&money(r.nextEstimate)!==money(r.estimate))
        next.plans[id].rateChanges.push({fromMonth:nextMonth(current),amountCents:money(r.nextEstimate)});
    }
    const bySource=new Map();
    for(const cycle of context.cycles??[]) {
      if(!active(cycle)||cycle.kind!=='expense')continue;
      const source=Number(cycle.extraordinary_source_row);
      if(!bySource.has(source))bySource.set(source,[]);
      bySource.get(source).push(cycle);
    }
    for(const [source,cycles] of bySource) {
      const ref=cycles.find(c=>c.start_month<=current&&c.end_month>=current)??cycles.filter(c=>c.start_month<=current).at(-1)??cycles[0];
      const ids=new Set(cycles.map(c=>Number(c.id))), allocations=(context.allocations??[]).filter(a=>ids.has(Number(a.cycle_id)));
      const links=(context.links??[]).filter(l=>ids.has(Number(l.cycle_id)));
      const annual=ref.repeat_rule==='Annuale', fund=annual&&/^Manutenzione auto\b/i.test(ref.name);
      const id='legacy-extra-'+source, kind=fund?'fund':annual?'fixed':'goal';
      const schedule=Object.fromEntries(allocations.filter(a=>a.month>=current).map(a=>[a.month,Number(a.amount_cents)]));
      const prior=allocations.filter(a=>a.month<current).reduce((n,a)=>n+Number(a.amount_cents),0)-links.filter(l=>String(l.actual_date).slice(0,7)<current).reduce((n,l)=>n+Number(l.attributed_cents),0);
      const amount=kind==='fund'?(schedule[current]??Math.round(ref.total_cents/12)):Number(ref.total_cents);
      const closed=kind==='goal'&&ref.status==='Pagato';
      next.plans[id]={id,name:ref.name,category:fund?'Manutenzione auto':/assicura/i.test(ref.name)?'Assicurazione':/bollo/i.test(ref.name)?'Bollo':'Straordinarie',
        kind,amountCents:amount,startMonth:ref.start_month>current?ref.start_month:current,endMonth:kind==='goal'?ref.end_month:null,
        intervalMonths:annual&&!fund?12:1,intervalAnchor:ref.start_month,createdDay:today,status:closed?'closed':'active',
        closedMonth:closed?String(ref.paid_date||today).slice(0,7):null,rateChanges:[],openingBalanceCents:prior,
        legacySchedule:kind==='goal'?schedule:undefined,legacy:{type:'extra',sourceRow:source,fromMonth:current}};
      for(const link of links) {
        const pid='legacy-link-'+link.cycle_id+'-'+link.movement_source_row;
        if(next.payments[pid])continue;
        const cycle=cycles.find(c=>Number(c.id)===Number(link.cycle_id));
        next.payments[pid]={id:pid,planId:id,status:'posted',legacy:true,movementId:Number(link.movement_source_row),
          amountCents:Number(link.attributed_cents),date:String(link.actual_date).slice(0,10),cycleMonth:cycle.start_month,
          competenceMonths:annual?12:1,settlementKey:kind==='goal'?pid:kind==='fixed'?cycleKey(next.plans[id],cycle.start_month):pid};
      }
    }
  }
  // Pick up payments entered through existing quick/recurring forms. Their bank
  // rows already exist: attach them, never create new cash or rewrite old months.
  for(const row of context.movements??[]) {
    if(row.status!=='Eseguito'||row.movement_type!=='Spesa'||Number(row.amount)>=0||!['Trade Republic','Revolut'].includes(row.account))continue;
    if(Object.values(next.payments).some(p=>p.movementId===Number(row.source_row)||p.existingMovementId===Number(row.source_row)||'APP-'+p.requestId===row.import_id))continue;
    const plan=Object.values(next.plans).find(p=>p.legacy?.type==='recurring'&&p.category===row.category);
    if(!plan||(String(row.actual_date).slice(0,7)<plan.startMonth&&plan.kind!=='estimated')||String(row.actual_date).slice(0,10)>today||!['auto','planned'].includes(row.treatment??'auto'))continue;
    const id='legacy-cash-'+row.source_row;
    next.payments[id]={id,planId:plan.id,status:'pending',legacy:true,amountCents:money(-row.amount),date:String(row.actual_date).slice(0,10),
      cycleMonth:String(row.actual_date).slice(0,7),competenceMonths:Math.max(1,Number(row.competence_months)||1),settlementKey:cycleKey(plan,String(row.actual_date).slice(0,7))};
    if(String(row.actual_date).slice(0,7)<plan.startMonth) {next.payments[id].status='posted';next.payments[id].movementId=Number(row.source_row);continue;}
    const completed=completePayment(next,id,Number(row.source_row),today);
    Object.assign(next,completed);
  }
  return next;
}
function nextMonth(m){const [y,n]=m.split('-').map(Number);return new Date(Date.UTC(y,n,1)).toISOString().slice(0,7);}

export async function readLegacyContext(db,overview) {
  const [cycles,allocations,links,movements]=await Promise.all([
    db.prepare('SELECT c.*,e.name,e.repeat_rule,e.paid_date FROM extraordinary_cycles c JOIN extraordinary e ON e.source_row=c.extraordinary_source_row ORDER BY c.start_month,c.id').all(),
    db.prepare('SELECT * FROM extraordinary_allocations ORDER BY month,cycle_id').all(),
    db.prepare("SELECT l.*,m.actual_date FROM extraordinary_movement_links l JOIN movements m ON m.source_row=l.movement_source_row WHERE l.role='payment'").all(),
    db.prepare("SELECT m.*,p.treatment FROM movements m LEFT JOIN movement_budget_policies p ON p.movement_source_row=m.source_row WHERE m.movement_type='Spesa' AND m.amount<0 ORDER BY m.actual_date,m.source_row").all()
  ]);
  return {overview,cycles:cycles.results,allocations:allocations.results,links:links.results,movements:movements.results};
}

export function replacement(base,view,current=false) {
  const adopted=view.plans.filter(p=>p.legacy&&view.month>=p.legacy.fromMonth), names=new Set(adopted.filter(p=>p.legacy.type==='recurring').map(p=>p.legacy.name));
  const sources=new Set(adopted.filter(p=>p.legacy.type==='extra').map(p=>p.legacy.sourceRow));
  const allocations=(base.extraPlan?.allocations??[]).filter(a=>a.month===view.month&&a.kind==='expense'&&active(a)&&sources.has(Number(a.extraordinary_source_row)));
  if(current) return (base.summary.recurringCommitments??[]).filter(r=>names.has(r.name)).reduce((n,r)=>n+money(r.remaining),0)+allocations.filter(a=>!(a.status==='Pagato'&&a.paid_date&&view.month<=String(a.paid_date).slice(0,7))).reduce((n,a)=>n+Number(a.amount_cents),0);
  return (base.summary.monthlyBudgetBreakdown??[]).filter(r=>names.has(r.name)).reduce((n,r)=>n+money(r.amount),0)+allocations.reduce((n,a)=>n+Number(a.amount_cents),0);
}
export function hideAdoptedLegacy(base,view) {
  const sources=new Set(view.plans.filter(p=>p.legacy?.type==='extra').map(p=>p.legacy.sourceRow));
  for(const key of ['extraPlan','forecastPlan'])if(base[key])base[key].allocations=base[key].allocations.filter(a=>!sources.has(Number(a.extraordinary_source_row))); 
}
