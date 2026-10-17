import {PlanError} from './engine.mjs';
import {D1PlanRepository,PlanService} from './service.mjs';
const METHODS={saveFinancePlan:'create',recordFinancePlanPayment:'pay',stopFinancePlan:'stop'};
const readMethods=new Set(['getFinanceOverview','getFinanceData']);
const protectedCash=new Set(['editMovement','deleteMovement']);
function json(value,status=200,extra={}) {return new Response(JSON.stringify(value),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store',...extra}});}
export function romeToday(now=new Date()) {
  const parts=Object.fromEntries(new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Rome',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(now).map(p=>[p.type,p.value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
}
export function augmentFinance(base,view,currentView) {
  const result=structuredClone(base), summary=result.summary;
  if(!summary||!Number.isFinite(summary.monthlyRemaining)||!Number.isFinite(summary.monthlyCommitted))throw new PlanError('Contratto del budget non compatibile.',502);
  summary.monthlyRemaining+=view.adjustmentCents/100;
  summary.monthlyCommitted-=view.adjustmentCents/100;
  summary.monthlyBudgetBreakdown=[...(summary.monthlyBudgetBreakdown??[]),...view.plans.filter(p=>p.contributionCents!==0).map(p=>({name:p.name,amount:p.contributionCents/100,planId:p.id}))];
  const earmarked=currentView.plans.reduce((sum,p)=>sum+p.fundCents,0)/100;
  if(Number.isFinite(summary.committedCurrent)&&Number.isFinite(summary.budget)) {
    summary.committedCurrent+=earmarked;summary.remainingFree=summary.budget-summary.committedCurrent;
  }
  result.plansV2=view;return result;
}
// Install around the existing Worker export; preserve its authentication, cash
// ledger and existing API routes. Do not expose a new unauthenticated handler.
export function withFinancePlans(base,{repositoryFactory=env=>new D1PlanRepository(env.DB),clock=romeToday,cashFactory}={}) {
  return {async fetch(request,env,ctx) {
    const url=new URL(request.url), method=url.pathname.startsWith('/api/')?url.pathname.slice(5):'';
    if(!METHODS[method]&&method!=='getFinancePlans'&&method!=='resumeFinancePlanPayment'&&!readMethods.has(method)&&!protectedCash.has(method))return base.fetch(request,env,ctx);
    if(request.method!=='POST')return json({error:'Metodo non consentito.'},405);
    if(request.headers.get('Origin')!==url.origin)return json({error:'Origine non consentita.'},403);
    try {
      const body=await request.clone().text();if(body.length>65536)throw new PlanError('Richiesta troppo grande.',413);
      const args=JSON.parse(body);if(!Array.isArray(args))throw new PlanError('Parametri non validi.');
      const today=clock(), current=today.slice(0,7);
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
      const cash=cashFactory?cashFactory({forward}):{async record(p) {
        const response=await forward('saveTransaction',[{requestId:p.requestId,name:p.name,amount:p.amountCents/100,type:'Spesa',category:p.category??'Altro',
          date:p.date,account:'Trade Republic',months:p.competenceMonths,budgetTreatment:'savings',note:'Piano '+p.planId}]);
        if(response.status!==200)throw new PlanError('Pagamento non confermato. Riprova dalla stessa operazione.',503);
        const result=await response.json();
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
      if(protectedCash.has(method)) {
        const movementId=Number(method==='deleteMovement'?args[0]:args[0]?.row), {state}=await repository.read();
        if(Object.values(state.payments).some(p=>p.movementId===movementId))throw new PlanError('Questo movimento è collegato a un piano. Conserva il collegamento e gestisci il pagamento da Piani.',409);
        return base.fetch(request,env,ctx);
      }
      if(method==='saveFinancePlan') {
        const name=String(args[0]?.name??'').trim().toLocaleLowerCase('it');
        const existing=[...(authorized.extraPlan?.allocations??[]),...(authorized.recurring??[])];
        if(existing.some(p=>String(p.name??'').trim().toLocaleLowerCase('it')===name&&!['Pagato','Annullato'].includes(p.status)))
          throw new PlanError('Esiste già un accantonamento precedente con questo nome. Gestiscilo da Piani precedenti: non verrà duplicato.');
      }
      if(method==='resumeFinancePlanPayment') { await service.finish(args[0]?.paymentId);return json({ok:true}); }
      if(METHODS[method]) { await service.execute(METHODS[method],args[0]??{});return json({ok:true}); }
      if(method==='getFinancePlans')return json(await service.view(args[0]??current));
      const selected=`${args[0]??current.slice(0,4)}-${String(args[1]??current.slice(-2)).padStart(2,'0')}`;
      const raw=authorized;
      const view=await service.view(selected), currentView=selected===current?view:await service.view(current);
      const source=auth.headers.get('X-LifeOS-Data-Source');
      return json(augmentFinance(raw,view,currentView),200,source?{'X-LifeOS-Data-Source':source}:{});
    } catch(error) {
      return json({error:error instanceof PlanError?error.message:'Piani momentaneamente non disponibili.'},error instanceof PlanError?error.status:503);
    }
  }};
}
