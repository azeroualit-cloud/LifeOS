(() => {
  const safe=escapeHtml;
  function progress(goal=state.data?.planning?.goal,target=state.data?.planning?.savingsTarget){
    const assets=Number(state.data?.summary?.budget)||0,emergency=Math.max(0,Number(goal)||0);
    target=Number(target)>0?Number(target):Math.max(5000,(Math.floor(Math.max(assets,emergency)/5000)+1)*5000);
    const months=Math.max(1,13-Number(todayIso().slice(5,7))),reserved=Math.min(Math.max(0,assets),emergency),missing=Math.max(0,target-assets);
    return {assets,emergency,target,months,reserved,other:Math.max(0,assets-reserved),missing,monthly:missing/months};
  }
  const line=(label,n)=>`<div class="kv"><span>${label}</span><strong>${state.assetsVisible?exactEuro(n):'••••'}</strong></div>`;
  planningCard=function(){
    const p=progress();
    return `<section class="card pad planning-card"><h2>Obiettivo di risparmio</h2>${line('Patrimonio totale',p.assets)}${line('Fondo emergenza',p.emergency)}${line('Fondo emergenza coperto',p.reserved)}${line('Altri risparmi',p.other)}${line('Prossimo traguardo',p.target)}${line('Manca',p.missing)}${line('Da risparmiare al mese',p.monthly)}<p class="hint">Cifra mancante divisa per ${p.months} mesi fino a dicembre, incluso quello corrente.</p><button data-edit-planning>Obiettivo e fondo emergenza</button></section>`;
  };
  overviewAnalysis=function(d){return `<div class="budget-flow"><section class="card pad"><h2>Ricorrenti</h2>${(d.recurring||[]).map((r,i)=>`<button class="plan-list-row" data-budget-recurring="${i}"><span>${safe(r.name)}</span><strong>${state.assetsVisible?exactEuro(r.estimate):'••••'}</strong></button>`).join('')||'<p class="empty">Nessuna voce ricorrente</p>'}</section>${planningCard(d)}</div>`;};
  function sheet(title,body){
    const host=document.getElementById('dialog');
    host.innerHTML=`<div class="modal" role="dialog" aria-modal="true" aria-label="${safe(title)}"><div class="modal-top"><h2>${safe(title)}</h2><button data-close aria-label="Chiudi">×</button></div>${body}</div>`;host.classList.remove('hidden');return host;
  }
  function settings(){
    const p=progress(),host=sheet('Obiettivo e fondo',`<form id="platform-planning-form" class="form-grid"><label>Fondo emergenza €<input name="goal" type="number" min="0" max="1000000" step="0.01" value="${p.emergency}" required></label><label>Obiettivo di risparmio €<input name="target" type="number" min="0.01" max="1000000" step="0.01" value="${p.target}" required></label><div class="full" data-saving-preview></div><p role="alert" class="os-form-error full"></p><div class="form-actions"><button type="button" data-close>Annulla</button><button class="save" type="submit">Salva</button></div></form>`);
    const form=host.querySelector('form');
    const preview=()=>{const p=progress(form.elements.goal.value,form.elements.target.value);form.querySelector('[data-saving-preview]').innerHTML=line('Da risparmiare',p.missing)+`<p>Mesi fino a dicembre: ${p.months}</p>`+line('Al mese',p.monthly);};
    form.addEventListener('input',preview);preview();
    form.addEventListener('submit',async e=>{
      e.preventDefault();if(!form.reportValidity()||form.dataset.busy)return;
      const p=progress(form.elements.goal.value,form.elements.target.value),button=form.querySelector('[type=submit]');form.dataset.busy='true';button.disabled=true;
      try{
        const result=await workerRequest('savePlanningSettings',[p.emergency,p.monthly,p.target]);if(result===false)throw Error('Il server non ha confermato la modifica.');
        const fresh=await workerRequest('getFinanceOverview',[state.year,state.month],{fresh:true});
        if(Math.abs(Number(fresh.planning?.goal)-p.emergency)>0.005||Math.abs(Number(fresh.planning?.savingsTarget)-p.target)>0.005||!Number.isFinite(fresh.planning?.goal)||!Number.isFinite(fresh.planning?.savingsTarget))throw Error('Impostazioni inviate ma non ancora verificate. Aggiorna prima di riprovare.');
        state.data={...state.data,...fresh};closeDialog();render();
      }catch(error){form.querySelector('[role=alert]').textContent=error.message;}
      finally{delete form.dataset.busy;button.disabled=false;}
    });
  }
  function recurring(index){
    const r=state.data?.recurring?.[index];if(!r)return;
    const host=sheet(r.name,`<form id="platform-recurring-form" class="form-grid"><label class="full">Stima mensile €<input name="estimate" type="number" min="0.01" max="1000000" step="0.01" value="${r.estimate}"></label>${Number.isFinite(r.nextEstimate)?`<p>Stima mese successivo: ${state.assetsVisible?exactEuro(r.nextEstimate):'••••'}</p>`:''}<button type="button" data-recurring-estimate>Salva stima</button><h3 class="full">Registra pagamento</h3><label>Importo €<input name="amount" type="number" min="0.01" max="1000000" step="0.01"></label><label>Data<input name="date" type="date" value="${todayIso()}" max="${todayIso()}"></label><label>Mesi coperti<input name="months" type="number" min="1" max="12" step="1" value="1"></label><p class="os-form-error full" role="alert"></p><div class="form-actions"><button type="button" data-close>Fine</button><button class="save" type="submit">Registra</button></div></form>`);
    const form=host.querySelector('form'),requestId=crypto.randomUUID();let submitted=null;
    async function send(method,args){
      if(form.dataset.busy)return;form.dataset.busy='true';const controls=[...form.querySelectorAll('button')];controls.forEach(b=>b.disabled=true);
      try{const result=await workerRequest(method,args);if(result===false)throw Error('Il server non ha confermato la modifica.');closeDialog();load();}
      catch(error){form.querySelector('[role=alert]').textContent=error.message;}
      finally{delete form.dataset.busy;controls.forEach(b=>b.disabled=false);}
    }
    form.querySelector('[data-recurring-estimate]').onclick=()=>{const input=form.elements.estimate;if(!input.value||!input.reportValidity())return;send('saveEstimate',[r.name,Number(input.value)]);};
    form.onsubmit=e=>{e.preventDefault();if(!form.elements.amount.value||!form.reportValidity())return;submitted??={requestId,type:'Spesa',name:r.name,category:r.name,account:'Trade Republic',date:form.elements.date.value,months:Number(form.elements.months.value),amount:Number(form.elements.amount.value),budgetTreatment:'auto'};send('saveTransaction',[submitted]);};
  }
  document.addEventListener('click',e=>{const b=e.target.closest('[data-edit-planning],[data-budget-recurring]');if(!b)return;if(b.hasAttribute('data-edit-planning'))settings();else recurring(Number(b.dataset.budgetRecurring));});
})();
