import {habitSchedule,habitDue} from "./habits.mjs";
import {expandEvents} from "./events.mjs";
import {platformContract} from "./platform-contract.mjs";

// LifeOS independent savings target v1
// LifeOS lightweight planning v2
function attachSavingsPlanning(result, config, day) {
  const cell = row => {
    const record = config.find(r => r.sheet === "Budget" && Number(r.row_number) === row);
    return record ? JSON.parse(record.values_json)[14] : null;
  };
  const rawGoal = cell(13), saving = Number(cell(14));
  result.planning ||= {
    year: Number(day.slice(0,4)),
    goal: rawGoal === null || rawGoal === "" || rawGoal === undefined ? null : Number(rawGoal),
    monthlySaving: Number.isFinite(saving) ? Math.max(0,saving) : 0,
    now: result.summary.budget,
  };
  const setting = config.find(r => r.sheet === "LifeOS Settings" && Number(r.row_number) === 1);
  const target = setting ? JSON.parse(setting.values_json)[0] : null;
  if (Number.isFinite(target) && target > 0) result.planning.savingsTarget = target;
  return result;
}
function forecastCashHistory(movements, plan, today) {
  const months = Array.from({length:6}, (_,i) => { const d=new Date(today.slice(0,7)+"-01T12:00:00Z"); d.setUTCMonth(d.getUTCMonth()-6+i); return d.toISOString().slice(0,7); });
  const linked = new Map();
  // Deduplicate linked amounts by movement, capped to its actual cash amount.
  for (const link of plan.links || []) if (link.role === 'payment') linked.set(Number(link.movement_source_row),(linked.get(Number(link.movement_source_row)) || 0)+Number(link.attributed_cents || 0)/100);
  return months.map(month => {
    const rows = movements.filter(r => r.account === 'Trade Republic' && r.status === 'Eseguito' && String(r.actual_date).slice(0,7) === month && String(r.actual_date).slice(0,10) < today);
    const net = rows.reduce((s,r) => s+Number(r.amount || 0),0);
    const extraPaid = rows.reduce((s,r) => s+(Number(r.amount)<0 ? Math.min(-Number(r.amount),linked.get(Number(r.source_row)) || 0) : 0),0);
    return {month,observed:rows.length>0,ordinaryNet:Math.round((net+extraPaid)*100)/100,extraPaid};
  });
}
/**
 * LIFE OS 11.63 - Cloudflare Worker module, D1 binding: DB.
 * Source of truth: this file; APP_HTML contains the JSON-serialized frontend.
 * Read LIFE-OS-PROJECT.md before changing balances, payments, migrations or authentication.
 * Never put credentials in this file. Never reset os_meta seed/migration markers.
 * Monetary invariant: summary.budget is the real balance; monthlyRemaining is a planning indicator.
 * Existing legacy schemas are required; additive Life OS and budget-policy migrations are idempotent.
 * Deploy this file as an ES-module Worker; retain existing D1 data and seed markers.
 */
// Liquidit\u00e0 4.0 - Cloudflare D1; build 2026.09.30.os.11.16
const ICON_180 = "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";
const ICON_64 = "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";
const APP_HTML = ""; // Injected from app.html by build.mjs.

/** Reconciliation approved for the legacy account: October 2026 account transition only.
 * Requires the actual paired return and the original 900 EUR October advance.
 * Matches only the nine reviewed expenses; later/new expenses remain chargeable.
 * Does not modify movements, bank balances, income or the stored advance cycle.
 */
function octoberAdvanceReconciliation(movements,month,todayDay,grossAdvance,rules={}) {
  const none={returned:0,covered:new Set()},cfg=rules.reconciliation;
  if(!cfg || month!==cfg.month || todayDay<cfg.day || grossAdvance<cfg.minimum)return none;
  const day=r=>r[1] instanceof Date?r[1].toISOString().slice(0,10):String(r[1]||'').slice(0,10);
  const cents=r=>Math.round(Number(r[3])*100);
  const leg=(account,amount)=>movements.some(r=>day(r)===cfg.day&&r[4]===account&&r[6]==='Trasferimento'&&r[7]==='Eseguito'&&cents(r)===amount);
  if(!leg('Revolut',-cfg.returnedCents)||!leg('Trade Republic',cfg.returnedCents))return none;
  const covered=new Set();
  for(const [date,amount,name] of cfg.reviewed) {
    const row=movements.find(r=>!covered.has(r)&&day(r)===date&&r[4]==='Revolut'&&r[6]==='Spesa'&&r[7]==='Eseguito'&&cents(r)===-amount&&String(r[2]||'').toLowerCase().includes(name));
    if(row)covered.add(row);
  }
  return {returned:cfg.returnedCents/100,covered};
}

/** Utility forecasts normalize prior bills by months covered; current-month estimates stay unchanged. */
function utilityEstimates(recurring,movements,month,todayDay,settings={}) {
  const utilities=new Set(["Elettricità","Gas","Acqua"]);
  const day=r=>r[1] instanceof Date?r[1].toISOString().slice(0,10):String(r[1]||"").slice(0,10);
  return recurring.map(r=>{
    if(!utilities.has(r.name) && r.name!=="Condominio")return {...r};
    const config=settings[r.name]||{}, changes=(config.changes||[]).filter(x=>x.month<=month).sort((a,b)=>a.month.localeCompare(b.month));
    const manual=changes.at(-1), base=manual?manual.value:(config.base??r.estimate);
    const history=(r.name==="Condominio"?[]:movements).filter(m=>m[5]===r.name && m[6]==="Spesa" && m[7]==="Eseguito" && Number(m[3])<0 &&
      ["Revolut","Trade Republic"].includes(m[4]) && day(m)<=todayDay && day(m).slice(0,7)<month &&
      (!manual || day(m).slice(0,7)>=manual.month)).sort((a,b)=>day(b).localeCompare(day(a))||Number(b[19])-Number(a[19])).slice(0,3);
    const months=history.reduce((n,m)=>n+Math.max(1,Number(m[8])||1),0);
    const estimate=history.length?Math.round(history.reduce((n,m)=>n-Number(m[3]),0)/months*100)/100:Number(base)||0;
    return {...r,estimate,estimateSource:history.length?"Media ultime "+history.length+" bollette":"Stima manuale",estimateSamples:history.length};
  });
}

/** User-confirmed split of the legacy 575 EUR housing estimate, effective October 2026.
 * A later explicit change to the source rent takes precedence; historical months stay intact. */
function rentEstimate(configuredRent,month,split) {
  return split && month>=split.fromMonth && Math.round(configuredRent*100)===Math.round(split.sourceAmount*100)
    ? Number(split.rent) : configuredRent;
}

const SAVINGS_CATEGORIES = ["Assicurazione","Bollo","Manutenzione auto","Dentista","Straordinarie"];
const budgetSchemaJobs = new WeakMap();
async function ensureBudgetPolicies(env) {
  if(!budgetSchemaJobs.has(env.DB))budgetSchemaJobs.set(env.DB,(async()=>{
    if(await env.DB.prepare("SELECT value FROM os_meta WHERE key='budget_policies_ready_v2'").first())return;
    await env.DB.batch([
    env.DB.prepare("CREATE TABLE IF NOT EXISTS movement_budget_policies(movement_source_row INTEGER PRIMARY KEY REFERENCES movements(source_row) ON DELETE CASCADE,treatment TEXT NOT NULL CHECK(treatment IN ('auto','ordinary','planned','savings','recovery')),recovery_json TEXT NOT NULL DEFAULT '[]')"),
    env.DB.prepare("CREATE TABLE IF NOT EXISTS finance_write_requests(id TEXT PRIMARY KEY,fingerprint TEXT NOT NULL)"),
    env.DB.prepare("CREATE TABLE IF NOT EXISTS finance_extra_requests(id TEXT PRIMARY KEY,source_row INTEGER NOT NULL,fingerprint TEXT NOT NULL)"),
    env.DB.prepare("CREATE TABLE IF NOT EXISTS extraordinary_settlements(cycle_id INTEGER PRIMARY KEY REFERENCES extraordinary_cycles(id) ON DELETE CASCADE,movement_source_row INTEGER NOT NULL REFERENCES movements(source_row) ON DELETE CASCADE,planned_cents INTEGER NOT NULL,actual_cents INTEGER NOT NULL)")
  ]);
    await env.DB.prepare("INSERT OR IGNORE INTO os_meta(key,value) VALUES ('budget_policies_ready_v2','1')").run();
  })());
  try {await budgetSchemaJobs.get(env.DB);} catch(error){budgetSchemaJobs.delete(env.DB);throw error;}
}
function validatedBudgetPolicy(input,amount,day,type) {
  const treatment=String(input.budgetTreatment || "auto");
  if(!["auto","ordinary","planned","savings","recovery"].includes(treatment))throw Error("Trattamento budget non valido.");
  if(type!=="Spesa" && treatment!=="auto")throw Error("Il trattamento budget è disponibile solo per le spese.");
  if(treatment!=="recovery")return {treatment,recovery:[]};
  const raw=Array.isArray(input.recoveryMonths)?input.recoveryMonths:String(input.recoveryMonths || "").split(",").map(v=>v.trim()).filter(Boolean);
  if(!raw.length || raw.length>60 || new Set(raw).size!==raw.length || raw.some(m=>!/^20[2-3]\d-(0[1-9]|1[0-2])$/.test(m) || m<day.slice(0,7)))throw Error("Scegli da 1 a 60 mesi distinti, dalla data della spesa in avanti (AAAA-MM).");
  const months=[...raw].sort(), total=validCents(input.recoveryAmount===undefined || input.recoveryAmount===null || input.recoveryAmount===""?amount:input.recoveryAmount);
  if(total>Math.round(amount*100))throw Error("Il recupero non può superare la spesa.");
  return {treatment,recovery:months.map((month,i)=>({month,amount_cents:Math.floor(total/months.length)+(i<total%months.length?1:0)}))};
}
function budgetPolicyStatement(env,row,policy) {
  return env.DB.prepare("INSERT INTO movement_budget_policies(movement_source_row,treatment,recovery_json) SELECT ?,?,? WHERE EXISTS(SELECT 1 FROM movements WHERE source_row=?) ON CONFLICT(movement_source_row) DO UPDATE SET treatment=excluded.treatment,recovery_json=excluded.recovery_json").bind(row,policy.treatment,JSON.stringify(policy.recovery),row);
}

/** Budget mensile: impegni pianificati e spese libere, distinti dal saldo bancario. */
function monthlyBudgetAmounts({salary,rent,recurring,movements,month,todayDay,extraPlan,extras,carFallback=0,privateRules={}}) {
  const round = (n) => Math.round((n + Number.EPSILON)*100)/100;
  salary=round(Number(salary)||0);
  const monthOf = (v) => v instanceof Date ? v.toISOString().slice(0,7) : String(v || "").slice(0,7);
  const dateOf = (v) => v instanceof Date ? v.toISOString().slice(0,10) : String(v || "").slice(0,10);
  const fixed = new Map([["Affitto",round(Number(rent)||0)],...recurring
    .filter(r=>r.treatment==="Vincolata" && r.name!=="Benzina")
    .map(r=>[r.name,round(Number(r.estimate)||0)])]);
  const allocations = (extraPlan?.allocations || []).filter(a=>a.month===month && a.status!=="Annullato");
  const extraCommitted = extraPlan
    ? allocations.filter(a=>a.kind==="expense").reduce((n,a)=>n+Number(a.amount_cents)/100,0)
    : extras.filter(e=>e.status!=="Annullato" && e.status!=="Previsto" && e.status!=="Anticipato" && e.start<=month &&
        (e.repeat==="Annuale" || e.end>=month)).reduce((n,e)=>n+Number(e.quota || 0),0)+carFallback;
  const grossAdvances = extraPlan
    ? allocations.filter(a=>a.kind==="budget_advance" && a.status==="Anticipato").reduce((n,a)=>n+Number(a.amount_cents)/100,0)
    : extras.filter(e=>e.status==="Anticipato" && e.start<=month && e.end>=month).reduce((n,e)=>n+Number(e.quota || 0),0);
  const reconciliation = octoberAdvanceReconciliation(movements,month,todayDay,grossAdvances,privateRules);
  const advances = round(grossAdvances-reconciliation.returned);
  const linked = new Map();
  for(const l of extraPlan?.links || [])if(l.role==="payment")linked.set(Number(l.movement_source_row),(linked.get(Number(l.movement_source_row))||0)+Number(l.attributed_cents||0));
  const policies = new Map((extraPlan?.budgetPolicies || []).map(p=>[Number(p.movement_source_row),p]));
  const fixedPaid = new Map();
  let freeCents = 0;
  for(const r of movements) {
    const amount=Number(r[3])||0, type=String(r[6]), category=String(r[5]), policy=policies.get(Number(r[19]));
    if(!["Revolut","Trade Republic"].includes(String(r[4])) || r[7]!=="Eseguito" || dateOf(r[1])>todayDay)continue;
    if(type!=="Spesa" && !(type==="Entrata" && /rimbors|refund|storno/i.test(category+" "+r[2])))continue;
    if(reconciliation.covered.has(r))continue;
    const mode=policy?.treatment || "auto";
    const covered=mode==="planned" || (mode==="auto" && fixed.has(category));
    if(covered) {
      if(monthOf(r[1])===month)fixedPaid.set(category,(fixedPaid.get(category)||0)-amount);
      continue;
    }
    if(mode==="savings" || mode==="recovery" || (mode==="auto" && SAVINGS_CATEGORIES.includes(category)))continue;
    if(monthOf(r[1])===month)freeCents-=Math.round(amount*100)+(amount<0?Math.min(Math.round(-amount*100),linked.get(Number(r[19]))||0):0);
  }
  const settlements=[...fixedPaid].map(([name,paid])=>({name,estimate:round(fixed.get(name)||0),paid:round(paid),
    released:0,excess:0,savingsDifference:round(paid-(fixed.get(name)||0))}));
  // Recovery quotas are planning entries, never additional cash movements.
  const recoveries=(extraPlan?.budgetPolicies || []).filter(p=>p.treatment==="recovery" && p.status==="Eseguito" && p.actual_date<=todayDay);
  const recoveryCents=recoveries.reduce((sum,p)=>sum+(JSON.parse(p.recovery_json || "[]").find(q=>q.month===month)?.amount_cents || 0),0);
  const monthlyCommitted=round([...fixed.values()].reduce((n,v)=>n+v,0)+extraCommitted+advances+recoveryCents/100);
  const monthlySpent=freeCents/100;
  return {monthlySalary:round(salary),monthlyCommitted,monthlyAdvances:round(advances),monthlyAdvanceReturned:reconciliation.returned,monthlySpent,
    monthlyRemaining:round(salary-monthlyCommitted-monthlySpent),monthlyRecoveries:recoveryCents/100,
    monthlyFixedSettlements:settlements,monthlyReleased:0,
    monthlyAdvanceGross:round(grossAdvances),
    monthlyAdvanceCovered:round([...reconciliation.covered].reduce((n,r)=>n-Number(r[3]),0)),
    monthlyBudgetBreakdown:[
      ...[...fixed].filter(([,amount])=>amount!==0).map(([name,amount])=>({name,amount:round(amount)})),
      {name:"Accantonamenti e straordinarie",amount:round(extraCommitted)},
      {name:"Anticipo netto",amount:round(advances)},
      ...recoveries.flatMap(p=>JSON.parse(p.recovery_json||"[]").filter(q=>q.month===month).map(q=>({name:"Recupero · "+p.description,amount:q.amount_cents/100})))
    ]};
}

