import {habitSchedule,habitDue,habitSummary,habitWeekdays} from './habits.mjs';
(() => {
 const supported=()=>life.data?.routineScheduleVersion===1||globalThis.lifeOSLocalMode?.mode==='demo';
 function updateFields(form){const mode=form.elements.mode.value;form.querySelector('[data-habit-interval]').hidden=mode!=='interval';form.querySelector('[data-habit-weekdays]').hidden=mode!=='weekdays';form.querySelector('[data-habit-start]').hidden=mode==='daily';form.elements.startDate.required=mode!=='daily';form.elements.startDate.disabled=mode==='daily';form.elements.intervalDays.required=mode==='interval';form.elements.intervalDays.disabled=mode!=='interval';}
 function edit(routine){
  const form=document.getElementById('os-routine-form'),s=habitSchedule(routine.schedule);
  form.elements.record_id.value=routine.id;form.elements.title.value=routine.title;form.elements.mode.value=s.mode;form.elements.intervalDays.value=s.mode==='interval'?s.intervalDays:2;form.elements.startDate.value=s.startDate||life.data.today;
  form.querySelectorAll('[name=weekday]').forEach(el=>el.checked=s.weekdays.includes(Number(el.value)));
  form.querySelector('[type=submit]').textContent='Salva';form.querySelector('[data-habit-cancel]').hidden=false;updateFields(form);form.elements.title.focus();
 }
 function open(){
  const host=document.getElementById('life-dialog'),ok=supported();
  host.innerHTML=`<div class="modal os-dialog os-routine-dialog" role="dialog" aria-modal="true" aria-label="Abitudini"><div class="os-topline"><h2>Abitudini</h2><button data-life-close aria-label="Chiudi">×</button></div><p>La dashboard mostra le abitudini previste oggi. Ogni data ha i propri completamenti.</p>${ok?'':'<p role="alert">Aggiorna il Worker collegato per programmare le abitudini.</p>'}<div class="os-routine-manager">${(life.data.routines||[]).map(h=>`<div><span>${osSafe(h.title)}<small style="display:block">${osSafe(habitSummary(h))}${h.schedule?.startDate?' · Dal '+osSafe(h.schedule.startDate):''}</small></span><button data-life-routine-edit="${h.id}" aria-label="Modifica ${osSafe(h.title)}">Modifica</button><button data-life-routine-delete="${h.id}" aria-label="Elimina ${osSafe(h.title)}">Elimina</button></div>`).join('')}</div><form id="os-routine-form" class="os-form"><fieldset ${ok?'':'disabled'} style="border:0;padding:0;min-width:0" class="wide habit-fields"><input type="hidden" name="record_id" value=""><label>Nome<input name="title" maxlength="60" required autocomplete="off"></label><label>Ripetizione<select name="mode"><option value="daily">Ogni giorno</option><option value="interval">Ogni N giorni</option><option value="weekdays">Giorni della settimana</option></select></label><label data-habit-interval hidden>Intervallo in giorni<input name="intervalDays" type="number" min="1" max="365" step="1" value="2"></label><fieldset data-habit-weekdays hidden style="border:0;padding:0"><legend>Giorni della settimana</legend>${habitWeekdays.map((name,i)=>`<label style="display:flex;align-items:center;min-height:44px;gap:8px"><input name="weekday" type="checkbox" value="${i+1}" style="width:auto">${name}</label>`).join('')}</fieldset><label data-habit-start hidden>Data di inizio<input name="startDate" type="date" value="${life.data.today}"></label><p class="hint">Gli intervalli si contano dalla data di inizio, anche se salti un completamento.</p><p role="alert" data-habit-error></p><div class="os-form-actions"><button type="button" data-habit-cancel hidden>Annulla modifica</button><button type="submit">Aggiungi</button></div></fieldset></form></div>`;
  host.classList.remove('hidden');const form=host.querySelector('form');form.elements.mode.onchange=()=>updateFields(form);form.querySelector('[data-habit-cancel]').onclick=open;updateFields(form);
 }
 async function save(form){
  if(life.busy||!supported()||!form.reportValidity())return;
  const error=form.querySelector('[data-habit-error]');error.textContent='';
  try{
   const schedule=habitSchedule({mode:form.elements.mode.value,intervalDays:Number(form.elements.intervalDays.value),weekdays:[...form.querySelectorAll('[name=weekday]:checked')].map(el=>Number(el.value)),startDate:form.elements.mode.value==='daily'?'':form.elements.startDate.value});
   const payload={id:Number(form.elements.record_id.value||0),title:form.elements.title.value,schedule};
   form.querySelector('fieldset').disabled=true;form.closest('.modal').querySelector('[data-life-close]').disabled=true;
   const result=await osWrite('saveRoutine',payload);if(result)open();
  }catch(e){error.textContent=e.message;}
  finally{if(form.isConnected){form.querySelector('fieldset').disabled=!supported();form.closest('.modal').querySelector('[data-life-close]').disabled=false;}}
 }
 globalThis.lifeOSHabits={due:habitDue,summary:habitSummary,open,edit,save};
})();
