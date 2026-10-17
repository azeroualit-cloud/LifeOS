import {addMonth,wealthForecast,aggregateCategories} from './finance-model.mjs';
(() => {
  let range=3,cache=new Map(),active='',generation=0,lastFinance=null;
  const safe=escapeHtml;
  const selectedMonth=()=>`${state.year}-${String(state.month).padStart(2,'0')}`;
  const monthList=(last,count)=>Array.from({length:count},(_,i)=>addMonth(last,i-count+1));
  function chart(rows,label,bar=false,directional=false){
    if(!rows.length)return '<p class="empty">Nessun dato disponibile nel periodo.</p>';
    if(!state.assetsVisible)return '<button data-toggle-assets>Mostra importi</button>';
    const values=rows.flatMap(p=>[p.value,p.lower,p.upper,p.base,p.additional].filter(Number.isFinite)),low=Math.min(0,...values),high=Math.max(1,...values),W=640,H=250;
    const x=i=>rows.length===1?320:48+i*560/Math.max(1,rows.length-1),y=v=>205-(v-low)/(high-low)*180;
    const path=rows.map((p,i)=>`${i?'L':'M'}${x(i)},${y(p.value)}`).join(' ');
    const bandRows=rows.map((p,i)=>({p,i})).filter(({p})=>Number.isFinite(p.lower)&&Number.isFinite(p.upper));
    const band=bandRows.length?`<path fill="var(--os-accent)" opacity=".15" d="${bandRows.map(({p,i},n)=>`${n?'L':'M'}${x(i)},${y(p.upper)}`).join(' ')} ${[...bandRows].reverse().map(({p,i})=>`L${x(i)},${y(p.lower)}`).join(' ')} Z"/>`:'';
    const rectangle=(i,a,b,color)=>`<rect x="${x(i)-8}" y="${Math.min(y(a),y(b))}" width="16" height="${Math.abs(y(a)-y(b))}" fill="${color}"><title>${safe(rows[i].label)}: ${safe(exactEuro(b-a))}</title></rect>`;
    const shapes=bar?rows.map((p,i)=>rectangle(i,0,p.base??p.value,'var(--os-accent)')+(p.additional?rectangle(i,Math.sign(p.base)===Math.sign(p.additional)?p.base:0,(Math.sign(p.base)===Math.sign(p.additional)?p.base:0)+p.additional,'var(--muted)'):'')).join(''):`${band}${directional?rows.slice(1).map((p,i)=>`<path d="M${x(i)},${y(rows[i].value)} L${x(i+1)},${y(p.value)}" fill="none" stroke="${p.value<rows[i].value?'var(--red)':'var(--green)'}" stroke-width="2"/>`).join(''):`<path d="${path}" fill="none" stroke="var(--os-accent)" stroke-width="2"/>`}${rows.map((p,i)=>`<circle cx="${x(i)}" cy="${y(p.value)}" r="3" fill="var(--os-accent)"><title>${safe(p.label)}: ${safe(exactEuro(p.value))}</title></circle>`).join('')}`;
    return `<svg class="trend-svg" viewBox="0 0 ${W} ${H}" role="img" aria-label="${safe(label)}"><line class="grid-line" x1="40" x2="620" y1="205" y2="205"/>${shapes}${rows.map((p,i)=>i%Math.max(1,Math.ceil(rows.length/6))&&i!==rows.length-1?'':`<text style="font-size:20px" x="${x(i)}" y="235" text-anchor="middle">${safe(p.label)}</text>`).join('')}</svg><details><summary>Valori del grafico</summary>${rows.map(p=>`<div class="kv"><span>${safe(p.label)}</span><strong>${safe(exactEuro(p.value))}${Number.isFinite(p.lower)?`<small> ${safe(exactEuro(p.lower))} – ${safe(exactEuro(p.upper))}</small>`:''}</strong></div>`).join('')}</details>`;
  }
  const card=(title,body)=>`<section class="card pad"><h2>${title}</h2>${body}</section>`;
  globalThis.platformAnalysis=function(d){
    if(lastFinance!==d){cache.clear();lastFinance=d;}
    const month=selectedMonth(),period=monthList(month,12),first=period[0];
    const model=wealthForecast(d,d.forecastPlan||d.extraPlan,todayIso());
    const wealth=new Map();for(const row of [...(d.lifetime?.series||[]),...(d.wealthHistory||[])])wealth.set(row.month,{...wealth.get(row.month),...row});
    const wealthRows=[...wealth.values()].filter(r=>r.month>=first&&r.month<=month).sort((a,b)=>a.month.localeCompare(b.month)).map(r=>({label:shortMonth(r.month),value:[r.measured,r.estimated,r.wealth].find(Number.isFinite)})).filter(r=>Number.isFinite(r.value));
    const salary=(d.lifetime?.salaryHistory||[]).filter(r=>r.month>=first&&r.month<=month).sort((a,b)=>a.month.localeCompare(b.month));
    const forecast=model.prediction.length?chart([...model.history.slice(0,-1),...model.prediction].map(p=>({...p,label:p.day.slice(0,7)})),'Previsione patrimonio'): `<p class="empty">Servono almeno 4 mesi completi osservati sui 6 precedenti. Disponibili: ${model.samples}.</p>`;
    const html=`<div class="budget-flow">${card('Spese per categoria',`<div class="chart-range" role="group" aria-label="Periodo categorie">${[3,6,12].map(n=>`<button data-category-period="${n}" class="${n===range?'active':''}" aria-pressed="${n===range}">${n} mesi</button>`).join('')}</div><p class="hint" data-category-interval></p><div data-period-categories role="status">Caricamento categorie…</div><button data-refresh-categories>Aggiorna categorie</button>`)}${card('Previsione patrimonio',`<p class="hint">6 mesi precedenti · 6 mesi successivi</p>${forecast}<details><summary>Come viene calcolata</summary><p>Fascia centrale dell’80% di 2.000 simulazioni dei flussi osservati, con valori anomali limitati tramite mediana e deviazione assoluta mediana. Sono sottratti i pagamenti futuri pianificati, senza sottrarre gli accantonamenti una seconda volta.</p><p>Pagamenti noti nei prossimi 6 mesi: ${state.assetsVisible?exactEuro(model.knownExtra):'••••'}</p><p>Scenario indicativo sul conto principale, non garantito.</p></details>`)}${card('Patrimonio',`<p class="hint">12 mesi fino a ${safe(titleMonth(state.year,state.month))}</p>${chart(wealthRows,'Patrimonio',false,true)}`)}${card('Stipendi per competenza',`<p class="hint">12 mesi fino a ${safe(titleMonth(state.year,state.month))}</p>${chart(salary.map(r=>({label:shortMonth(r.month),value:(r.base||0)+(r.additional||0),base:r.base||0,additional:r.additional||0})),'Stipendi per competenza',true)}${salary.length?`<details><summary>Base e aggiuntive</summary>${salary.map(r=>`<div class="kv"><span>${safe(shortMonth(r.month))}</span><strong>${state.assetsVisible?`Base ${exactEuro(r.base||0)} · Aggiuntive ${exactEuro(r.additional||0)}`:'••••'}</strong></div>`).join('')}</details>`:''}`)}</div>`;
    // Successful monthly reads are retained when switching period or retrying.
    if(Array.isArray(d.categories))cache.set(month,d.categories);
    queueMicrotask(()=>loadCategories(d));return html;
  };
  async function loadCategories(d){
    const month=selectedMonth(),requested=monthList(month,range),token=`${month}|${range}|${++generation}`;active=token;
    const target=document.querySelector('[data-period-categories]');if(!target)return;
    const interval=document.querySelector('[data-category-interval]');interval.textContent=shortMonth(requested[0])+' – '+shortMonth(month);
    const refresh=document.querySelector('[data-refresh-categories]');refresh.disabled=true;
    const current=()=>active===token&&state.view==='analysis'&&selectedMonth()===month&&target.isConnected;
    try{
      for(const m of [...requested].reverse())if(!cache.has(m)){
        if(!current())return;
        target.textContent=`Categorie: ${requested.filter(m=>cache.has(m)).length} di ${requested.length} mesi…`;
        const data=await workerRequest('getFinanceData',[Number(m.slice(0,4)),Number(m.slice(-2))]);
        if(!current())return;aggregateCategories(new Map([[m,data.categories]]),[m]);cache.set(m,data.categories);
      }
      if(!current())return;
      const rows=aggregateCategories(cache,requested);
      const colors=['var(--os-accent)','#6e9cc1','#c79a58','#a788b8','#b9777b','#8b929b'],total=rows.reduce((s,r)=>s+r.amount,0);let offset=0;
      const segments=rows.map((r,i)=>{const share=r.amount/total*100,shape=`<circle cx="60" cy="60" r="48" pathLength="100" fill="none" stroke="${colors[i%colors.length]}" stroke-width="12" stroke-dasharray="${share} ${100-share}" stroke-dashoffset="${-offset}" transform="rotate(-90 60 60)"/>`;offset+=share;return shape;}).join('');
      target.innerHTML=rows.length?`<div class="breakdown"><div class="category-ring"><svg viewBox="0 0 120 120" role="img" aria-label="Spese per categoria">${segments}</svg><div class="category-ring-label"><small>Spese</small><strong>${state.assetsVisible?exactEuro(total):'••••'}</strong></div></div><div>${rows.map((r,i)=>`<div class="kv"><span><i class="category-swatch" style="background:${colors[i%colors.length]}"></i>${safe(r.name)}</span><strong>${state.assetsVisible?exactEuro(r.amount):'••••'}</strong></div>`).join('')}</div></div>`:'<p class="empty">Nessuna spesa nel periodo</p>';
      refresh.textContent='Aggiorna categorie';
    }catch(error){if(current()){target.textContent=`Caricati ${requested.filter(m=>cache.has(m)).length} di ${requested.length} mesi. ${error.message} Riprova riprende dai mesi mancanti.`;refresh.textContent='Riprova';}}
    finally{if(current())refresh.disabled=false;}
  }
  document.addEventListener('click',e=>{
    const period=e.target.closest('[data-category-period]'),refresh=e.target.closest('[data-refresh-categories]');
    if(period){range=Number(period.dataset.categoryPeriod);render();}
    if(refresh){if(refresh.textContent!=='Riprova')cache.clear();loadCategories(state.data);}
  });
})();