/** Motore puro derivato dal foglio originale. Importi in euro; eventi/quote in centesimi. */
function computeFinance(
  book,
  year,
  month,
  extraPlan,
  bankSnapshots = [],
  bankEvents = [],
  lightweight = false,
  privateRules = {},
) {
  const TZ = "Europe/Rome";
  const APP_VERSION = "2026.10.09.os.11.63";
  const romeFormatter = new Intl.DateTimeFormat("en-GB", {
    timeZone: TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  });
  const Utilities = {
    formatDate(date, timezone, pattern) {
      const bits = Object.fromEntries(
        romeFormatter
          .formatToParts(date)
          .filter((x) => x.type !== "literal")
          .map((x) => [x.type, x.value]),
      );
      return pattern.replace(
        /yyyy|MM|dd|HH|mm|M/g,
        (x) =>
          ({
            yyyy: bits.year,
            MM: bits.month,
            dd: bits.day,
            HH: bits.hour,
            mm: bits.minute,
            M: String(Number(bits.month)),
          })[x],
      );
    },
  };

  /** Calcola il modello della vista. Budget = saldo Trade Republic; spendibile = saldo - impegni residui. */
  
  const now = new Date();
  year = boundedInteger_(
    year,
    2024,
    2035,
    Number(Utilities.formatDate(now, TZ, "yyyy")),
  );
  month = boundedInteger_(
    month,
    1,
    12,
    Number(Utilities.formatDate(now, TZ, "M")),
  );
  const budget = book.getSheetByName("Budget").getRange("A1:O24").getValues();
  const assets = book
    .getSheetByName("Patrimonio")
    .getRange("A1:H10")
    .getValues();
  const extrasRows = book
    .getSheetByName("Straordinarie")
    .getRange("A1:K500")
    .getValues();
  const trProof =
    book
      .getSheetByName("Estratto TR verificato")
      .getRange("A1:A1")
      .getValues()[0][0] || null;
  const payslipRows = book
    .getSheetByName("Cedolini")
    .getRange("A1:N500")
    .getValues();
  const payrollRows = book
    .getSheetByName("Riconciliazione stipendi")
    .getRange("A2:H100")
    .getValues();
  const recurringRows = book
    .getSheetByName("Storico ricorrenti")
    .getRange("A2:E200")
    .getValues();
  const balanceRow = book
    .getSheetByName("Saldi operativi")
    .getRange("A2:D2")
    .getValues()[0];
  const assetHistoryRows = book
    .getSheetByName("Storico patrimonio")
    .getRange("A2:D500")
    .getValues();
  const sheet = book.getSheetByName("Movimenti");
  const movements = sheet
    .getRange(2, 1, Math.max(1, sheet.getLastRow() - 1), 23)
    .getValues();
  const key = ym_(year, month);
  const todayDay = Utilities.formatDate(now, TZ, "yyyy-MM-dd");
  const extras = extrasRows
    .slice(1)
    .map((r, i) => ({ r, row: i + 2 }))
    .filter((x) => x.r[0])
    .map(({ r, row }) => ({
      row,
      name: String(r[0]),
      total: number_(r[1]),
      start: monthOf_(r[2]),
      months: number_(r[3]),
      quota: number_(r[4]),
      end: monthOf_(r[5]),
      status: String(r[6] || ""),
      account: String(r[7] || ""),
      paidAt: monthOf_(r[8]),
      note: String(r[9] || ""),
      repeat: String(r[10] || "No"),
    }));
  let salary = number_(budget[1][14]);
  let salaryWindow = null;
  const rent = rentEstimate(number_(budget[2][14]),key,extraPlan?.rentSplit);
  const car = number_(budget[3][14]);
  let revolut = number_(budget[5][14]);
  const utilitySettings = book.getSheetByName("Stime utenze").getRange("A1:A1").getValues()[0][0] || {};
  const baseRecurring = budget.slice(1, 7).map((r) => ({
    name: String(r[0]),
    estimate: number_(r[1]),
    treatment: String(r[2]),
  }));
  if(extraPlan?.condominiumSettings){baseRecurring.push({name:"Condominio",estimate:0,treatment:"Vincolata"});utilitySettings.Condominio=extraPlan.condominiumSettings;}
  const nextUtilityMonth = new Date(Date.UTC(year,month,1)).toISOString().slice(0,7);
  const nextUtilityEstimates = utilityEstimates(baseRecurring,movements,nextUtilityMonth,todayDay,utilitySettings);
  const recurring = utilityEstimates(baseRecurring,movements,key,todayDay,utilitySettings).map(r=>({...r,
    nextEstimate:r.estimateSource?nextUtilityEstimates.find(x=>x.name===r.name)?.estimate:undefined}));
  const reserved = recurring
    .filter((r) => r.treatment === "Vincolata")
    .reduce((sum, r) => sum + r.estimate, 0);
  let baseFree = revolut - reserved;
  const annualCostDefaults = budget.slice(2, 5).map((r) => ({
    name: String(r[7]),
    monthly: number_(r[8]),
    yearly: number_(r[9]),
  }));
  const yearly = Array.from({ length: 12 }, (_, i) => ({
    budgetCommitments: 0,
    monthlyRemaining: 0,
    month: ym_(year, i + 1),
    income: 0,
    incomePayslip: 0,
    spent: 0,
    commitments: 0,
    spendable: baseFree,
    hasRecords: false,
    carCommitments: 0,
    otherCommitments: 0,
    advanceOffset: 0,
    grossAdvanceOffset: 0,
    extraCommitments: 0,
    net: 0,
  }));

  /** Riconosce gli accrediti stipendio storici senza includere i trasferimenti interni. */
  function isSalaryMovement(r) {
    const text = [r[2], r[11], r[12]]
      .join(" ")
      .toLowerCase()
      .replace(/[^a-z0-9]/g, "");
    return (
      new RegExp(privateRules.salaryPattern || 'stipendio','i').test(text) ||
      ["Reddito", "Stipendio"].includes(String(r[5]))
    );
  }
  const categories = {};
  const incomeSources = {};
  const monthlyCategories = Object.fromEntries(
    yearly.map((y) => [y.month, {}]),
  );
  const selectedTransactions = [];
  const candidates = [];
  let pending = 0,
    unmatched = 0,
    funded = 0,
    prepaid = 0,
    futureFunded = 0;
  const fundedRows = new Set();
  const today = Utilities.formatDate(now, TZ, "yyyy-MM");

  const balanceDate = dateIso_(balanceRow[2]);
  const balanceAt = (account, day) => {
    if (day > todayDay) return null;
    const anchor = bankSnapshots
      .filter((s) => s.account === account && s.as_of_day <= day)
      .sort((a, b) => a.as_of_day.localeCompare(b.as_of_day) || a.id - b.id)
      .at(-1);
    if (!anchor) {
      if (
        account === "Trade Republic" &&
        trProof &&
        !trProof.conflicts?.length &&
        day >= trProof.from
      )
        return (
          Math.round(
            movements
              .filter(
                (r) =>
                  String(r[4]) === account &&
                  String(r[7]) === "Eseguito" &&
                  dateIso_(r[1]) >= trProof.from &&
                  dateIso_(r[1]) <= day,
              )
              .reduce(
                (n, r) => n + Math.round(number_(r[3]) * 100),
                trProof.opening,
              ),
          ) / 100
        );
      return null;
    }
    const cents = bankEvents
      .filter(
        (e) =>
          e.account === account &&
          e.id > anchor.event_watermark &&
          e.day <= day &&
          !(e.absorbed_snapshot_id && anchor.id >= e.absorbed_snapshot_id),
      )
      .reduce((sum, e) => sum + e.delta_cents, anchor.amount_cents);
    return Math.round(cents) / 100;
  };
  const currentRevolut =
    balanceAt("Revolut", todayDay) ?? number_(balanceRow[1]);
  const currentAssets =
    balanceAt("Trade Republic", todayDay) ?? number_(assets[1][1]);
  const monthEnd = new Date(Date.UTC(year, month, 0))
    .toISOString()
    .slice(0, 10);
  const selectedDay =
    monthEnd > todayDay ? (key === today ? todayDay : null) : monthEnd;
  for (
    let movementIndex = 0;
    movementIndex < movements.length;
    movementIndex++
  ) {
    const row = movements[movementIndex];
    if (!row[2]) continue;
    const actual = monthOf_(row[1]);
    const competence = monthOf_(row[15]) || monthOf_(row[0]);
    const amount = number_(row[3]);
    const account = String(row[4] || "");
    const category = String(row[5] || "Altro");
    const type = String(row[6] || "");
    const status = String(row[7] || "");
    const counterpart = String(row[10] || "");
    if (type === "Da verificare") pending++;
    if (type === "Trasferimento" && (!counterpart || counterpart === "Altro"))
      unmatched++;
    if (
      status === "Eseguito" &&
      type === "Trasferimento" &&
      account === "Trade Republic" &&
      counterpart === "Revolut" &&
      amount < 0
    ) {
      if (competence === key) {
        funded -= amount;
        fundedRows.add(number_(row[19]));
        if (actual && actual < key) prepaid -= amount;
      }
      if (actual === key && competence && competence > key)
        futureFunded -= amount;
    }
    const cashflowMonth = actual || String(row[20] || "");
    if (
      ["Trade Republic", "Revolut"].includes(account) &&
      cashflowMonth &&
      cashflowMonth.slice(0, 4) === String(year) &&
      status === "Eseguito"
    ) {
      const m = Number(cashflowMonth.slice(5, 7)) - 1;
      if ((type === "Entrata" || isSalaryMovement(row)) && amount > 0) {
        yearly[m].income += amount;
        yearly[m].hasRecords = true;
        const salaryMovement = isSalaryMovement(row);
        const source = salaryMovement
          ? "Stipendio"
          : /interessi/i.test(category)
            ? "Interessi"
            : /rimbors/i.test(category)
              ? "Rimborsi"
              : "Altre entrate";
        incomeSources[source] = (incomeSources[source] || 0) + amount;
      }
      if (type === "Spesa" && amount < 0) {
        yearly[m].spent -= amount;
        yearly[m].hasRecords = true;
        const flowCategory = normalizedCategory(row);
        monthlyCategories[cashflowMonth][flowCategory] =
          (monthlyCategories[cashflowMonth][flowCategory] || 0) - amount;
        if (cashflowMonth === key)
          categories[flowCategory] = (categories[flowCategory] || 0) - amount;
      }
    }
    if (
      status === "Eseguito" &&
      type === "Spesa" &&
      amount <= -180 &&
      actual &&
      actual.slice(0, 4) === String(year) &&
      !(String(row[9]) === "S\u00ec" && number_(row[8]) > 1) &&
      !/prestito a yousra/i.test(String(row[11] || "")) &&
      !/AUTOSERVICE MB|KLARNA|SWAPPIE/i.test(String(row[2])) &&
      !/^(Affitto|Utenze|Palestra|Abbonamenti)$/i.test(category)
    ) {
      const importId = String(row[14] || "");
      const registeredExtra = extras.some(
        (e) =>
          e.status !== "Annullato" &&
          ((importId && e.note.includes(importId)) ||
            (e.total === -amount &&
              e.start === actual &&
              String(row[2]).length >= 5 &&
              e.name.toLowerCase().includes(String(row[2]).toLowerCase()))),
      );
      if (!registeredExtra)
        candidates.push({
          date: dateIso_(row[1]),
          name: String(row[2]),
          amount: -amount,
          category,
          account,
        });
    }
    if (actual === key && status === "Eseguito") {
      selectedTransactions.push({
        row: number_(row[19]),
        date: dateIso_(row[1]),
        name: String(row[2]),
        amount,
        account,
        category,
        displayCategory: normalizedCategory(row),
        type,
        status,
        counterpart,
      });
    }
  }
  const payroll = payrollRows
    .filter((r) => r[0] instanceof Date)
    .map((r) => ({
      month: monthOf_(r[0]),
      competence: String(r[1]),
      amount: number_(r[2]),
      bank: number_(r[3]),
      internal: number_(r[4]),
      status: String(r[5]),
      source: String(r[6]),
      note: String(r[7]),
    }));
  // Media dei dodici mesi di accredito, con mensilit\u00e0 aggiuntive accreditate.
  // I bonifici interni, i buoni pasto e il welfare non sono stipendio.
  const creditedSalary = new Map();
  for (const row of movements) {
    if (
      String(row[4]) !== "Trade Republic" ||
      String(row[7]) !== "Eseguito" ||
      (String(row[6]) !== "Entrata" && !isSalaryMovement(row)) ||
      number_(row[3]) <= 0
    )
      continue;
    if (!isSalaryMovement(row)) continue;
    const creditMonth = monthOf_(row[1]);
    if (creditMonth)
      creditedSalary.set(
        creditMonth,
        (creditedSalary.get(creditMonth) || 0) + number_(row[3]),
      );
  }
  for (const item of payroll) {
    if (
      item.status === "Ricostruito" &&
      !creditedSalary.has(item.month) &&
      item.amount > 0
    )
      creditedSalary.set(item.month, item.amount);
  }
  const latestMonth = today < key ? today : key;
  const salaryMonths = Array.from({ length: 12 }, (_, i) => {
    const d = new Date(
      Date.UTC(
        Number(latestMonth.slice(0, 4)),
        Number(latestMonth.slice(5, 7)) - i - 1,
        1,
      ),
    );
    return d.toISOString().slice(0, 7);
  });
  if (salaryMonths.every((m) => creditedSalary.has(m))) {
    salary =
      Math.round(
        (salaryMonths.reduce((sum, m) => sum + creditedSalary.get(m), 0) /
          12) *
          100,
      ) / 100;
    salaryWindow = {
      from: salaryMonths[11],
      to: salaryMonths[0],
      months: 12,
      source: "accrediti e cedolini ricostruiti",
    };
  }
  const isAutoReserve = (e) =>
    e.repeat === "Annuale" &&
    /^(Assicurazione auto|Bollo auto|Manutenzione auto)\b/i.test(e.name);
  const planMonth = (monthKey) =>
    (extraPlan?.allocations || []).filter(
      (a) =>
        a.month === monthKey &&
        a.status !== "Annullato" &&
        !(
          a.status === "Pagato" &&
          a.paid_date &&
          monthKey <= String(a.paid_date).slice(0, 7)
        ),
    );
  const planAuto = (a) =>
    /^(Assicurazione auto|Bollo auto|Manutenzione auto)\b/i.test(a.name);
  const hasAutoSchedule = extras.some(isAutoReserve);
  const activeExtras = (item) =>
    extras.filter(
      (e) =>
        (e.status === "Programmato" || e.status === "Anticipato") &&
        e.start &&
        e.start <= item.month &&
        (e.repeat === "Annuale" || e.end >= item.month),
    );
  for (const item of yearly) {
    const active = activeExtras(item),
      monthly = planMonth(item.month);
    item.carCommitments = extraPlan
      ? monthly
          .filter((a) => a.kind === "expense" && planAuto(a))
          .reduce((sum, a) => sum + a.amount_cents / 100, 0)
      : hasAutoSchedule
        ? active.filter(isAutoReserve).reduce((sum, e) => sum + e.quota, 0)
        : car;
    item.otherCommitments = extraPlan
      ? monthly
          .filter((a) => a.kind === "expense" && !planAuto(a))
          .reduce((sum, a) => sum + a.amount_cents / 100, 0)
      : active
          .filter((e) => !isAutoReserve(e))
          .reduce((sum, e) => sum + e.quota, 0);
    item.advanceOffset = extraPlan
      ? monthly
          .filter(
            (a) => a.kind === "budget_advance" && a.status === "Anticipato",
          )
          .reduce((sum, a) => sum + a.amount_cents / 100, 0)
      : 0;
    item.grossAdvanceOffset = item.advanceOffset;
    item.advanceOffset -= octoberAdvanceReconciliation(movements,item.month,todayDay,item.advanceOffset,privateRules).returned;
    item.extraCommitments = item.carCommitments + item.otherCommitments;
    item.commitments =
      rent + item.carCommitments + utilityEstimates(baseRecurring,movements,item.month,todayDay,utilitySettings).filter(r=>r.treatment==="Vincolata").reduce((n,r)=>n+r.estimate,0) + item.otherCommitments;
    item.spendable = salary - item.commitments - item.advanceOffset;
    item.net = item.income - item.spent;
  }
  selectedTransactions.sort((a, b) => b.date.localeCompare(a.date));
  const absorbedNow = extras
    .filter((e) => e.status === "Anticipato" && e.start === key)
    .reduce((sum, e) => sum + e.total, 0);
  const absorbedFuture = extras
    .filter((e) => e.status === "Anticipato" && e.start > key)
    .reduce((sum, e) => sum + e.total, 0);
  const allowedRecurring = [
    "Elettricit\u00e0",
    "Gas",
    "Acqua",
    "Palestra",
    "Abbonamenti",
    "Benzina",
  ];
  const bankHistory = movements
    .filter(
      (r) =>
        r[1] instanceof Date &&
        r[6] === "Spesa" &&
        r[7] === "Eseguito" &&
        allowedRecurring.includes(String(r[5])) &&
        number_(r[3]) < 0,
    )
    .map((r) => ({
      date: dateIso_(r[1]),
      name: String(r[5]),
      paid: -number_(r[3]),
      note: String(r[11] || ""),
      months: Math.max(1, number_(r[8])),
    }));
  const welfare = recurringRows
    .filter((r) => String(r[1]) === "Benzina welfare")
    .map((r) => ({
      date: dateIso_(r[0]),
      name: "Benzina welfare",
      paid: number_(r[2]),
      note: String(r[3] || ""),
      months: 0,
    }));
  const history = bankHistory
    .concat(welfare)
    .sort((a, b) => b.date.localeCompare(a.date));
  const averages = recurring.map((r) => {
    const rows = bankHistory.filter((h) => h.name === r.name);
    return {
      name: r.name,
      count: rows.length,
      mean: rows.length
        ? rows.reduce((sum, h) => sum + h.paid, 0) /
          rows.reduce((sum, h) => sum + h.months, 0)
        : null,
    };
  });
  const selected = yearly[month - 1];
  revolut =
    salary -
    rent -
    selected.carCommitments -
    selected.otherCommitments -
    selected.advanceOffset;
  baseFree = revolut - reserved;
  // Le quote degli anticipi sono gi\u00e0 sottratte: escludi dal finanziamento
  // soltanto gli importi collegati e gi\u00e0 attribuiti a questo mese.
  const advanceFundingOffset = extraPlan
    ? planMonth(key)
        .filter(
          (a) => a.kind === "budget_advance" && a.status === "Anticipato",
        )
        .reduce(
          (sum, a) =>
            sum +
            Math.min(
              a.amount_cents,
              (extraPlan.links || [])
                .filter(
                  (l) =>
                    l.cycle_id === a.cycle_id &&
                    l.role === "budget_advance" &&
                    fundedRows.has(l.movement_source_row),
                )
                .reduce((cents, l) => cents + l.attributed_cents, 0),
            ) /
              100,
          0,
        )
    : 0;
  const fundedOutsideAdvance = Math.max(0, funded - advanceFundingOffset);
  const annualCosts = hasAutoSchedule
    ? activeExtras(selected)
        .filter(isAutoReserve)
        .map((e) => ({ name: e.name, monthly: e.quota, yearly: e.total }))
    : annualCostDefaults;
  const reservedNames = [
    "Elettricit\u00e0",
    "Gas",
    "Acqua",
    "Palestra",
    "Abbonamenti",
  ];
  const linkedPayments = new Set(
    (extraPlan?.links || [])
      .filter((l) => l.role === "payment")
      .map((l) => l.movement_source_row),
  );
  const coveredAdvanceRows = new Set([...octoberAdvanceReconciliation(movements,key,todayDay,selected.grossAdvanceOffset,privateRules).covered].map(r=>Number(r[19])));
  const rawUsedFree = selectedTransactions
    .filter(
      (t) =>
        (t.account === "Revolut" || t.account === "Trade Republic") &&
        (t.type === "Spesa" || t.type === "Entrata") &&
        !linkedPayments.has(t.row) &&
        !coveredAdvanceRows.has(Number(t.row)) &&
        t.category !== "Affitto" &&
        !reservedNames.includes(t.category) &&
        !(
          t.type === "Entrata" &&
          !/rimbors|refund|storno/i.test(t.category + " " + t.name)
        ),
    )
    .reduce((sum, t) => sum - t.amount, 0);
  const borrowedThisMonth = extras
    .filter(
      (e) => e.status === "Anticipato" && e.start > key && e.paidAt === key,
    )
    .reduce((sum, e) => sum + e.total, 0);
  const usedFromFuture = Math.min(
    Math.max(0, rawUsedFree - selected.spendable),
    borrowedThisMonth,
  );
  const usedFree = rawUsedFree;
  const commitmentCategories = [
    { name: "Affitto", amount: rent },
    { name: "Auto, accantonamento", amount: selected.carCommitments },
    ...recurring
      .filter((r) => r.treatment === "Vincolata")
      .map((r) => ({ name: r.name, amount: r.estimate })),
    ...(extraPlan
      ? planMonth(key)
          .filter((a) => a.kind === "expense" && !planAuto(a))
          .map((a) => ({ name: a.name, amount: a.amount_cents / 100 }))
      : activeExtras(selected)
          .filter((e) => !isAutoReserve(e))
          .map((e) => ({ name: e.name, amount: e.quota }))),
  ].filter((x) => x.amount > 0);
  const currentRecurring=utilityEstimates(baseRecurring,movements,today,todayDay,utilitySettings);
  const currentSettlements=monthlyBudgetAmounts({salary,rent,recurring:currentRecurring,movements,
    month:today,todayDay,extraPlan,extras,privateRules}).monthlyFixedSettlements;
  const recurringCommitments = currentRecurring
    .filter(r=>r.treatment==="Vincolata" && r.name!=="Benzina")
    .map(r=>{
      const settlement=currentSettlements.find(x=>x.name===r.name);
      return {name:r.name,estimate:r.estimate,paid:settlement?.paid||0,
        remaining:settlement ? 0 : r.estimate};
    });
  const rentSettlement=currentSettlements.find(x=>x.name==="Affitto"),rentPaid=rentSettlement?.paid||0;
  const currentExtraReserves = extraPlan
    ? planMonth(today).filter((a) => a.kind === "expense")
        .reduce((n,a) => n + a.amount_cents / 100,0)
    : activeExtras({month:today}).reduce((n,e) => n + e.quota,0);
  const currentCarFallback = !extraPlan && !hasAutoSchedule ? car : 0;
  const commitmentDetails = [
    ...recurringCommitments,
    {name:"Affitto",estimate:rent,paid:rentPaid,remaining:rentSettlement ? 0 : rent},
    {name:"Straordinarie e auto",estimate:currentExtraReserves + currentCarFallback,
      paid:0,remaining:currentExtraReserves + currentCarFallback},
  ];
  const committedCurrent = Math.round(commitmentDetails.reduce((n,r) => n+r.remaining,0)*100)/100;
  const currentSpendable =
    Math.round((currentAssets - committedCurrent) * 100) / 100;
  const monthlyBudget = monthlyBudgetAmounts({
    salary, rent, recurring, movements, month:key, todayDay, extraPlan, extras, privateRules,
    carFallback: !extraPlan && !hasAutoSchedule ? car : 0,
  });
  if (lightweight)
    return {
      year,
      month,
      key,
      today,
      appVersion: APP_VERSION,
      updatedAt: Utilities.formatDate(new Date(), TZ, "dd/MM/yyyy HH:mm"),
      summary: {
        ...selected,
        ...monthlyBudget,
        budget: currentAssets,
        committedCurrent,
        recurringCommitments: commitmentDetails,
        remainingFree: currentSpendable,
        revolutBalance: currentRevolut,
        totalAssets: currentAssets,
        account: "Trade Republic",
        accountBalance: currentAssets,
        assets: currentAssets,
        balanceDate,
        assetDate: dateIso_(assets[1][2]),
      },
      recurring,
      extras,
      transactions: selectedTransactions,
      candidates: [],
      extraPlan,
      categoryOptions: [],
    };
  const goalCell = budget[12] && budget[12][14];
  const goal =
    goalCell === "" || goalCell === null || goalCell === undefined
      ? null
      : number_(goalCell);
  const monthlySaving = Math.max(0, number_(budget[13] && budget[13][14]));
  const monthsRemaining = 12 - Number(Utilities.formatDate(now, TZ, "M"));
  const planning = {
    year: Number(Utilities.formatDate(now, TZ, "yyyy")),
    goal,
    monthlySaving,
    monthsRemaining,
    now: currentAssets,
    projection: currentAssets + monthlySaving * monthsRemaining,
  };
  Object.assign(
    planning,
    planningAmounts(currentAssets, goal, monthlySaving, monthsRemaining),
  );
  const snapshotDay = dateIso_(assets[1][2]);
  const anchorBalance = number_(assets[1][1]);
  const trMovements = movements
    .map((r, i) => ({
      date: dateIso_(r[1]),
      amount: number_(r[3]),
      account: String(r[4]),
      status: String(r[7]),
      source: String(r[13]),
      row: i + 2,
    }))
    .filter(
      (r) =>
        r.account === "Trade Republic" && r.status === "Eseguito" && r.date,
    );
  const firstTrDate = trMovements.reduce(
    (min, r) => (min && min < r.date ? min : r.date),
    "",
  );
  const snapshots = assetHistoryRows
    .filter((r) => r[0] instanceof Date && typeof r[1] === "number")
    .map((r) => ({
      date: dateIso_(r[0]),
      month: monthOf_(r[0]),
      amount: number_(r[1]),
      source: String(r[2] || "Rilevazione"),
    }));
  const wealthHistory = yearly.map((item) => {
    const following = new Date(
      Date.UTC(year, Number(item.month.slice(5)), 1),
    );
    const end = new Date(following.getTime() - 86400000)
      .toISOString()
      .slice(0, 10);
    const available =
      item.month <= today && firstTrDate && firstTrDate <= end;
    let estimate = null;
    if (available && snapshotDay) {
      if (end < snapshotDay)
        estimate =
          anchorBalance -
          trMovements
            .filter((r) => r.date > end && r.date <= snapshotDay)
            .reduce((n, r) => n + r.amount, 0);
      else
        estimate = balanceAt(
          "Trade Republic",
          end > todayDay && item.month === today ? todayDay : end,
        );
    }
    const measured = snapshots
      .filter((x) => x.month === item.month)
      .sort((a, b) => b.date.localeCompare(a.date))[0];
    return {
      month: item.month,
      estimated: estimate,
      measured: measured ? measured.amount : null,
      measuredDate: measured?.date || "",
    };
  });
  // Historical analytics are separate from budget and bank cash flow.

  /** Categoria risolta per i report, con fallback a quella importata. */
  function normalizedCategory(r) {
    return String(r[21] || r[5] || "Da classificare");
  }
  // Payslip competence is separate from actual bank credit dates and balances.
  const italianMonths = [
    "gen",
    "feb",
    "mar",
    "apr",
    "mag",
    "giu",
    "lug",
    "ago",
    "set",
    "ott",
    "nov",
    "dic",
  ];
  const salaryHistory = payslipRows
    .flatMap((r) => {
      const match = String(r[0] || "")
        .trim()
        .toLowerCase()
        .match(/^([a-z]{3})\s+(\d{2}|\d{4})$/);
      if (
        !match ||
        !italianMonths.includes(match[1]) ||
        r[1] === null ||
        r[1] === ""
      )
        return [];
      const y =
        match[2].length === 2 ? 2000 + Number(match[2]) : Number(match[2]);
      const competence = ym_(y, italianMonths.indexOf(match[1]) + 1);
      if (competence > today) return [];
      return [
        {
          month: competence,
          base: number_(r[1]),
          additional: number_(r[5]),
          gross: number_(r[1]) + number_(r[5]),
        },
      ];
    })
    .sort((a, b) => a.month.localeCompare(b.month));
  const payrollGross = salaryHistory.reduce((n, r) => n + r.gross, 0);
  const taxRefund = salaryHistory.some((r) => r.month.startsWith("2025-"))
    ? 930
    : 0;
  const salaryHistoryTotal = payrollGross - taxRefund;
  const salaryHistoryYears = [
    ...new Set(salaryHistory.map((r) => r.month.slice(0, 4))),
  ].map((y) => ({
    year: Number(y),
    gross: salaryHistory
      .filter((r) => r.month.startsWith(y))
      .reduce((n, r) => n + r.gross, 0),
    refund: y === "2025" ? taxRefund : 0,
    salary:
      salaryHistory
        .filter((r) => r.month.startsWith(y))
        .reduce((n, r) => n + r.gross, 0) - (y === "2025" ? taxRefund : 0),
  }));
  const lifetimeMonths = new Map(),
    lifetimeSources = {},
    lifetimeExpenses = {},
    incomeAudit = [],
    expenseAudit = [],
    investmentGroups = new Map();
  for (const r of movements) {
    const day = dateIso_(r[1]),
      m = monthOf_(r[1]),
      amount = number_(r[3]),
      account = String(r[4]),
      type = String(r[6]);
    if (!day || day > todayDay || String(r[7]) !== "Eseguito") continue;
    if (!lifetimeMonths.has(m))
      lifetimeMonths.set(m, {
        month: m,
        income: 0,
        spent: 0,
        hasRecords: true,
      });
    const item = lifetimeMonths.get(m);
    if (
      account === "Trade Republic" &&
      type === "Investimento" &&
      !(amount > 0 && isSalaryMovement(r))
    ) {
      const text = String(r[2]),
        codes = [...text.matchAll(/\b[A-Z]{2}[A-Z0-9]{9}[0-9]\b/g)].map(
          (x) => x[0],
        ),
        isin = codes[0] || "Senza ISIN";
      const qtyMatch = text.match(/quantity:\s*([\d.]+)/i),
        qty = qtyMatch ? Number(qtyMatch[1]) : null;
      if (!investmentGroups.has(isin))
        investmentGroups.set(isin, {
          isin,
          bought: 0,
          sold: 0,
          buyQty: 0,
          sellQty: 0,
          invalid: false,
          lastDay: day,
          rows: [],
        });
      const g = investmentGroups.get(isin);
      g.lastDay = g.lastDay > day ? g.lastDay : day;
      g.rows.push({ date: day, name: text, amount, quantity: qty });
      if (amount < 0) {
        g.bought -= amount;
        g.buyQty += qty || 0;
      } else {
        g.sold += amount;
        g.sellQty += qty || 0;
      }
      if (
        codes.length !== 1 ||
        qty === null ||
        !Number.isFinite(qty) ||
        qty <= 0 ||
        (/buy trade|savings plan|ordine d'acquisto/i.test(text) &&
          amount > 0) ||
        (/sell trade/i.test(text) && amount < 0)
      )
        g.invalid = true;
    }
    if (
      account === "Trade Republic" &&
      (type === "Entrata" || isSalaryMovement(r)) &&
      amount > 0
    ) {
      const source = isSalaryMovement(r)
        ? "Stipendio"
        : /rimbors/i.test(String(r[5]) + " " + r[2])
          ? "Rimborsi"
          : /interess|interest|dividend/i.test(String(r[5]) + " " + r[2])
            ? "Interessi"
            : "Altre entrate";
      if (
        source !== "Stipendio" ||
        !salaryHistory.some((p) => p.month === m)
      ) {
        item.income += amount;
        lifetimeSources[source] = (lifetimeSources[source] || 0) + amount;
      }
      incomeAudit.push({ date: day, name: String(r[2]), amount, source });
    }

    const internal =
      type === "Trasferimento" &&
      (/Revolut|Trade Republic|IsyBank|EasyBank/i.test(String(r[10])) ||
        new RegExp(privateRules.ownerPattern || 'a^','i').test(String(r[2])));
    if (
      amount < 0 &&
      ["Revolut", "Trade Republic"].includes(account) &&
      ["Spesa", "Trasferimento"].includes(type) &&
      !internal
    ) {
      item.spent -= amount;
      const cat = normalizedCategory(r);
      lifetimeExpenses[cat] = (lifetimeExpenses[cat] || 0) - amount;
      expenseAudit.push({
        row: number_(r[19]),
        date: day,
        name: String(r[2]),
        amount: -amount,
        category: cat,
        account,
        estimated: false,
      });
    }
  }
  if (salaryHistory.length) {
    lifetimeSources.Stipendio =
      (lifetimeSources.Stipendio || 0) + salaryHistoryTotal;
    lifetimeSources["Rimborso 730"] = taxRefund;
    for (const r of salaryHistory) {
      if (!lifetimeMonths.has(r.month))
        lifetimeMonths.set(r.month, {
          month: r.month,
          income: 0,
          spent: 0,
          hasRecords: true,
        });
      lifetimeMonths.get(r.month).income += r.gross;
    }
  }
  for (const g of investmentGroups.values()) {
    const prices = g.rows
      .filter((r) => r.quantity > 0 && r.amount !== 0)
      .map((r) => Math.abs(r.amount) / r.quantity);
    // A large unit-price discontinuity indicates a balance/amount import error.
    if (prices.length > 1 && Math.max(...prices) / Math.min(...prices) > 10)
      g.invalid = true;
  }
  const investmentAudit = [...investmentGroups.values()].map((g) => ({
    ...g,
    net: Math.round((g.sold - g.bought) * 100) / 100,
    reconciled:
      !g.invalid &&
      g.buyQty > 0 &&
      Math.abs(g.buyQty - g.sellQty) <= Math.max(0.0001, g.buyQty * 0.000001),
  }));
  const investmentTotals = investmentAudit.reduce(
    (t, g) => ({
      bought: t.bought + g.bought,
      sold: t.sold + g.sold,
      net: t.net + g.net,
    }),
    { bought: 0, sold: 0, net: 0 },
  );
  // Only fully closed, quantity-matched instruments contribute a net result.
  const investmentConfirmed = investmentAudit
    .filter((g) => g.reconciled)
    .reduce((n, g) => n + g.net, 0);
  // Reconciled bank cash flow is not the same as realised investment performance.
  const investmentCashRows = movements.filter(
    (r) =>
      String(r[4]) === "Trade Republic" &&
      String(r[6]) === "Investimento" &&
      String(r[7]) === "Eseguito" &&
      dateIso_(r[1]) <= todayDay,
  );
  const investmentCashNet =
    investmentCashRows.reduce(
      (n, r) => n + Math.round(number_(r[3]) * 100),
      0,
    ) / 100;
  if (trProof && !trProof.conflicts?.length) {
    for (const r of investmentCashRows) {
      const m = lifetimeMonths.get(monthOf_(r[1]));
      if (m) m.investmentCashNet = (m.investmentCashNet || 0) + number_(r[3]);
    }

    if (investmentCashNet > 0)
      lifetimeSources["Investimenti - netto cassa"] = investmentCashNet;
    if (investmentCashNet < 0)
      lifetimeExpenses["Investimenti - netto cassa"] = -investmentCashNet;
  } else {
    for (const g of investmentAudit.filter((g) => g.reconciled)) {
      const m = lifetimeMonths.get(g.lastDay.slice(0, 7));
      if (m) {
        if (g.net > 0) m.income += g.net;
        else m.spent -= g.net;
      }
      if (g.net > 0)
        lifetimeSources["Utili investimenti - parziale"] =
          (lifetimeSources["Utili investimenti - parziale"] || 0) + g.net;
      if (g.net < 0)
        lifetimeExpenses["Perdite investimenti - parziale"] =
          (lifetimeExpenses["Perdite investimenti - parziale"] || 0) - g.net;
    }
  }
  const lifetimeSeries = [...lifetimeMonths.values()]
    .sort((a, b) => a.month.localeCompare(b.month))
    .map((item) => {
      const end = new Date(
        Date.UTC(
          Number(item.month.slice(0, 4)),
          Number(item.month.slice(5)),
          0,
        ),
      )
        .toISOString()
        .slice(0, 10);
      let wealth = null;
      const target = end > todayDay ? todayDay : end;
      const recorded = snapshots
        .filter((x) => x.month === item.month && x.date <= target)
        .sort((a, b) => a.date.localeCompare(b.date))
        .at(-1);
      if (recorded) wealth = recorded.amount;
      if (
        trProof ||
        bankSnapshots.some(
          (x) => x.account === "Trade Republic" && x.as_of_day <= target,
        )
      )
        wealth = balanceAt("Trade Republic", target);
      if (item.month === today) wealth = currentAssets;
      const revolut = balanceAt("Revolut", target);
      const liquidWealth =
        item.month === today
          ? Math.round((currentAssets + currentRevolut) * 100) / 100
          : Number.isFinite(wealth) && Number.isFinite(revolut)
            ? Math.round((wealth + revolut) * 100) / 100
            : null;
      return { ...item, wealth, liquidWealth };
    });
  const lifetime = {
    from: lifetimeSeries[0]?.month || today,
    to: today,
    series: lifetimeSeries,
    income: Object.values(lifetimeSources).reduce((n, v) => n + v, 0),
    spent: Object.values(lifetimeExpenses).reduce((n, v) => n + v, 0),
    sources: Object.entries(lifetimeSources).map(([name, amount]) => ({
      name,
      amount,
    })),
    expenses: Object.entries(lifetimeExpenses)
      .map(([name, amount]) => ({ name, amount, estimated: false }))
      .sort((a, b) => b.amount - a.amount),
    investmentCashNet,
    statement: trProof
      ? {
          from: trProof.from,
          to: trProof.to,
          opening: trProof.opening / 100,
          closing: trProof.closing / 100,
          incoming: trProof.incoming / 100,
          outgoing: trProof.outgoing / 100,
          rows: trProof.rows.length,
          corrections: trProof.fixes.length,
          conflicts: trProof.conflicts || [],
          refundCorrections: trProof.classifications?.length || 0,
          cashflow: trProof.cashflow,
        }
      : null,
    salaryHistory,
    salaryHistoryYears,
    salaryHistoryTotal,
    taxRefund,
    salaryHistoryBasis: salaryHistory.length
      ? "cedolini per competenza"
      : "accrediti TR",
    expenseAudit,
    investmentAudit,
    investmentTotals,
    investmentConfirmed,
    salaryAverageReview:
      taxRefund > 0
        ? "Mese del rimborso 730 2025 da confermare; media da accrediti verificati conservata."
        : "",
    incomeAudit: incomeAudit.sort((a, b) => b.date.localeCompare(a.date)),
  };
  const databaseCategories =
    book
      .getSheetByName("Categorie finanziarie")
      .getRange("A1:A1")
      .getValues()[0][0] || [];
  lifetime.expenseGroups = databaseCategories.map((c) => ({
    id: c.id,
    name: c.name,
    members: [...c.members],
    amount: 0,
  }));
  const byDetail = new Map();
  for (const r of movements)
    byDetail.set(normalizedCategory(r), number_(r[22]) || 10);
  for (const c of lifetime.expenses) {
    const group =
      lifetime.expenseGroups.find((g) => g.id === byDetail.get(c.name)) ||
      lifetime.expenseGroups.find((g) => g.id === 10);
    if (!group) throw Error("Categorie finanziarie non inizializzate.");
    if (!group.members.includes(c.name)) group.members.push(c.name);
    group.amount += c.amount;
  }
  lifetime.expenseGroups = lifetime.expenseGroups
    .filter((g) => g.amount > 0)
    .map((g) => ({
      ...g,
      percentage: lifetime.spent
        ? Math.round((g.amount / lifetime.spent) * 100)
        : 0,
    }))
    .sort((a, b) => b.amount - a.amount);
  const bankAudit = ["Trade Republic", "Revolut"].map((account) => {
    const rows = movements.filter(
      (r) =>
        String(r[4]) === account &&
        String(r[7]) === "Eseguito" &&
        dateIso_(r[1]) &&
        dateIso_(r[1]) <= todayDay,
    );
    const dates = rows.map((r) => dateIso_(r[1])).sort();
    return {
      account,
      from: dates[0] || null,
      to: dates.at(-1) || null,
      count: rows.length,
      rawNet:
        Math.round(rows.reduce((n, r) => n + number_(r[3]), 0) * 100) / 100,
      balance: account === "Trade Republic" ? currentAssets : currentRevolut,
    };
  });
  const suspiciousTransfers = movements
    .filter(
      (r) =>
        String(r[4]) === "Trade Republic" &&
        String(r[6]) === "Trasferimento" &&
        String(r[7]) === "Eseguito" &&
        number_(r[3]) <= -2500,
    )
    .map((r) => ({
      row: number_(r[19]),
      date: dateIso_(r[1]),
      name: String(r[2]),
      amount: number_(r[3]),
      counterpart: String(r[10]),
    }));
  const creditedSalaryTotal = incomeAudit
    .filter((r) => r.source === "Stipendio")
    .reduce((n, r) => n + r.amount, 0);
  const cashTotal = currentAssets;
  lifetime.reconciliation = {
    status: "incomplete",
    cashTotal,
    tradeRepublic: currentAssets,
    revolut: currentRevolut,
    recordedFlowDifference:
      Math.round((lifetime.income - lifetime.spent) * 100) / 100,
    unexplainedDifference:
      Math.round((lifetime.income - lifetime.spent - cashTotal) * 100) / 100,
    // Comparison only: not a balancing expense, opening balance, or investment loss.
    openingBalanceKnown: false,
    creditedSalaryTotal,
    payslipSalaryWithoutTrCredit:
      Math.round((salaryHistoryTotal - creditedSalaryTotal) * 100) / 100,
    tradeRepublicStatementVerified: !!trProof && !trProof.conflicts?.length,
    missingAccounts: [
      "IsyBank / EasyBank: movimenti storici non disponibili",
    ],
    bankAudit,
    suspiciousTransfers,
  };
  const monthlyBreakdowns = Object.fromEntries(
    yearly.map((item) => {
      const all = Object.entries(monthlyCategories[item.month] || {})
        .filter((x) => x[1] > 0)
        .sort((a, b) => b[1] - a[1]);
      const total = all.reduce((n, x) => n + x[1], 0),
        top = all.slice(0, 5),
        other = all.slice(5).reduce((n, x) => n + x[1], 0);
      if (other) top.push(["Altre", other]);
      let position = 0;
      const items = top.map(([name, amount]) => {
        const start = position;
        position += total ? (amount / total) * 100 : 0;
        return {
          name,
          amount,
          start,
          end: position,
          bar: top[0]?.[1] ? Math.round((amount / top[0][1]) * 100) : 0,
        };
      });
      const commitments = [
        { name: "Affitto", amount: rent },
        { name: "Auto, accantonamento", amount: item.carCommitments },
        ...recurring
          .filter((r) => r.treatment === "Vincolata")
          .map((r) => ({ name: r.name, amount: r.estimate })),
        ...(extraPlan
          ? planMonth(item.month)
              .filter((a) => a.kind === "expense" && !planAuto(a))
              .map((a) => ({ name: a.name, amount: a.amount_cents / 100 }))
          : activeExtras(item)
              .filter((e) => !isAutoReserve(e))
              .map((e) => ({ name: e.name, amount: e.quota }))),
      ].filter((x) => x.amount > 0);
      return [
        item.month,
        { total, items, commitments, commitmentTotal: item.commitments },
      ];
    }),
  );
  for (const item of yearly) {
    const policy = monthlyBudgetAmounts({salary,
      rent:rentEstimate(number_(budget[2][14]),item.month,extraPlan?.rentSplit),
      recurring:utilityEstimates(baseRecurring,movements,item.month,todayDay,utilitySettings),
      movements,month:item.month,todayDay,extraPlan,extras,privateRules,
      carFallback:hasAutoSchedule?0:car});
    item.budgetCommitments=policy.monthlyCommitted;
    item.monthlyRemaining=policy.monthlyRemaining;
  }
  const yearTotal = yearly.reduce(
    (o, m) => ({
      income: o.income + m.income,
      incomePayslip: o.incomePayslip + m.incomePayslip,
      spent: o.spent + m.spent,
      net: o.net + m.net,
      commitments: o.commitments + (m.budgetCommitments ?? m.commitments),
      spendable: 0,
    }),
    {
      income: 0,
      incomePayslip: 0,
      spent: 0,
      net: 0,
      commitments: 0,
      spendable: 0,
    },
  );
  return {
    year,
    month,
    key,
    appVersion: APP_VERSION,
    updatedAt: Utilities.formatDate(new Date(), TZ, "dd/MM/yyyy HH:mm"),
    summary: {
      ...selected,
      ...monthlyBudget,
      salary,
      salaryWindow,
      rent,
      car: selected.carCommitments,
      revolut,
      reserved,
      baseFree,
      funded,
      prepaid,
      advanceFundingOffset,
      fundedOutsideAdvance,
      toTransfer: Math.max(0, revolut - fundedOutsideAdvance),
      futureFunded,
      absorbedNow,
      absorbedFuture,
      futureAvailable: Math.max(0, futureFunded - absorbedFuture),
      rentAndCar: rent + selected.carCommitments,
      totalAssets: currentAssets,
        account: "Trade Republic",
        accountBalance: currentAssets,
      assets: currentAssets,
      assetMonthBalance: selectedDay
        ? balanceAt("Trade Republic", selectedDay)
        : null,
      assetDate: dateIso_(assets[1][2]),
      revolutBalance: currentRevolut,
      revolutMonthBalance: selectedDay
        ? balanceAt("Revolut", selectedDay)
        : null,
      balanceDate,
      usedFree,
      rawUsedFree,
      usedFromFuture,
      borrowedThisMonth,
      remainingBeforeAdvance: selected.spendable - rawUsedFree,
      budget: currentAssets,
      committedCurrent,
      recurringCommitments: commitmentDetails,
      remainingFree: currentSpendable,
    },
    lifetime,
    yearly,
    wealthHistory,
    snapshots,
    planning,
    incomeSources: Object.entries(incomeSources)
      .filter(([_, amount]) => amount > 0)
      .map(([name, amount]) => ({ name, amount, estimated: false }))
      .sort((a, b) => b.amount - a.amount),
    categories: Object.entries(categories)
      .filter(([_, amount]) => amount > 0)
      .map(([name, amount]) => ({ name, amount }))
      .sort((a, b) => b.amount - a.amount),
    commitmentCategories,
    monthlyCategories,
    monthlyBreakdowns,
    yearTotal,
    today,
    candidates: candidates.sort((a, b) => b.amount - a.amount).slice(0, 16),
    transactions: selectedTransactions,
    recurring,
    annualCosts,
    extras,
    history,
    averages,
    payroll,
    quality: { pending, unmatched },
    dataNote:
      year === 2026
        ? "Gennaio-marzo: gli accrediti IsyBank ricostruiti dai cedolini servono solo alla media di riferimento. I bonifici verso Trade Republic restano trasferimenti interni, non entrate reali."
        : "",
  };


  /** Chiave anno-mese zero-padded. */
  function ym_(year, month) {
    return String(year) + "-" + ("0" + month).slice(-2);
  }

  /** Valida interi in un intervallo; usa il fallback per input non validi. */
  function boundedInteger_(value, min, max, fallback) {
    const n = Number(value);
    return Number.isInteger(n) && n >= min && n <= max ? n : fallback;
  }

  /** Conversione numerica tollerante degli import legacy; non usare per validare scritture. */
  function number_(value) {
    const n = Number(value);
    return Number.isFinite(n) ? n : 0;
  }

  /** Estrae il mese dalla rappresentazione data del workbook compatibile. */
  function monthOf_(date) { return dateIso_(date).slice(0, 7); }

  /** Data civile ISO della rappresentazione workbook. */
  function dateIso_(date) {
    return date instanceof Date && !Number.isNaN(date.getTime())
      ? date.toISOString().slice(0, 10)
      : "";
  }

}

