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
    const local=globalThis.lifeOSLocalMode,mode=local?.mode||'server';
    const host=document.getElementById('dialog');
    host.innerHTML=`<div class="modal" role="dialog" aria-modal="true" aria-label="Impostazioni"><div class="modal-top"><h2>Impostazioni</h2><button data-close aria-label="Chiudi">×</button></div><section class="os-task-section"><h3>Aspetto</h3><label>Tema<select data-settings-theme>${[['system','Automatico'],['light','Chiaro'],['dark','Scuro']].map(([key,label])=>`<option value="${key}" ${key===selected?'selected':''}>${label}</option>`).join('')}</select></label></section><section class="os-task-section"><h3>Modalità</h3><p>${mode==='demo'?'Demo locale':mode==='snapshot'?'Snapshot locale':'Server collegato'}</p><button data-settings-demo ${mode==='demo'?'disabled':''}>Apri demo completa</button>${mode!=='server'?'<button data-settings-restore>Torna ai dati precedenti</button>':'<button data-settings-disconnect>Scollega per consultare uno snapshot</button>'}<p class="hint">La demo contiene dati simulati. Non invia dati al server.</p></section><section class="os-task-section"><h3>Connessione Life OS</h3><label>Indirizzo del server<input data-settings-endpoint type="url" value="${escapeHtml(location.origin)}" placeholder="https://lifeos-native-test.a-zeroual-it.workers.dev"></label><label class="settings-confirm"><input data-settings-confirm type="checkbox">Confermo l’indirizzo del mio server Life OS</label><button data-settings-connect disabled>Collega</button><button data-settings-sync ${mode!=='server'?'disabled':''}>Sincronizza</button><a href="/login">Accedi</a><p role="status" aria-live="polite" data-settings-status></p></section><section class="os-task-section"><h3>Importazione e backup</h3><label>Importa snapshot JSON<input data-settings-import type="file" accept="application/json,.json" ${mode==='server'?'disabled':''}></label><button data-settings-paste ${mode==='server'?'disabled':''}>Incolla JSON</button><div class="hidden" data-settings-paste-area><label>Snapshot JSON<textarea name="snapshot" maxlength="5000000"></textarea></label><button data-settings-import-text>Importa snapshot</button></div><button data-settings-export>Esporta backup completo</button><p class="hint">Il backup contiene i dati già caricati su questo dispositivo. Le modifiche restano sullo stesso database usato dall’app.</p></section><button data-close>Fine</button></div>`;
    host.classList.remove('hidden');
    const report=error=>{host.querySelector('[data-settings-status]').textContent=error.message||String(error);};
    const connect=host.querySelector('[data-settings-connect]');host.querySelector('[data-settings-confirm]').onchange=e=>connect.disabled=!e.target.checked;
    connect.onclick=()=>{try{const url=new URL(host.querySelector('[data-settings-endpoint]').value.trim());if(url.protocol!=='https:'||url.username||url.password||url.search||url.hash||url.pathname!=='/')throw Error('Inserisci l’indirizzo HTTPS del server Life OS.');if((globalThis.lifeOSDeviceBackup?.().pending.length||0)&&url.origin!==location.origin)throw Error('Ci sono movimenti da conservare. Sincronizza prima di cambiare server.');if(url.origin===location.origin)local.server();else location.assign(url.origin);}catch(error){report(error);}};

    host.querySelector('[data-settings-demo]').onclick=()=>{if(confirm('Aprire la demo con dati simulati? I dati attuali verranno conservati separatamente.'))try{local.demo();}catch(error){report(error);}};
    host.querySelector('[data-settings-restore]')?.addEventListener('click',()=>{try{local.server();}catch(error){report(error);}});
    host.querySelector('[data-settings-disconnect]')?.addEventListener('click',()=>{try{local.disconnect();}catch(error){report(error);}});
    host.querySelector('[data-settings-paste]').onclick=()=>host.querySelector('[data-settings-paste-area]').classList.remove('hidden');
    const importText=text=>{if(text.length>5000000)throw Error('Il file è troppo grande.');local.import(JSON.parse(text));};
    host.querySelector('[data-settings-import-text]').onclick=()=>{try{importText(host.querySelector('[name=snapshot]').value);}catch(error){report(error);}};
    host.querySelector('[data-settings-import]').onchange=async e=>{try{const file=e.target.files[0];if(!file)return;if(file.size>5000000)throw Error('Il file è troppo grande.');importText(await file.text());}catch(error){report(error);}};
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
      const pending=(mode==='server'?(globalThis.lifeOSDeviceBackup?.().pending||[]):[]).map(w=>({id:w.id,method:'saveTransaction',payload:w.payload,accepted:false}));
      const current={...(local?.archive||{}),life:local?.archive?.life||life.data||{},finance:state.data||{},plan:state.data?.extraPlan||{},pending,demo:mode==='demo',imported:mode==='snapshot',financeMonth:`${state.year}-${String(state.month).padStart(2,'0')}`,calendarMonth:life.month,routineDay:life.data?.today||''};
      const blob=new Blob([JSON.stringify({format:'LifeOS-native-backup-v2',current,...(mode!=='server'&&local?.previousArchive?{previous:local.previousArchive}:{}),...(local?.rawArchive?{rawLocalArchive:local.rawArchive}:{}),...(globalThis.lifeOSDeviceBackup?.().rawArchive?{rawDeviceArchive:globalThis.lifeOSDeviceBackup().rawArchive}:{})},null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),link=document.createElement('a');
      link.href=url;link.download='LifeOS-backup-'+todayIso()+'.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
    };
  };
})();
