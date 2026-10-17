/* Web Piani v2. Runs after the original UI; uses the same authenticated transport. */
(() => {
  const kinds={goal:'Obiettivo',fund:'Fondo',fixed:'Ricorrenza fissa',estimated:'Utenza stimata',advance:'Anticipo budget',recovery:'Recupero spesa'};
  const statuses={active:'Attivo',stopped:'Interrotto',closed:'Completato',cancelled:'Annullato',pendingPayment:'Pagamento da completare'};
  const today=()=>new Date().toLocaleDateString('sv-SE',{timeZone:'Europe/Rome'});
  const current=()=>today().slice(0,7);
  const next=m=>{const [y,n]=m.split('-').map(Number);return new Date(Date.UTC(y,n,1)).toISOString().slice(0,7);};
  const safe=osSafe, money=c=>exactEuro(Number(c||0)/100);
  const view=()=>state.data?.plansV2;
  const plan=id=>view()?.plans.find(p=>p.id===id);
  const field=(label,name,type,value='',attrs='')=>`<label class="${name==='name'?'full':''}">${label}<input name="${name}" type="${type}" value="${safe(value)}" ${attrs}></label>`;
  const amount=(label,value='')=>field(label,'amount','number',value,'required min="0.01" max="1000000" step="0.01"');
  const monthField=(label,name,value)=>field(label,name,'month',value,'required');
  const oldActions=osPageActions;
  osPageActions=function(){oldActions();document.querySelectorAll('[data-new-extra]').forEach(b=>{b.setAttribute('aria-label','Nuovo piano');b.setAttribute('title','Nuovo piano');if(!b.classList.contains('fab-button'))b.textContent='+ Piano';});};
  const oldSetView=setView;
  setView=function(v){oldSetView(v);if(v==='extras')document.getElementById('page-title').textContent='Piani';};
  const oldOverview=overview;
  overview=function(d){return oldOverview(d).replace('>Extra</button>','>Piani</button>');};
  extrasView=function(d){
    const v=d.plansV2;
    if(!v)return '<p role="status">Caricamento Piani…</p><button data-plans-refresh>Riprova</button>';
    const pending=v.payments.filter(p=>p.status==='pending');
    return `<div class="plans-web"><div class="card-title"><div><h2>Piani</h2><p class="hint">Quote e anticipi organizzano il budget. Il saldo cambia solo con un pagamento.</p></div><button class="save" data-new-extra>Nuovo piano</button></div>${pending.map(p=>`<div class="errorbox">Pagamento da completare · ${safe(plan(p.planId)?.name||'Piano')} <button data-plans-resume="${safe(p.id)}">Riprendi senza duplicare</button></div>`).join('')}<div class="extra-grid">${v.plans.map(p=>{
      const payable=p.status==='active'&&!['advance','recovery'].includes(p.kind)&&p.startMonth<=current();
      let cycle=v.month;
      if(p.kind==='fixed'&&p.intervalMonths>1){const anchor=p.intervalAnchor||p.startMonth,[y,m]=anchor.split('-').map(Number),delta=(Number(cycle.slice(0,4))-y)*12+Number(cycle.slice(-2))-m;cycle=new Date(Date.UTC(y,m-1+Math.floor(delta/p.intervalMonths)*p.intervalMonths,1)).toISOString().slice(0,7);}
      const paid=p.kind!=='fund'&&v.payments.some(x=>x.planId===p.id&&x.status==='posted'&&(p.kind==='goal'||x.settlementKey===cycle));
      return `<article class="extra-card"><div class="extra-card-head"><h3>${safe(p.name)}</h3><strong>${money(p.contributionCents)}<small> / mese</small></strong></div><p>${safe(kinds[p.kind])} · ${safe(statuses[p.status]||p.status)}</p><p class="hint">${safe(p.startMonth)}${p.endMonth?' → '+safe(p.endMonth):' · Senza scadenza'}</p>${p.kind==='advance'?`<p class="hint">Budget anticipato a ${safe(p.beneficiaryMonth)} · ${money(p.amountCents)}</p>`:`<div class="kv"><span>Accumulato</span><strong>${money(p.fundCents)}</strong></div><div class="kv"><span>Pagato</span><strong>${money(p.paidCents)}</strong></div>`}${p.kind==='goal'?`<p class="hint">Obiettivo ${money(p.amountCents)} · residuo ${money(p.outstandingCents)}</p>`:''}<div class="extra-card-controls">${payable&&!paid?`<button data-plans-pay="${safe(p.id)}">Paga o collega</button>`:paid?'<span class="state-tag">Pagamento registrato</span>':''}${p.status==='active'?`${!['advance','recovery'].includes(p.kind)?`<button data-plans-edit="${safe(p.id)}">Modifica quote future</button>`:''}<button data-plans-stop="${safe(p.id)}">${p.kind==='advance'?'Annulla anticipo':'Interrompi'}</button>`:''}</div></article>`;
    }).join('')||'<p class="empty">Nessun piano. Crea un obiettivo, un fondo o una ricorrenza.</p>'}</div></div>`;
  };
  function modal(title,body,method,makePayload){
    const host=document.getElementById('dialog');
    host.innerHTML=`<div class="modal" role="dialog" aria-modal="true" aria-label="${safe(title)}"><div class="modal-top"><h2>${safe(title)}</h2><button type="button" data-plans-close aria-label="Chiudi">×</button></div><form id="plans-web-form" class="form-grid">${body}<p class="os-form-error full" role="alert"></p><div class="form-actions full"><button type="button" data-plans-close>Annulla</button><button class="save" type="submit">Salva</button></div></form></div>`;
    host.classList.remove('hidden');
    const form=host.querySelector('form'),requestId=crypto.randomUUID();let payload=null,busy=false;
    form.addEventListener('submit',async e=>{
      e.preventDefault();if(busy||!form.reportValidity())return;
      const error=form.querySelector('[role=alert]'),button=form.querySelector('[type=submit]');
      try {
        if(!payload)payload={requestId,...makePayload(new FormData(form))};
        busy=true;button.disabled=true;button.textContent='Salvataggio…';error.textContent='';
        // Freeze values once submitted. A retry must use the same payload and ID.
        form.querySelectorAll('input,select').forEach(x=>x.disabled=true);
        await workerRequest(method,[payload]);
        host.classList.add('hidden');state.data=null;state.loadedDetail=false;load();osLoadHomeFinance();
      }catch(err){error.textContent=err.message+' Puoi riprovare la stessa operazione senza duplicarla.';button.textContent='Riprova';}
      finally{busy=false;button.disabled=false;}
    });return form;
  }
  const cents=f=>{const n=Number(f.get('amount'));if(!Number.isFinite(n)||n<=0||Math.abs(n*100-Math.round(n*100))>1e-6)throw Error('Usa un importo positivo con massimo due decimali.');return Math.round(n*100);};
  openExtra=function(){
    const form=modal('Nuovo piano',`<label class="full">Tipo<select name="kind">${Object.entries(kinds).map(([k,v])=>`<option value="${k}">${v}</option>`).join('')}</select></label>${field('Nome','name','text','','required maxlength="120" class="full"')}<div class="full" data-plan-fields></div>`,'saveFinancePlan',f=>{
      const kind=String(f.get('kind')),p={kind,name:String(f.get('name')),amountCents:cents(f),startMonth:String(f.get('startMonth')),category:'Altro'};
      if(['goal','advance','recovery'].includes(kind))p.endMonth=String(f.get('endMonth'));
      if(kind==='advance')p.beneficiaryMonth=String(f.get('beneficiaryMonth'));
      if(kind==='fixed')p.intervalMonths=Number(f.get('intervalMonths'));
      if(kind==='recovery'){p.paymentDate=String(f.get('date'));if(f.get('movementId'))p.movementId=Number(f.get('movementId'));}
      return p;
    });
    const update=()=>{
      const kind=form.elements.kind.value,start=kind==='advance'?next(current()):current();
      const labels={goal:'Totale obiettivo €',fund:'Quota mensile €',fixed:'Importo per scadenza €',estimated:'Stima mensile €',advance:'Budget da anticipare €',recovery:'Spesa da recuperare €'};
      form.querySelector('[data-plan-fields]').innerHTML=`<div class="form-grid">${amount(labels[kind])}${monthField(kind==='advance'?'Primo mese di recupero':'Dal mese','startMonth',start)}${['goal','advance','recovery'].includes(kind)?monthField('Ultimo mese','endMonth',start):'<p class="hint">Senza scadenza: continua finché non lo interrompi.</p>'}${kind==='advance'?monthField('Mese beneficiario','beneficiaryMonth',current()):''}${kind==='fixed'?'<label>Ogni quanti mesi<select name="intervalMonths"><option value="1">Ogni mese</option><option value="2">Ogni 2 mesi</option><option value="3">Ogni 3 mesi</option><option value="6">Ogni 6 mesi</option><option value="12">Ogni anno</option></select></label>':''}${kind==='recovery'?`${field('Data della spesa','date','date',today(),'required max="'+today()+'"')}<label class="full">Movimento<select name="movementId"><option value="">Registra una nuova spesa</option></select></label><p class="hint full">Collega una spesa già registrata per recuperarla senza un secondo addebito.</p>`:''}<p class="hint full">${kind==='advance'?'Non sposta denaro tra conti: aumenta il budget del mese beneficiario e lo recupera nei mesi scelti.':kind==='recovery'?'La spesa incide sul saldo una sola volta; le quote recuperano il budget nei mesi scelti.':'Creare il piano non registra un pagamento.'}</p></div>`;
      if(kind==='recovery')loadMovements(form);
    };form.elements.kind.addEventListener('change',update);update();
  };
  async function loadMovements(form){
    const select=form.elements.movementId;if(!select)return;
    const date=form.elements.date;
    const refresh=async()=>{
      try{const d=await workerRequest('getFinancePlanMovements',[date.value.slice(0,7)]);if(!form.isConnected)return;select.innerHTML='<option value="">Registra una nuova spesa</option>'+d.movements.map(m=>`<option value="${m.row}" data-cents="${m.amountCents}" data-date="${safe(m.date)}">${safe(m.name)} · ${money(m.amountCents)}</option>`).join('');}
      catch(err){form.querySelector('[role=alert]').textContent='Movimenti non disponibili: '+err.message;}
    };
    select.addEventListener('change',()=>{const o=select.selectedOptions[0];if(o?.dataset.cents){form.elements.amount.value=Number(o.dataset.cents)/100;date.value=o.dataset.date;}});
    date.addEventListener('change',refresh);await refresh();
  }
  function pay(id){
    const p=plan(id);if(!p)return;
    const m=view().month<=current()?view().month:current();
    const form=modal('Paga o collega · '+p.name,`${amount('Importo effettivo €',(p.kind==='goal'?p.outstandingCents:p.kind==='fixed'?p.amountCents:Math.max(p.contributionCents,1))/100)}${field('Data pagamento','date','date',today(),'required max="'+today()+'"')}${monthField('Scadenza di riferimento','cycleMonth',m)}${field('Mesi coperti','competenceMonths','number',1,'required min="1" max="12"')}<label class="full">Movimento<select name="movementId"><option value="">Registra un nuovo pagamento</option></select></label><p class="hint full">Collegare un movimento esistente non genera un nuovo addebito.${p.kind==='goal'?' Il pagamento chiude l’obiettivo e libera le quote future.':''}</p>${p.kind==='goal'?`<label class="full">Eccedenza<select name="recoverDifference"><option value="">Usa i risparmi</option><option value="yes">Recupera solo l’eccedenza nei mesi successivi</option></select></label>${monthField('Recupero dal mese','recoveryStartMonth',next(current()))}${monthField('Recupero fino al mese','recoveryEndMonth',next(current()))}`:''}`,'recordFinancePlanPayment',f=>{
      const out={planId:id,amountCents:cents(f),date:String(f.get('date')),cycleMonth:String(f.get('cycleMonth')),competenceMonths:Number(f.get('competenceMonths'))};
      if(f.get('movementId'))out.movementId=Number(f.get('movementId'));
      if(f.get('recoverDifference')==='yes')Object.assign(out,{recoverDifference:true,recoveryStartMonth:String(f.get('recoveryStartMonth')),recoveryEndMonth:String(f.get('recoveryEndMonth'))});return out;
    });loadMovements(form);
  }
  function edit(id){const p=plan(id);if(!p)return;modal('Modifica quote future · '+p.name,`${amount(p.kind==='goal'?'Nuovo totale obiettivo €':'Nuova quota / scadenza €',p.amountCents/100)}${monthField('Decorrenza','fromMonth',next(current()))}${p.kind==='goal'?monthField('Nuova scadenza','endMonth',p.endMonth<next(current())?next(current()):p.endMonth):''}<p class="hint full">Il mese corrente e le quote precedenti restano invariati.</p>`,'editFinancePlan',f=>({planId:id,amountCents:cents(f),fromMonth:String(f.get('fromMonth')),...(p.kind==='goal'?{endMonth:String(f.get('endMonth'))}:{})}));}
  document.addEventListener('click',e=>{
    const b=e.target.closest('[data-new-extra],[data-plans-pay],[data-plans-edit],[data-plans-stop],[data-plans-close],[data-plans-refresh],[data-plans-resume]');if(!b)return;
    e.preventDefault();e.stopImmediatePropagation();
    if(b.hasAttribute('data-new-extra'))openExtra();
    if(b.hasAttribute('data-plans-close'))document.getElementById('dialog').classList.add('hidden');
    if(b.hasAttribute('data-plans-pay'))pay(b.dataset.plansPay);
    if(b.hasAttribute('data-plans-edit'))edit(b.dataset.plansEdit);
    if(b.hasAttribute('data-plans-stop')){const id=b.dataset.plansStop,p=plan(id);modal('Interrompi · '+p.name,'<p class="full">Conserva i pagamenti e lo storico. Le quote successive al mese corrente si interrompono. Gli anticipi di mesi chiusi non possono essere annullati.</p>','stopFinancePlan',()=>({planId:id}));}
    if(b.hasAttribute('data-plans-resume'))modal('Riprendi pagamento','<p class="full">Completa la conferma del movimento già avviato, senza creare un secondo addebito.</p>','resumeFinancePlanPayment',()=>({paymentId:b.dataset.plansResume}));
    if(b.hasAttribute('data-plans-refresh'))load();
  },true);
})();