// Private legacy rules are opened only using identity data already in D1.
// No statement rows, personal tasks or plaintext account identifiers are shipped.
const PRIVATE_RULES_BLOB={"identity":"6701beea61046c84a3a74b2d1000895ae7f00c1f17180088fdae30f09318637a","iv":"h6hG/U/LaEvMdM+S","ciphertext":"mjug8N0UqJLg3I0fTsSEE4PvjB1ag27tqquqoqOo7Nn6zPKc8R8veQd6SF6nWexmsTYdC3nlGkY+UNB3sEmUKAwKvfWZYmmNeiWpx0Oyctb8VB71NNPA0V5CmPNIUBHFCcUw2iH73aRUaZNH9x3BD73kDd2wrfVHASL4Q0H0/YSiaYql3UOyz051dHatY/n5zx8qvwLew5iK4QL+KoBGMfyfgPj51dcaOgQTtHJpCMSyrvOSaWjtcglCSmkDZKzCtuqPt8f7oU7iRPwyiOMZGIy0W45pRHQjijyVpg8uFcC88J7K7xQa8DQXPnwmwxrzE8JIY3va5teRoJZ7yJBiCN2WTcyEiMBGItzFPRDiiHWUfq6URf7bH7vUBsDMDSZXovmS308gYQ738VOMb+NZF7zUe5qsdtt1eQbhgWj1o8FUmkV1XgtNJ02qyrD7NW/+OItxL72zlLUJe8a2KH6ba2LPO7ZDipDobiZErro2CJT2UTkiME2KpQrZRwLyUUHUyMMnCTgrD60ePKs/POMyZ2xqd3QtGQ4BUCyCdG3JIL8h1BH7JvpD+tpeOU9Cwouo5TsbNl5P6Z5BHcz0gf4M1V3MLOvVJkGYPLiNSLYJSc00ZDjt+pCcIKGDMecvDzUgra8C58y5/u82hrNZXOCtkHF7ty4vhFV/zxUtYGVCzqsnpvgLM27KHF96NwrT+etIYBx2MgTzu8M1gQmq+hsml4X1PzgBhSguX/l219roEEEyUYNa+Ik3/tim6gvmrcwiqDhne9xvTWLtgLnhHeLXyezqpSwfaK45HM4xtB5ECe/H7CpbiqljmSz7iw=="};
const privateRulesByDB=new WeakMap();
async function privateRulesForProof(proof) {
  if(!proof.rows?.length)return {};
  const values=[...new Set((JSON.stringify(proof).match(/IT\d{2}[A-Z]\d{22}/gi)||[]).map(s=>s.toUpperCase()))];
  const bytes=s=>new TextEncoder().encode(s);
  for(const value of values) {
    const hash=new Uint8Array(await crypto.subtle.digest('SHA-256',bytes(value)));
    if([...hash].map(b=>b.toString(16).padStart(2,'0')).join('')!==PRIVATE_RULES_BLOB.identity)continue;
    const key=await crypto.subtle.importKey('raw',await crypto.subtle.digest('SHA-256',bytes(value+'|LifeOS private rules v1')),'AES-GCM',false,['decrypt']);
    const decode=s=>Uint8Array.from(atob(s),c=>c.charCodeAt(0));
    return JSON.parse(new TextDecoder().decode(await crypto.subtle.decrypt({name:'AES-GCM',iv:decode(PRIVATE_RULES_BLOB.iv)},key,decode(PRIVATE_RULES_BLOB.ciphertext))));
  }
  throw Error('Configurazione storica non riconosciuta: conserva il database originale e usa il Worker dell’archivio privato.');
}
const trRepairJobs = new WeakMap();

/** Inizializza/verifica la riconciliazione TR importata; preserva il marcatore storico. */
async function ensureTrStatement(env) {
  if(!trRepairJobs.has(env.DB))trRepairJobs.set(env.DB,(async()=>{
    const found=await env.DB.prepare("SELECT values_json FROM source_rows WHERE sheet='Estratto TR verificato' AND row_number=1").first();
    const proof=found?JSON.parse(found.values_json)?.[0]:null;
    if(proof?.version!==2)throw Error('Riconciliazione storica mancante: ripristina la configurazione D1 esistente.');
    privateRulesByDB.set(env.DB,await privateRulesForProof(proof));
  })());
  try {await trRepairJobs.get(env.DB);}catch(error){trRepairJobs.delete(env.DB);throw error;}
}

const FINANCE_MANUAL_CATEGORIES = [...new Set([...platformContract.expenseCategories, ...platformContract.incomeCategories])];

