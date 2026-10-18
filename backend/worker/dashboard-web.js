/* Home follows the native order: rolling week, day summary, next time, habits. */
(() => {
  const safe=osSafe;
  const shiftNames={morning:'di mattina',afternoon:'di pomeriggio',night:'di notte',rest:'di riposo',holiday:'in ferie'};
  const labels=[['fajr','Prima dell’alba'],['sunrise','Alba'],['dhuhr','Mezzogiorno'],['asr','Pomeriggio'],['maghrib','Tramonto'],['isha','Notte']];
  const addDay=(day,n)=>{const d=new Date(day+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10);};
  let agenda=[];
  function sheet(title,body){
    const host=document.getElementById('life-dialog');
    host.innerHTML=`<div class="modal os-dialog" role="dialog" aria-modal="true" aria-label="${safe(title)}"><div class="modal-top"><h2>${safe(title)}</h2><button data-life-close aria-label="Chiudi">×</button></div>${body}</div>`;
    host.classList.remove('hidden');
  }
  function nextTime(now=new Date()){
    const today=todayIso(),clock=new Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Rome',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).format(now);
    const times=osPrayerTimes(today),found=labels.find(([key])=>times[key].label>clock);
    const day=found?today:addDay(today,1),entry=found||labels[0],schedule=found?times:osPrayerTimes(day);
    return {day,label:entry[1],time:schedule[entry[0]].label};
  }
  osToday=function(){
    const d=life.data,today=d.today,tomorrow=addDay(today,1),end=addDay(today,7),seen=new Set();
    const hour=Number(new Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Rome',hour:'2-digit',hourCycle:'h23'}).format(new Date()));
    const clock=new Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Rome',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).format(new Date());
    agenda=[...(d.upcomingEvents||[]),...(d.events||[])].filter(e=>{
      const key=`${e.id}:${e.day}`;
      if(e.day<today||e.day>=end||(e.occurrence_status||'open')!=='open'||e.day===today&&e.start_time&&e.start_time<clock||seen.has(key))return false;
      seen.add(key);return true;
    }).sort((a,b)=>`${a.day}|${a.start_time||''}|${String(a.id).padStart(10,'0')}`.localeCompare(`${b.day}|${b.start_time||''}|${String(b.id).padStart(10,'0')}`));
    const shifts=new Map((d.shifts||[]).map(s=>[s.day,s.kind]));
    const mark=new Set([...(d.events||[]).map(e=>e.day),...(d.tasks||[]).map(t=>t.scheduled_date)]);
    const week=Array.from({length:7},(_,i)=>addDay(today,i-3)).map(day=>{
      const date=new Date(day+'T12:00:00Z'),kind=shifts.get(day);
      return `<div><small>${['D','L','M','M','G','V','S'][date.getUTCDay()]}</small><button class="os-day ${day===today?'today selected':''}" data-home-day="${day}" data-kind="${kind||''}" aria-label="${safe(osDate(day))}${kind?' · '+safe(osShift[kind]):''}"><b>${date.getUTCDate()}</b><span class="os-shift ${kind?'':'no-shift'}">${kind?osShiftInitial[kind]:''}</span><span class="os-day-mark ${mark.has(day)?'dot':''}"></span></button></div>`;
    }).join('');
    const parts=[];
    if(life.weather){const w=life.weather,c=w.code===0?'sereno':w.code<=3?'cielo nuvoloso':w.code<50?'nebbia':w.code<70?'pioggia':w.code<80?'neve':w.code<95?'rovesci':'temporali';parts.push(`A Empoli, ${Math.round(w.temp)}° e ${c}.`);}
    const shift=shifts.get(today),next=shifts.get(tomorrow);
    if(shifts.get(addDay(today,-1))==='night'&&hour<6)parts.push('Stai terminando il turno di notte.');
    const phrase=(kind,when)=>`${when} ${['rest','holiday'].includes(kind)?'sei':'lavori'} ${shiftNames[kind]}.`;
    if(shift&&shift===next)parts.push(phrase(shift,'Oggi e domani'));
    else {if(shift)parts.push(phrase(shift,'Oggi'));if(next)parts.push(phrase(next,'Domani'));}
    if(!shift&&!next)parts.push('Turni non disponibili.');
    if(agenda.length){const e=agenda[0],when=e.day===today?'Oggi':e.day===tomorrow?'Domani':osDate(e.day);parts.push(`${when}: ${String(e.title||'Appuntamento').replace(/\s+/g,' ').slice(0,70)}${e.start_time?' alle '+e.start_time:''}.`);}
    else parts.push('Nessun appuntamento nei prossimi 7 giorni.');
    const nextSolar=nextTime(),habits=(d.routines||[]).filter(h=>lifeOSHabits.due(h,today));
    return `<div class="home-native"><section class="home-week"><div class="card-title"><span>${safe(titleMonth(Number(today.slice(0,4)),Number(today.slice(5,7))))}</span><button data-home-day="${today}" aria-label="Apri calendario">▦</button></div><div class="home-week-grid">${week}</div></section><section><p class="hint">${hour<12?'Buongiorno':hour<18?'Buon pomeriggio':'Buonasera'}, Anass.</p><p class="home-summary">${safe(parts.join(' '))}</p>${agenda.length?`<button data-home-agenda>${agenda.length===1?'Dettagli appuntamento':'Tutti i '+agenda.length+' appuntamenti'}</button>`:''}</section><button class="home-next-time" data-home-times-sheet aria-label="Prossimo orario, ${safe(nextSolar.label)}, ${safe(nextSolar.time)}"><span>${safe(nextSolar.label)}</span><strong>${safe(nextSolar.time)}</strong></button><section class="os-card"><div class="card-title"><h2>Abitudini</h2><button data-life-routine-manage>Gestisci</button></div>${habits.map(h=>`<button class="home-habit" data-life-routine="${h.id}" aria-pressed="${!!h.checked}"><span aria-hidden="true">${h.checked?'✓':'○'}</span>${safe(h.title)}</button>`).join('')||(d.routines?.length?'<p class="hint">Nessuna abitudine prevista per oggi.</p>':'<button data-life-routine-manage>Aggiungi la prima abitudine</button>')}</section></div>`;
  };
  document.addEventListener('click',async e=>{
    const b=e.target.closest('[data-home-day],[data-home-times-sheet],[data-home-agenda]');if(!b)return;
    if(b.hasAttribute('data-home-day')){
      const day=b.dataset.homeDay,month=day.slice(0,7),changed=life.month!==month;
      life.month=month;life.selected=day;setView('calendar');if(changed)await loadLifeOS();
    }
    if(b.hasAttribute('data-home-times-sheet')){const next=nextTime(),times=osPrayerTimes(next.day);sheet('Empoli · '+osDate(next.day),labels.map(([key,label])=>`<div class="kv"><span>${label}</span><strong>${safe(times[key].label)}</strong></div>`).join(''));}
    if(b.hasAttribute('data-home-agenda'))sheet('Appuntamenti',agenda.map(ev=>`<div class="os-agenda-entry"><button class="os-agenda-row" data-life-event="${ev.id}"><span>${safe(ev.title)}<small>${safe(osDate(ev.day))} · ${safe(ev.start_time||'Tutto il giorno')}</small></span></button><button data-life-occurrence="${ev.id}:${ev.day}:done" aria-label="Segna fatto ${safe(ev.title)}">Fatto</button></div>`).join(''));
  });
})();
