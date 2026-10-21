/* Web Piani v2. Runs after the original UI; uses the same authenticated transport. */
import {budgetFlow} from '../plans/budget-flow.mjs';
import {newPlan,contribution,months,addMonth} from '../plans/engine.mjs';
(() => {
  const kinds=lifeOSContract.planKinds;
  const statuses=lifeOSContract.planStatuses;
  const today=()=>new Date().toLocaleDateString('sv-SE',{timeZone:'Europe/Rome'});
  const current=()=>today().slice(0,7);
  const next=m=>{const [y,n]=m.split('-').map(Number);return new Date(Date.UTC(y,n,1)).toISOString().slice(0,7);};
  const safe=osSafe, money=c=>exactEuro(Number(c||0)/100);
  const view=()=>state.data?.plansV2;
  const plan=id=>view()?.plans.find(p=>p.id===id);
  const field=(label,name,type,value='',attrs='')=>`<label class="${name==='name'?'full':''}">${label}<input name="${name}" type="${type}" value="${safe(value)}" ${attrs}></label>`;
  const amount=(label,value='')=>field(label,'amount','number',value,'required min="0.01" max="1000000" step="0.01"');
  const monthField=(label,name,value)=>field(label,name,'month',value,'required min="'+current()+'" max="2099-12"');
  const oldActions=osPageActions;
  osPageActions=function(){oldActions();document.querySelectorAll('[data-new-extra]').forEach(b=>{b.setAttribute('aria-label','Nuovo piano');b.setAttribute('title','Nuovo piano');});};
  const oldSetView=setView;
  setView=function(v){if(!['extras','budget'].includes(v))activePlan=null;oldSetView(v==='extras'?'budget':v);};
  let activePlan=null;
  overviewAnalysis=extrasView=function(d){
    const v=d.plansV2;
    if(!v||v.version!==2||!Array.isArray(v.plans)||!Array.isArray(v.payments))return `<p role="alert">${safe(lifeOSContract.plansUnavailable)}</p><button data-plans-refresh>Riprova</button>`;
    const p=v.plans.find(p=>p.id===activePlan);
    if(p){document.getElementById('page-title').textContent='Dettagli piano';return detail(p,v);}
    activePlan=null;document.getElementById('page-title').textContent='Budget';
    const flow=budgetFlow(d.summary,v.plans,v.month),currentIDs=new Set(flow.rows.map(r=>r.planId));
    const value=c=>state.assetsVisible?money(c):'•••• €';
    const line=(name,c)=>`<div class="kv"><span>${safe(name)}</span><strong>${value(c)}</strong></div>`;
    const legacy=[...new Map((d.extraPlan?.allocations||[]).map(r=>[r.cycle_id,r])).values()];
    return `<div class="plans-web"><div class="card-title"><div><h2>Budget di ${safe(titleMonth(state.year,state.month))}</h2><p class="hint">Stipendio, piani e budget disponibile</p></div><div class="actions"><button data-plans-info aria-label="Come funzionano i piani">ⓘ</button><button class="save" data-new-extra>Nuovo piano</button></div></div><section class="card pad budget-waterfall">${line('Stipendio di riferimento',flow.salaryCents)}${flow.rows.map(r=>`<${r.planId?'button':'div'} class="plan-list-row" ${r.planId?`data-plans-detail="${safe(r.planId)}"`:''}><span><strong>${safe(r.name)}</strong><small>Rimane ${value(r.remainingCents)}</small></span><strong>${value(-r.amountCents)}</strong></${r.planId?'button':'div'}>`).join('')||'<p class="empty">Nessun piano per questo mese.</p>'}${line('Spese non già coperte dai piani',-flow.spentCents)}<div data-budget-final>${line('Budget finale',flow.remainingCents)}</div><p class="hint">Le quote dei piani riducono il budget. I pagamenti già coperti da un piano non vengono sottratti una seconda volta.</p></section><details class="card pad"><summary>Altri piani · futuri e conclusi</summary>${v.plans.filter(p=>!currentIDs.has(p.id)).map(p=>`<button class="plan-list-row" data-plans-detail="${safe(p.id)}"><span>${safe(p.name)}<small>${safe(statuses[p.status]||p.status)} · da ${safe(p.startMonth)}</small></span><span aria-hidden="true">›</span></button>`).join('')||'<p class="empty">Nessun altro piano</p>'}</details>${legacy.length?`<section class="card pad"><h2>Piani precedenti</h2><p class="hint">Le voci storiche non adottate sono conservate. Non duplicarle con un nuovo piano.</p>${legacy.map(r=>`<button class="plan-list-row" data-plans-legacy="${Number(r.extraordinary_source_row)}"><span>${safe(r.name)}<small>${safe(NativeExtraTitle(r.status))}</small></span><span aria-hidden="true">›</span></button>`).join('')}</section>`:''}${planningCard(d)}</div>`;
  };
  function NativeExtraTitle(status){return {Pagato:'Pagata',Programmato:'In corso',Previsto:'Da valutare',Annullato:'Annullata'}[status]||status;}
  function detail(p,v){
    let cycle=v.month;
    if(p.kind==='fixed'&&p.intervalMonths>1){const anchor=p.intervalAnchor||p.startMonth,[y,m]=anchor.split('-').map(Number),delta=(Number(cycle.slice(0,4))-y)*12+Number(cycle.slice(-2))-m;cycle=addMonth(anchor,Math.floor(delta/p.intervalMonths)*p.intervalMonths);}
    const payments=v.payments.filter(x=>x.planId===p.id),paid=p.kind!=='fund'&&payments.some(x=>['posted','deleting'].includes(x.status)&&(p.kind==='goal'||x.settlementKey===cycle));
    const payable=p.status==='active'&&!['advance','recovery'].includes(p.kind)&&p.startMonth<=current();
    return `<div class="plans-web"><button data-plans-back>‹ Budget</button><section class="card pad"><h2>${safe(p.name)}</h2><p>${safe(kinds[p.kind])} · ${safe(statuses[p.status]||p.status)}</p><p class="hint">${safe(p.startMonth)}${p.endMonth?' → '+safe(p.endMonth):' · Senza scadenza'}</p><div class="kv"><span>Categoria della spesa</span><strong>${safe(p.category||'Altro')}</strong></div><div class="kv"><span>Budget di ${safe(shortMonth(v.month))}</span><strong>${money(-p.contributionCents)}</strong></div>${p.kind==='advance'?`<div class="kv"><span>Mese beneficiario</span><strong>${safe(shortMonth(p.beneficiaryMonth))}</strong></div>`:p.kind!=='recovery'?`<div class="kv"><span>Destinato al fondo nel mese consultato</span><strong>${money(p.fundCents)}</strong></div>${p.fromGeneralSavingsCents>0?`<div class="kv"><span>Pagato dagli altri risparmi</span><strong>${money(p.fromGeneralSavingsCents)}</strong></div>`:''}`:''}${p.kind==='goal'?`<div class="kv"><span>Obiettivo</span><strong>${money(p.amountCents)}</strong></div><div class="kv"><span>Residuo</span><strong>${money(p.outstandingCents)}</strong></div>`:''}${payable&&!paid?`<button data-plans-pay="${safe(p.id)}">${p.kind==='goal'?'Paga dai risparmi e chiudi il piano':'Registra un pagamento'}</button>`:paid?'<p>Pagamento registrato</p>':''}</section><section class="card pad"><h2>Pagamenti</h2>${payments.map(p=>`<div class="kv"><span>${safe(p.date||'')}<small>${p.status==='posted'?'Pagato · movimento collegato':p.status==='deleting'?'Eliminazione da completare':'Da completare · non registrare una nuova spesa'}</small></span><strong>${money(p.amountCents)}</strong></div>${['posted','deleting'].includes(p.status)?`<button data-plans-payment="${safe(p.id)}">${p.status==='deleting'?'Completa eliminazione':'Gestisci pagamento'}</button>`:''}${p.status==='pending'?`<button data-plans-resume="${safe(p.id)}">Completa questa registrazione</button>`:''}`).join('')||'<p class="empty">Nessun pagamento registrato</p>'}</section>${p.status==='active'?`<section class="card pad">${!['advance','recovery'].includes(p.kind)?`<button data-plans-edit="${safe(p.id)}">Modifica le quote future</button>`:''}<button class="danger" data-plans-stop="${safe(p.id)}">${p.kind==='advance'?'Annulla l’intero anticipo':'Interrompi le quote future'}</button></section>`:''}</div>`;
  }
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
        busy=true;form.dataset.submitted='true';host.querySelectorAll('[data-plans-close]').forEach(b=>b.disabled=true);button.disabled=true;button.textContent='Salvataggio…';error.textContent='';
        // Freeze values once submitted. A retry must use the same payload and ID.
        form.querySelectorAll('input,select').forEach(x=>x.disabled=true);
        const result=await workerRequest(method,[payload]);
        if(result===false)throw Error('Il server non ha confermato la modifica.');
        host.classList.add('hidden');state.data=null;state.loadedDetail=false;if(method==='saveFinancePlan'){activePlan=null;setView('budget');}else load();osLoadHomeFinance();
      }catch(err){error.textContent=err.message+' Puoi riprovare la stessa operazione senza duplicarla.';button.textContent='Riprova';}
      finally{busy=false;button.disabled=false;host.querySelectorAll('[data-plans-close]').forEach(b=>b.disabled=false);}
    });return form;
  }
  const cents=f=>{const n=Number(f.get('amount'));if(!Number.isFinite(n)||n<=0||Math.abs(n*100-Math.round(n*100))>1e-6)throw Error('Usa un importo positivo con massimo due decimali.');return Math.round(n*100);};
  openExtra=function(){
    const form=modal('Nuovo piano',`<label class="full">Tipo<select name="kind">${Object.entries(kinds).map(([k,v])=>`<option value="${k}" ${k==='goal'?'selected':''}>${v}</option>`).join('')}</select></label>${field('Nome','name','text','','required maxlength="120" class="full"')}<div class="full" data-plan-fields></div>`,'saveFinancePlan',f=>{
      const kind=String(f.get('kind')),p={kind,name:String(f.get('name')).trim(),amountCents:cents(f),startMonth:String(f.get('startMonth')),category:String(f.get('category')||'Altro')};
      if(['goal','advance','recovery'].includes(kind))p.endMonth=String(f.get('endMonth'));
      if(kind==='advance')p.beneficiaryMonth=String(f.get('beneficiaryMonth'));
      if(kind==='fixed')p.intervalMonths=Number(f.get('intervalMonths'));
      if(kind==='recovery'){p.paymentDate=String(f.get('date'));if(f.get('movementId'))p.movementId=Number(f.get('movementId'));}
      newPlan(p,today(),'preview');return p;
    });
    const update=()=>{
      const kind=form.elements.kind.value,start=kind==='advance'?next(current()):current();
      const labels={goal:'Totale obiettivo €',fund:'Quota mensile €',fixed:'Importo per scadenza €',estimated:'Stima mensile €',advance:'Budget da anticipare €',recovery:'Spesa da recuperare €'};
      form.querySelector('[data-plan-fields]').innerHTML=`<div class="form-grid">${kind!=='advance'?`<label>Categoria della spesa<select name="category">${lifeOSContract.expenseCategories.map(c=>`<option ${c==='Altro'?'selected':''}>${safe(c)}</option>`).join('')}</select></label>`:''}${amount(labels[kind])}${monthField(kind==='advance'?'Primo mese di recupero':'Dal mese','startMonth',start)}${['goal','advance','recovery'].includes(kind)?monthField('Ultimo mese','endMonth',start):'<p class="hint">Senza scadenza: continua finché non lo interrompi.</p>'}${kind==='advance'?monthField('Mese beneficiario','beneficiaryMonth',current()):''}${kind==='fixed'?`<label>Ogni quanti mesi<select name="intervalMonths">${Array.from({length:12},(_,i)=>`<option value="${i+1}">Ogni ${i+1} ${i===0?'mese':'mesi'}</option>`).join('')}</select></label>`:''}${kind==='recovery'?`${field('Data della spesa','date','date',today(),'required max="'+today()+'"')}<label class="full">Movimento<select name="movementId"><option value="">Registra una nuova spesa</option></select></label><p class="hint full">Collega una spesa già registrata per recuperarla senza un secondo addebito.</p>`:''}<p class="hint full">${kind==='advance'?'Non sposta denaro tra conti: aumenta il budget del mese beneficiario e lo recupera nei mesi scelti.':kind==='recovery'?'La spesa incide sul saldo una sola volta; le quote recuperano il budget nei mesi scelti.':'Creare il piano non registra un pagamento.'}</p><section class="full" data-plan-preview aria-live="polite"></section></div>`;
      preview();
      if(kind==='recovery')loadMovements(form);
    };
    function preview(){
      const target=form.querySelector('[data-plan-preview]');if(!target)return;
      const save=form.querySelector('[type=submit]');save.disabled=true;
      try {
        const f=new FormData(form),kind=String(f.get('kind'));
        if(!f.get('amount')){target.textContent='Inserisci importo e mesi per vedere l’anteprima budget.';return;}
        const p=newPlan({kind,name:f.get('name')||'Anteprima',category:f.get('category')||'Altro',amountCents:cents(f),startMonth:f.get('startMonth'),endMonth:f.get('endMonth'),beneficiaryMonth:f.get('beneficiaryMonth'),intervalMonths:Number(f.get('intervalMonths')||1),paymentDate:f.get('date')},today(),'preview');
        p.status='active';
        const range=p.endMonth?months(p.startMonth,p.endMonth):[0,1,2].map(i=>addMonth(p.startMonth,i));
        if(kind==='advance')range.unshift(p.beneficiaryMonth);
        save.disabled=state.data?.plansV2?.version!==2;
        if(save.disabled)form.querySelector('[role=alert]').textContent=lifeOSContract.plansUnavailable;
        target.innerHTML='<h3>Anteprima budget'+(p.endMonth?'':' · primi tre mesi')+'</h3>'+range.map(m=>`<div class="kv"><span>${safe(shortMonth(m))}</span><strong>${money(-contribution(p,m))}</strong></div>`).join('');
      }catch(error){target.textContent=error.message;}
    }
    form.addEventListener('input',preview);form.addEventListener('change',preview);
    form.elements.kind.addEventListener('change',update);update();
  };
  async function loadMovements(form){
    const select=form.elements.movementId;if(!select)return;
    const date=form.elements.date;let revision=0;
    const refresh=async()=>{
      const token=++revision;select.disabled=true;
      try{const d=await workerRequest('getFinancePlanMovements',[date.value.slice(0,7)]);if(!form.isConnected||!select.isConnected||token!==revision)return;select.innerHTML='<option value="">Registra una nuova spesa</option>'+d.movements.map(m=>`<option value="${m.row}" data-cents="${m.amountCents}" data-date="${safe(m.date)}">${safe(m.name)} · ${money(m.amountCents)}</option>`).join('');}
      catch(err){if(token===revision&&select.isConnected)form.querySelector('[role=alert]').textContent='Movimenti non disponibili: '+err.message;}
      finally{if(token===revision&&select.isConnected&&!form.dataset.submitted)select.disabled=false;}
    };
    select.addEventListener('change',()=>{const o=select.selectedOptions[0];if(o?.dataset.cents){form.elements.amount.value=Number(o.dataset.cents)/100;date.value=o.dataset.date;}form.elements.amount.readOnly=!!o?.dataset.cents;date.readOnly=!!o?.dataset.cents;form.dispatchEvent(new Event('input'));});
    date.addEventListener('change',refresh);await refresh();
  }
  function paymentDetail(id){
    const p=view()?.payments.find(p=>p.id===id);if(!p)return;
    const removing=p.status==='deleting';
    const form=modal('Pagamento del piano',`<div class="full"><p>${safe(p.date)} · ${money(p.amountCents)}</p><p>Elimina il pagamento e il movimento collegato. Il saldo verrà aggiornato. Un piano interrotto resta interrotto; un obiettivo chiuso torna aperto.</p></div>`,removing?'resumeFinancePlanPayment':'deleteFinancePlanPayment',()=>({paymentId:id,...(removing?{}:{planId:p.planId})}));
    form.querySelector('[type=submit]').textContent=removing?'Completa eliminazione':'Elimina pagamento';
  }
  globalThis.openPlanPayment=(planId,paymentId)=>{activePlan=planId;closeDialog();setView('extras');paymentDetail(paymentId);};
  function pay(id){
    const p=plan(id);if(!p)return;
    const m=view().month<=current()?view().month:current();
    const form=modal('Paga o collega · '+p.name,`${amount('Importo effettivo €',(p.kind==='goal'?p.outstandingCents:['fixed','fund','estimated'].includes(p.kind)?(p.rateChanges||[]).filter(r=>r.fromMonth<=current()).sort((a,b)=>a.fromMonth.localeCompare(b.fromMonth)).at(-1)?.amountCents??p.amountCents:Math.max(p.contributionCents,1))/100)}${field('Data pagamento','date','date',today(),'required max="'+today()+'"')}${['fixed','estimated'].includes(p.kind)?monthField('Scadenza pagata','cycleMonth',m):''}${p.kind==='estimated'?field('Mesi coperti dalla bolletta','competenceMonths','number',1,'required min="1" max="12"'):''}<label class="full">Movimento<select name="movementId"><option value="">Registra un nuovo pagamento</option></select></label><p class="hint full">Collegare un movimento esistente non genera un nuovo addebito.${p.kind==='goal'?' Il pagamento chiude l’obiettivo e libera le quote future.':''}</p>${p.kind==='goal'?`<section class="full hidden" data-overage><label class="full">Eccedenza<select name="recoverDifference"><option value="">Usa i risparmi</option><option value="yes">Recupera solo l’eccedenza nei mesi successivi</option></select></label><div class="full hidden" data-excess-recovery>${monthField('Primo mese','recoveryStartMonth',next(current()))}${monthField('Ultimo mese','recoveryEndMonth',next(current()))}</div></section>`:''}`,'recordFinancePlanPayment',f=>{
      const out={planId:id,amountCents:cents(f),date:String(f.get('date')),cycleMonth:String(f.get('cycleMonth')||current()),competenceMonths:Number(f.get('competenceMonths')||1)};
      if(f.get('movementId'))out.movementId=Number(f.get('movementId'));
      if(f.get('recoverDifference')==='yes')Object.assign(out,{recoverDifference:true,recoveryStartMonth:String(f.get('recoveryStartMonth')),recoveryEndMonth:String(f.get('recoveryEndMonth'))});return out;
    });if(form.elements.cycleMonth)form.elements.cycleMonth.min='2024-01';
    if(form.elements.recoverDifference){const update=()=>{const extra=Number(form.elements.amount.value)*100>(p.outstandingCents??p.amountCents);form.querySelector('[data-overage]').classList.toggle('hidden',!extra);if(!extra)form.elements.recoverDifference.value='';};form.addEventListener('input',update);update();}
    form.elements.recoverDifference?.addEventListener('change',()=>form.querySelector('[data-excess-recovery]').classList.toggle('hidden',form.elements.recoverDifference.value!=='yes'));
    loadMovements(form);
  }
  function edit(id){const p=plan(id);if(!p)return;modal('Modifica quote future · '+p.name,`${amount(p.kind==='goal'?'Nuovo totale obiettivo €':'Nuova quota / scadenza €',(p.kind==='goal'?p.amountCents:(p.rateChanges||[]).filter(r=>r.fromMonth<=next(current())).sort((a,b)=>a.fromMonth.localeCompare(b.fromMonth)).at(-1)?.amountCents??p.amountCents)/100)}${monthField('Decorrenza','fromMonth',next(current()))}${p.kind==='goal'?monthField('Nuova scadenza','endMonth',p.endMonth<next(current())?next(current()):p.endMonth):''}<p class="hint full">Il mese corrente e le quote precedenti restano invariati.</p>`,'editFinancePlan',f=>({planId:id,amountCents:cents(f),fromMonth:String(f.get('fromMonth')),...(p.kind==='goal'?{endMonth:String(f.get('endMonth'))}:{})}));}
  function showInfo(){
    const host=document.getElementById('dialog');
    const sections=[["La regola di base", ["Il budget indica quanto puoi destinare ai mesi. Il saldo è il denaro reale sul conto. Accantonare modifica il budget, pagare registra una sola uscita reale."]], ["+ · Scegli cosa vuoi fare", ["Il + è indipendente dal mese che stai consultando. Prima scegli l’intento, poi nome, importo e mesi. Il giorno serve soltanto per il pagamento."]], ["Anticipa budget", ["250 € su ottobre, recuperati da novembre e dicembre: ottobre +250 €, novembre −125 €, dicembre −125 €. Il saldo non cambia. Non puoi cancellare solo le quote future mantenendo l’anticipo di un mese chiuso."]], ["Obiettivo finito", ["Distribuisci il totale sui mesi scelti. Quando paghi, confermi l’importo effettivo e chiudi le quote future. Le quote maturate restano nello storico.", "Previsti 600 €, pagati 500 €: il residuo rimane nei risparmi. Pagati 700 €: puoi recuperare i soli 100 € in più nei budget futuri; altrimenti restano a carico dei risparmi."]], ["Fondo senza scadenza · manutenzione auto", ["Scegli una quota mensile. Il fondo accumula nel tempo. Un pagamento riduce il fondo e il saldo una sola volta; il piano continua. Interrompi ferma le quote future senza generare una spesa e libera l’eventuale residuo nei risparmi generali."]], ["Affitto e utenze", ["Affitto: importo e periodicità fissi. Il pagamento chiude una scadenza, non il piano. Utenze: quota stimata dai pagamenti e dai mesi coperti. Una bolletta di 160 € per due mesi vale 80 €/mese. La media aggiorna soltanto le quote dal prossimo mese."]], ["Rateizza una spesa", ["Il pagamento è una sola uscita dai risparmi. Nei mesi scelti riduci il budget per ricostituirli. Questo piano non ha un secondo pulsante Paga. Se la registrazione è rimasta in sospeso, usa Completa questa registrazione, senza creare un altro pagamento."]], ["Piani precedenti e modifiche", ["Affitto, utenze e accantonamenti esistenti vengono adottati una sola volta, senza creare movimenti bancari né riscrivere i mesi chiusi. Il pagamento può essere nuovo oppure collegato a una spesa già registrata. Le modifiche alle quote decorrono da un mese futuro."]], ["Spesa rapida", ["Automatico applica le regole ordinarie. Da risparmi evita un nuovo addebito al budget. I piani, i recuperi e i pagamenti pianificati si gestiscono qui."]], ["Prima di confermare", ["Controlla l’anteprima mese per mese. Le quote sono esatte al centesimo. Un anticipo non è un’entrata bancaria. Un piano interrotto non cancella pagamenti già effettuati. L’adozione conserva le identità delle voci esistenti e sostituisce le loro quote dal mese corrente, senza duplicarle. Gli anticipi storici restano consultabili."]]];
    host.innerHTML=`<div class="modal" role="dialog" aria-modal="true" aria-label="Come funzionano i piani"><div class="modal-top"><h2>Come funzionano i piani</h2><button data-plans-close aria-label="Chiudi">×</button></div>${sections.map(([title,texts])=>`<section class="os-task-section"><h3>${safe(title)}</h3>${texts.map(t=>`<p>${safe(t)}</p>`).join('')}</section>`).join('')}<button data-plans-close>Fine</button></div>`;
    host.classList.remove('hidden');host.querySelector('button').focus();
  }
  document.addEventListener('click',e=>{
    const b=e.target.closest('[data-plans-payment],[data-new-extra],[data-plans-pay],[data-plans-edit],[data-plans-stop],[data-plans-close],[data-plans-refresh],[data-plans-resume],[data-plans-info],[data-plans-detail],[data-plans-back],[data-plans-legacy]');if(!b)return;
    e.preventDefault();e.stopImmediatePropagation();
    if(b.hasAttribute('data-plans-detail')){activePlan=b.dataset.plansDetail;render();}
    if(b.hasAttribute('data-plans-back')){activePlan=null;render();}
    if(b.hasAttribute('data-plans-legacy'))openExtraEdit(Number(b.dataset.plansLegacy));
    if(b.hasAttribute('data-plans-info'))showInfo();
    if(b.hasAttribute('data-new-extra')){activePlan=null;openExtra();}
    if(b.hasAttribute('data-plans-close'))document.getElementById('dialog').classList.add('hidden');
    if(b.hasAttribute('data-plans-payment'))paymentDetail(b.dataset.plansPayment);
    if(b.hasAttribute('data-plans-pay'))pay(b.dataset.plansPay);
    if(b.hasAttribute('data-plans-edit'))edit(b.dataset.plansEdit);
    if(b.hasAttribute('data-plans-stop')){const id=b.dataset.plansStop,p=plan(id);modal('Interrompi · '+p.name,'<p class="full">Conserva i pagamenti e lo storico. Le quote successive al mese corrente si interrompono. Gli anticipi di mesi chiusi non possono essere annullati.</p>','stopFinancePlan',()=>({planId:id}));}
    if(b.hasAttribute('data-plans-resume'))modal('Riprendi pagamento','<p class="full">Completa la conferma del movimento già avviato, senza creare un secondo addebito.</p>','resumeFinancePlanPayment',()=>({paymentId:b.dataset.plansResume}));
    if(b.hasAttribute('data-plans-refresh'))load();
  },true);
})();
