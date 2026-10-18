/* Same quick-movement contract as NativeStore: durable payload first, then sync. */
(() => {
  const transport=workerRequest,key='lifeos-web-device-v2';
  let device={pending:[],cache:{}},draining=null,offline=false,corrupt=false,lastFailure='';
  try{const saved=JSON.parse(localStorage.getItem(key)||'null');if(saved){if(!Array.isArray(saved.pending)||!saved.pending.every(w=>w&&typeof w.id==='string'&&w.payload&&w.payload.requestId===w.id)||!saved.cache||Array.isArray(saved.cache))throw Error('Archivio non valido.');device=saved;}}catch{corrupt=true;}
  const status=document.createElement('div');status.id='platform-sync-status';status.className='hint';status.setAttribute('role','status');document.getElementById('error').before(status);
  function persist(){
    if(corrupt)throw Error('Archivio locale non leggibile. I dati originali sono conservati.');
    // Remote read caches are replaceable; pending financial writes never are.
    while(true){
      try{localStorage.setItem(key,JSON.stringify(device));return;}
      catch(error){const oldest=Object.keys(device.cache)[0];if(error.name!=='QuotaExceededError'||!oldest)throw error;delete device.cache[oldest];}
    }
  }
  function draw(){status.textContent=corrupt?'Archivio locale non leggibile. I dati originali sono conservati.':device.pending.length?`${device.pending.length} movimenti salvati sul dispositivo. In attesa di sincronizzazione. Il saldo mostra l’ultimo dato del server. ${lastFailure}`:offline?'Dati locali · connessione non disponibile. Sincronizza per aggiornare.':'';}
  const cacheKey=(method,args)=>`${method}:${JSON.stringify(args)}`;
  async function drain(){
    if(globalThis.lifeOSLocalMode&&(globalThis.lifeOSLocalMode.mode!=='server'||!globalThis.lifeOSLocalMode.isValid))return;
    if(draining)return draining;
    draining=(async()=>{
      for(const write of [...device.pending]){
        try{
          const result=await transport('saveTransaction',[write.payload]);if(result!==true)throw Error('Movimento non confermato.');lastFailure='';
          const previous=device.pending;device.pending=device.pending.filter(p=>p.id!==write.id);
          try{persist();}catch(error){device.pending=previous;throw error;}
        }catch(error){lastFailure=String(error.message||error).slice(0,200);break;}
      }
      draw();
    })();
    try{await draining;}finally{draining=null;}
  }
  workerRequest=async function(method,args,{fresh=false}={}){
    if(method==='saveTransaction'){
      if(corrupt)throw Error('Archivio locale non leggibile. I dati originali sono conservati.');
      const payload=structuredClone(args[0]),id=payload.requestId||crypto.randomUUID();payload.requestId=id;
      const previous=device.pending.find(w=>w.id===id);
      if(previous&&JSON.stringify(previous.payload)!==JSON.stringify(payload))throw Error('Operazione già salvata con dati diversi. Sincronizza prima di riprovare.');
      if(!previous){device.pending.push({id,payload});try{persist();}catch(error){device.pending=device.pending.filter(w=>w.id!==id);throw Error('Impossibile conservare il movimento sul dispositivo. Nessuna richiesta inviata.');}}
      draw();await drain();return true;
    }
    const cached=['getFinanceOverview','getFinanceData','getLifeData'].includes(method),slot=cacheKey(method,args);
    if(cached&&device.pending.length)await drain();
    try{
      const result=await transport(method,args);
      if(cached){device.cache[slot]=result;try{persist();}catch{}offline=false;draw();}
      return result;
    }catch(error){
      // Never substitute a different month's data or an expired authorization.
      if(!fresh&&cached&&device.cache[slot]&&!/sessione|accedi/i.test(error.message)){
        offline=true;draw();return structuredClone(device.cache[slot]);
      }
      throw error;
    }
  };
  window.addEventListener('online',async()=>{if(globalThis.lifeOSLocalMode?.mode!=='server')return;await drain();if(state.data)load();});
  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')drain();});
  globalThis.lifeOSDeviceBackup=()=>({...structuredClone(device),rawArchive:corrupt?localStorage.getItem(key):null});
  const movementRender=renderMovements;
  renderMovements=function(){
    movementRender();
    if(device.pending.length)document.getElementById('movements').insertAdjacentHTML('afterbegin',`<section class="card pad"><h2>Salvati sul dispositivo</h2>${device.pending.map(w=>`<div class="kv"><span>${escapeHtml(w.payload.name)}<small>In attesa di sincronizzazione</small></span><strong>${state.assetsVisible?exactEuro(Number(w.payload.amount)):'••••'}</strong></div>`).join('')}</section>`);
  };
  draw();
})();
