import {romeInput,weightLink} from './weight-transfer.mjs';
(() => {
 const renderHome=osToday;
 osToday=function(){const html=renderHome();return html.slice(0,-6)+`<section class="os-card"><div class="card-title"><h2>Peso e calorie</h2><button data-web-weight aria-label="Aggiungi peso">+</button></div><p class="hint">La lettura di Apple Health è disponibile nell’app. Puoi preparare una pesata da confermare su iPhone.</p></section></div>`;};
 document.addEventListener('click',e=>{
  if(!e.target.closest('[data-web-weight]'))return;
  const host=document.getElementById('life-dialog'),id=crypto.randomUUID();
  host.innerHTML=`<div class="modal os-dialog" role="dialog" aria-modal="true" aria-label="Aggiungi peso"><div class="modal-top"><h2>Aggiungi peso</h2><button data-life-close aria-label="Chiudi">×</button></div><form id="web-weight-form" class="form-grid"><label>Peso in chilogrammi<input name="weight" type="number" min="0.001" max="500" step="any" required></label><label>Data · Roma<input name="date" type="datetime-local" max="${romeInput()}" value="${romeInput()}" required></label><p class="hint full">La pesata viene salvata in Apple Health dopo la conferma nell’app Life OS su iPhone. Questi valori non vengono inviati al server.</p><p role="alert" class="os-form-error full"></p><div class="form-actions"><button type="button" data-life-close>Annulla</button><button type="submit">Continua nell’app</button></div><div class="full" data-weight-handoff></div></form></div>`;
  host.classList.remove('hidden');const form=host.querySelector('form');let link=null;
  form.onsubmit=e=>{
   e.preventDefault();if(!form.reportValidity())return;
   try{
    link??=weightLink(form.elements.weight.value,form.elements.date.value,id);
    form.elements.weight.readOnly=true;form.elements.date.readOnly=true;
    const target=form.querySelector('[data-weight-handoff]');target.replaceChildren();
    const anchor=document.createElement('a');anchor.href=link;anchor.textContent='Apri Life OS su iPhone e conferma la pesata';anchor.className='os-button';anchor.dataset.weightLink='';target.append(anchor);
    const text=document.createElement('p');text.className='hint';text.textContent='Il salvataggio non è ancora confermato. Apri il link con Life OS 0.9.5 o successivo e tocca Salva nell’app.';target.append(text);
   }catch(error){form.querySelector('[role=alert]').textContent=error.message;}
  };
 });
})();
