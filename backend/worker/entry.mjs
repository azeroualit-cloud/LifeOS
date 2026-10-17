import original,{saveTransaction} from './runtime.mjs';
import {withFinancePlans} from '../plans/worker-adapter.mjs';
export default withFinancePlans(original,{recordTransaction:(env,input)=>saveTransaction(env,input)});
