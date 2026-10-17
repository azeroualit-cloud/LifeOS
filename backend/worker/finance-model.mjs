// Mirrors NativeWealthForecast. Civil dates and deterministic bootstrap are shared contracts.
export function addMonth(value, count) {
  const [y,m,d=1]=value.split('-').map(Number);
  const first=new Date(Date.UTC(y,m-1+count,1));
  const last=new Date(Date.UTC(first.getUTCFullYear(),first.getUTCMonth()+1,0)).getUTCDate();
  first.setUTCDate(Math.min(d,last));
  return first.toISOString().slice(0,value.length);
}
const endOfMonth=m=>new Date(Date.UTC(Number(m.slice(0,4)),Number(m.slice(-2)),0)).toISOString().slice(0,10);
const sum=rows=>rows.reduce((a,b)=>a+b,0);
const median=rows=>rows.length?(rows[Math.floor((rows.length-1)/2)]+rows[Math.floor(rows.length/2)])/2:0;
const monthDelta=(a,b)=>(Number(a.slice(0,4))-Number(b.slice(0,4)))*12+Number(a.slice(5,7))-Number(b.slice(5,7));
export function wealthForecast(finance, plan={}, day) {
  const month=day.slice(0,7),earliest=addMonth(month,-6);
  const source=(finance.forecastHistory||[]).filter(r=>r.month>=earliest&&r.month<month&&r.observed).sort((a,b)=>a.month.localeCompare(b.month));
  const grouped=new Map(),actual={};
  for(const link of plan.links||[])if(link.role==='payment'&&link.account==='Trade Republic'){
    const rows=grouped.get(link.movement_source_row)||[];rows.push(link);grouped.set(link.movement_source_row,rows);
  }
  for(const links of grouped.values()){
    const first=links[0],attributed=sum(links.map(link=>((plan.settlements||[]).find(s=>s.cycle_id===link.cycle_id&&s.movement_source_row===link.movement_source_row)?.actual_cents??link.attributed_cents)/100));
    const m=first.actual_date.slice(0,7);actual[m]=(actual[m]||0)+Math.min(Math.max(0,-first.amount),attributed);
  }
  const plans=finance.plansV2?.plans||[],posted=(finance.plansV2?.payments||[]).filter(p=>p.status==='posted');
  for(const p of posted)if(!p.legacy){
    const linked=plans.find(r=>r.id===p.planId);
    if(linked&&(['goal','fund','recovery'].includes(linked.kind)||linked.kind==='fixed'&&linked.intervalMonths>1)){
      const m=p.date.slice(0,7);actual[m]=(actual[m]||0)+p.amountCents/100;
    }
  }
  const nets=source.map(r=>(r.ordinaryNet||0)+Math.max(0,(actual[r.month]||0)-(r.extraPaid||0))).filter(Number.isFinite).sort((a,b)=>a-b);
  const center=median(nets),mad=median(nets.map(v=>Math.abs(v-center)).sort((a,b)=>a-b));
  const spread=mad>0?3*1.4826*mad:Math.max(0,nets.length>=4?nets.at(-2)-nets[1]:0);
  const robust=nets.map(v=>Math.min(center+spread,Math.max(center-spread,v)));
  const normalizedNet=robust.length?sum(robust)/robust.length:0,assets=finance.summary?.budget||0;
  const balances=new Map();
  for(const row of [...(finance.lifetime?.series||[]),...(finance.wealthHistory||[])])balances.set(row.month,{...balances.get(row.month),...row});
  const history=[...balances.values()].filter(r=>r.month>=earliest&&r.month<month).map(r=>({day:endOfMonth(r.month),value:[r.measured,r.estimated,r.wealth].find(Number.isFinite)})).filter(p=>Number.isFinite(p.value)).sort((a,b)=>a.day.localeCompare(b.day));
  history.push({day,value:assets});
  const payments=[],cycles=new Map();
  for(const row of plan.allocations||[])if(row.kind==='expense'&&(row.payment_account||'Trade Republic')==='Trade Republic'&&!['Pagato','Annullato','Previsto'].includes(row.status)&&!cycles.has(row.cycle_id))cycles.set(row.cycle_id,row);
  for(const row of cycles.values())if(row.end_month){
    const linked=sum((plan.links||[]).filter(l=>l.cycle_id===row.cycle_id&&l.role==='payment').map(l=>l.attributed_cents));
    payments.push({day:[day,endOfMonth(row.end_month.slice(0,7))].sort().at(-1),amount:Math.max(0,row.total_cents-linked)/100});
  }
  for(const row of plans.filter(r=>r.status==='active')){
    if(row.kind==='goal'&&/^20\d\d-\d\d$/.test(row.endMonth))payments.push({day:[day,endOfMonth(row.endMonth)].sort().at(-1),amount:(row.outstandingCents??row.amountCents)/100});
    if(row.kind==='fixed'&&row.intervalMonths>1)for(let offset=0;offset<=6;offset++){
      const m=addMonth(month,offset);if(m<row.startMonth)continue;
      const anchor=row.intervalAnchor||row.startMonth,cycle=addMonth(anchor,Math.floor(monthDelta(m,anchor)/row.intervalMonths)*row.intervalMonths);
      if(addMonth(cycle,row.intervalMonths-1)!==m)continue;
      let amount=row.amountCents;for(const rate of [...(row.rateChanges||[])].sort((a,b)=>a.fromMonth.localeCompare(b.fromMonth)))if(rate.fromMonth<=m)amount=rate.amountCents;
      const paid=sum(posted.filter(p=>p.planId===row.id&&p.settlementKey===cycle).map(p=>p.amountCents));
      payments.push({day:[day,endOfMonth(m)].sort().at(-1),amount:Math.max(0,amount-paid)/100});
    }
  }
  const horizon=addMonth(day,6),knownExtra=sum(payments.filter(p=>p.day<=horizon).map(p=>p.amount));
  if(robust.length<4)return {history,prediction:[],samples:source.length,normalizedNet,knownExtra};
  let seed=0x4C6966654F53n;
  const draw=()=>{seed=BigInt.asUintN(64,seed*6364136223846793005n+1442695040888963407n);return robust[Number((seed>>32n)%BigInt(robust.length))];};
  const paths=Array(2000).fill(assets),prediction=[{day,value:assets,lower:assets,upper:assets}];let previous=day;
  for(let step=1;step<=6;step++){
    const date=addMonth(day,step),payment=sum(payments.filter(p=>p.day<=date&&(p.day>previous||step===1&&p.day===day)).map(p=>p.amount));
    for(let i=0;i<paths.length;i++)paths[i]+=draw()-payment;
    const sorted=[...paths].sort((a,b)=>a-b),expected=assets+step*normalizedNet-sum(payments.filter(p=>p.day<=date).map(p=>p.amount));
    prediction.push({day:date,value:expected,lower:Math.min(expected,sorted[199]),upper:Math.max(expected,sorted[1799])});previous=date;
  }
  return {history,prediction,samples:source.length,normalizedNet,knownExtra};
}

export function aggregateCategories(snapshots,months){
  if(!months.length||new Set(months).size!==months.length)throw Error('Dati incompleti per il periodo selezionato.');
  const totals=new Map();
  for(const month of months){
    const rows=snapshots.get(month);if(!Array.isArray(rows))throw Error('Dati incompleti per il periodo selezionato.');
    for(const row of rows){
      const name=String(row.name||'').trim(),cents=Math.sign(row.amount)*Math.round(Math.abs(row.amount)*100);
      if(!name||typeof row.amount!=='number'||!Number.isSafeInteger(cents))throw Error('Dati categoria non validi.');
      const total=(totals.get(name)||0)+cents;if(!Number.isSafeInteger(total))throw Error('Totale categoria non valido.');totals.set(name,total);
    }
  }
  return [...totals].filter(([,n])=>n>0).sort((a,b)=>b[1]-a[1]||(a[0]<b[0]?-1:1)).map(([name,cents])=>({name,amount:cents/100}));
}