const FINANCE_CATEGORY_SEED = {
  categories: [
    {
      id: 1,
      name: "Auto e trasporti",
      members: ["Auto", "Benzina", "Trasporti", "Pedaggi"],
    },
    {
      id: 2,
      name: "Casa",
      members: [
        "Affitto e ingresso casa",
        "Arredamento e casa",
        "Utenze",
        "Affitto",
        "Casa",
        "Acqua",
        "Gas",
        "Elettricita",
      ],
    },
    {
      id: 3,
      name: "Shopping e tecnologia",
      members: ["Shopping", "Elettronica"],
    },
    { id: 4, name: "Alimentari", members: ["Alimentari"] },
    { id: 5, name: "Ristorazione", members: ["Ristorazione"] },
    {
      id: 6,
      name: "Salute e benessere",
      members: ["Salute", "Palestra", "Cura personale", "Sport"],
    },
    {
      id: 7,
      name: "Tempo libero",
      members: ["Viaggi", "Svago", "Abbonamenti"],
    },
    {
      id: 8,
      name: "Trasferimenti a terzi",
      members: ["Trasferimenti a terzi", "Famiglia"],
    },
    {
      id: 9,
      name: "Imposte e commissioni",
      members: ["Imposte", "Imposte e servizi", "Commissioni", "Imposte e commissioni"],
    },
    {
      id: 10,
      name: "Da classificare",
      members: [
        "Da classificare",
        "Contanti",
        "Altro",
        "Stipendio",
        "Interessi",
        "Rimborsi",
      ],
    },
  ],
  rules: [
    {
      id: 1,
      pattern:
        "affitt|caparr|cauzion|contanti destinati alle spese di agenzia",
      label: "Affitto e ingresso casa",
    },
    {
      id: 2,
      pattern:
        "beyfin|\\besso\\b|\\bq8\\b|enilive|\\beni\\b|ip italiana petroli|ok petrol|desideri carburanti|new gas network",
      label: "Benzina",
    },
    {
      id: 3,
      pattern: "iris palest|iris societa sportiva|fitactive",
      label: "Palestra",
    },
    { id: 4, pattern: "etrurialucegas|regione.*utenze", label: "Utenze" },
    {
      id: 5,
      pattern:
        "laredoute|la.?redoute|maisons du|\\bikea\\b|\\bobi\\b|brico io|abain components",
      label: "Arredamento e casa",
    },
    {
      id: 6,
      pattern: "computer.?gross|media.?world|swappie|back.?market",
      label: "Elettronica",
    },
    {
      id: 7,
      pattern:
        "unomobile|uno.?mobile|iliad|\\btim\\b|chatgpt|signulous|linkedin|fastweb|google play|apple.com|goread|brazethemes|\\binwi\\b",
      label: "Abbonamenti",
    },
    { id: 8, pattern: "taptap", label: "Trasferimenti a terzi" },
    {
      id: 9,
      pattern: "cupsolidale|farmac|pharma|dr\\.?max|odontoiatr|receptor chem",
      label: "Salute",
    },
    { id: 10, pattern: "decathlon", label: "Sport" },
    {
      id: 11,
      pattern: "parrucch|salone 198|tmt parrucchiere",
      label: "Cura personale",
    },
    {
      id: 12,
      pattern:
        "trainline|trenitalia|flixbus|malta public transport|tussam|s.bahn|valletta ferry|\\bbolt\\b",
      label: "Trasporti",
    },
    {
      id: 13,
      pattern:
        "ipertosano|macelleria|jaouda market|supermarket|\\bspar\\b|pam panorama|\\bcondis\\b|berry pantry|arkadia foodstore",
      label: "Alimentari",
    },
    {
      id: 14,
      pattern:
        "aliexpress|sonny bono|alcott|zalando|vinted|duty.free|gold shop",
      label: "Shopping",
    },
    {
      id: 15,
      pattern:
        "bistrot|pizzer|pinsa|caff[e\\u00e8]|coffee|cornett|taverna|pastizzer|past[ie]cc|mc.?donald|illy spa|cioccolat|my chef|porca vacca|\\bvyta\\b|angolo divino|buffet empoli",
      label: "Ristorazione",
    },
    {
      id: 16,
      pattern: "aviation muse|real alc.zar|orto botanico|zoo berlin|planetice",
      label: "Svago",
    },
    {
      id: 17,
      pattern: "comune.*pagop|comune di san miniato|universita",
      label: "Imposte e servizi",
    },
    {
      id: 18,
      pattern: "autostrade|autoroutes|aspit|miser direz",
      label: "Pedaggi",
    },
    {
      id: 19,
      pattern:
        "imperiale moto|autogamma|carfax|autoservice|allianz|assicurazioni",
      label: "Auto",
    },
  ],
};
const categorySchemaJobs = new WeakMap();
const movementCategoryFingerprint = (r) =>
  [r.category, r.description, r.merchant, r.notes]
    .map((x) => String(x || ""))
    .join(String.fromCharCode(31));

/** Schema e classificazione incrementale; fingerprint evita ricalcoli non necessari. */
async function ensureFinanceCategories(env) {
  await ensureTrStatement(env);
  if (!categorySchemaJobs.has(env.DB)) {
    const job = (async () => {
      if(await env.DB.prepare("SELECT value FROM os_meta WHERE key='finance_categories_ready_v2'").first()) return;
      await env.DB.batch([
        env.DB.prepare(
          "CREATE TABLE IF NOT EXISTS financial_categories(id INTEGER PRIMARY KEY CHECK(id BETWEEN 1 AND 10),name TEXT NOT NULL UNIQUE,sort_order INTEGER NOT NULL)",
        ),
        env.DB.prepare(
          "CREATE TABLE IF NOT EXISTS financial_category_mappings(detail_category TEXT PRIMARY KEY,category_id INTEGER NOT NULL REFERENCES financial_categories(id))",
        ),
        env.DB.prepare(
          "CREATE TABLE IF NOT EXISTS financial_category_rules(id INTEGER PRIMARY KEY,pattern TEXT NOT NULL,detail_category TEXT NOT NULL,priority INTEGER NOT NULL)",
        ),
        env.DB.prepare(
          "CREATE TABLE IF NOT EXISTS movement_financial_categories(movement_source_row INTEGER PRIMARY KEY REFERENCES movements(source_row) ON DELETE CASCADE,category_id INTEGER NOT NULL REFERENCES financial_categories(id),detail_category TEXT NOT NULL,source_category TEXT NOT NULL,source_fingerprint TEXT NOT NULL)",
        ),
        env.DB.prepare(
          "CREATE INDEX IF NOT EXISTS idx_movement_financial_category ON movement_financial_categories(category_id)",
        ),
      ]);
      const seedState = await env.DB.prepare("SELECT COUNT(*) n FROM financial_categories").first();
      if (!seedState.n) await env.DB.batch([
        env.DB.prepare("INSERT OR IGNORE INTO financial_categories(id,name,sort_order) SELECT json_extract(value,'$.id'),json_extract(value,'$.name'),json_extract(value,'$.id') FROM json_each(?)").bind(JSON.stringify(FINANCE_CATEGORY_SEED.categories)),
        env.DB.prepare("INSERT OR IGNORE INTO financial_category_mappings(detail_category,category_id) SELECT m.value,json_extract(c.value,'$.id') FROM json_each(?) c,json_each(c.value,'$.members') m").bind(JSON.stringify(FINANCE_CATEGORY_SEED.categories)),
        env.DB.prepare("INSERT OR IGNORE INTO financial_category_rules(id,pattern,detail_category,priority) SELECT json_extract(value,'$.id'),json_extract(value,'$.pattern'),json_extract(value,'$.label'),json_extract(value,'$.id') FROM json_each(?)").bind(JSON.stringify(FINANCE_CATEGORY_SEED.rules.map(r=>r.id===1&&privateRulesByDB.get(env.DB)?.rentPattern?{...r,pattern:privateRulesByDB.get(env.DB).rentPattern}:r))),
      ]);
      await env.DB.batch([
        env.DB.prepare("INSERT OR IGNORE INTO financial_category_mappings(detail_category,category_id) SELECT json_extract(value,'$[0]'),json_extract(value,'$[1]') FROM json_each(?)").bind(JSON.stringify([["Assicurazione",1],["Bollo",1],["Manutenzione auto",1],["Condominio",2],["Dentista",6],["Farmaci e visite",6]])),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_rules_update AFTER UPDATE ON financial_category_rules BEGIN DELETE FROM movement_financial_categories; END",
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_rules_insert AFTER INSERT ON financial_category_rules BEGIN DELETE FROM movement_financial_categories; END",
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_rules_delete AFTER DELETE ON financial_category_rules BEGIN DELETE FROM movement_financial_categories; END",
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_mapping_update AFTER UPDATE ON financial_category_mappings BEGIN DELETE FROM movement_financial_categories WHERE detail_category=OLD.detail_category OR detail_category=NEW.detail_category; END",
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_mapping_insert AFTER INSERT ON financial_category_mappings BEGIN DELETE FROM movement_financial_categories WHERE detail_category=NEW.detail_category; END",
        ),
        env.DB.prepare(
          "CREATE TRIGGER IF NOT EXISTS financial_mapping_delete AFTER DELETE ON financial_category_mappings BEGIN DELETE FROM movement_financial_categories WHERE detail_category=OLD.detail_category; END",
        ),
      ]);
      const categoryUpgrade = await env.DB.prepare(
        "SELECT value FROM os_meta WHERE key='finance_categories_1136'",
      ).first();
      if (!categoryUpgrade) {
        const edits = [];
        const upgrades = [
          [
            "veer g|a domani|la fortuna empoli|breasy|red garter|tokyo club|havana club|noa sardinian winery|ta zaren|briciole",
            "Ristorazione",
          ],
          ["el alamein", "Alimentari"],
          ["caddy.s", "Cura personale"],
          ["gamelife|tiktok", "Svago"],
          ["souvenir occitan|avolta", "Shopping"],
          ["abaco s[.]p[.]a|biglietteria piazza", "Trasporti"],
          ["rosa.?s garden", "Arredamento e casa"],
          ["dedem", "Shopping"],
        ];
        edits.push(env.DB.prepare("INSERT OR IGNORE INTO financial_category_rules(id,pattern,detail_category,priority) SELECT 113600+CAST(key AS INTEGER),json_extract(value,'$[0]'),json_extract(value,'$[1]'),70+CAST(key AS INTEGER) FROM json_each(?)").bind(JSON.stringify(upgrades)));
        edits.push(
          env.DB.prepare(
            "INSERT OR IGNORE INTO financial_category_mappings(detail_category,category_id) VALUES ('Pagamenti non dettagliati',10)",
          ),
        );
        edits.push(
          env.DB.prepare(
            "INSERT OR IGNORE INTO financial_category_mappings(detail_category,category_id) VALUES ('Elettricit\u00e0',2)",
          ),
        );
        edits.push(
          env.DB.prepare(
            "UPDATE financial_categories SET name='Altre spese' WHERE id=10 AND name='Da classificare'",
          ),
        );
        edits.push(
          env.DB.prepare(
            "DELETE FROM movement_financial_categories WHERE detail_category='Da classificare'",
          ),
        );
        edits.push(
          env.DB.prepare(
            "INSERT INTO os_meta(key,value) VALUES ('finance_categories_1136','1')",
          ),
        );
        await env.DB.batch(edits);
      }
      await env.DB.prepare("CREATE TABLE IF NOT EXISTS financial_reporting_adjustments(id TEXT PRIMARY KEY,label TEXT NOT NULL,amount_cents INTEGER NOT NULL CHECK(amount_cents>=0),as_of_day TEXT NOT NULL,method TEXT NOT NULL)").run();
      await env.DB.prepare("INSERT OR IGNORE INTO os_meta(key,value) VALUES ('finance_categories_ready_v2','1')").run();
    })();
    categorySchemaJobs.set(env.DB, job);
  }
  try {
    await categorySchemaJobs.get(env.DB);
  } catch (e) {
    categorySchemaJobs.delete(env.DB);
    throw e;
  }
  const [changed, rules, mappings] = await Promise.all([
    env.DB.prepare(
      `SELECT m.* FROM movements m LEFT JOIN movement_financial_categories c ON c.movement_source_row=m.source_row WHERE c.movement_source_row IS NULL OR c.source_fingerprint<>COALESCE(m.category,'')||char(31)||COALESCE(m.description,'')||char(31)||COALESCE(m.merchant,'')||char(31)||COALESCE(m.notes,'')`,
    ).all(),
    env.DB.prepare(
      "SELECT * FROM financial_category_rules ORDER BY priority,id",
    ).all(),
    env.DB.prepare("SELECT * FROM financial_category_mappings").all(),
  ]);
  if (!changed.results.length) return;
  const compiled = rules.results.map((r) => ({
    ...r,
    regex: new RegExp(r.pattern, "i"),
  }));
  const map = new Map(
    mappings.results.map((r) => [r.detail_category, r.category_id]),
  );
  const statements = [];
  for (const r of changed.results) {
    let detail = String(r.category || "Altro").trim();
    if (!String(r.notes || "").includes("[Categoria manuale]")) {
      const text = [r.description, r.merchant, r.notes].join(" ");
      const rule = compiled.find((x) => x.regex.test(text));
      if (rule) detail = rule.detail_category;
      else if (detail === "Casa") detail = "Arredamento e casa";
      else if (
        /^(Altro|Altre spese|Altri movimenti|Da classificare)$/i.test(detail)
      )
        detail = "Pagamenti non dettagliati";
      if (
        /^(Apple|Google)$/i.test(String(r.description || "")) &&
        Math.abs(Number(r.amount)) < 20
      )
        detail = "Abbonamenti";
    }
    statements.push([r.source_row,map.get(detail)||10,detail,String(r.category||""),movementCategoryFingerprint(r)]);
  }
  if(statements.length) await env.DB.prepare("INSERT OR REPLACE INTO movement_financial_categories(movement_source_row,category_id,detail_category,source_category,source_fingerprint) SELECT json_extract(value,'$[0]'),json_extract(value,'$[1]'),json_extract(value,'$[2]'),json_extract(value,'$[3]'),json_extract(value,'$[4]') FROM json_each(?)").bind(JSON.stringify(statements)).run();
}

/** Proiezione pura di obiettivo e risparmio; non modifica movimenti o saldi. */
function planningAmounts(now, goal, monthlySaving, monthsRemaining) {
  const base = goal === null ? 0 : Math.max(1, goal, now);
  return {
    now,
    goal,
    monthlySaving,
    monthsRemaining,
    projection: Math.round((now + monthlySaving * monthsRemaining) * 100) / 100,
    surplusNow: goal === null ? null : Math.max(0, now - goal),
    projectedSurplus:
      goal === null
        ? null
        : Math.max(0, now + monthlySaving * monthsRemaining - goal),
    covered:
      goal === null ? 0 : (Math.max(0, Math.min(goal, now)) / base) * 100,
    surplus: goal === null ? 0 : (Math.max(0, now - goal) / base) * 100,
    missing: goal === null ? null : Math.max(0, goal - now),
  };
}

/** Validazione condivisa per impostazioni e proiezione, con gli stessi limiti. */
function planningInputs(target, monthly) {
  const goal = target === "" || target === null ? null : Number(target),
    saving = Number(monthly);
  if (
    (goal !== null && (!Number.isFinite(goal) || goal < 0 || goal > 1e6)) ||
    !Number.isFinite(saving) ||
    saving < 0 ||
    saving > 1e5
  )
    throw Error("Importi non validi.");
  return {goal, saving};
}

/** Legge il saldo TR corrente e restituisce la proiezione validata. */
async function getPlanningProjection(env, target, monthly) {
  const {goal, saving} = planningInputs(target, monthly);
  const day = nowDay();
  const snap = await env.DB.prepare(
    "SELECT * FROM account_balance_snapshots WHERE account='Trade Republic' AND as_of_day<=? ORDER BY as_of_day DESC,id DESC LIMIT 1",
  )
    .bind(day)
    .first();
  let now;
  if (snap) {
    const events = await env.DB.prepare(
      "SELECT COALESCE(SUM(delta_cents),0) delta FROM account_balance_events WHERE account='Trade Republic' AND id>? AND day<=? AND NOT (absorbed_snapshot_id IS NOT NULL AND absorbed_snapshot_id<=?)",
    )
      .bind(snap.event_watermark, day, snap.id)
      .first();
    now = (snap.amount_cents + Number(events.delta)) / 100;
  } else {
    const row = await env.DB.prepare(
      "SELECT values_json FROM source_rows WHERE sheet='Patrimonio' AND row_number=2",
    ).first();
    if (!row) throw Error("Saldo TR non disponibile.");
    now = Number(JSON.parse(row.values_json)[1]);
  }
  return planningAmounts(now, goal, saving, 12 - Number(day.slice(5, 7)));
}

const ALLOWED_RECURRING = [
  "Condominio",
  "Elettricit\u00e0",
  "Gas",
  "Acqua",
  "Palestra",
  "Abbonamenti",
  "Benzina",
];
const MOVEMENT_COLUMNS =
  "source_row budget_date actual_date description amount account category movement_type status competence_months baseline counterparty_account notes merchant source_name import_id budget_month competence_end monthly_share actual_month transfer_id".split(
    " ",
  );
const EXTRAS_COLUMNS =
  "source_row name total start_month month_count monthly_share end_month status payment_account paid_date notes repeat_rule".split(
    " ",
  );
const CONFIG_PAGE = `<!doctype html><html lang="it"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Importa impostazioni</title><style>body{background:#000000;color:#f2f5f9;font:16px system-ui;margin:0;padding:25px}main{max-width:560px;margin:auto}button,input{font:inherit;padding:10px;margin:8px 0}p{line-height:1.5;color:#b5c3d0}</style><main><h1>Completa la migrazione</h1><p>I movimenti sono gi\u00e0 nel database. Importa impostazioni, saldi, stipendi e storico dal file di configurazione. Questa operazione aggiorna le righe importate.</p><input type="file" id="file" accept=".json,application/json"><br><button id="send">Importa configurazione</button><p id="status"></p><a href="/">Apri app</a></main><script>document.querySelector('#send').onclick=async e=>{const s=document.querySelector('#status'),f=document.querySelector('#file').files[0];if(!f){s.textContent='Scegli il file JSON.';return}e.target.disabled=true;try{let rows=JSON.parse(await f.text());if(!Array.isArray(rows))throw Error('File non valido');for(let i=0;i<rows.length;i+=20){let r=await fetch('/api/import-config',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(rows.slice(i,i+20))});if(!r.ok)throw Error(await r.text());s.textContent='Righe importate: '+Math.min(i+20,rows.length)+'/'+rows.length}s.textContent='Configurazione importata. Apri app.'}catch(x){s.textContent='Errore: '+x.message}finally{e.target.disabled=false}}</script></html>`;
const LOGIN_PAGE = `<!doctype html><html lang="it"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="theme-color" content="#111111"><link rel="manifest" href="/manifest.webmanifest"><link rel="apple-touch-icon" href="/apple-touch-icon.png"><meta name="apple-mobile-web-app-capable" content="yes"><title>Life OS \u00b7 Accesso</title><style>*{box-sizing:border-box}body{min-height:100dvh;display:grid;place-items:center;margin:0;background:#000000;color:#f0f4fa;font:16px system-ui;padding:18px}main{width:min(370px,100%);padding:27px;border:1px solid #344159;border-radius:18px;background:#1b2534}h1{margin:0 0 8px;font-size:24px}p{color:#b1bfd0;line-height:1.45}label{display:block;margin:16px 0 6px}input,button{width:100%;padding:13px;font:inherit;border-radius:9px}input{border:1px solid #54647c;background:#121d2b;color:white}button{border:0;margin-top:20px;background:#7790e6;color:#0e1623;font-weight:700}small{color:#ffaaa9}body{background:radial-gradient(ellipse at 50% 0%,#3d3d3d66,transparent 65%),#111111;color:#f3f3f1;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}main{background:#1c1c1c;border:1px solid #ffffff10;border-radius:28px;padding:30px}h1{font-size:32px;letter-spacing:-.04em}p,label{color:#a6a6a3;font-size:13px}input{background:#131313;border:1px solid #ffffff15;border-radius:14px;min-height:48px}button{border-radius:24px;min-height:48px;color:#fff;background:linear-gradient(145deg,#e9d9bb55,#7aaeff20),#447dc7c9;border:1px solid #e9d9bb55;box-shadow:inset 0 1px #ffffff25;font-weight:550}input:focus-visible,button:focus-visible{outline:2px solid #d6bd91;outline-offset:3px}small{color:#ff9da4}</style><main><h1>Life OS</h1><form id="login"><label>Nome utente</label><input name="user" autocomplete="username" value="nas" required><label>Password</label><input name="password" type="password" autocomplete="current-password" required><button>Accedi</button></form><p><small id="error"></small></p></main><script>document.querySelector('#login').onsubmit=async e=>{e.preventDefault();const f=e.target,b=f.querySelector('button'),box=document.querySelector('#error');b.disabled=true;box.textContent='';try{let r=await fetch('/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({user:f.elements.namedItem('user').value,password:f.elements.namedItem('password').value})});if(!r.ok)throw Error('Credenziali non valide.');location.href='/'}catch(x){box.textContent=x.message;b.disabled=false}}</script></html>`;
const noCache = {
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
};
const response = (value, status = 200) =>
  Response.json(value, { status, headers: noCache });
const fail = (message, status = 400) =>
  new Response(message, { status, headers: noCache });
const icon = (b64) =>
  new Response(
    Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)),
    {
      headers: {
        "content-type": "image/png",
        "cache-control": "public, max-age=86400",
      },
    },
  );
const encode64 = (x) =>
  btoa(String.fromCharCode(...x))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
const decode64 = (x) =>
  Uint8Array.from(
    atob(
      x
        .replace(/-/g, "+")
        .replace(/_/g, "/")
        .padEnd(Math.ceil(x.length / 4) * 4, "="),
    ),
    (c) => c.charCodeAt(0),
  );

