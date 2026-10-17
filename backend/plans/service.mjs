import {PlanError,initialState,command,completePayment,project} from './engine.mjs';

// Repository owns optimistic concurrency. No user financial records are migrated.
export class D1PlanRepository {
  constructor(db) { this.db=db; }
  async initialize() {
    await this.db.prepare('CREATE TABLE IF NOT EXISTS finance_plans_v2_state (id INTEGER PRIMARY KEY CHECK(id=1), revision INTEGER NOT NULL, document TEXT NOT NULL)').run();
    await this.db.prepare('INSERT OR IGNORE INTO finance_plans_v2_state(id,revision,document) VALUES(1,0,?)').bind(JSON.stringify(initialState())).run();
  }
  async read() {
    const row=await this.db.prepare('SELECT revision,document FROM finance_plans_v2_state WHERE id=1').first();
    if(!row)throw new PlanError('Archivio piani non inizializzato.',503);
    return {revision:row.revision,state:JSON.parse(row.document)};
  }
  async compareAndSet(revision,state) {
    const result=await this.db.prepare('UPDATE finance_plans_v2_state SET revision=revision+1,document=? WHERE id=1 AND revision=?').bind(JSON.stringify(state),revision).run();
    return result.meta.changes===1;
  }
}
export class PlanService {
  constructor(repository,cash,today) {this.repository=repository;this.cash=cash;this.today=today;}
  async change(transform) {
    for(let attempt=0;attempt<5;attempt++) {
      const {revision,state}=await this.repository.read(), next=transform(state);
      if(await this.repository.compareAndSet(revision,next.state))return next.result;
    }
    throw new PlanError('Un altro dispositivo sta aggiornando i piani. Riprova.',409);
  }
  async execute(action,input) {
    const result=await this.change(state=>command(state,action,input,this.today));
    if(result.paymentId)await this.finish(result.paymentId);
    return result;
  }
  async finish(paymentId) {
    const {state}=await this.repository.read(), p=state.payments[paymentId];
    if(!p)throw new PlanError('Pagamento non trovato.',404);
    if(p.status==='posted')return;
    const plan=state.plans[p.planId];
    // Stable requestId is shared across retries/crashes. The legacy cash adapter MUST
    // implement idempotent saveTransaction, not an unprotected insert.
    const movementId=await this.cash.record({requestId:p.requestId,name:plan.name,amountCents:p.amountCents,
      date:p.date,competenceMonths:p.competenceMonths,planId:p.planId});
    await this.change(current=>({state:completePayment(current,paymentId,movementId,this.today),result:{}}));
  }
  async view(month) { const {state}=await this.repository.read();return project(state,month); }
}
