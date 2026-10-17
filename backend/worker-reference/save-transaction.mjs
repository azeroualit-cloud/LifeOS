// Exact function supplied by the user, Worker 11.63. Reference only.
// Dependencies remain in the original Worker; this is not a standalone entrypoint.
/** Registra movimento e delta in batch; trasferimenti in coppia, snapshot assorbiti espliciti. */
async function saveTransaction(env, input) {
  await ensureBudgetPolicies(env);
  if (
    !input ||
    !["Spesa", "Entrata", "Rimborso", "Trasferimento"].includes(input.type)
  )
    throw Error("Tipo non valido.");
  const closingTransfer = input.type === "Trasferimento" && input.account === "Revolut" && input.counterpart === "Trade Republic";
  if (input.account !== "Trade Republic" && !closingTransfer)
    throw Error("Il conto operativo è Trade Republic.");
  if (input.type === "Trasferimento" && !closingTransfer)
    throw Error("È disponibile solo il trasferimento finale da Revolut a Trade Republic.");
  let amount = validCents(input.amount) / 100,
    day = validDate(input.date),
    name = String(input.name || "")
      .trim()
      .slice(0, 120);
  if (day > nowDay()) throw Error("Per spese future usa Straordinarie.");
  if (!name) throw Error("Indica una descrizione.");
  const policy=validatedBudgetPolicy(input,amount,day,input.type);
  const requestId=String(input.requestId || crypto.randomUUID());
  if(!/^[a-zA-Z0-9-]{8,80}$/.test(requestId))throw Error("Identificativo richiesta non valido.");
  const fingerprint=JSON.stringify({type:input.type,amount,day,name,account:input.account,category:input.category||"Altro",months:input.months||1,counterpart:input.counterpart||"",note:input.note||"",snapshot:!!input.includedInSnapshot,policy});
  const previous=await env.DB.prepare("SELECT fingerprint FROM finance_write_requests WHERE id=?").bind(requestId).first();
  if(previous){if(previous.fingerprint!==fingerprint)throw Error("Richiesta già usata con dati diversi. Riapri il modulo.");return true;}
  let covered = Number(input.months ?? 1);
  if (!Number.isInteger(covered) || covered < 1 || covered > 12)
    throw Error("Mesi coperti non validi.");
  if (
    input.type === "Trasferimento" &&
    (!["Revolut", "Trade Republic"].includes(input.counterpart) ||
      input.counterpart === input.account)
  )
    throw Error("Indica un altro conto.");
  let absorbedId = null;
  if (input.includedInSnapshot) {
    if (input.type === "Trasferimento")
      throw Error(
        "Per un trasferimento usa i due conti, non la spunta dello snapshot.",
      );
    const snapshot = await env.DB.prepare(
      "SELECT id,as_of_day FROM account_balance_snapshots WHERE account=? ORDER BY as_of_day DESC,id DESC LIMIT 1",
    )
      .bind(input.account)
      .first();
    if (!snapshot || day > snapshot.as_of_day)
      throw Error("Questa data non \u00e8 precedente al saldo rilevato.");
    absorbedId = snapshot.id;
  }
  let signed = ["Spesa", "Trasferimento"].includes(input.type)
    ? -amount
    : amount;
  let category =
    input.type === "Trasferimento"
      ? "Altro"
      : String(input.category || "Altro")
          .trim()
          .slice(0, 60);
  let actual = day.slice(0, 7),
    start = day.slice(0, 7) + "-01";
  let end =
    new Date(
      Date.UTC(
        Number(day.slice(0, 4)),
        Number(day.slice(5, 7)) - 1 + covered,
        0,
      ),
    )
      .toISOString()
      .slice(0, 7) + "-01";
  let r = {
    budget_date: day,
    actual_date: day,
    description: name,
    amount: signed,
    account: input.account,
    category,
    movement_type: input.type === "Rimborso" ? "Spesa" : input.type,
    status: "Eseguito",
    competence_months: covered,
    baseline: "No",
    counterparty_account:
      input.type === "Trasferimento" ? input.counterpart : "",
    notes:
      (input.type === "Rimborso" ? "Rimborso / restituzione: " : "") +
      String(input.note || "").slice(0, 200)+" [Categoria manuale]",
    merchant: name,
    source_name: "App 4.0",
    import_id: "APP-" + requestId,
    budget_month: start,
    competence_end: end,
    monthly_share: input.type === "Spesa" ? amount / covered : null,
    actual_month: start,
    transfer_id: input.type === "Trasferimento" ? crypto.randomUUID() : null,
  };
  const claim=env.DB.prepare("INSERT OR IGNORE INTO finance_write_requests(id,fingerprint) VALUES (?,?)").bind(requestId,fingerprint);
  const insertOnce=(movement)=>env.DB.prepare(`INSERT INTO movements (source_row,${MOVEMENT_COLUMNS.slice(1).join(",")}) SELECT MAX((SELECT COALESCE(MAX(source_row),1) FROM movements),(SELECT COALESCE(MAX(movement_source_row),1) FROM account_balance_events))+1,${MOVEMENT_COLUMNS.slice(1).map(()=>"?").join(",")} WHERE NOT EXISTS (SELECT 1 FROM movements WHERE import_id=?) AND EXISTS (SELECT 1 FROM finance_write_requests WHERE id=? AND fingerprint=?)`).bind(...MOVEMENT_COLUMNS.slice(1).map(k=>movement[k]??null),movement.import_id,requestId,fingerprint);
  const eventOnce=(id,snapshot=null)=>env.DB.prepare(`INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row,absorbed_snapshot_id) SELECT account,substr(actual_date,1,10),CAST(ROUND(amount*100) AS INTEGER),source_row,? FROM movements m WHERE import_id=? AND status='Eseguito' AND account IN ('Revolut','Trade Republic') AND NOT EXISTS(SELECT 1 FROM account_balance_events WHERE movement_source_row=m.source_row)`).bind(snapshot,id);
  const ops=[claim,insertOnce(r),eventOnce(r.import_id,absorbedId)];
  if(input.type==="Trasferimento"){
    const other={...r,description:"Trasferimento da "+input.account,amount,account:input.counterpart,category:"Altro",counterparty_account:input.account,import_id:r.import_id+"-PAIR",monthly_share:null};
    ops.push(insertOnce(other),eventOnce(other.import_id));
  }else{
    ops.push(env.DB.prepare("INSERT OR IGNORE INTO movement_budget_policies(movement_source_row,treatment,recovery_json) SELECT source_row,?,? FROM movements WHERE import_id=?").bind(policy.treatment,JSON.stringify(policy.recovery),r.import_id));
  }
  await env.DB.batch(ops);
  const committed=await env.DB.prepare("SELECT fingerprint FROM finance_write_requests WHERE id=?").bind(requestId).first();
  if(committed.fingerprint!==fingerprint)throw Error("Richiesta già usata con dati diversi. Riapri il modulo.");
  return true;
}