/** Deriva una chiave HMAC dal secret di deploy, mai incorporato nel codice. */
async function cookieKey(secret) {
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/** Cookie firmato, Secure, HttpOnly e SameSite Strict con scadenza di 30 giorni. */
async function sessionCookie(secret) {
  const payload = encode64(
    new TextEncoder().encode(
      JSON.stringify({ exp: Date.now() + 30 * 86400000 }),
    ),
  );
  const signature = encode64(
    new Uint8Array(
      await crypto.subtle.sign(
        "HMAC",
        await cookieKey(secret),
        new TextEncoder().encode(payload),
      ),
    ),
  );
  return `liquidita_session=${payload}.${signature}; Path=/; Max-Age=2592000; Secure; HttpOnly; SameSite=Strict`;
}

/** Verifica firma e scadenza del cookie; input malformati falliscono chiusi. */
async function validSession(req, secret) {
  const match = (req.headers.get("cookie") || "").match(
    /(?:^|;\s*)liquidita_session=([^;]+)/,
  );
  if (!match || match[1].length > 512) return false;
  try {
    const [body, sig] = match[1].split(".");
    if (!body || !sig) return false;
    const payload = JSON.parse(new TextDecoder().decode(decode64(body)));
    if (!Number.isFinite(payload.exp) || payload.exp <= Date.now())
      return false;
    const expected = new Uint8Array(
      await crypto.subtle.sign(
        "HMAC",
        await cookieKey(secret),
        new TextEncoder().encode(body),
      ),
    );
    const actual = decode64(sig);
    if (expected.length !== actual.length) return false;
    let diff = 0;
    for (let i = 0; i < expected.length; i++) diff |= expected[i] ^ actual[i];
    return diff === 0;
  } catch {
    return false;
  }
}

/** Compatibilità Basic auth; confronto digest senza uscita anticipata sui byte. */
async function checkPassword(req, secret) {
  const value = req.headers.get("authorization") || "";
  if (!value.startsWith("Basic ")) return false;
  let raw;
  try {
    raw = atob(value.slice(6));
  } catch {
    return false;
  }
  const [user, ...parts] = raw.split(":");
  if (user !== "nas" || !parts.length) return false;
  let enc = new TextEncoder(),
    [a, b] = await Promise.all([
      crypto.subtle.digest("SHA-256", enc.encode(parts.join(":"))),
      crypto.subtle.digest("SHA-256", enc.encode(secret)),
    ]);
  let diff = 0,
    x = new Uint8Array(a),
    y = new Uint8Array(b);
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}
const date = (s) =>
  s
    ? new Date(
        s.length === 7
          ? s + "-01T12:00:00Z"
          : s.length === 10
            ? s + "T12:00:00Z"
            : s + "Z",
      )
    : null;
const iso = (s) => String(s || "").slice(0, 10);
const month = (s) => iso(s).slice(0, 7);
const nowDay = () =>
  new Intl.DateTimeFormat("sv-SE", {
    timeZone: "Europe/Rome",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
const planYear = (value) => {
  const y = Number(value);
  return Number.isInteger(y) && y >= 2024 && y <= 2035
    ? y
    : Number(nowDay().slice(0, 4));
};
const validAmount = (value, max = 1e6) => {
  let n = Number(value);
  if (!Number.isFinite(n) || n <= 0 || n > max)
    throw Error("Importo non valido.");
  return n;
};
const validCents = (value) => {
  const n = validAmount(value),
    c = Math.round(n * 100);
  if (!Number.isSafeInteger(c) || c < 1 || Math.abs(c / 100 - n) > 0.00000001)
    throw Error("Usa importi con massimo due decimali.");
  return c;
};
const validDate = (value) => {
  if (
    typeof value !== "string" ||
    !/^20\d\d-\d\d-\d\d$/.test(value) ||
    !Number.isFinite(new Date(value).getTime()) ||
    new Date(value).toISOString().slice(0, 10) !== value
  )
    throw Error("Data non valida.");
  return value;
};

/** Adattatore record D1 -> colonne workbook. Non riordinare senza aggiornare il motore. */
function recordToMovement(r) {
  return [
    date(r.budget_date),
    date(r.actual_date),
    r.description,
    r.amount,
    r.account,
    r.category,
    r.movement_type,
    r.status,
    r.competence_months,
    r.baseline,
    r.counterparty_account,
    r.notes,
    r.merchant,
    r.source_name,
    r.import_id,
    date(r.budget_month),
    r.competence_end,
    r.monthly_share,
    r.actual_month,
    r.source_row,
    r.cashflow_month || "",
    r.resolved_category || r.category,
    r.financial_category_id,
  ];
}

/** Adattatore straordinaria D1 -> colonne workbook storiche. */
function recordToExtra(r) {
  return [
    r.name,
    r.total,
    r.start_month,
    r.month_count,
    r.monthly_share,
    r.end_month,
    r.status,
    r.payment_account,
    r.paid_date,
    r.notes,
    r.repeat_rule,
  ].map((v, i) => ([2, 5, 8].includes(i) ? date(v) : v));
}

/** Emula letture del foglio usando D1, preservando source_row anche con buchi. */
function sheetBook(config, movements, extras) {
  let sheets = new Map();
  for (let r of config) {
    let rows = sheets.get(r.sheet) || [];
    rows[r.row_number - 1] = JSON.parse(r.values_json);
    sheets.set(r.sheet, rows);
  }
  sheets.set("Movimenti", [[], ...movements.map(recordToMovement)]);
  const extraGrid = [[]];
  for (const record of extras)
    extraGrid[Number(record.source_row) - 1] = recordToExtra(record);
  sheets.set("Straordinarie", extraGrid);
  for (let [name, indices] of [
    ["Patrimonio", [2]],
    ["Saldi operativi", [2]],
    ["Riconciliazione stipendi", [0]],
    ["Storico ricorrenti", [0]],
    ["Storico patrimonio", [0]],
  ]) {
    let rows = sheets.get(name) || [];
    for (let r of rows)
      if (r)
        for (let i of indices)
          if (
            r[i] &&
            typeof r[i] === "string" &&
            /^20\d\d-\d\d-\d\d/.test(r[i])
          )
            r[i] = date(r[i]);
  }
  return {
    getSheetByName(name) {
      let rows = sheets.get(name) || [];
      return {
        getLastRow() {
          return rows.length;
        },
        getRange(...args) {
          let first, start, width, height;
          if (typeof args[0] === "string") {
            let match = /^([A-Z]+)(\d+):([A-Z]+)(\d+)$/.exec(args[0]);
            if (!match) throw Error("Intervallo non supportato: " + args[0]);
            start = Number(match[2]);
            height = Number(match[4]) - start + 1;
            let column = (s) =>
              [...s].reduce((v, c) => v * 26 + c.charCodeAt(0) - 64, 0);
            first = column(match[1]);
            width = column(match[3]) - first + 1;
          } else {
            [start, first, height, width] = args;
          }
          return {
            getValues: () =>
              Array.from({ length: height }, (_, i) =>
                Array.from(
                  { length: width },
                  (_, j) => rows[start + i - 1]?.[first + j - 1] ?? "",
                ),
              ),
          };
        },
      };
    },
  };
}

/** Legge D1, calcola il modello e aggiunge analytics solo per richieste complete. */
async function loadFinance(env, year, monthNumber, lightweight = false) {
  await ensureTrStatement(env);
  await ensureBudgetPolicies(env);
  if (!lightweight) await ensureFinanceCategories(env);
  const [m, e, c, snapshots, events, categoryRows, categoryMappings, utilityConfig] =
    await Promise.all([
      env.DB.prepare(
        lightweight
          ? "SELECT * FROM movements ORDER BY source_row"
          : "SELECT m.*,c.detail_category resolved_category,c.category_id financial_category_id FROM movements m LEFT JOIN movement_financial_categories c ON c.movement_source_row=m.source_row ORDER BY m.source_row",
      ).all(),
      env.DB.prepare("SELECT * FROM extraordinary ORDER BY source_row").all(),
      env.DB.prepare(
        "SELECT sheet,row_number,values_json FROM source_rows ORDER BY sheet,row_number",
      ).all(),
      env.DB.prepare(
        "SELECT * FROM account_balance_snapshots ORDER BY id",
      ).all(),
      env.DB.prepare("SELECT * FROM account_balance_events ORDER BY id").all(),
      lightweight
        ? Promise.resolve({ results: [] })
        : env.DB.prepare(
            "SELECT * FROM financial_categories ORDER BY sort_order,id",
          ).all(),
      lightweight
        ? Promise.resolve({ results: [] })
        : env.DB.prepare("SELECT * FROM financial_category_mappings").all(),
      env.DB.prepare("SELECT (SELECT value FROM os_meta WHERE key='utility_estimates_v1') value,(SELECT value FROM os_meta WHERE key='condominium_estimates_v1') condo,(SELECT value FROM os_meta WHERE key='rent_condominium_split_v1158') rent_split").first(),
    ]);
  const config = [
    ...c.results,
    {sheet:"Stime utenze",row_number:1,values_json:JSON.stringify([utilityConfig?.value?JSON.parse(utilityConfig.value):{}])},
    {
      sheet: "Categorie finanziarie",
      row_number: 1,
      values_json: JSON.stringify([
        categoryRows.results.map((c) => ({
          ...c,
          members: categoryMappings.results
            .filter((m) => m.category_id === c.id)
            .map((m) => m.detail_category),
        })),
      ]),
    },
  ];
  if (!config.some((r) => r.sheet === "Budget"))
    throw Error("Apri /setup e importa liquidita-4.0-config.json.");
  const plan = await getExtraPlan(env, planYear(year));
  plan.budgetPolicies=(await env.DB.prepare("SELECT p.*,m.description,m.amount,m.actual_date,m.status FROM movement_budget_policies p JOIN movements m ON m.source_row=p.movement_source_row").all()).results;
  const condo=utilityConfig?.condo;
  plan.condominiumSettings=condo?JSON.parse(condo):{base:0,changes:[{month:"2026-10",value:25}]};
  // The legacy configuration confirms that the legacy 575 includes 25 condo, now shown separately.
  // Persist once, rather than subtracting every future condo estimate from rent.
  let rentSplit=utilityConfig?.rent_split?{value:utilityConfig.rent_split}:null;
  const legacyRent=c.results.find(r=>r.sheet==="Budget" && Number(r.row_number)===3);
  if(!rentSplit && legacyRent && Math.round(Number(JSON.parse(legacyRent.values_json)[14])*100)===57500) {
  await env.DB.prepare("INSERT OR IGNORE INTO os_meta(key,value) SELECT 'rent_condominium_split_v1158',? WHERE EXISTS(SELECT 1 FROM source_rows WHERE sheet='Budget' AND row_number=3 AND ROUND(CAST(json_extract(values_json,'$[14]') AS REAL)*100)=57500)").bind(JSON.stringify({fromMonth:"2026-10",sourceAmount:575,rent:550})).run();
    rentSplit=await env.DB.prepare("SELECT value FROM os_meta WHERE key='rent_condominium_split_v1158'").first();
  }
  plan.rentSplit=rentSplit?.value?JSON.parse(rentSplit.value):null;
  const currentYear = Number(nowDay().slice(0,4));
  if (planYear(year) !== currentYear) {
    const currentPlan = await getExtraPlan(env,currentYear);
    plan.allocations.push(...currentPlan.allocations);
    // links are already read globally by getExtraPlan.
  }
  const result = computeFinance(
    sheetBook(config, m.results, e.results),
    year,
    monthNumber,
    plan,
    snapshots.results,
    events.results,
    lightweight,
    privateRulesByDB.get(env.DB)||{},
  );
  attachSavingsPlanning(result, c.results, nowDay());
  result.forecastHistory = forecastCashHistory(m.results, plan, nowDay());
  if (!lightweight) {
    const y=Number(nowDay().slice(0,4));
    const nextPlan=await getExtraPlan(env,y+1);
    const cycles=new Map([...plan.allocations,...nextPlan.allocations].map(a=>[a.cycle_id+":"+a.month,a]));
    result.forecastPlan={...plan,allocations:[...cycles.values()]};
  }
  if (lightweight) return result;

  const gap = Math.max(
    0,
    Math.round(
      (result.lifetime.income -
        result.lifetime.spent -
        result.summary.totalAssets) *
        100,
    ),
  );
  const adjustment = await env.DB.prepare(
    "INSERT INTO financial_reporting_adjustments(id,label,amount_cents,as_of_day,method) VALUES ('legacy_spending','Spese storiche non dettagliate',?,?, 'Stima autorizzata: redditi documentati meno spese registrate meno liquidita rilevata alla data della stima') ON CONFLICT(id) DO UPDATE SET id=excluded.id RETURNING *"
  ).bind(gap,new Date().toISOString().slice(0,10)).first();
  result.lifetime.recordedSpent = result.lifetime.spent;
  result.lifetime.historicalSpendingEstimate = {
    ...adjustment,
    amount: adjustment.amount_cents / 100,
  };
  if (adjustment.amount_cents > 0) {
    const amount = adjustment.amount_cents / 100;
    result.lifetime.spent =
      Math.round((result.lifetime.spent + amount) * 100) / 100;
    result.lifetime.expenses.push({
      name: adjustment.label,
      amount,
      estimated: true,
    });
    const group =
      result.lifetime.expenseGroups.find((g) => g.id === 10) ||
      result.lifetime.expenseGroups.find((g) =>
        g.members.includes("Pagamenti non dettagliati"),
      );
    if (group) {
      group.amount = Math.round((group.amount + amount) * 100) / 100;
      group.members.push(adjustment.label);
    }
    result.lifetime.expenseGroups.sort((a, b) => b.amount - a.amount);
    for (const group of result.lifetime.expenseGroups)
      group.percentage = Math.round(
        (group.amount / result.lifetime.spent) * 100,
      );
    result.lifetime.expenseAudit.push({
      row: null,
      date: "Storico",
      name: adjustment.label,
      amount,
      category: adjustment.label,
      account: "Conti precedenti",
      estimated: true,
    });
  }
  result.extraPlan = plan;
  result.categoryOptions = [...FINANCE_MANUAL_CATEGORIES];
  return result;
}

/** Esportazione paginata di righe finanziarie per manutenzione autenticata. */
async function getFinanceRaw(env, offset) {
  await ensureTrStatement(env);
  const n = Number(offset);
  if (!Number.isInteger(n) || n < 0 || n > 100000 || n % 50 !== 0)
    throw Error("Pagina non valida.");
  const movements = (
    await env.DB.prepare(
      "SELECT * FROM movements ORDER BY source_row LIMIT 50 OFFSET ?",
    )
      .bind(n)
      .all()
  ).results;
  return { movements };
}

/** Metadati/configurazione per la manutenzione autenticata. */
async function getFinanceMeta(env) {
  await ensureTrStatement(env);
  const [count, extras, config, snapshots, events] = await Promise.all([
    env.DB.prepare("SELECT COUNT(*) AS total FROM movements").first(),
    env.DB.prepare("SELECT * FROM extraordinary ORDER BY source_row").all(),
    env.DB.prepare(
      "SELECT sheet,row_number,values_json FROM source_rows ORDER BY sheet,row_number",
    ).all(),
    env.DB.prepare("SELECT * FROM account_balance_snapshots ORDER BY id").all(),
    env.DB.prepare("SELECT * FROM account_balance_events ORDER BY id").all(),
  ]);
  return {
    total: count.total,
    extras: extras.results,
    config: config.results,
    bankSnapshots: snapshots.results,
    bankEvents: events.results,
  };
}

/** Aggiorna una riga JSON della configurazione legacy; errore se manca. */
async function updateSheetRow(env, sheet, rowNumber, change) {
  const found = await env.DB.prepare(
    "SELECT values_json FROM source_rows WHERE sheet=? AND row_number=?",
  )
    .bind(sheet, rowNumber)
    .first();
  if (!found)
    throw Error(
      "Configurazione non importata: " + sheet + " riga " + rowNumber,
    );
  const values = JSON.parse(found.values_json);
  change(values);
  await env.DB.prepare(
    "UPDATE source_rows SET values_json=? WHERE sheet=? AND row_number=?",
  )
    .bind(JSON.stringify(values), sheet, rowNumber)
    .run();
}

/** Invia la stima della voce selezionata; il server valida nome e intervallo. */
async function saveEstimate(env, name, value) {
  if(name==="Condominio"){
    const n=Number(value);if(!Number.isFinite(n)||n<0||n>1000||Math.abs(Math.round(n*100)/100-n)>1e-8)throw Error("Stima non valida: usa massimo due decimali.");
    const stored=await env.DB.prepare("SELECT value FROM os_meta WHERE key='condominium_estimates_v1'").first();
    const settings=stored?.value?JSON.parse(stored.value):{base:0,changes:[{month:"2026-10",value:25}]},month=nowDay().slice(0,7);
    settings.changes=[...(settings.changes||[]).filter(x=>x.month!==month),{month,value:Math.round(n*100)/100}];
    await env.DB.prepare("INSERT INTO os_meta(key,value) VALUES ('condominium_estimates_v1',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value").bind(JSON.stringify(settings)).run();return true;
  }
  const index = {
    "Elettricit\u00e0": 2,
    Gas: 3,
    Acqua: 4,
    Palestra: 5,
    Abbonamenti: 6,
    Benzina: 7,
  }[name];
  if (!index) throw Error("Voce non valida.");
  let n = Number(value);
  if (!Number.isFinite(n) || n < 0 || n > 1000 || Math.abs(Math.round(n*100)/100-n)>1e-8)
    throw Error("Stima non valida: usa massimo due decimali.");
  if(["Elettricità","Gas","Acqua"].includes(name)) {
    const stored=await env.DB.prepare("SELECT value FROM os_meta WHERE key='utility_estimates_v1'").first();
    const settings=stored?.value?JSON.parse(stored.value):{};
    const prior=await env.DB.prepare("SELECT values_json FROM source_rows WHERE sheet='Budget' AND row_number=?").bind(index).first();
    const config=settings[name]||{base:Number(prior?JSON.parse(prior.values_json)[1]:n)||0,changes:[]};
    const month=nowDay().slice(0,7);
    config.changes=[...(config.changes||[]).filter(x=>x.month!==month),{month,value:n}];settings[name]=config;
    const path='$."'+name+'"',encoded=JSON.stringify(config);
    await env.DB.prepare("INSERT INTO os_meta(key,value) VALUES ('utility_estimates_v1',json_set('{}',?,json(?))) ON CONFLICT(key) DO UPDATE SET value=json_set(os_meta.value,?,json(?))").bind(path,encoded,path,encoded).run();
  } else await updateSheetRow(env, "Budget", index, (row) => (row[1] = n));
  return true;
}




/** Registra il delta del movimento appena inserito, identificato da import_id univoco. */
function insertedBalanceEvent(env, importId, absorbedId = null) {
  return env.DB.prepare(
    `INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row,absorbed_snapshot_id)
  SELECT account,substr(actual_date,1,10),CAST(ROUND(amount*100) AS INTEGER),source_row,?
  FROM movements WHERE import_id=? AND status='Eseguito' AND account IN ('Revolut','Trade Republic')`,
  ).bind(absorbedId, importId);
}

/** Recupera e valida un source_row esistente prima delle operazioni di modifica. */
async function getMovement(env, id) {
  if (!Number.isInteger(id) || id < 2) throw Error("Movimento non valido.");
  const row = await env.DB.prepare("SELECT * FROM movements WHERE source_row=?")
    .bind(id)
    .first();
  if (!row) throw Error("Movimento non trovato. Aggiorna la pagina.");
  await ensureBudgetPolicies(env);
  const policy=await env.DB.prepare("SELECT * FROM movement_budget_policies WHERE movement_source_row=?").bind(id).first();
  return {...row,budgetTreatment:policy?.treatment || "auto",recoveryMonths:policy?JSON.parse(policy.recovery_json).map(q=>q.month).join(", "):"",recoveryAmount:policy?JSON.parse(policy.recovery_json).reduce((n,q)=>n+q.amount_cents,0)/100:0};
}

/** Trova la seconda riga di un trasferimento; rifiuta abbinamenti ambigui. */
async function findMirror(env, row) {
  if (row.transfer_id) {
    const pair = (
      await env.DB.prepare("SELECT * FROM movements WHERE transfer_id=?")
        .bind(row.transfer_id)
        .all()
    ).results;
    const other = pair.find((x) => x.source_row !== row.source_row);
    if (
      pair.length !== 2 ||
      !other ||
      row.movement_type !== "Trasferimento" ||
      other.movement_type !== "Trasferimento" ||
      other.account !== row.counterparty_account ||
      other.counterparty_account !== row.account ||
      Math.abs(other.amount + row.amount) >= 0.005
    )
      throw Error("Trasferimento non coerente: nessuna modifica applicata.");
    return other;
  }
  if (
    row.movement_type !== "Trasferimento" ||
    row.source_name !== "App 4.0" ||
    !row.counterparty_account
  )
    return null;
  const rows = (
    await env.DB.prepare(
      "SELECT * FROM movements WHERE source_row<>? AND transfer_id IS NULL AND movement_type='Trasferimento' AND source_name='App 4.0' AND account=? AND counterparty_account=? AND actual_date=? AND ABS(amount+?)<0.005",
    )
      .bind(
        row.source_row,
        row.counterparty_account,
        row.account,
        row.actual_date,
        row.amount,
      )
      .all()
  ).results;
  // Existing app-created pairs have different import IDs. Only use a unique match.
  if (rows.length !== 1)
    throw Error(
      "Trasferimento storico ambiguo o incompleto: nessuna modifica applicata.",
    );
  return rows[0];
}

/** Aggiorna movimento, eventuale speculare e delta conto nello stesso batch. */
async function saveMovementEdit(env, input) {
  const old = await getMovement(env, Number(input?.row));
  if (
    ![
      "Spesa",
      "Entrata",
      "Trasferimento",
      "Investimento",
      "Da verificare",
    ].includes(old.movement_type)
  )
    throw Error("Tipo storico non modificabile da questa schermata.");
  const type = String(input.type || "");
  if (
    ![
      "Spesa",
      "Entrata",
      "Rimborso",
      "Trasferimento",
      "Investimento",
      "Da verificare",
    ].includes(type)
  )
    throw Error("Tipo non valido.");
  const account = String(input.account || "");
  if (!["Revolut", "Trade Republic", "IsyBank"].includes(account))
    throw Error("Conto non valido.");
  let counterpart =
    type === "Trasferimento" ? String(input.counterpart || "") : "";
  if (
    type === "Trasferimento" &&
    (!["Revolut", "Trade Republic", "IsyBank"].includes(counterpart) ||
      counterpart === account)
  )
    throw Error("Conto di destinazione non valido.");
  const name = String(input.name || "")
      .trim()
      .slice(0, 120),
    day = validDate(input.date),
    amount = validCents(input.amount) / 100;
  if (!name || day > nowDay()) throw Error("Descrizione o data non valida.");
  const months = Number(input.months ?? 1);
  if (!Number.isInteger(months) || months < 1 || months > 12)
    throw Error("Mesi coperti non validi.");
  const category =
    type === "Trasferimento"
      ? "Altro"
      : String(input.category || "Altro")
          .trim()
          .slice(0, 60);
  const signed =
    type === "Rimborso" || type === "Entrata"
      ? amount
      : ["Investimento", "Da verificare", "Trasferimento", "Spesa"].includes(
            type,
          ) &&
          old.movement_type === type &&
          old.amount > 0 && !String(old.notes||"").startsWith("Rimborso / restituzione:")
        ? amount
        : -amount;
  const end =
    new Date(
      Date.UTC(
        Number(day.slice(0, 4)),
        Number(day.slice(5, 7)) - 1 + months,
        0,
      ),
    )
      .toISOString()
      .slice(0, 7) + "-01";
  const mirror = await findMirror(env, old);
  const linked = (
    await env.DB.prepare(
      `SELECT DISTINCT cycle_id FROM extraordinary_movement_links
  WHERE movement_source_row IN (${mirror ? "?,?" : "?"})`,
    )
      .bind(
        ...(mirror ? [old.source_row, mirror.source_row] : [old.source_row]),
      )
      .all()
  ).results;
  if (
    linked.length &&
    (account !== old.account ||
      (mirror && counterpart !== old.counterparty_account))
  )
    throw Error(
      "Un conto \u00e8 collegato a una straordinaria: scollega prima il movimento.",
    );
  const settlement=linked.length?await env.DB.prepare("SELECT * FROM extraordinary_settlements WHERE movement_source_row=?").bind(old.source_row).first():null;
  if(linked.length){
    const attributed=await env.DB.prepare("SELECT COALESCE(SUM(attributed_cents),0) n FROM extraordinary_movement_links WHERE movement_source_row=?").bind(old.source_row).first();
    const required=Number(attributed.n)-(settlement?Math.min(settlement.actual_cents,settlement.planned_cents):0)+(settlement?Math.min(Math.round(-signed*100),settlement.planned_cents):0);
    if(type!==old.movement_type || signed>=0 || Math.round(-signed*100)<required)throw Error("Scollega il piano prima di ridurre l’importo attribuito o cambiare il tipo.");
  }
  const query =
    "UPDATE movements SET actual_date=?,budget_date=?,description=?,amount=?,account=?,category=?,movement_type=?,counterparty_account=?,merchant=?,competence_months=?,budget_month=?,competence_end=?,monthly_share=?,actual_month=?,transfer_id=?,notes=? WHERE source_row=?";
  const sameSchedule =
    String(old.actual_date || "").slice(0, 10) === day &&
    Number(old.competence_months || 1) === months;
  const budgetMonth =
    sameSchedule && old.budget_month
      ? old.budget_month
      : day.slice(0, 7) + "-01";
  const competenceEnd =
    sameSchedule && old.competence_end ? old.competence_end : end;
  const primary = env.DB.prepare(query).bind(
    day,
    sameSchedule && old.budget_date ? old.budget_date : day,
    name,
    signed,
    account,
    category,
    type === "Rimborso" ? "Spesa" : type,
    counterpart,
    name,
    months,
    budgetMonth,
    competenceEnd,
    type === "Spesa" ? -signed / months : null,
    day.slice(0, 7) + "-01",
    type === "Trasferimento" ? old.transfer_id : null,
    (type==="Rimborso"?"Rimborso / restituzione: ":"")+String(old.notes||"").replace(/^Rimborso \/ restituzione:\s*/,""),
    old.source_row,
  );
  const policyInput=input.budgetTreatment===undefined?{...input,budgetTreatment:type==="Spesa"?old.budgetTreatment:"auto",recoveryMonths:old.recoveryMonths,recoveryAmount:Math.min(old.recoveryAmount||amount,amount)}:input;
  const policy=validatedBudgetPolicy(policyInput,amount,day,type);
  if(policy.treatment==="recovery" && signed>=0)throw Error("Un rimborso non può creare un recupero di spesa.");
  if(linked.length && policy.treatment==="recovery")throw Error("Questo movimento è già coperto da un piano. Scollegalo prima di creare un recupero.");
  const operations = [primary,budgetPolicyStatement(env,old.source_row,policy),env.DB.prepare("UPDATE movements SET notes=CASE WHEN instr(COALESCE(notes,''),'[Categoria manuale]')>0 THEN notes ELSE COALESCE(notes,'')||' [Categoria manuale]' END WHERE source_row=?").bind(old.source_row)];
  if(settlement){
    const nextCents=Math.round(-signed*100),attribute=Math.min(nextCents,settlement.planned_cents);
    const linkUpdate=env.DB.prepare("UPDATE extraordinary_movement_links SET attributed_cents=? WHERE cycle_id=? AND movement_source_row=?").bind(attribute,settlement.cycle_id,old.source_row);
    if(attribute<=Math.min(settlement.actual_cents,settlement.planned_cents))operations.unshift(linkUpdate);else operations.push(linkUpdate);
    operations.push(env.DB.prepare("UPDATE extraordinary_settlements SET actual_cents=? WHERE movement_source_row=?").bind(nextCents,old.source_row));
  }
  const changed = [
    { old, next: { account, actual_date: day, amount: signed } },
  ];
  if (mirror) {
    if (type === "Trasferimento") {
      operations.push(
        env.DB.prepare(query).bind(
          day,
          day,
          "Trasferimento da " + account,
          -signed,
          counterpart,
          "Altro",
          "Trasferimento",
          account,
          "Trasferimento da " + account,
          months,
          budgetMonth,
          competenceEnd,
          null,
          day.slice(0, 7) + "-01",
          old.transfer_id,
          mirror.notes||"",
          mirror.source_row,
        ),
      );
      changed.push({
        old: mirror,
        next: { account: counterpart, actual_date: day, amount: -signed },
      });
    } else {
      operations.push(
        env.DB.prepare("DELETE FROM movements WHERE source_row=?").bind(
          mirror.source_row,
        ),
      );
      changed.push({ old: mirror, next: null });
    }
  } else if (
    type === "Trasferimento" &&
    old.movement_type !== "Trasferimento"
  ) {
    // Reclassifying an imported row does not invent a bank movement on another account.
    // An app-created transfer is instead created as a pair by saveTransaction.
  }
  const balanceOperations=[];
  for(const item of changed){
    balanceOperations.push(env.DB.prepare("INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row) SELECT account,substr(actual_date,1,10),-CAST(ROUND(amount*100) AS INTEGER),source_row FROM movements WHERE source_row=? AND status='Eseguito' AND account IN ('Revolut','Trade Republic')").bind(item.old.source_row));
    if(item.next && ["Revolut","Trade Republic"].includes(item.next.account))balanceOperations.push(env.DB.prepare("INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row) SELECT ?,?,?,source_row FROM movements WHERE source_row=? AND status='Eseguito'").bind(item.next.account,item.next.actual_date,Math.round(item.next.amount*100),item.old.source_row));
  }
  operations.unshift(...balanceOperations);
  for (const link of linked)
    operations.push(
      env.DB.prepare(
        `UPDATE extraordinary SET status=(
   SELECT status FROM extraordinary_cycles WHERE id=?),paid_date=(
   SELECT MAX(m.actual_date) FROM extraordinary_movement_links l JOIN movements m
   ON m.source_row=l.movement_source_row WHERE l.cycle_id=?)
   WHERE source_row=(SELECT extraordinary_source_row FROM extraordinary_cycles WHERE id=?)`,
      ).bind(link.cycle_id, link.cycle_id, link.cycle_id),
    );
  await env.DB.batch(operations);
  return true;
}

/** Elimina movimento e speculare con storno condizionato atomico, una sola volta. */
async function deleteMovement(env, id) {
  const old = await getMovement(env, Number(id));
  const mirror = await findMirror(env, old);
  const rows = [old, ...(mirror ? [mirror] : [])];
  const linked = (
    await env.DB.prepare(
      `SELECT DISTINCT cycle_id FROM extraordinary_movement_links
   WHERE movement_source_row IN (${rows.map(() => "?").join(",")})`,
    )
      .bind(...rows.map((r) => r.source_row))
      .all()
  ).results;
  await env.DB.batch([
    // Reverse only rows that STILL exist, inside the same atomic batch as DELETE.
    // Two simultaneous delete requests must not credit the account twice.
    ...rows.map((r) =>
      env.DB.prepare(
        `INSERT INTO account_balance_events(account,day,delta_cents,movement_source_row)
    SELECT account,substr(actual_date,1,10),-CAST(ROUND(amount*100) AS INTEGER),source_row
    FROM movements WHERE source_row=? AND status='Eseguito' AND account IN ('Revolut','Trade Republic')`,
      ).bind(r.source_row),
    ),
    ...rows.map((r) =>
      env.DB.prepare(
        "DELETE FROM extraordinary_movement_links WHERE movement_source_row=?",
      ).bind(r.source_row),
    ),
    ...rows.map(r=>env.DB.prepare("DELETE FROM movement_budget_policies WHERE movement_source_row=?").bind(r.source_row)),
    ...rows.map(r=>env.DB.prepare("DELETE FROM extraordinary_settlements WHERE movement_source_row=?").bind(r.source_row)),
    ...rows.map((r) =>
      env.DB.prepare("DELETE FROM movements WHERE source_row=?").bind(
        r.source_row,
      ),
    ),
    ...linked.flatMap((x) => syncExtraStatusStatements(env, x.cycle_id)),
    ...linked.map((x) =>
      env.DB.prepare(
        `UPDATE extraordinary SET status=(
    SELECT status FROM extraordinary_cycles WHERE id=?),
    paid_date=(SELECT MAX(m.actual_date) FROM extraordinary_movement_links l
      JOIN movements m ON m.source_row=l.movement_source_row WHERE l.cycle_id=?)
    WHERE source_row=(SELECT extraordinary_source_row FROM extraordinary_cycles WHERE id=?)`,
      ).bind(x.cycle_id, x.cycle_id, x.cycle_id),
    ),
  ]);
  return { deleted: mirror ? 2 : 1 };
}
// Schema readiness is per D1 binding; concurrent cold starts share one promise.
const lifeSchemaJobs = new WeakMap();

/** Condivide l’inizializzazione per binding D1; un errore consente un nuovo tentativo. */
async function ensureLife(env) {
  if (!lifeSchemaJobs.has(env.DB))
    lifeSchemaJobs.set(env.DB, initializeLife(env));
  try {
    await lifeSchemaJobs.get(env.DB);
  } catch (error) {
    lifeSchemaJobs.delete(env.DB);
    throw error;
  }
}

/** Migrazioni idempotenti e seed storici protetti da os_meta; non resettare i marcatori. */
async function initializeLife(env) {
  await env.DB.batch([
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_meta (key TEXT PRIMARY KEY,value TEXT NOT NULL)",
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_tasks (id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,list_kind TEXT NOT NULL DEFAULT 'action',status TEXT NOT NULL DEFAULT 'todo',due_date TEXT,scheduled_date TEXT,notes TEXT NOT NULL DEFAULT '',import_key TEXT UNIQUE,created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,completed_at TEXT)",
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_categories (key TEXT PRIMARY KEY,label TEXT NOT NULL COLLATE NOCASE UNIQUE,position INTEGER NOT NULL DEFAULT 0)",
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_shifts (day TEXT PRIMARY KEY,kind TEXT NOT NULL,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)",
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_events (id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,day TEXT NOT NULL,start_time TEXT,end_time TEXT,location TEXT NOT NULL DEFAULT '',notes TEXT NOT NULL DEFAULT '',created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)",
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_event_repeat (event_id INTEGER PRIMARY KEY,frequency TEXT NOT NULL,until_day TEXT)",
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_routines (id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT NOT NULL,position INTEGER NOT NULL DEFAULT 0,created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)",
    ),
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_routine_checks (routine_id INTEGER NOT NULL,day TEXT NOT NULL,checked_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY(routine_id,day))",
    ),
  ]);
  await env.DB.batch(
    [
      ["action", "Attivit\u00e0", 0],
      ["wishlist", "Desideri", 1],
      ["games", "Giochi", 2],
      ["books", "Letture", 3],
    ].map(([key, label, position]) =>
      env.DB.prepare(
        "INSERT OR IGNORE INTO os_categories(key,label,position) SELECT ?,?,? WHERE NOT EXISTS (SELECT 1 FROM os_meta WHERE key='deleted_category:'||?)",
      ).bind(key, label, position,key),
    ),
  );
  // Personal tasks, routines, shifts and their seed markers remain in the existing D1 database.
  const routineColumns = (await env.DB.prepare("PRAGMA table_info(os_routines)").all()).results;
  if (!routineColumns.some(c => c.name === "schedule_json")) {
    try { await env.DB.prepare("ALTER TABLE os_routines ADD COLUMN schedule_json TEXT").run(); }
    catch (error) { if (!(await env.DB.prepare("PRAGMA table_info(os_routines)").all()).results.some(c => c.name === "schedule_json")) throw error; }
  }
  // Older exports predate task ordering and occurrence exceptions.
  const columns = (await env.DB.prepare("PRAGMA table_info(os_tasks)").all())
    .results;
  if (!columns.some((column) => column.name === "sort_order")) {
    try {
      await env.DB.prepare(
        "ALTER TABLE os_tasks ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0",
      ).run();
    } catch (error) {
      const fresh = (await env.DB.prepare("PRAGMA table_info(os_tasks)").all())
        .results;
      if (!fresh.some((column) => column.name === "sort_order")) throw error;
    }
  }
  await env.DB.batch([
    env.DB.prepare(
      "CREATE TABLE IF NOT EXISTS os_event_occurrences(event_id INTEGER NOT NULL,day TEXT NOT NULL,status TEXT NOT NULL,updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY(event_id,day))",
    ),
    env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_os_tasks_list_order ON os_tasks(list_kind,status,sort_order,id)",
    ),
    env.DB.prepare(
      "CREATE INDEX IF NOT EXISTS idx_os_events_day ON os_events(day)",
    ),
  ]);
}
const validMonthKey = (s) =>
  typeof s === "string" && /^20\d\d-(0[1-9]|1[0-2])$/.test(s);
