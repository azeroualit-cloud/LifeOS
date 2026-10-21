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
  document.addEventListener('click',e=>{if(e.target.closest('[data-edit-planning]'))settings();});
})();
