import original,{saveTransaction} from './runtime.generated.mjs';
import {withFinancePlans} from '../plans/worker-adapter.mjs';
const app=withFinancePlans(original,{recordTransaction:(env,input)=>saveTransaction(env,input)});
// Preserve the existing native gateway's configured source/maintenance contract
// when the same single-file Worker is installed on either existing endpoint.
export default {async fetch(request,env,ctx){
  if(env.NATIVE_DATA_MODE==='maintenance'&&new URL(request.url).pathname.startsWith('/api/'))return new Response('Aggiornamento in corso. I movimenti locali restano conservati.',{status:503,headers:{'Cache-Control':'no-store','Retry-After':'30'}});
  const response=await app.fetch(request,env,ctx);
  if(!['shared','maintenance'].includes(env.NATIVE_DATA_MODE))return response;
  const headers=new Headers(response.headers);headers.set('X-LifeOS-Data-Source',env.NATIVE_DATA_MODE);
  return new Response(response.body,{status:response.status,statusText:response.statusText,headers});
}};
