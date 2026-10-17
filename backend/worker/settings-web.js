/* Shared controls retain browser/OS storage on their respective devices. */
(() => {
  const control=document.querySelector('.theme-toggle');
  function theme(value){
    try{if(value==='system')localStorage.removeItem('life-theme');else localStorage.setItem('life-theme',value);}catch{}
    document.documentElement.dataset.theme=value==='system'?(matchMedia('(prefers-color-scheme: light)').matches?'light':'dark'):value;
    document.querySelector('meta[name="theme-color"]').content=document.documentElement.dataset.theme==='light'?'#f3f3f5':'#0c0c0e';
  }
  const draw=()=>{control.textContent='⚙︎';control.setAttribute('aria-label','Impostazioni');control.title='Impostazioni';};
  matchMedia('(prefers-color-scheme: light)').addEventListener('change',draw);draw();
  control.onclick=()=>{
    let selected='system';try{selected=localStorage.getItem('life-theme')||'system';}catch{}
    const host=document.getElementById('dialog');
    host.innerHTML=`<div class="modal" role="dialog" aria-modal="true" aria-label="Impostazioni"><div class="modal-top"><h2>Impostazioni</h2><button data-close aria-label="Chiudi">×</button></div><section class="os-task-section"><h3>Aspetto</h3><label>Tema<select data-settings-theme>${[['system','Automatico'],['light','Chiaro'],['dark','Scuro']].map(([key,label])=>`<option value="${key}" ${key===selected?'selected':''}>${label}</option>`).join('')}</select></label></section><section class="os-task-section"><h3>Connessione Life OS</h3><p>${escapeHtml(location.host)}</p><button data-settings-sync>Sincronizza</button><p role="status" aria-live="polite" data-settings-status></p></section><section class="os-task-section"><h3>Importazione e backup</h3><button data-settings-export>Esporta backup completo</button><p class="hint">Il backup contiene i dati già caricati su questo dispositivo. Le modifiche restano sullo stesso database usato dall’app.</p></section><button data-close>Fine</button></div>`;
    host.classList.remove('hidden');
    host.querySelector('[data-settings-theme]').onchange=e=>{theme(e.target.value);draw();};
    host.querySelector('[data-settings-sync]').onclick=async e=>{
      const button=e.currentTarget,status=host.querySelector('[data-settings-status]');button.disabled=true;status.textContent='Aggiornamento…';
      try{
        const d=await workerRequest('getFinanceOverview',[state.year,state.month],{fresh:true});
        const current=await workerRequest('getLifeData',[life.month],{fresh:true});
        state.data=d;state.loadedDetail=false;life.data=current;renderLifeOS();if(['overview','extras'].includes(state.view))render();else if(['budget','analysis','movements'].includes(state.view))load();
        const pending=globalThis.lifeOSDeviceBackup?.().pending.length||0;
        status.textContent=pending?`${pending} movimenti ancora in attesa di sincronizzazione.`:'Aggiornamento completato.';
      }catch(error){status.textContent=error.message;}
      finally{button.disabled=false;}
    };
    host.querySelector('[data-settings-export]').onclick=()=>{
      const pending=(globalThis.lifeOSDeviceBackup?.().pending||[]).map(w=>({id:w.id,method:'saveTransaction',payload:w.payload}));
      const current={life:life.data||{},finance:state.data||{},plan:state.data?.extraPlan||{},pending,demo:false,imported:false,financeMonth:`${state.year}-${String(state.month).padStart(2,'0')}`,calendarMonth:life.month,routineDay:life.data?.today||''};
      const blob=new Blob([JSON.stringify({format:'LifeOS-native-backup-v2',current},null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),link=document.createElement('a');
      link.href=url;link.download='LifeOS-backup-'+todayIso()+'.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
    };
  };
})();
