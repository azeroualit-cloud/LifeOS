// Integrates the existing plan service. No second cash ledger or category-only debit rules.
export function createExpenseRouting({ PlanError, balance, command, completePayment, completePaymentDeletion, fingerprint, requestKey, month, cycleKey }) {
  const payable = new Set(['fixed', 'estimated', 'goal', 'fund']);
  const fail = (message, status = 400) => { throw new PlanError(message, status); };
  const signature = value => fingerprint(value);
  const linked = (state, row) => Object.values(state.payments).filter(p => p.status !== 'deleted' && (p.movementId === row || p.existingMovementId === row));
  function validate(input, today) {
    const amount = Number(input.amountCents ?? Math.round(Number(input.amount) * 100));
    if (!Number.isSafeInteger(amount) || amount <= 0 || amount > 100000000) fail('Importo non valido.');
    const date = String(input.date ?? '');
    if (!/^20\d\d-(0[1-9]|1[0-2])-\d\d$/.test(date) || !Number.isFinite(Date.parse(date)) || new Date(date + 'T12:00:00Z').toISOString().slice(0,10) !== date || date > today) fail('Data non valida.');
    const competenceMonths = Number(input.competenceMonths ?? input.months ?? 1);
    if (!Number.isInteger(competenceMonths) || competenceMonths < 1 || competenceMonths > 12) fail('Indica da 1 a 12 mesi coperti.');
    return { amount, date, competenceMonths, category: String(input.category ?? '').trim() };
  }
  function detach(state, payment, id, today) {
    if (payment.status !== 'posted') fail('Completa il pagamento in sospeso prima di cambiare destinazione.', 409);
    if (state.plans[payment.planId]?.kind === 'recovery') fail('Gestisci questo pagamento dal piano di recupero.');
    const result = command(state, 'deletePayment', { requestId: id, planId: payment.planId, paymentId: payment.id }, today);
    return completePaymentDeletion(result.state, payment.id, today);
  }
  function candidates(state, checked) {
    return Object.values(state.plans).filter(p => {
      if (!payable.has(p.kind) || p.status !== 'active' || p.category !== checked.category || p.startMonth > checked.date.slice(0,7)) return false;
      if (['fixed','estimated'].includes(p.kind)) {
        const key = cycleKey(p, checked.date.slice(0,7));
        if (Object.values(state.payments).some(x => x.planId === p.id && x.status !== 'deleted' && x.settlementKey === key)) return false;
      }
      return true;
    }).sort((a,b) => a.name.localeCompare(b.name) || a.id.localeCompare(b.id));
  }
  function available(state,plan,throughMonth) {
    const pending=Object.values(state.payments).filter(p=>p.planId===plan.id && p.status==='pending' && p.date.slice(0,7)<=throughMonth).reduce((sum,p)=>sum+p.amountCents,0);
    return Math.max(0,balance(state,plan,throughMonth).fundCents-pending);
  }
  function checkQuote(state,plan,checked,input) {
    if(!Number.isSafeInteger(input.expectedAvailableCents) || input.expectedAvailableCents!==available(state,plan,checked.date.slice(0,7))) fail('La disponibilità del fondo è cambiata. Aggiorna l’anteprima prima di confermare.',409);
  }
  async function movement(db, id) {
    if (!Number.isSafeInteger(id) || id < 2) fail('Movimento non valido.');
    const row = await db.prepare("SELECT m.*,p.treatment FROM movements m LEFT JOIN movement_budget_policies p ON p.movement_source_row=m.source_row WHERE m.source_row=?").bind(id).first();
    if (!row || row.account !== 'Trade Republic' || row.movement_type !== 'Spesa' || row.status !== 'Eseguito' || Number(row.amount) >= 0) fail('Destinazione modificabile per le spese eseguite su Trade Republic.');
    if (await db.prepare('SELECT 1 FROM extraordinary_movement_links WHERE movement_source_row=? LIMIT 1').bind(id).first()) fail('Questo movimento è collegato a un piano precedente: gestiscilo da quel piano.');
    return row;
  }
  async function preview({ input, repository, db, today }) {
    let checked = validate(input, today), { state } = await repository.read();
    if (input.movementId) {
      const row = await movement(db, Number(input.movementId));
      checked = validate({ amount: -Number(row.amount), date: String(row.actual_date).slice(0,10), category: row.category }, today);
      const payments = linked(state, row.source_row);
      if (payments.length > 1) fail('Il movimento ha più collegamenti: gestiscilo dal piano.',409);
      if (payments[0]) state = detach(state, payments[0], 'preview-detach-' + row.source_row, today);
    }
    return { version: 1, category: checked.category, amountCents:checked.amount, date:checked.date, plans: candidates(state, checked).map(p => {
      const funds = available(state, p, checked.date.slice(0,7));
      return { id:p.id, name:p.name, kind:p.kind, availableCents:funds, fromFundCents:Math.min(funds,checked.amount), fromSavingsCents:Math.max(0,checked.amount-funds) };
    }) };
  }
  async function status({ input, repository, db }) {
    const id = requestKey(input.requestId), { state } = await repository.read();
    if (state.expenseRoutingCommands?.[id]?.cancelled) return { started:false, complete:false, cancelled:true };
    if (state.expenseRoutingCommands?.[id]) return { started:true, complete:!state.expenseRoutingCommands[id].pending };
    const payment = state.payments[id];
    if (state.commands[id] || payment) return { started:true, complete:payment?.status === 'posted' };
    const row = await db.prepare('SELECT id FROM finance_write_requests WHERE id=?').bind(id).first();
    return { started:!!row, complete:!!row };
  }
  async function save({ input, repository, service, db, today, recordTransaction, env }) {
    requestKey(input.requestId);
    const checked = validate(input, today);
    if (typeof input.name!=='string' || !input.name.trim() || input.name.trim().length>120 || input.note!=null && (typeof input.note!=='string' || input.note.length>1000)) fail('Descrizione o note non valide.');
    if (input.type !== 'Spesa' || input.account !== 'Trade Republic') fail('Usa il flusso spese sul conto Trade Republic.');
    if (!['ordinary','plan'].includes(input.expenseDestination)) fail('Scegli la destinazione della spesa.');
    if (input.expenseDestination === 'ordinary') {
      if (input.planId) fail('Destinazione e piano non coerenti.');
      // Reserve the routing choice too: a reused request may never debit a second path.
      const key = requestKey(input.requestId), sig = signature(input);
      await service.change(state => {
        if (state.commands[key]) fail('Questa operazione appartiene già a un piano.',409);
        const old = state.expenseRoutingCommands?.[key];
        if (old && old.signature !== sig) fail('Identificatore già usato con dati diversi.',409);
        const next = structuredClone(state); next.expenseRoutingCommands ??= {};
        next.expenseRoutingCommands[key] = { signature:sig, kind:'ordinary', pending:true };
        return { state:next,result:{} };
      });
      await recordTransaction(env, { ...input, months:1, budgetTreatment:'ordinary' });
      await service.change(state => { const next=structuredClone(state); next.expenseRoutingCommands[key].pending=false;return {state:next,result:{}}; });
      return true;
    }
    const paymentInput = { requestId:input.requestId, planId:input.planId, amountCents:checked.amount, date:checked.date, cycleMonth:checked.date.slice(0,7), competenceMonths:checked.competenceMonths, originalName:String(input.name ?? ''), originalNote:String(input.note ?? ''), originalIncludedInSnapshot:input.includedInSnapshot===true };
    const result = await service.change(state => {
      if (state.expenseRoutingCommands?.[input.requestId]) fail('Questa operazione appartiene già al budget ordinario.',409);
      const existing = state.payments[input.requestId];
      if (existing && state.plans[existing.planId]?.category !== checked.category) fail('Categoria non coerente con il pagamento in corso.',409);
      if (!existing && !candidates(state,checked).some(p => p.id === input.planId)) fail('Il piano scelto non è più disponibile per questa categoria e data. Aggiorna la destinazione.',409);
      if (!existing) checkQuote(state,state.plans[input.planId],checked,input);
      return command(state,'pay',paymentInput,today);
    });
    await service.finish(result.paymentId);
    return true;
  }
  async function change({ input, repository, db, today }) {
    const id=requestKey(input.requestId), rowID=Number(input.movementId), sig=signature(input);
    if (!['ordinary','plan'].includes(input.expenseDestination)) fail('Scegli la destinazione della spesa.');
    for (let attempt=0;attempt<5;attempt++) {
      const { revision,state }=await repository.read(), old=state.expenseRoutingCommands?.[id];
      if (old) { if(old.signature!==sig) fail('Identificatore già usato con dati diversi.',409);return true; }
      const row=await movement(db,rowID), payments=linked(state,rowID);
      if(Number(input.expectedAmountCents)!==Math.round(-Number(row.amount)*100) || input.expectedDate!==String(row.actual_date).slice(0,10) || input.expectedCategory!==row.category) fail('Il movimento è cambiato. Riaprilo prima di cambiare destinazione.',409);
      if (payments.length>1) fail('Movimento con più collegamenti.',409);
      const payment=payments[0];
      if ((input.expectedPaymentId ?? '') !== (payment?.id ?? '')) fail('La destinazione è cambiata su un altro dispositivo. Riapri il movimento.',409);
      let next=payment ? detach(state,payment,id+'-detach',today) : structuredClone(state);
      const checked=validate({amount:-Number(row.amount),date:String(row.actual_date).slice(0,10),category:row.category,competenceMonths:input.competenceMonths},today);
      if(input.expenseDestination==='plan') {
        if (checked.date.slice(0,7)<today.slice(0,7) && row.treatment!=='savings' && !payment) fail('Per cambiare una spesa ordinaria di un mese passato occorre prima una verifica del budget storico.');
        if (!candidates(next,checked).some(p=>p.id===input.planId)) fail('Piano non disponibile per questa spesa.',409);
        checkQuote(next,next.plans[input.planId],checked,input);
        const added=command(next,'pay',{requestId:id+'-attach',planId:input.planId,amountCents:checked.amount,date:checked.date,cycleMonth:checked.date.slice(0,7),competenceMonths:checked.competenceMonths,movementId:rowID},today);
        next=completePayment(added.state,added.result.paymentId,rowID,today);
      } else if (input.planId) fail('Destinazione e piano non coerenti.');
      next.expenseRoutingCommands ??= {};next.expenseRoutingCommands[id]={signature:sig,kind:input.expenseDestination};
      const document=JSON.stringify(next), path='$.'+JSON.stringify('expenseRoutingCommands')+'.'+JSON.stringify(id)+'.signature';
      // D1 batch is a single transaction. Both state and policy are guarded by the same CAS.
      const results=await db.batch([
        db.prepare("UPDATE finance_plans_v2_state SET revision=revision+1,document=? WHERE id=1 AND revision=? AND EXISTS(SELECT 1 FROM movements WHERE source_row=? AND amount=? AND actual_date=? AND category=? AND account='Trade Republic' AND movement_type='Spesa' AND status='Eseguito')").bind(document,revision,rowID,row.amount,row.actual_date,row.category),
        db.prepare("INSERT INTO movement_budget_policies(movement_source_row,treatment,recovery_json) SELECT ?,?,'[]' WHERE EXISTS(SELECT 1 FROM finance_plans_v2_state WHERE id=1 AND revision=? AND json_extract(document,?)=?) ON CONFLICT(movement_source_row) DO UPDATE SET treatment=excluded.treatment,recovery_json='[]'").bind(rowID,input.expenseDestination==='plan'?'savings':'ordinary',revision+1,path,sig)
      ]);
      if(results[0].meta.changes===1 && results[1].meta.changes===1) return true;
    }
    fail('Un altro dispositivo sta modificando la spesa. Riaprila e riprova.',409);
  }
  async function cancel({input,service}) {
    const id=requestKey(input.requestId);
    await service.change(state=>{
      if(state.expenseRoutingCommands?.[id]?.cancelled) return {state,result:{}};
      if(state.expenseRoutingCommands?.[id] || state.commands[id] || state.payments[id]) fail('Il server ha già iniziato il salvataggio. Riprova la sincronizzazione per completarlo.',409);
      const next=structuredClone(state);next.expenseRoutingCommands ??= {};next.expenseRoutingCommands[id]={cancelled:true};return {state:next,result:{}};
    });
    return true;
  }
  return { preview,save,change,status,cancel };
}
