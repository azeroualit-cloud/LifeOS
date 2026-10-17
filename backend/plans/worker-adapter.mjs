import {PlanError,month,addMonth} from './engine.mjs';
import {adoptLegacy,readLegacyContext,replacement,hideAdoptedLegacy} from './legacy.mjs';
import {D1PlanRepository,PlanService} from './service.mjs';
const METHODS={saveFinancePlan:'create',recordFinancePlanPayment:'pay',stopFinancePlan:'stop',editFinancePlan:'edit'};
const readMethods=new Set(['getFinanceOverview','getFinanceData']);
const protectedCash=new Set(['editMovement','deleteMovement']);
const quickWrites=new Set(['saveTransaction','saveRecurringPayment','saveEstimate']);
const legacyWrites=new Set(['recordExtraPayment','markExtraPaid','cancelExtraCycle','deleteExtraPlan','updateExtraPlan','setExtraStatus','linkExtraMovement','unlinkExtraMovement']);
function json(value,status=200,extra={}) {return new Response(JSON.stringify(value),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store','X-LifeOS-Plans-Version':'2',...extra}});}
async function existingMovement(db,p,current) {
          const row=await db.prepare('SELECT m.*,p.treatment FROM movements m LEFT JOIN movement_budget_policies p ON p.movement_source_row=m.source_row WHERE m.source_row=?').bind(p.existingMovementId).first();
          const linked=await db.prepare('SELECT 1 FROM extraordinary_movement_links WHERE movement_source_row=? LIMIT 1').bind(p.existingMovementId).first();
          const autoSavings=['Assicurazione','Bollo','Manutenzione auto','Dentista','Straordinarie'].includes(row?.category)&&(!row.treatment||row.treatment==='auto');
          if(!row||linked||row.account!=='Trade Republic'||row.status!=='Eseguito'||row.movement_type!=='Spesa'||Math.round(-row.amount*100)!==p.amountCents||String(row.actual_date).slice(0,10)!==p.date||row.treatment==='recovery'||(p.date.slice(0,7)<current&&row.treatment!=='savings'&&!autoSavings))
            throw new PlanError('Il movimento non è collegabile: verifica conto, importo, data e trattamento dai risparmi.');
  return row;
}
export function romeToday(now=new Date()) {
  const parts=Object.fromEntries(new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Rome',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(now).map(p=>[p.type,p.value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
}
export function augmentFinance(base,view,currentView,currentBase=base) {
  const result=structuredClone(base), summary=result.summary;
  if(!summary||!Number.isFinite(summary.monthlyRemaining)||!Number.isFinite(summary.monthlyCommitted))throw new PlanError('Contratto del budget non compatibile.',502);
  const replaced=replacement(base,view), currentReplaced=replacement(currentBase,currentView,true);
  summary.monthlyRemaining+=(view.adjustmentCents+replaced)/100;
  summary.monthlyCommitted-=(view.adjustmentCents+replaced)/100;
  summary.monthlyBudgetBreakdown=[...(summary.monthlyBudgetBreakdown??[]),...view.plans.filter(p=>p.contributionCents!==0).map(p=>({name:p.name,amount:p.contributionCents/100,planId:p.id}))];
  const earmarked=currentView.plans.reduce((sum,p)=>sum+p.fundCents,0)/100;
  if(Number.isFinite(summary.committedCurrent)&&Number.isFinite(summary.budget)) {
    summary.committedCurrent=currentBase.summary.committedCurrent+earmarked-currentReplaced/100;summary.remainingFree=summary.budget-summary.committedCurrent;
  }
  const names=new Set(view.plans.filter(p=>p.legacy?.type==='recurring'&&view.month>=p.legacy.fromMonth).map(p=>p.name));
  const oldExtra=replaced-(base.summary.monthlyBudgetBreakdown??[]).filter(r=>names.has(r.name)).reduce((n,r)=>n+Math.round(r.amount*100),0);
  summary.monthlyBudgetBreakdown=summary.monthlyBudgetBreakdown.filter(r=>r.planId||!names.has(r.name)).map(r=>r.name==='Accantonamenti e straordinarie'?{...r,amount:r.amount-oldExtra/100}:r);
  hideAdoptedLegacy(result,view);
  const currentNames=new Set(currentView.plans.filter(p=>p.legacy?.type==='recurring').map(p=>p.name));
  const currentExtra=currentReplaced-(currentBase.summary.recurringCommitments??[]).filter(r=>currentNames.has(r.name)).reduce((n,r)=>n+Math.round(r.remaining*100),0);
  summary.recurringCommitments=[...(currentBase.summary.recurringCommitments??[]).filter(r=>!currentNames.has(r.name)).map(r=>r.name==='Straordinarie e auto'?{...r,remaining:r.remaining-currentExtra/100,estimate:r.estimate-currentExtra/100}:r),...currentView.plans.filter(p=>p.fundCents||p.contributionCents>0).map(p=>({name:p.name,estimate:p.contributionCents/100,remaining:p.fundCents/100,planId:p.id}))];
  for(const key of ['monthlyRemaining','monthlyCommitted','committedCurrent','remainingFree'])if(Number.isFinite(summary[key]))summary[key]=Math.round(summary[key]*100)/100;
  summary.monthlyBudgetBreakdown=summary.monthlyBudgetBreakdown.map(r=>({...r,amount:Math.round(r.amount*100)/100}));
  result.plansV2=view;return result;
}
// Install around the existing Worker export; preserve its authentication, cash
// ledger and existing API routes. Do not expose a new unauthenticated handler.
/**
 * @param {any} base
 * @param {{repositoryFactory?: (env: any) => any, clock?: () => string,
 * cashFactory?: (context: {forward: Function}) => any,
 * recordTransaction?: (env: any, input: any) => Promise<any>}} [options]
 */
export function withFinancePlans(base,{repositoryFactory=env=>new D1PlanRepository(env.DB),clock=romeToday,cashFactory=null,recordTransaction=null}={}) {
  return {async fetch(request,env,ctx) {
    const url=new URL(request.url), method=url.pathname.startsWith('/api/')?url.pathname.slice(5):'';
    if(!METHODS[method]&&method!=='getFinancePlans'&&method!=='resumeFinancePlanPayment'&&!readMethods.has(method)&&!protectedCash.has(method)&&!legacyWrites.has(method)&&method!=='getFinancePlanMovements'&&!quickWrites.has(method))return base.fetch(request,env,ctx);
    if(request.method!=='POST')return json({error:'Metodo non consentito.'},405);
    if(request.headers.get('Origin')!==url.origin)return json({error:'Origine non consentita.'},403);
    try {
      const body=await request.clone().text();if(body.length>65536)throw new PlanError('Richiesta troppo grande.',413);
      const args=JSON.parse(body);if(!Array.isArray(args)||args.length>5)throw new PlanError('Parametri non validi.');
      const today=clock(), current=today.slice(0,7), nativeV2=request.headers.get('X-LifeOS-Plans-Version')==='2'||method.includes('FinancePlan');
      const forward=async (name,values)=> {
        const headers=new Headers(request.headers);headers.delete('Content-Length');headers.set('Content-Type','application/json');
        return base.fetch(new Request(new URL('/api/'+name,url),{method:'POST',headers,body:JSON.stringify(values)}),env,ctx);
      };
      // Ask the existing protected read endpoint to authorize this exact cookie,
      // origin and user. Fail closed on redirects, HTML, errors and invalid JSON.
      const auth=readMethods.has(method)?await base.fetch(request,env,ctx):await forward('getFinanceOverview',[Number(current.slice(0,4)),Number(current.slice(-2))]);
      if(auth.status!==200||!(auth.headers.get('Content-Type')??'').includes('application/json'))return new Response(auth.body,{status:auth.status===200?401:auth.status,headers:auth.headers});
      const authorized=await auth.json();if(!authorized.summary||!Array.isArray(authorized.transactions))throw new PlanError('Sessione non confermata.',401);
      const repository=repositoryFactory(env);await repository.initialize();
      let currentBase=authorized;
      if(readMethods.has(method)&&`${args[0]}-${String(args[1]).padStart(2,'0')}`!==current) {
        const response=await forward('getFinanceOverview',[Number(current.slice(0,4)),Number(current.slice(-2))]);
        if(!response.ok)throw new PlanError('Budget corrente non disponibile.',503);currentBase=await response.json();
      }
      const cash=cashFactory?cashFactory({forward}):{async record(p) {
        if(p.existingMovementId) {
          const row=await existingMovement(env.DB,p,current);
          await env.DB.prepare("INSERT INTO movement_budget_policies(movement_source_row,treatment,recovery_json) VALUES (?,'savings','[]') ON CONFLICT(movement_source_row) DO UPDATE SET treatment='savings',recovery_json='[]'").bind(row.source_row).run();
          return row.source_row;
        }
        const input={requestId:p.requestId,name:p.name,amount:p.amountCents/100,type:'Spesa',category:p.category??'Altro',
          date:p.date,account:'Trade Republic',months:p.competenceMonths,budgetTreatment:'savings',note:'Piano '+p.planId};
        let result;
        if(recordTransaction)result=await recordTransaction(env,input);
        else {
          const response=await forward('saveTransaction',[input]);
          if(response.status!==200)throw new PlanError('Pagamento non confermato. Riprova dalla stessa operazione.',503);
          result=await response.json();
        }
        // Worker 11.63 returns true and persists APP-<requestId>. Resolve the
        // committed ledger row, including after an idempotent replay.
        let id=typeof result==='number'?result:result?.movementId??result?.row;
        if(result===true) {
          const row=env.DB?await env.DB.prepare('SELECT source_row,amount,actual_date,account,movement_type,status FROM movements WHERE import_id=?').bind('APP-'+p.requestId).first():null;
          if(!row||row.account!=='Trade Republic'||row.movement_type!=='Spesa'||row.status!=='Eseguito'||String(row.actual_date).slice(0,10)!==p.date||Math.round(Number(row.amount)*100)!==-p.amountCents)
            throw new PlanError('Movimento non verificato nel registro. Riprendi questa operazione senza crearne una nuova.',502);
          id=row.source_row;
        }
        if(!Number.isSafeInteger(id)||id<=0)throw new PlanError('Il server deve confermare l’identificatore del pagamento. Non ripetere con una nuova operazione.',502);
        return id;
      }};
      const service=new PlanService(repository,cash,today);
      if(nativeV2&&env.DB&&Array.isArray(currentBase.recurring)&&currentBase.extraPlan) {
        const context=await readLegacyContext(env.DB,currentBase);
        await service.change(state=>({state:adoptLegacy(state,context,today),result:{}}));
      }
      if(quickWrites.has(method)) {
        const {state}=await repository.read();
        if(method==='saveEstimate') {
          const plan=Object.values(state.plans).find(p=>p.legacy?.type==='recurring'&&p.name===args[0]);
          if(plan) {await service.execute('edit',{requestId:crypto.randomUUID(),planId:plan.id,amountCents:Math.round(Number(args[1])*100),fromMonth:addMonth(current,1)});return json(true);}
        } else {
          const input=args[0]??{}, category=method==='saveRecurringPayment'?input.name:input.category;
          const automatic=method==='saveRecurringPayment'||(input.type==='Spesa'&&(!input.budgetTreatment||input.budgetTreatment==='auto'));
          if(automatic) {
            const candidates=Object.values(state.plans).filter(p=>['fixed','estimated'].includes(p.kind)&&p.category===category&&p.status==='active'&&p.startMonth<=String(input.date).slice(0,7));
            if(candidates.length===1) {
              const value=Number(input.amount), cents=Math.round(value*100);
              if(!Number.isFinite(value)||Math.abs(value-cents/100)>1e-8||(input.account&&input.account!=='Trade Republic'))throw new PlanError('Importo o conto non valido.');
              await service.execute('pay',{requestId:input.requestId??crypto.randomUUID(),planId:candidates[0].id,amountCents:cents,date:input.date,cycleMonth:String(input.date).slice(0,7),competenceMonths:input.months??1,originalName:input.name});return json(true);
            }
            const old=Object.values(state.plans).find(p=>p.legacy?.type==='recurring'&&p.category===category);
            if(old&&old.stopAfter&&String(input.date).slice(0,7)>old.stopAfter&&method==='saveTransaction')return forward(method,[{...input,budgetTreatment:'ordinary'}]);
          }
        }
        if(recordTransaction&&method==='saveTransaction')return json(await recordTransaction(env,args[0]));
        if(recordTransaction&&method==='saveRecurringPayment'&&['Condominio','Elettricità','Gas','Acqua','Palestra','Abbonamenti','Benzina'].includes(args[0]?.name)) {
          const x=args[0];return json(await recordTransaction(env,{type:'Spesa',account:x.account||'Trade Republic',amount:x.amount,name:x.name,category:x.name,date:x.date,note:x.note,months:x.months??1,requestId:x.requestId}));
        }
        return base.fetch(request,env,ctx);
      }
      if(method==='getFinancePlanMovements') {
        const selected=month(args[0]??current), {state}=await repository.read();
        const rows=await env.DB.prepare("SELECT m.*,p.treatment FROM movements m LEFT JOIN movement_budget_policies p ON p.movement_source_row=m.source_row WHERE m.account='Trade Republic' AND m.status='Eseguito' AND m.movement_type='Spesa' AND m.amount<0 AND substr(m.actual_date,1,7)=? AND m.actual_date<=? AND NOT EXISTS(SELECT 1 FROM extraordinary_movement_links l WHERE l.movement_source_row=m.source_row) ORDER BY m.actual_date DESC,m.source_row DESC LIMIT 100").bind(selected,today).all();
        return json({movements:rows.results.filter(r=>r.treatment!=='recovery'&&!Object.values(state.payments).some(p=>p.movementId===r.source_row||p.existingMovementId===r.source_row)&&(selected>=current||r.treatment==='savings'||(!r.treatment||r.treatment==='auto')&&['Assicurazione','Bollo','Manutenzione auto','Dentista','Straordinarie'].includes(r.category))).map(r=>({row:r.source_row,name:r.description,date:String(r.actual_date).slice(0,10),amountCents:Math.round(-r.amount*100)}))});
      }
      if(legacyWrites.has(method)) {
        const {state}=await repository.read(), cycleId=Number(args[0]?.cycleId);
        const source=method==='setExtraStatus'?Number(args[0]):(await env.DB.prepare('SELECT extraordinary_source_row FROM extraordinary_cycles WHERE id=?').bind(cycleId).first())?.extraordinary_source_row;
        if(Object.values(state.plans).some(p=>p.legacy?.sourceRow===source))throw new PlanError('Questo piano è stato adottato: gestiscilo nella sezione Piani aggiornata.',409);
        return base.fetch(request,env,ctx);
      }
      if(protectedCash.has(method)) {
        const movementId=Number(method==='deleteMovement'?args[0]:args[0]?.row), {state}=await repository.read();
        const row=env.DB?await env.DB.prepare('SELECT import_id FROM movements WHERE source_row=?').bind(movementId).first():null;
        if(Object.values(state.payments).some(p=>p.movementId===movementId||p.existingMovementId===movementId||row?.import_id==='APP-'+p.requestId))throw new PlanError('Movimento collegato a un piano: modifica o eliminazione diretta non consentita.',409);
        return base.fetch(request,env,ctx);
      }
      if(method==='saveFinancePlan') {
        const name=String(args[0]?.name??'').trim().toLocaleLowerCase('it');
        const {state}=await repository.read();
        const adopted=Object.values(state.plans);
        const existing=[...(authorized.extraPlan?.allocations??[]).filter(r=>!adopted.some(p=>p.legacy?.sourceRow===Number(r.extraordinary_source_row))),...(authorized.recurring??[]).filter(r=>!adopted.some(p=>p.legacy?.type==='recurring'&&p.name===r.name)),...adopted];
        if(existing.some(p=>p.id!==args[0]?.requestId&&String(p.name??'').trim().toLocaleLowerCase('it')===name&&!['Pagato','Annullato','closed','cancelled','stopped'].includes(p.status)))
          throw new PlanError('Esiste già un accantonamento precedente con questo nome. Gestiscilo da Piani: non verrà duplicato.');
      }
      if(method==='resumeFinancePlanPayment') { await service.finish(args[0]?.paymentId);return json({ok:true}); }
      if(METHODS[method]&&args[0]?.movementId)await existingMovement(env.DB,{existingMovementId:Number(args[0].movementId),amountCents:args[0].amountCents,date:args[0].date??args[0].paymentDate},current);
      if(METHODS[method]) { await service.execute(METHODS[method],args[0]??{});return json({ok:true}); }
      if(method==='getFinancePlans')return json(await service.view(args[0]??current));
      const selected=`${args[0]??current.slice(0,4)}-${String(args[1]??current.slice(-2)).padStart(2,'0')}`;
      const raw=authorized;
      const view=await service.view(selected), currentView=selected===current?view:await service.view(current);
      const source=auth.headers.get('X-LifeOS-Data-Source');
      return json(augmentFinance(raw,view,currentView,currentBase),200,source?{'X-LifeOS-Data-Source':source}:{});
    } catch(error) {
      return json({error:error instanceof PlanError?error.message:'Piani momentaneamente non disponibili.'},error instanceof PlanError?error.status:error instanceof SyntaxError?400:503);
    }
  }};
}
