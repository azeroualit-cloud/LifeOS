import {LocalModel,demoArchive,snapshotArchive} from './local-model.mjs';
(() => {
  const key='lifeos-web-local-v2',transport=workerRequest;
  let mode='server',model=null,snapshot=null,previous=null,invalid=false;
  const status=document.createElement('p');status.className='hint';status.id='platform-local-status';status.setAttribute('role','status');document.getElementById('error').before(status);
  function persist(value=model){localStorage.setItem(key,JSON.stringify({mode,archive:value?.archive||snapshot,planState:value?.planState,revision:value?.revision,previous}));}
  function restore(raw){
    if(!raw||!['demo','snapshot'].includes(raw.mode)||!raw.archive||!/^20\d\d-(0[1-9]|1[0-2])$/.test(raw.archive.financeMonth)||!['tasks','categories','routines','events','shifts'].every(k=>Array.isArray(raw.archive.life?.[k])))throw Error('Archivio locale non valido.');
    snapshotArchive({current:raw.archive});
    if(raw.revision!==undefined&&(!Number.isSafeInteger(raw.revision)||raw.revision<0))throw Error('Revisione archivio non valida.');
    if(raw.planState&&(raw.planState.version!==1||!['plans','payments','commands'].every(k=>raw.planState[k]&&typeof raw.planState[k]==='object'&&!Array.isArray(raw.planState[k]))))throw Error('Archivio piani non valido.');
    mode=raw.mode;previous=raw.previous&&Number.isInteger(raw.previous.year)&&Number.isInteger(raw.previous.month)&&raw.previous.month>=1&&raw.previous.month<=12&&/^20\d\d-(0[1-9]|1[0-2])$/.test(raw.previous.calendarMonth)?raw.previous:null;
    if(mode==='demo'){model=new LocalModel(raw.archive,todayIso(),persist);if(raw.planState)model.planState=raw.planState;model.revision=raw.revision||0;}
    else if(mode==='snapshot')snapshot=raw.archive;else throw Error('Modalità non valida.');
  }
  try{const raw=JSON.parse(localStorage.getItem(key)||'null');if(raw)restore(raw);}catch{invalid=true;status.textContent='Archivio locale non leggibile. I dati originali sono conservati.';}
  function draw(){document.getElementById('platform-sync-status').hidden=mode!=='server';if(!invalid)status.textContent=mode==='demo'?'Demo con dati simulati · nessuna modifica al server.':mode==='snapshot'?'Snapshot locale · consultazione senza modificare il database.':'';}
  function connection(){
    const finance=state.data||life.finance||{},pending=(globalThis.lifeOSDeviceBackup?.().pending||[]).map(w=>({id:w.id,method:'saveTransaction',payload:w.payload,accepted:false}));
    return {year:state.year,month:state.month,calendarMonth:life.month,archive:{life:structuredClone(life.data||{}),finance:structuredClone(finance),plan:structuredClone(finance.extraPlan||{}),pending,demo:false,imported:false,endpoint:location.origin,financeMonth:finance.key||`${state.year}-${String(state.month).padStart(2,'0')}`,calendarMonth:life.month,routineDay:life.data?.today||todayIso()}};
  }
  function apply(){
    const archive=mode==='demo'?model.archive:snapshot;
    if(archive){const m=archive.financeMonth||todayIso().slice(0,7);state.year=Number(m.slice(0,4));state.month=Number(m.slice(-2));life.month=archive.calendarMonth||m;}
    else if(previous){state.year=previous.year;state.month=previous.month;life.month=previous.calendarMonth;}
    const view=state.view;++state.loadRevision;++life.readRevision;life.homeFinanceRevision=(life.homeFinanceRevision||0)+1;
    state.data=null;state.loadedDetail=false;life.finance=null;life.data=null;life.selected=null;
    document.querySelectorAll('.view').forEach(element=>element.replaceChildren());
    closeDialog();draw();loadLifeOS();setView(view);
  }
  globalThis.lifeOSLocalMode={
    get mode(){return mode;},
    get isValid(){return !invalid;},
    get previousArchive(){return previous?.archive?structuredClone(previous.archive):null;},
    get rawArchive(){return invalid?localStorage.getItem(key):null;},
    get archive(){return mode==='demo'?structuredClone(model.archive):mode==='snapshot'?structuredClone(snapshot):null;},
    demo(){
      if(state.busy||life.busy)throw Error('Attendi la fine dell’operazione in corso.');
      if(invalid)throw Error('Conserva prima l’archivio locale non leggibile.');
      if(mode==='demo')throw Error('La demo è già aperta. Le modifiche locali sono conservate.');
      const old={mode,model,snapshot,previous};if(mode==='server')previous=connection();mode='demo';model=new LocalModel(demoArchive(todayIso()),todayIso(),persist);
      try{persist();}catch(error){({mode,model,snapshot,previous}=old);throw error;}apply();
    },
    import(raw){
      if(mode==='server')throw Error('Scollega prima il server per importare uno snapshot locale.');
      const next=snapshotArchive(raw,snapshot?.financeMonth||`${state.year}-${String(state.month).padStart(2,'0')}`);const old={mode,model,snapshot};mode='snapshot';model=null;snapshot=next;
      try{persist();}catch(error){({mode,model,snapshot}=old);throw error;}apply();
    },
    disconnect(){
      const finance=state.data||life.finance;if(!finance)throw Error('Carica prima uno snapshot da conservare.');
      const old={mode,model,snapshot,previous};previous=connection();snapshot=snapshotArchive(finance);mode='snapshot';model=null;
      try{persist();}catch(error){({mode,model,snapshot,previous}=old);throw error;}apply();
    },
    server(){if(invalid){const raw=localStorage.getItem(key);if(raw)localStorage.setItem(key+'-recovery-'+crypto.randomUUID(),raw);}localStorage.removeItem(key);mode='server';model=null;snapshot=null;invalid=false;apply();},
  };
  workerRequest=async function(method,args=[],options){
    if(invalid)throw Error('Archivio locale non leggibile. I dati originali sono conservati.');
    if(mode==='server')return transport(method,args,options);
    if(method==='getFinanceCategoryOptions')return [...new Set([...lifeOSContract.expenseCategories,...lifeOSContract.incomeCategories])];
    if(mode==='demo'){
      model.today=todayIso();
      try{return await model.request(method,args);}
      catch(error){const raw=JSON.parse(localStorage.getItem(key));if(raw)restore(raw);throw error;}
    }
    if(method==='getLifeData')return {...structuredClone(snapshot.life),today:todayIso(),month:args[0]};
    if(['getFinanceOverview','getFinanceData','getFinanceExtras'].includes(method)){
      const m=`${args[0]}-${String(args[1]).padStart(2,'0')}`;
      if(m!==snapshot.financeMonth)throw Error('Questo mese non è incluso nello snapshot. Collega Life OS per aggiornarlo.');
      return {...structuredClone(snapshot.finance),key:m,year:Number(m.slice(0,4)),month:Number(m.slice(-2)),extraPlan:structuredClone(snapshot.plan)};
    }
    if(method==='getFinancePlans'&&snapshot.finance.plansV2)return structuredClone(snapshot.finance.plansV2);
    throw Error('Questo snapshot è consultabile. Per modificare attività e calendario usa la demo o collega Life OS.');
  };
  if(mode!=='server'){
    const archive=mode==='demo'?model.archive:snapshot,m=archive.financeMonth||todayIso().slice(0,7);state.year=Number(m.slice(0,4));state.month=Number(m.slice(-2));life.month=archive.calendarMonth||m;
  }
  draw();
})();