const validClock = (s) =>
  s === null ||
  s === "" ||
  (typeof s === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(s));

/** Legge attività, turni e occorrenze; la home esclude eventi fatti o saltati. */
async function lifeRead(env, focus) {
  await ensureLife(env);
  await env.DB.prepare(
    "DELETE FROM os_tasks WHERE status='done' AND completed_at IS NOT NULL AND strftime('%s',completed_at)<=strftime('%s','now','-5 days')",
  ).run();
  const base = validMonthKey(focus) ? focus : nowDay().slice(0, 7);
  const first = new Date(base + "-01T12:00:00Z");
  const low = new Date(
    Date.UTC(first.getUTCFullYear(), first.getUTCMonth() - 1, 1),
  )
    .toISOString()
    .slice(0, 10);
  const high = new Date(
    Date.UTC(first.getUTCFullYear(), first.getUTCMonth() + 2, 1),
  )
    .toISOString()
    .slice(0, 10);
  const today = nowDay(),
    end = new Date(Date.parse(today + "T12:00:00Z") + 6 * 86400000)
      .toISOString()
      .slice(0, 10),
    clock = new Intl.DateTimeFormat("en-GB", {
      timeZone: "Europe/Rome",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).format(new Date());
  const [tasks, categories, shifts, events, routines, occurrences] =
    await Promise.all([
      env.DB.prepare(
        "SELECT * FROM os_tasks ORDER BY CASE status WHEN 'todo' THEN 0 WHEN 'waiting' THEN 1 ELSE 2 END,sort_order,id",
      ).all(),
      env.DB.prepare(
        "SELECT * FROM os_categories ORDER BY position,label",
      ).all(),
      env.DB.prepare(
        "SELECT * FROM os_shifts WHERE (day>=? AND day<?) OR day=? OR day=? ORDER BY day",
      )
        .bind(
          low,
          high,
          today,
          new Date(Date.parse(today + "T12:00:00Z") + 86400000)
            .toISOString()
            .slice(0, 10),
        )
        .all(),
      env.DB.prepare(
        "SELECT e.*,r.frequency,r.until_day FROM os_events e LEFT JOIN os_event_repeat r ON r.event_id=e.id WHERE e.day<? ORDER BY e.day",
      )
        .bind(high)
        .all(),
      env.DB.prepare(
        "SELECT r.id,r.title,r.position,r.schedule_json,CASE WHEN c.routine_id IS NULL THEN 0 ELSE 1 END AS checked FROM os_routines r LEFT JOIN os_routine_checks c ON c.routine_id=r.id AND c.day=? ORDER BY r.position,r.id",
      )
        .bind(today)
        .all(),
      env.DB.prepare(
        "SELECT event_id,day,status FROM os_event_occurrences",
      ).all(),
    ]);
  const all = await env.DB.prepare(
    "SELECT e.*,r.frequency,r.until_day FROM os_events e LEFT JOIN os_event_repeat r ON r.event_id=e.id WHERE e.day<=?",
  )
    .bind(end)
    .all();
  const next = new Date(Date.parse(end + "T12:00:00Z") + 86400000)
    .toISOString()
    .slice(0, 10);
  const statusMap = new Map(
    occurrences.results.map((o) => [o.event_id + ":" + o.day, o.status]),
  );
  const state = (e) => ({
    ...e,
    occurrence_status: statusMap.get(e.id + ":" + e.day) || "open",
  });
  return {
    tasks: tasks.results,
    categories: categories.results,
    shifts: shifts.results,
    events: expandEvents(events.results, low, high)
      .map(state)
      .filter((e) => e.occurrence_status !== "skipped"),
    upcomingEvents: expandEvents(all.results, today, next)
      .map(state)
      .filter(
        (e) =>
          e.occurrence_status === "open" &&
          (e.day > today || !e.start_time || e.start_time >= clock),
      )
      .slice(0, 3),
    routines: routines.results.map(({schedule_json,...r}) => ({...r,schedule:habitSchedule(schedule_json == null ? undefined : JSON.parse(schedule_json))})),
    routineScheduleVersion: 1,
    today,
    month: base,
  };
}

/** Dispatch validato delle operazioni Life OS; tutte le query usano bind. */
async function lifeAction(env, method, args) {
  const x = args[0];
  if (method === "getLifeData") return lifeRead(env, x);
  await ensureLife(env);
  if (method === "setRoutineCheck") {
    const id = Number(x?.id),
      checked = x?.checked;
    if (!Number.isInteger(id) || id < 1 || typeof checked !== "boolean")
      throw Error("Routine non valida.");
    if (x.day !== nowDay())
      throw Error(
        "\u00c8 iniziato un nuovo giorno. Aggiorna la routine e riprova.",
      );
    const routine = await env.DB.prepare("SELECT schedule_json FROM os_routines WHERE id=?").bind(id).first();
    if (!routine) throw Error("Abitudine non trovata.");
    if (checked && !habitDue({schedule:habitSchedule(routine.schedule_json == null ? undefined : JSON.parse(routine.schedule_json))},x.day)) throw Error("Questa abitudine non è prevista per oggi.");
    if (checked)
      await env.DB.prepare(
        "INSERT OR IGNORE INTO os_routine_checks(routine_id,day) VALUES (?,?)",
      )
        .bind(id, nowDay())
        .run();
    else
      await env.DB.prepare(
        "DELETE FROM os_routine_checks WHERE routine_id=? AND day=?",
      )
        .bind(id, nowDay())
        .run();
    return true;
  }
  if (method === "saveRoutine") {
    const title = String(x?.title || "")
        .trim()
        .slice(0, 60),
      id = Number(x?.id || 0);
    if (!title) throw Error("Inserisci un nome.");
    if (!Number.isInteger(id) || id < 0) throw Error("Routine non valida.");
    const schedule = x?.schedule === undefined ? undefined : JSON.stringify(habitSchedule(x.schedule));
    if (id) {
      const result = await env.DB.prepare(
        schedule === undefined ? "UPDATE os_routines SET title=? WHERE id=?" : "UPDATE os_routines SET title=?,schedule_json=? WHERE id=?",
      )
        .bind(...(schedule === undefined ? [title,id] : [title,schedule,id]))
        .run();
      if (result.meta.changes !== 1) throw Error("Routine non trovata.");
      return true;
    }
    const count = await env.DB.prepare(
      "SELECT COUNT(*) AS n FROM os_routines",
    ).first();
    if (count.n >= 100) throw Error("Massimo 100 abitudini.");
    await env.DB.prepare("INSERT INTO os_routines(title,position,schedule_json) VALUES (?,?,?)")
      .bind(title, count.n, schedule ?? JSON.stringify(habitSchedule(undefined)))
      .run();
    return true;
  }
  if (method === "deleteRoutine") {
    const id = Number(x);
    if (!Number.isInteger(id) || id < 1) throw Error("Routine non valida.");
    await env.DB.batch([
      env.DB.prepare("DELETE FROM os_routine_checks WHERE routine_id=?").bind(
        id,
      ),
      env.DB.prepare("DELETE FROM os_routines WHERE id=?").bind(id),
    ]);
    return true;
  }
  if (method === "addCategory") {
    const label = String(x?.label || "")
      .trim()
      .slice(0, 40);
    if (!label) throw Error("Indica un nome per la categoria.");
    const duplicate = await env.DB.prepare(
      "SELECT key FROM os_categories WHERE label=? COLLATE NOCASE",
    )
      .bind(label)
      .first();
    if (duplicate) throw Error("Questa categoria esiste gi\u00e0.");
    const key = "custom-" + crypto.randomUUID(),
      position = (
        await env.DB.prepare(
          "SELECT COALESCE(MAX(position),0)+1 AS n FROM os_categories",
        ).first()
      ).n;
    await env.DB.prepare(
      "INSERT INTO os_categories(key,label,position) VALUES (?,?,?)",
    )
      .bind(key, label, position)
      .run();
    return { key, label };
  }
  if (method === "deleteCategory") {
    const key=String(x?.key||""),destination=String(x?.destination||"");
    if(!key || key===destination)throw Error("Scegli una categoria diversa per le attività.");
    const rows=(await env.DB.prepare("SELECT key FROM os_categories").all()).results;
    if(rows.length<2 || !rows.some(r=>r.key===key) || !rows.some(r=>r.key===destination))throw Error("Categoria non valida.");
    await env.DB.batch([
      env.DB.prepare("UPDATE os_tasks SET list_kind=? WHERE list_kind=?").bind(destination,key),
      env.DB.prepare("INSERT OR REPLACE INTO os_meta(key,value) VALUES (?, '1')").bind("deleted_category:"+key),
      env.DB.prepare("DELETE FROM os_categories WHERE key=?").bind(key)
    ]);
    return true;
  }
  if (method === "renameCategory") {
    const key = String(x?.key || ""),
      label = String(x?.label || "")
        .trim()
        .slice(0, 40);
    if (!label) throw Error("Indica un nome per la categoria.");
    const r = await env.DB.prepare(
      "UPDATE os_categories SET label=? WHERE key=?",
    )
      .bind(label, key)
      .run();
    if (r.meta.changes !== 1) throw Error("Categoria non trovata.");
    return true;
  }
  if (method === "reorderCategories") {
    const keys = x?.keys,
      current = (
        await env.DB.prepare("SELECT key FROM os_categories").all()
      ).results.map((r) => r.key);
    if (
      !Array.isArray(keys) ||
      keys.length !== current.length ||
      new Set(keys).size !== keys.length ||
      keys.some((k) => !current.includes(k))
    )
      throw Error("Le categorie sono cambiate: ricarica e riprova.");
    await env.DB.batch(
      keys.map((key, position) =>
        env.DB.prepare("UPDATE os_categories SET position=? WHERE key=?").bind(
          position,
          key,
        ),
      ),
    );
    return true;
  }
  if (method === "reorderTasks") {
    const category = String(x?.category || ""),
      ids = x?.ids;
    if (
      !Array.isArray(ids) ||
      ids.length > 500 ||
      !ids.every((id) => Number.isInteger(id) && id > 0) ||
      new Set(ids).size !== ids.length
    )
      throw Error("Ordine non valido.");
    const rows = (
      await env.DB.prepare(
        "SELECT id FROM os_tasks WHERE list_kind=? AND status='todo' ORDER BY sort_order,id",
      )
        .bind(category)
        .all()
    ).results;
    if (rows.length !== ids.length || rows.some((r) => !ids.includes(r.id)))
      throw Error("La lista \u00e8 cambiata. Aggiorna e riprova.");
    if (ids.length)
      await env.DB.batch(
        ids.map((id, i) =>
          env.DB.prepare(
            "UPDATE os_tasks SET sort_order=?,updated_at=CURRENT_TIMESTAMP WHERE id=? AND list_kind=? AND status='todo'",
          ).bind(i + 1, id, category),
        ),
      );
    return true;
  }
  if (method === "deleteCompletedTasks") {
    const category = String(x?.category || "");
    if (
      !(await env.DB.prepare("SELECT key FROM os_categories WHERE key=?")
        .bind(category)
        .first())
    )
      throw Error("Categoria non trovata.");
    await env.DB.prepare(
      "DELETE FROM os_tasks WHERE list_kind=? AND status='done'",
    )
      .bind(category)
      .run();
    return true;
  }
  if (method === "saveTask") {
    const title = String(x?.title || "")
        .trim()
        .slice(0, 160),
      notes = String(x?.notes || "")
        .trim()
        .slice(0, 1000),
      kind = String(x?.list_kind || "action");
    if (
      !title ||
      !(await env.DB.prepare("SELECT key FROM os_categories WHERE key=?")
        .bind(kind)
        .first())
    )
      throw Error("Attivit\u00e0 o categoria non valida.");
    const due = x.due_date ? validDate(x.due_date) : null,
      scheduled = x.scheduled_date ? validDate(x.scheduled_date) : null;
    if (x.id) {
      const id = Number(x.id);
      if (!Number.isInteger(id) || id < 1) throw Error("ID non valido.");
      const r = await env.DB.prepare(
        "UPDATE os_tasks SET title=?,list_kind=?,sort_order=CASE WHEN list_kind=? THEN sort_order ELSE (SELECT COALESCE(MAX(sort_order),0)+1 FROM os_tasks WHERE list_kind=?) END,notes=?,due_date=?,scheduled_date=?,updated_at=CURRENT_TIMESTAMP WHERE id=?",
      )
        .bind(title, kind, kind, kind, notes, due, scheduled, id)
        .run();
      if (r.meta.changes !== 1) throw Error("Attivit\u00e0 non trovata.");
      return true;
    }
    await env.DB.prepare(
      "INSERT INTO os_tasks(title,list_kind,notes,due_date,scheduled_date,sort_order) VALUES (?,?,?,?,?,(SELECT COALESCE(MAX(sort_order),0)+1 FROM os_tasks WHERE list_kind=?))",
    )
      .bind(title, kind, notes, due, scheduled, kind)
      .run();
    return true;
  }
  if (method === "setTaskStatus") {
    const id = Number(x?.id),
      status = String(x?.status || "");
    if (
      !Number.isInteger(id) ||
      id < 1 ||
      !["todo", "waiting", "done"].includes(status)
    )
      throw Error("Stato non valido.");
    const r = await env.DB.prepare(
      "UPDATE os_tasks SET status=?,completed_at=CASE WHEN ?='done' THEN COALESCE(completed_at,strftime('%Y-%m-%dT%H:%M:%SZ','now')) ELSE NULL END,updated_at=CURRENT_TIMESTAMP WHERE id=?",
    )
      .bind(status, status, id)
      .run();
    if (r.meta.changes !== 1) throw Error("Attivit\u00e0 non trovata.");
    return true;
  }
  if (method === "deleteTask") {
    const id = Number(x);
    if (!Number.isInteger(id) || id < 1) throw Error("ID non valido.");
    await env.DB.prepare("DELETE FROM os_tasks WHERE id=?").bind(id).run();
    return true;
  }
  if (method === "paintShift") {
    const day = validDate(x?.day),
      kind = String(x?.kind || "");
    if (kind === "erase") {
      await env.DB.prepare("DELETE FROM os_shifts WHERE day=?").bind(day).run();
      return true;
    }
    if (!["morning", "afternoon", "night", "holiday", "rest"].includes(kind))
      throw Error("Turno non valido.");
    await env.DB.prepare(
      "INSERT INTO os_shifts(day,kind) VALUES (?,?) ON CONFLICT(day) DO UPDATE SET kind=excluded.kind,updated_at=CURRENT_TIMESTAMP",
    )
      .bind(day, kind)
      .run();
    return true;
  }
  if (method === "saveEvent") {
    const title = String(x?.title || "")
        .trim()
        .slice(0, 140),
      day = validDate(x?.day),
      start = x?.start_time || null,
      end = x?.end_time || null;
    if (!title || !validClock(start) || !validClock(end) || (end && !start))
      throw Error("Evento o orario non valido.");
    const place = String(x?.location || "")
        .trim()
        .slice(0, 160),
      notes = String(x?.notes || "")
        .trim()
        .slice(0, 1000);
    const frequency = x.frequency || "none",
      until = x.until_day ? validDate(x.until_day) : null;
    if (
      !["none", "weekly", "monthly", "yearly"].includes(frequency) ||
      (until && until < day)
    )
      throw Error("Ricorrenza o data finale non valida.");
    if (x.id) {
      const id = Number(x.id);
      if (!Number.isInteger(id) || id < 1) throw Error("ID non valido.");
      const old = await env.DB.prepare(
        "SELECT e.day,r.frequency FROM os_events e LEFT JOIN os_event_repeat r ON r.event_id=e.id WHERE e.id=?",
      )
        .bind(id)
        .first();
      if (!old) throw Error("Evento non trovato.");
      if (old.day !== day || old.frequency !== frequency) {
        const exceptions = await env.DB.prepare(
          "SELECT COUNT(*) AS n FROM os_event_occurrences WHERE event_id=?",
        )
          .bind(id)
          .first();
        if (exceptions.n)
          throw Error(
            "Questa serie ha occorrenze segnate: per conservare la storia usa Modifica da qui o riaprile prima di cambiare la regola.",
          );
      }
      await env.DB.batch([
        env.DB.prepare(
          "UPDATE os_events SET title=?,day=?,start_time=?,end_time=?,location=?,notes=?,updated_at=CURRENT_TIMESTAMP WHERE id=?",
        ).bind(title, day, start, end, place, notes, id),
        env.DB.prepare(
          "INSERT INTO os_event_repeat(event_id,frequency,until_day) VALUES (?,?,?) ON CONFLICT(event_id) DO UPDATE SET frequency=excluded.frequency,until_day=excluded.until_day",
        ).bind(id, frequency, until),
      ]);
      return true;
    }
    await env.DB.batch([
      env.DB.prepare(
        "INSERT INTO os_events(title,day,start_time,end_time,location,notes) VALUES (?,?,?,?,?,?)",
      ).bind(title, day, start, end, place, notes),
      env.DB.prepare(
        "INSERT INTO os_event_repeat(event_id,frequency,until_day) VALUES (last_insert_rowid(),?,?)",
      ).bind(frequency, until),
    ]);
    return true;
  }
  if (method === "setEventOccurrence") {
    const id = Number(x?.id),
      day = validDate(x?.day),
      status = String(x?.status || "");
    if (
      !Number.isInteger(id) ||
      id < 1 ||
      !["open", "done", "skipped"].includes(status)
    )
      throw Error("Occorrenza non valida.");
    const event = await env.DB.prepare(
      "SELECT e.*,r.frequency,r.until_day FROM os_events e LEFT JOIN os_event_repeat r ON r.event_id=e.id WHERE e.id=?",
    )
      .bind(id)
      .first();
    const next = new Date(Date.parse(day + "T12:00:00Z") + 86400000)
      .toISOString()
      .slice(0, 10);
    if (!event || !expandEvents([event], day, next).some((e) => e.day === day))
      throw Error("Questa occorrenza non esiste.");
    if (status === "open")
      await env.DB.prepare(
        "DELETE FROM os_event_occurrences WHERE event_id=? AND day=?",
      )
        .bind(id, day)
        .run();
    else
      await env.DB.prepare(
        "INSERT INTO os_event_occurrences(event_id,day,status) VALUES (?,?,?) ON CONFLICT(event_id,day) DO UPDATE SET status=excluded.status,updated_at=CURRENT_TIMESTAMP",
      )
        .bind(id, day, status)
        .run();
    return true;
  }
  if (method === "splitEventSeries") {
    const id = Number(x?.id),
      from = validDate(x?.split_from),
      day = validDate(x?.day);
    if (!Number.isInteger(id) || id < 1) throw Error("Serie non valida.");
    const original = await env.DB.prepare(
      "SELECT e.*,r.frequency,r.until_day FROM os_events e JOIN os_event_repeat r ON r.event_id=e.id WHERE e.id=?",
    )
      .bind(id)
      .first();
    if (
      !original ||
      !["weekly", "monthly", "yearly"].includes(original.frequency)
    )
      throw Error("La ricorrenza non esiste.");
    const following = new Date(Date.parse(from + "T12:00:00Z") + 86400000)
      .toISOString()
      .slice(0, 10);
    const instances = expandEvents([original], original.day, following);
    if (!instances.some((e) => e.day === from))
      throw Error("La data scelta non appartiene alla serie.");
    const previous = instances.filter((e) => e.day < from).at(-1)?.day || "";
    if (day <= previous)
      throw Error("La nuova data deve seguire la precedente occorrenza.");
    const title = String(x?.title || "")
        .trim()
        .slice(0, 140),
      start = x?.start_time || null,
      end = x?.end_time || null;
    const frequency = String(x?.frequency || "none"),
      until = x?.until_day ? validDate(x.until_day) : null;
    if (
      !title ||
      !validClock(start) ||
      !validClock(end) ||
      (end && !start) ||
      !["none", "weekly", "monthly", "yearly"].includes(frequency) ||
      (until && until < day)
    )
      throw Error("Nuova scadenza non valida.");
    const futureExceptions = await env.DB.prepare(
      "SELECT COUNT(*) AS n FROM os_event_occurrences WHERE event_id=? AND day>=?",
    )
      .bind(id, from)
      .first();
    if (futureExceptions.n)
      throw Error(
        "Ci sono occorrenze gi\u00e0 completate o saltate da questa data: riaprile prima di modificare la serie.",
      );
    const oldEnd = new Date(Date.parse(from + "T12:00:00Z") - 86400000)
      .toISOString()
      .slice(0, 10);
    const place = String(x?.location || "")
        .trim()
        .slice(0, 160),
      notes = String(x?.notes || "")
        .trim()
        .slice(0, 1000);
    await env.DB.batch([
      env.DB.prepare(
        "UPDATE os_event_repeat SET until_day=? WHERE event_id=?",
      ).bind(oldEnd, id),
      env.DB.prepare(
        "INSERT INTO os_events(title,day,start_time,end_time,location,notes) VALUES (?,?,?,?,?,?)",
      ).bind(title, day, start, end, place, notes),
      env.DB.prepare(
        "INSERT INTO os_event_repeat(event_id,frequency,until_day) VALUES (last_insert_rowid(),?,?)",
      ).bind(frequency, until),
    ]);
    return true;
  }
  if (method === "deleteEvent") {
    const id = Number(x);
    if (!Number.isInteger(id) || id < 1) throw Error("ID non valido.");
    await env.DB.batch([
      env.DB.prepare("DELETE FROM os_event_occurrences WHERE event_id=?").bind(
        id,
      ),
      env.DB.prepare("DELETE FROM os_event_repeat WHERE event_id=?").bind(id),
      env.DB.prepare("DELETE FROM os_events WHERE id=?").bind(id),
    ]);
    return true;
  }
  throw Error("Operazione non disponibile.");
}

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

/** Materializza cicli annuali idempotenti e legge quote del periodo selezionato. */
async function getExtraPlan(env, year) {
  await ensureBudgetPolicies(env);
  const y = planYear(year);
  // Materialize the requested and previous annual cycle so January/February
  // can still see a cycle whose twelve months began in the prior year.
  await env.DB.batch([
    env.DB.prepare(
      `WITH RECURSIVE requested(y) AS
    (SELECT ? UNION ALL SELECT y+1 FROM requested WHERE y<?)
    INSERT OR IGNORE INTO extraordinary_cycles
      (extraordinary_source_row,start_month,end_month,total_cents,kind,status)
    SELECT e.source_row,
      substr(date(e.start_month,'+'||(12*(requested.y-CAST(substr(e.start_month,1,4) AS INTEGER)))||' months'),1,7),
      substr(date(e.end_month,'+'||(12*(requested.y-CAST(substr(e.start_month,1,4) AS INTEGER)))||' months'),1,7),
      CAST(ROUND(e.total*100) AS INTEGER),'expense','Programmato'
    FROM extraordinary e,requested
    WHERE e.repeat_rule='Annuale' AND e.status!='Annullato'
      AND requested.y>=CAST(substr(e.start_month,1,4) AS INTEGER)`,
    ).bind(y - 1, y),
    env.DB.prepare(
      `WITH RECURSIVE seq(n) AS
    (SELECT 0 UNION ALL SELECT n+1 FROM seq WHERE n<11)
    INSERT OR IGNORE INTO extraordinary_allocations(cycle_id,month,amount_cents)
    SELECT c.id,substr(date(c.start_month||'-01','+'||seq.n||' months'),1,7),
      CAST(c.total_cents/12 AS INTEGER)+CASE WHEN seq.n<c.total_cents%12 THEN 1 ELSE 0 END
    FROM extraordinary_cycles c JOIN extraordinary e ON e.source_row=c.extraordinary_source_row,seq
    WHERE e.repeat_rule='Annuale' AND c.start_month>=? AND c.start_month<?`,
    ).bind(y - 1 + "-01", y + 1 + "-01"),
  ]);
  const [allocations, ledger] = await Promise.all([
    env.DB.prepare(
      `SELECT a.cycle_id,a.month,a.amount_cents,c.kind,c.status,e.name,
    c.extraordinary_source_row,c.start_month,c.end_month,c.total_cents,e.payment_account,e.paid_date FROM extraordinary_allocations a
    JOIN extraordinary_cycles c ON c.id=a.cycle_id
    JOIN extraordinary e ON e.source_row=c.extraordinary_source_row
    WHERE a.month>=? AND a.month<? ORDER BY a.month,e.name`,
    )
      .bind(y + "-01", y + 1 + "-01")
      .all(),
    env.DB.prepare(`SELECT
      (SELECT json_group_array(json_object('cycle_id',l.cycle_id,'movement_source_row',l.movement_source_row,'attributed_cents',l.attributed_cents,'role',l.role,'actual_date',m.actual_date,'account',m.account,'amount',m.amount)) FROM extraordinary_movement_links l JOIN movements m ON m.source_row=l.movement_source_row) links,
      (SELECT json_group_array(json_object('cycle_id',cycle_id,'movement_source_row',movement_source_row,'planned_cents',planned_cents,'actual_cents',actual_cents)) FROM extraordinary_settlements) settlements`).first(),
  ]);
  return {allocations:allocations.results,links:JSON.parse(ledger.links),settlements:JSON.parse(ledger.settlements)};
}

/** Valida l’ID e recupera il ciclo straordinario. */
async function getExtraCycle(env, id) {
  await ensureBudgetPolicies(env);
  if(!Number.isInteger(id)||id<1)throw Error("Ciclo non valido.");
  const cycle = await env.DB.prepare(
    "SELECT * FROM extraordinary_cycles WHERE id=?",
  )
    .bind(id)
    .first();
  if (!cycle)
    throw Error(
      "Ciclo straordinario non trovato. Applica prima la migrazione.",
    );
  return cycle;
}

/** Completa il ciclo con nome, conto, regola e pagamenti attribuiti. */
async function getExtraCycleDetail(env, id) {
  const cycle = await getExtraCycle(env, id);
  const [extra, linked] = await Promise.all([
    env.DB.prepare(
      "SELECT name,notes,payment_account,repeat_rule FROM extraordinary WHERE source_row=?",
    )
      .bind(cycle.extraordinary_source_row)
      .first(),
    env.DB.prepare(
      "SELECT COALESCE(SUM(attributed_cents),0) total FROM extraordinary_movement_links WHERE cycle_id=?",
    )
      .bind(id)
      .first(),
  ]);
  if (!extra) throw Error("Voce straordinaria non trovata.");
  return {
    ...cycle,
    name: extra.name,
    notes: extra.notes,
    account: extra.payment_account,
    repeat: extra.repeat_rule,
    linked_cents: linked.total,
  };
}

/** Modifica il piano e distribuisce centesimi esatti; non scende sotto il già pagato. */
async function updateExtraPlan(env, input) {
  const id = Number(input?.cycleId);
  if (!Number.isSafeInteger(id) || id < 1) throw Error("Ciclo non valido.");
  const cycle = await getExtraCycleDetail(env, id);
  const cents = validCents(input?.amount),
    start = String(input?.month || ""),
    end = String(input?.endMonth || "");
  if (
    !/^20\d\d-(0[1-9]|1[0-2])$/.test(start) ||
    !/^20\d\d-(0[1-9]|1[0-2])$/.test(end)
  )
    throw Error("Mese non valido.");
  const months =
    (Number(end.slice(0, 4)) - Number(start.slice(0, 4))) * 12 +
    Number(end.slice(5)) -
    Number(start.slice(5)) +
    1;
  if (months < 1 || months > 60) throw Error("Durata non valida.");
  if (cents < Number(cycle.linked_cents))
    throw Error(
      "Il totale non pu\u00f2 essere inferiore ai pagamenti gi\u00e0 collegati.",
    );
  const annual = cycle.repeat === "Annuale";
  if (annual && (start !== cycle.start_month || months !== 12))
    throw Error(
      "Per un ciclo annuale puoi modificare il totale; il periodo resta quello della ricorrenza.",
    );
  const name = String(input?.name || "")
    .trim()
    .slice(0, 100);
  const account = String(input?.account || "");
  if (
    !name ||
    (cycle.kind === "budget_advance"
      ? account !== cycle.account
      : !["Revolut", "Trade Republic"].includes(account))
  )
    throw Error("Voce o conto non valido.");
  const note = String(input?.note || "").slice(0, 200);
  const shares = Array.from(
    { length: months },
    (_, i) => Math.floor(cents / months) + (i < cents % months ? 1 : 0),
  );
  const allocations = shares.map((amount, i) => {
    const date = new Date(
      Date.UTC(Number(start.slice(0, 4)), Number(start.slice(5)) - 1 + i, 1),
    );
    return env.DB.prepare(
      "INSERT INTO extraordinary_allocations(cycle_id,month,amount_cents) VALUES (?,?,?)",
    ).bind(id, date.toISOString().slice(0, 7), amount);
  });
  const operations = [
    env.DB.prepare(
      "UPDATE extraordinary_cycles SET start_month=?,end_month=?,total_cents=? WHERE id=?",
    ).bind(start, end, cents, id),
    env.DB.prepare(
      "DELETE FROM extraordinary_allocations WHERE cycle_id=?",
    ).bind(id),
    ...allocations,
  ];
  if (!annual)
    operations.push(
      env.DB.prepare(
        `UPDATE extraordinary SET name=?,total=?,start_month=?,month_count=?,monthly_share=?,end_month=?,payment_account=?,notes=? WHERE source_row=?`,
      ).bind(
        name,
        cents / 100,
        start + "-01",
        months,
        cents / 100 / months,
        end + "-01",
        account,
        note,
        cycle.extraordinary_source_row,
      ),
    );
  else
    operations.push(
      env.DB.prepare(
        "UPDATE extraordinary SET name=?,payment_account=?,notes=? WHERE source_row=?",
      ).bind(name, account, note, cycle.extraordinary_source_row),
    );
  operations.push(
    ...(annual
      ? syncExtraStatusStatements(env, id).slice(0, 1)
      : syncExtraStatusStatements(env, id)),
  );
  await env.DB.batch(operations);
  return { cycleId: id, months, total_cents: cents };
}

/** Prepara aggiornamenti stato da importi collegati; non riattiva piani annullati. */
function syncExtraStatusStatements(env, cycleId) {
  return [
    env.DB.prepare(
      `UPDATE extraordinary_cycles SET status=CASE
   WHEN status='Annullato' THEN 'Annullato'
   WHEN EXISTS(SELECT 1 FROM extraordinary_settlements s JOIN movements m ON m.source_row=s.movement_source_row WHERE s.cycle_id=extraordinary_cycles.id) THEN 'Pagato'
   WHEN (SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE cycle_id=?)
     >=total_cents THEN CASE WHEN kind='budget_advance' THEN 'Anticipato' ELSE 'Pagato' END
   WHEN status IN ('Pagato','Anticipato','Da riconciliare') THEN 'Da riconciliare'
   ELSE status END WHERE id=?`,
    ).bind(cycleId, cycleId),
    env.DB.prepare(
      `UPDATE extraordinary SET status=(SELECT status FROM extraordinary_cycles WHERE id=?),
   paid_date=(SELECT MAX(m.actual_date) FROM extraordinary_movement_links l
     JOIN movements m ON m.source_row=l.movement_source_row WHERE l.cycle_id=?)
   WHERE source_row=(SELECT extraordinary_source_row FROM extraordinary_cycles WHERE id=?)`,
    ).bind(cycleId, cycleId, cycleId),
  ];
}

/** Attribuisce centesimi di un movimento esistente a un ciclo; nessun nuovo addebito. */
async function linkExtraMovement(env, input) {
  const cycleId = Number(input?.cycleId),
    movementId = Number(input?.movementId);
  const cents = validCents(input?.amount);
  if (
    !Number.isInteger(cycleId) ||
    !Number.isInteger(movementId) ||
    !Number.isSafeInteger(cents)
  )
    throw Error("Collegamento non valido.");
  const cycle = await getExtraCycle(env, cycleId);
  const movement=await getMovement(env,movementId);
  if(movement.status!=="Eseguito" || Number(movement.amount)>=0 || movement.movement_type!==(cycle.kind==="budget_advance"?"Trasferimento":"Spesa") || !["Trade Republic","Revolut"].includes(movement.account))throw Error("Movimento non compatibile con il piano.");
  if(movement.budgetTreatment==="recovery")throw Error("Il movimento ha già un recupero: rimuovilo prima di collegare il piano.");
  const existing=await env.DB.prepare("SELECT COALESCE(SUM(attributed_cents),0) n FROM extraordinary_movement_links WHERE movement_source_row=?").bind(movementId).first();
  const paid=await env.DB.prepare("SELECT COALESCE(SUM(attributed_cents),0) n FROM extraordinary_movement_links WHERE cycle_id=?").bind(cycleId).first();
  if(["Annullato","Pagato"].includes(cycle.status) || cents+Number(existing.n)>Math.round(-movement.amount*100) || cents+Number(paid.n)>cycle.total_cents)throw Error("Importo già attribuito o superiore al residuo del piano.");
  const role = cycle.kind === "budget_advance" ? "budget_advance" : "payment";
  const result=await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO extraordinary_movement_links
   (cycle_id,movement_source_row,attributed_cents,role)
   SELECT ?,?,?,? WHERE NOT EXISTS(SELECT 1 FROM extraordinary_movement_links WHERE cycle_id=? AND movement_source_row=?)
   AND (SELECT CAST(ROUND(-amount*100) AS INTEGER) FROM movements WHERE source_row=?)-(SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE movement_source_row=?)>=?
   AND (SELECT total_cents FROM extraordinary_cycles WHERE id=? AND status NOT IN ('Annullato','Pagato'))-(SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE cycle_id=?)>=?
   AND NOT EXISTS(SELECT 1 FROM movement_budget_policies WHERE movement_source_row=? AND treatment='recovery')`,
    ).bind(cycleId,movementId,cents,role,cycleId,movementId,movementId,movementId,cents,cycleId,cycleId,cents,movementId),
    ...syncExtraStatusStatements(env, cycleId),
  ]);
  if(result[0].meta.changes!==1)throw Error("Il movimento o il piano è cambiato: ricarica prima di collegarlo.");
  return true;
}

/** Rimuove l’attribuzione e ricalcola lo stato; non elimina il movimento bancario. */
async function unlinkExtraMovement(env, input) {
  const cycleId = Number(input?.cycleId),
    movementId = Number(input?.movementId);
  if (!Number.isInteger(cycleId) || !Number.isInteger(movementId))
    throw Error("Collegamento non valido.");
  await getExtraCycle(env, cycleId);
  await env.DB.batch([
    env.DB.prepare(
      "DELETE FROM extraordinary_movement_links WHERE cycle_id=? AND movement_source_row=?",
    ).bind(cycleId, movementId),
    env.DB.prepare("DELETE FROM extraordinary_settlements WHERE cycle_id=? AND movement_source_row=?").bind(cycleId,movementId),
    ...syncExtraStatusStatements(env, cycleId),
  ]);
  return true;
}

/** Pagamento atomico condizionato al residuo; due richieste simultanee non duplicano l’addebito. */
async function recordExtraPayment(env, input) {
  const cycleId = Number(input?.cycleId),
    cycle = await getExtraCycle(env, cycleId);
  if (cycle.kind !== "expense" || cycle.status === "Annullato")
    throw Error("Questa voce non \u00e8 pagabile.");
  const cents = validCents(input?.amount),
    amount = cents / 100,
    day = validDate(input?.date);
  const linked = (
    await env.DB.prepare(
      "SELECT COALESCE(SUM(attributed_cents),0) n FROM extraordinary_movement_links WHERE cycle_id=?",
    )
      .bind(cycleId)
      .first()
  ).n;
  if(cycle.status==="Pagato" || linked>=cycle.total_cents){
    const prior=await env.DB.prepare("SELECT actual_cents FROM extraordinary_settlements WHERE cycle_id=?").bind(cycleId).first();
    if(prior && prior.actual_cents!==cents)throw Error("Questo ciclo è già pagato con un importo diverso. Correggi il movimento esistente.");
    return {alreadyPaid:true};
  }
  const expectedRemaining=cycle.total_cents-linked,attributed=Math.min(cents,expectedRemaining);
  if (day > nowDay()) throw Error("La data del pagamento \u00e8 futura.");
  const account = String(input?.account || ""),
    name = String(input?.name || "")
      .trim()
      .slice(0, 120);
  if (account !== "Trade Republic" || !name)
    throw Error("Conto o descrizione non validi.");
  const extra = await env.DB.prepare(
    "SELECT name FROM extraordinary WHERE source_row=?",
  )
    .bind(cycle.extraordinary_source_row)
    .first();
  const month = day.slice(0, 7) + "-01",
    importId = "APP-" + crypto.randomUUID();
  const r = {
    budget_date: day,
    actual_date: day,
    description: name,
    amount: -amount,
    account,
    category: "Straordinarie",
    movement_type: "Spesa",
    status: "Eseguito",
    competence_months: 1,
    baseline: "No",
    counterparty_account: "",
    notes: "Pagamento " + extra.name,
    merchant: name,
    source_name: "App 4.0",
    import_id: importId,
    budget_month: month,
    competence_end: month,
    monthly_share: amount,
    actual_month: month,
  };
  const columns = MOVEMENT_COLUMNS.slice(1);
  const insert = env.DB.prepare(
    `INSERT INTO movements (source_row,${columns.join(",")})
   SELECT MAX((SELECT COALESCE(MAX(source_row),1) FROM movements),(SELECT COALESCE(MAX(movement_source_row),1) FROM account_balance_events))+1,${columns.map(() => "?").join(",")} WHERE EXISTS (SELECT 1 FROM extraordinary_cycles c WHERE c.id=? AND c.status NOT IN ('Annullato','Pagato') AND NOT EXISTS(SELECT 1 FROM extraordinary_settlements WHERE cycle_id=c.id) AND c.total_cents-(SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE cycle_id=c.id)=?)`,
  ).bind(...columns.map((k) => r[k] ?? null), cycleId, expectedRemaining);
  const batch = await env.DB.batch([
    insert,
    insertedBalanceEvent(env, importId),
    env.DB.prepare(
      `INSERT INTO extraordinary_movement_links
   (cycle_id,movement_source_row,attributed_cents,role)
   SELECT ?,source_row,?,'payment' FROM movements WHERE import_id=?`,
    ).bind(cycleId, attributed, importId),
    env.DB.prepare("INSERT OR IGNORE INTO extraordinary_settlements(cycle_id,movement_source_row,planned_cents,actual_cents) SELECT ?,source_row,?,? FROM movements WHERE import_id=?").bind(cycleId,expectedRemaining,cents,importId),
    ...syncExtraStatusStatements(env, cycleId),
    env.DB.prepare(
      "UPDATE extraordinary SET payment_account=? WHERE source_row=? AND EXISTS(SELECT 1 FROM movements WHERE import_id=?)",
    ).bind(account, cycle.extraordinary_source_row, importId),
  ]);
  if(batch[0].meta.changes!==1){
    const current=await env.DB.prepare("SELECT c.status,c.total_cents,(SELECT COALESCE(SUM(attributed_cents),0) FROM extraordinary_movement_links WHERE cycle_id=c.id) linked_cents FROM extraordinary_cycles c WHERE c.id=?").bind(cycleId).first();
    if(!current || current.status==="Annullato" || (current.status!=="Pagato" && current.linked_cents<current.total_cents))throw Error("Il piano è cambiato durante il pagamento. Aggiorna la pagina e verifica l’importo prima di riprovare.");
    const prior=await env.DB.prepare("SELECT actual_cents FROM extraordinary_settlements WHERE cycle_id=?").bind(cycleId).first();
    if(prior && prior.actual_cents!==cents)throw Error("Questo ciclo è già pagato con un importo diverso. Correggi il movimento esistente.");
    return {alreadyPaid:true};
  }
  return {movementId:batch[0].meta.last_row_id};
}

/** Crea piano, ciclo e quote; la creazione non muove denaro. */
async function saveExtra(env, input) {
  await ensureBudgetPolicies(env);
  let name = String(input?.name || "")
      .trim()
      .slice(0, 100),
    cents = validCents(input?.amount),
    total = cents / 100,
    start = String(input?.month || ""),
    end = String(input?.endMonth || "");
  if (
    !/^20\d\d-(0[1-9]|1[0-2])$/.test(start) ||
    !/^20\d\d-(0[1-9]|1[0-2])$/.test(end) ||
    !name
  )
    throw Error("Voce o mese non valido.");
  let months =
    (Number(end.slice(0, 4)) - Number(start.slice(0, 4))) * 12 +
    Number(end.slice(5)) -
    Number(start.slice(5)) +
    1;
  if (months < 1 || months > 60) throw Error("Durata non valida.");
  if (
    !["Previsto", "Programmato", "Annullato"].includes(input.status) ||
    input.account !== "Trade Republic"
  )
    throw Error(
      "Crea la voce come Programmato; per Pagato o Anticipato collega un movimento.",
    );
  if (input.repeat === "Annuale" && months !== 12)
    throw Error("Annuale richiede 12 mesi inclusi.");
  let value = {
    name,
    total,
    start_month: start + "-01",
    month_count: months,
    monthly_share: total / months,
    end_month: end + "-01",
    status: input.status,
    payment_account: input.account,
    paid_date: null,
    notes: String(input.note || "").slice(0, 200),
    repeat_rule: input.repeat === "Annuale" ? "Annuale" : "No",
  };
  const requestId=String(input.requestId || crypto.randomUUID());
  if(!/^[a-zA-Z0-9-]{8,80}$/.test(requestId))throw Error("Identificativo richiesta non valido.");
  const fingerprint=JSON.stringify(value),previous=await env.DB.prepare("SELECT * FROM finance_extra_requests WHERE id=?").bind(requestId).first();
  if(previous){if(previous.fingerprint!==fingerprint)throw Error("Richiesta già usata con dati diversi. Riapri il modulo.");return {row:previous.source_row};}
  const columns=EXTRAS_COLUMNS.slice(1);
  await env.DB.batch([
    env.DB.prepare(`INSERT INTO extraordinary(source_row,${columns.join(",")}) SELECT MAX((SELECT COALESCE(MAX(source_row),1) FROM extraordinary),(SELECT COALESCE(MAX(source_row),1) FROM finance_extra_requests))+1,${columns.map(()=>"?").join(",")} WHERE NOT EXISTS(SELECT 1 FROM finance_extra_requests WHERE id=?)`).bind(...columns.map(k=>value[k]??null),requestId),
    env.DB.prepare("INSERT OR IGNORE INTO finance_extra_requests(id,source_row,fingerprint) SELECT ?,MAX(source_row),? FROM extraordinary WHERE NOT EXISTS(SELECT 1 FROM finance_extra_requests WHERE id=?)").bind(requestId,fingerprint,requestId),
    env.DB.prepare("INSERT OR IGNORE INTO extraordinary_cycles(extraordinary_source_row,start_month,end_month,total_cents,kind,status) SELECT source_row,?,?,?,'expense',? FROM finance_extra_requests WHERE id=? AND fingerprint=?").bind(start,end,cents,input.status,requestId,fingerprint),
    env.DB.prepare(`WITH RECURSIVE seq(n) AS (SELECT 0 UNION ALL SELECT n+1 FROM seq WHERE n+1<?)
      INSERT OR IGNORE INTO extraordinary_allocations(cycle_id,month,amount_cents)
      SELECT c.id,substr(date(?,'+'||seq.n||' months'),1,7),CAST(?/? AS INTEGER)+CASE WHEN seq.n<?%? THEN 1 ELSE 0 END
      FROM extraordinary_cycles c JOIN finance_extra_requests r ON r.source_row=c.extraordinary_source_row,seq WHERE r.id=? AND r.fingerprint=? AND c.start_month=?`).bind(months,start+"-01",cents,months,cents,months,requestId,fingerprint,start)
  ]);
  const result=await env.DB.prepare("SELECT * FROM finance_extra_requests WHERE id=?").bind(requestId).first();
  if(result.fingerprint!==fingerprint)throw Error("Richiesta già usata con dati diversi. Riapri il modulo.");
  return {row:result.source_row};
}

/** Compatibilità cambio stato storico con controllo dello stato precedente. */
async function setExtraStatus(env, row, previous, next, paidDate) {
  if (
    !Number.isInteger(row) ||
    row < 2 ||
    !["Previsto", "Programmato", "Pagato", "Anticipato", "Annullato"].includes(
      next,
    )
  )
    throw Error("Stato non valido.");
  if (next === "Pagato" || next === "Anticipato")
    throw Error(
      "Per segnare pagata o anticipata una voce, collega il movimento bancario.",
    );
  const cycle = await env.DB.prepare(
    "SELECT id FROM extraordinary_cycles WHERE extraordinary_source_row=? ORDER BY id DESC LIMIT 1",
  )
    .bind(row)
    .first();
  if (!cycle) throw Error("Applica prima la migrazione delle straordinarie.");
  const linked = await env.DB.prepare(
    "SELECT 1 FROM extraordinary_movement_links WHERE cycle_id=? LIMIT 1",
  )
    .bind(cycle.id)
    .first();
  if (linked)
    throw Error(
      "La voce ha movimenti collegati: scollegali prima di cambiarne lo stato.",
    );
  const result = await env.DB.batch([
    env.DB.prepare(
      "UPDATE extraordinary SET status=? WHERE source_row=? AND status=?",
    ).bind(next, row, previous),
    env.DB.prepare(
      "UPDATE extraordinary_cycles SET status=? WHERE id=? AND status=?",
    ).bind(next, cycle.id, previous),
  ]);
  if (result[0].meta.changes !== 1 || result[1].meta.changes !== 1)
    throw Error("La voce \u00e8 stata modificata: ricarica la pagina.");
  return true;
}

/** Paga il residuo del ciclo dal conto previsto; già pagato è idempotente. */
async function markExtraPaid(env, input) {
  const c = await getExtraCycleDetail(env, Number(input?.cycleId));
  if (c.status === "Pagato" || c.linked_cents >= c.total_cents)
    return { alreadyPaid: true };
  return recordExtraPayment(env, {
    cycleId: c.id,
    amount: (c.total_cents - c.linked_cents) / 100,
    account: "Trade Republic",
    name: c.name,
    date: nowDay(),
  });
}

/** Annulla la pianificazione; conserva movimenti e denaro già speso. */
async function cancelExtraCycle(env, input) {
  const c = await getExtraCycleDetail(env, Number(input?.cycleId));
  await env.DB.batch([
    env.DB.prepare(
      "UPDATE extraordinary_cycles SET status='Annullato' WHERE id=?",
    ).bind(c.id),
    ...(c.repeat === "Annuale"
      ? []
      : [
          env.DB.prepare(
            "UPDATE extraordinary SET status='Annullato' WHERE source_row=?",
          ).bind(c.extraordinary_source_row),
        ]),
  ]);
  return true;
}

/** Elimina solo pianificazioni annullate prive di pagamenti collegati. */
async function deleteExtraPlan(env, input) {
  const c = await getExtraCycleDetail(env, Number(input?.cycleId));
  const linked = await env.DB.prepare(
    "SELECT 1 FROM extraordinary_movement_links l JOIN extraordinary_cycles c ON c.id=l.cycle_id WHERE c.extraordinary_source_row=? LIMIT 1",
  )
    .bind(c.extraordinary_source_row)
    .first();
  if (linked)
    throw Error(
      "I pagamenti sono nello storico: puoi annullare il piano, ma non eliminarlo.",
    );
  if (c.status !== "Annullato")
    throw Error("Annulla la voce prima di eliminarla.");
  await env.DB.batch([
    env.DB.prepare(
      "DELETE FROM extraordinary_allocations WHERE cycle_id IN (SELECT id FROM extraordinary_cycles WHERE extraordinary_source_row=?)",
    ).bind(c.extraordinary_source_row),
    env.DB.prepare(
      "DELETE FROM extraordinary_cycles WHERE extraordinary_source_row=?",
    ).bind(c.extraordinary_source_row),
    env.DB.prepare("DELETE FROM extraordinary WHERE source_row=?").bind(
      c.extraordinary_source_row,
    ),
  ]);
  return true;
}

/** Cambia solo categoria con marcatore manuale, preservando importo e saldo. */
async function classifyMovement(env, id, category) {
  id = Number(id);
  category = String(category || "").trim();
  if (!Number.isSafeInteger(id) || id < 1 || !category || category.length > 80)
    throw Error("Categoria non valida.");
  const current = await env.DB.prepare(
    "SELECT source_row FROM movements WHERE source_row=?",
  )
    .bind(id)
    .first();
  if (!current) throw Error("Movimento non trovato.");
  await env.DB.prepare(
    "UPDATE movements SET category=?,notes=CASE WHEN instr(COALESCE(notes,''),'[Categoria manuale]')>0 THEN notes ELSE COALESCE(notes,'')||' [Categoria manuale]' END WHERE source_row=?",
  )
    .bind(category, id)
    .run();
  return true;
}

/** Whitelist RPC di letture e scritture; nessuna esecuzione di nomi arbitrari. */
async function writeAction(env, method, args) {
  if (
    [
      "getLifeData",
      "addCategory",
      "renameCategory",
      "deleteCategory",
      "reorderCategories",
      "reorderTasks",
      "deleteCompletedTasks",
      "saveTask",
      "setEventOccurrence",
      "splitEventSeries",
      "setTaskStatus",
      "deleteTask",
      "paintShift",
      "saveEvent",
      "deleteEvent",
      "setRoutineCheck",
      "saveRoutine",
      "deleteRoutine",
    ].includes(method)
  )
    return lifeAction(env, method, args);
  switch (method) {
    case "getFinanceCategoryOptions":
      await ensureFinanceCategories(env);
      return [...FINANCE_MANUAL_CATEGORIES];
    case "classifyMovement":
      return classifyMovement(env, args[0], args[1]);
    case "getMovement":
      return getMovement(env, Number(args[0]));
    case "editMovement":
      return saveMovementEdit(env, args[0]);
    case "deleteMovement":
      return deleteMovement(env, args[0]);
    case "saveTransaction":
      return saveTransaction(env, args[0]);
    case "saveRecurringPayment": {
      let x = args[0];
      if (!ALLOWED_RECURRING.includes(x?.name)) throw Error("Voce non valida.");
      return saveTransaction(env, {
        type: "Spesa",
        account: x.account || "Trade Republic",
        amount: x.amount,
        name: x.name,
        category: x.name,
        date: x.date,
        note: x.note,
        months: x.months ?? 1,
        requestId:x.requestId,
      });
    }
    case "markExtraPaid":
      return markExtraPaid(env, args[0]);
    case "cancelExtraCycle":
      return cancelExtraCycle(env, args[0]);
    case "deleteExtraPlan":
      return deleteExtraPlan(env, args[0]);
    case "saveExtra":
      return saveExtra(env, args[0]);
    case "setExtraStatus":
      return setExtraStatus(env, Number(args[0]), args[1], args[2], args[3]);
    case "getExtraPlan":
      return getExtraPlan(env, args[0]);
    case "getExtraCycleDetail":
      return getExtraCycleDetail(env, Number(args[0]));
    case "updateExtraPlan":
      return updateExtraPlan(env, args[0]);
    case "linkExtraMovement":
      return linkExtraMovement(env, args[0]);
    case "unlinkExtraMovement":
      return unlinkExtraMovement(env, args[0]);
    case "recordExtraPayment":
      return recordExtraPayment(env, args[0]);
    case "saveEstimate":
      return saveEstimate(env, args[0], args[1]);
    case "savePlanningSettings": {
      const {goal: target, saving: monthly} = planningInputs(args[0], args[1]);
      // Older workbook exports stop at row 12. Create optional settings without
      // rewriting unrelated cells, and commit both values in one D1 transaction.
      const existing = await env.DB.prepare(
        "SELECT row_number,values_json FROM source_rows WHERE sheet='Budget' AND row_number IN (13,14)",
      ).all();
      const rows = new Map(
        existing.results.map((r) => [r.row_number, JSON.parse(r.values_json)]),
      );
      const statements = [
          [13, target],
          [14, monthly],
        ].map(([rowNumber, value]) => {
          const row = rows.get(rowNumber) || Array(15).fill("");
          row[14] = value;
          return env.DB.prepare(
            "INSERT INTO source_rows(sheet,row_number,values_json) VALUES ('Budget',?,?) ON CONFLICT(sheet,row_number) DO UPDATE SET values_json=excluded.values_json",
          ).bind(rowNumber, JSON.stringify(row));
        });
      if (args.length >= 3) {
        const savingsTarget = Number(args[2]);
        if (!Number.isFinite(savingsTarget) || savingsTarget <= 0 || savingsTarget > 1000000) throw Error("Obiettivo non valido.");
        statements.push(env.DB.prepare("INSERT INTO source_rows(sheet,row_number,values_json) VALUES ('LifeOS Settings',1,?) ON CONFLICT(sheet,row_number) DO UPDATE SET values_json=excluded.values_json").bind(JSON.stringify([Math.round(savingsTarget*100)/100])));
      }
      await env.DB.batch(statements);
      return true;
    }
    case "saveRevolutSnapshot":
      throw Error("Revolut è un conto storico. Aggiorna il saldo Trade Republic.");
    case "saveAssetBalance":
      throw Error("Il saldo si aggiorna attraverso i movimenti; la modifica manuale è disattivata.");
    default:
      throw Error("Operazione non disponibile.");
  }
}
/** HTTP boundary: public icons, authenticated HTML/API, same-origin POST validation. */
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url),
      path = url.pathname;
    if (request.method === "GET" && path === "/apple-touch-icon.png")
      return icon(ICON_180);
    if (request.method === "GET" && path === "/favicon.png")
      return icon(ICON_64);
    if (request.method === "GET" && path === "/manifest.webmanifest")
      return Response.json(
        {
          name: "Life OS",
          short_name: "Life OS",
          start_url: "/",
          scope: "/",
          display: "standalone",
          background_color: "#0c0c0e",
          theme_color: "#0c0c0e",
          icons: [
            {
              src: "/apple-touch-icon.png?v=1146growth",
              sizes: "180x180",
              type: "image/png",
            },
          ],
        },
        {
          headers: {
            "content-type": "application/manifest+json",
            "cache-control": "public, max-age=86400",
          },
        },
      );
    // ACCESS_EMAIL switches authentication to Cloudflare Access. A missing Access
    // context then fails closed, even if an old password or cookie is supplied.
    const accessEmail = String(env.ACCESS_EMAIL || "")
      .trim()
      .toLowerCase();
    if (accessEmail) {
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(accessEmail))
        return fail("Configura ACCESS_EMAIL con il tuo indirizzo Google.", 503);
      if (!ctx?.access)
        return fail(
          "Attiva Cloudflare Access su questo Worker e accedi con Google.",
          403,
        );
      let identity;
      try {
        identity = await ctx.access.getIdentity();
      } catch {
        return fail("Identit\u00e0 Cloudflare Access non disponibile.", 403);
      }
      if (String(identity?.email || "").toLowerCase() !== accessEmail)
        return fail("Questo account Google non \u00e8 autorizzato.", 403);
    } else {
      if (request.method === "GET" && path === "/login")
        return new Response(LOGIN_PAGE, {
          headers: {
            ...noCache,
            "content-type": "text/html; charset=utf-8",
            "x-frame-options": "DENY",
            "content-security-policy":
              "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'",
          },
        });
      if (!env.APP_PASSWORD || env.APP_PASSWORD.length < 24)
        return fail(
          "Configura il Secret APP_PASSWORD di almeno 24 caratteri.",
          503,
        );
      if (request.method === "POST" && path === "/auth/login") {
        if (request.headers.get("origin") !== url.origin)
          return fail("Origine non valida.", 403);
        if (Number(request.headers.get("content-length") || 0) > 2000)
          return fail("Richiesta troppo grande.", 413);
        let input;
        try {
          input = await request.json();
        } catch {
          return fail("JSON non valido.", 400);
        }
        if (
          input?.user !== "nas" ||
          typeof input.password !== "string" ||
          input.password.length > 1000 ||
          input.password !== env.APP_PASSWORD
        )
          return fail("Credenziali non valide.", 401);
        return new Response("{}", {
          headers: {
            ...noCache,
            "content-type": "application/json",
            "set-cookie": await sessionCookie(env.APP_PASSWORD),
          },
        });
      }
      if (
        !(await validSession(request, env.APP_PASSWORD)) &&
        !(await checkPassword(request, env.APP_PASSWORD))
      ) {
        if (request.method === "GET")
          return new Response(null, {
            status: 302,
            headers: { ...noCache, location: "/login" },
          });
        return fail("Sessione scaduta. Riapri l\u2019app e accedi.", 401);
      }
    }
    if (!env.DB) return fail("Aggiungi il binding D1 con nome DB.", 503);
    if (request.method === "GET") {
      if (path === "/")
        return new Response(APP_HTML, {
          headers: {
            ...noCache,
            "content-type": "text/html; charset=utf-8",
            "x-frame-options": "DENY",
            "content-security-policy":
              "default-src 'self' data:; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self' data:; connect-src 'self' https://api.open-meteo.com",
          },
        });
      if (path === "/setup")
        return new Response(CONFIG_PAGE, {
          headers: {
            ...noCache,
            "content-type": "text/html; charset=utf-8",
            "x-frame-options": "DENY",
            "content-security-policy":
              "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'",
          },
        });
      return fail("Non trovato.", 404);
    }
    if (request.method !== "POST") return fail("Metodo non disponibile.", 405);
    if (request.headers.get("origin") !== url.origin)
      return fail("Origine non valida.", 403);
    if (path === "/api/import-config") {
      if (Number(request.headers.get("content-length") || 0) > 150000)
        return fail("Blocco troppo grande.", 413);
      let rows;
      try {
        rows = await request.json();
      } catch {
        return fail("JSON non valido.", 400);
      }
      if (
        !Array.isArray(rows) ||
        rows.length < 1 ||
        rows.length > 20 ||
        rows.some(
          (r) =>
            !r ||
            typeof r.sheet !== "string" ||
            r.sheet.length > 60 ||
            !Number.isInteger(r.row_number) ||
            r.row_number < 1 ||
            r.row_number > 5000 ||
            typeof r.values_json !== "string" ||
            r.values_json.length > 100000,
        )
      )
        return fail("Dati non validi.", 400);
      await env.DB.prepare(
        "CREATE TABLE IF NOT EXISTS source_rows (sheet TEXT NOT NULL,row_number INTEGER NOT NULL,values_json TEXT NOT NULL,PRIMARY KEY(sheet,row_number))",
      ).run();
      await env.DB.batch(
        rows.map((r) =>
          env.DB.prepare(
            "INSERT OR REPLACE INTO source_rows(sheet,row_number,values_json) VALUES (?,?,?)",
          ).bind(r.sheet, r.row_number, r.values_json),
        ),
      );
      return response({ imported: rows.length });
    }
    const method = path.startsWith("/api/") ? path.slice(5) : "";
    let args;
    try {
      args = await request.json();
    } catch {
      return fail("JSON non valido.", 400);
    }
    if (!Array.isArray(args) || args.length > 5)
      return fail("Argomenti non validi.", 400);
    try {
      if (method === "getPlanningProjection")
        return response(await getPlanningProjection(env, args[0], args[1]));
      if (method === "getFinanceData")
        return response(await loadFinance(env, args[0], args[1]));
      if (method === "getFinanceOverview" || method === "getFinanceExtras")
        return response(await loadFinance(env, args[0], args[1], true));
      if (method === "getFinanceRaw")
        return response(await getFinanceRaw(env, args[0]));
      if (method === "getFinanceMeta")
        return response(await getFinanceMeta(env));
      const result = await writeAction(env, method, args);
      if (
        [
          "classifyMovement",
          "editMovement",
          "deleteMovement",
          "saveTransaction",
          "saveRecurringPayment",
          "recordExtraPayment",
          "markExtraPaid",
          "setExtraStatus",
        ].includes(method)
      )
        await ensureFinanceCategories(env);
      return response(result);
    } catch (e) {
      return fail(String(e.message || e), 400);
    }
  },
};

export {saveTransaction};
