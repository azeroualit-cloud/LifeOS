// A bill owns a competence period. Cash and fund contributions keep their dates.
export function isUtilityCostFund(plan) {
  return plan?.kind === 'estimated' || ['fund', 'fixed', 'goal'].includes(plan?.kind)
    && ['Elettricità', 'Gas', 'Acqua', 'Utenze', 'Condominio'].includes(plan?.category);
}
export function utilityPeriod(input) {
  const start = input.competenceStartMonth, end = input.competenceEndMonth;
  if (start == null && end == null) return null;
  const valid = x => typeof x === 'string' && /^20\d\d-(0[1-9]|1[0-2])$/.test(x);
  if (!valid(start) || !valid(end)) throw Error('Indica mese iniziale e finale di competenza.');
  const index = x => Number(x.slice(0, 4)) * 12 + Number(x.slice(-2)) - 1;
  const count = index(end) - index(start) + 1;
  if (count < 1 || count > 12) throw Error('Il periodo della bolletta deve comprendere da 1 a 12 mesi.');
  return { start, end, count };
}

export function utilityShares(amountCents, period) {
  if (!Number.isSafeInteger(amountCents) || amountCents <= 0) throw Error('Importo della bolletta non valido.');
  const checked = utilityPeriod({ competenceStartMonth: period?.start, competenceEndMonth: period?.end });
  if (!checked) throw Error('Periodo della bolletta mancante.');
  const first = Number(checked.start.slice(0, 4)) * 12 + Number(checked.start.slice(-2)) - 1;
  return Array.from({ length: checked.count }, (_, i) => {
    const n = first + i;
    return { month: `${Math.floor(n / 12)}-${String(n % 12 + 1).padStart(2, '0')}`,
      amountCents: Math.floor(amountCents / checked.count) + (i < amountCents % checked.count ? 1 : 0) };
  });
}

export function utilityCompetenceContext(state, movements) {
  const rows = new Map(movements.map(r => [Number(r.source_row), r]));
  const imports = new Map(movements.filter(r => r.import_id).map(r => [r.import_id, r]));
  const bills = new Map();
  // FUNDING-BLOCK-2026-11-21 (build 95): part of a bill may come from savings; only the rest is split
  // over the competence months, where it replaces the estimate.
  // BILL-PAST-MONTHS-2026-11-24: a bill paid from that day never changes past months. The plan pays what it
  // set aside, the savings part stays on savings and the rest is added to the budget months chosen at payment
  // (the payment month by default). The period only feeds the average and Analisi. Older bills keep their shares.
  const ruleFrom = '2026-11-24';
  const setAside = (plan, month) => {
    if (plan.budgetEstimates && plan.budgetEstimates[month] != null) return Math.max(0, Number(plan.budgetEstimates[month]));
    if (plan.legacySchedule) return Math.max(0, Number(plan.legacySchedule[month] ?? 0));
    let rate = plan.amountCents;
    for (const c of plan.rateChanges || []) if (c.fromMonth <= month) rate = c.amountCents;
    return Math.max(0, Number(rate) || 0);
  };
  // What the plan had set aside before this bill (used when the payment did not store it).
  const fundBefore = (entry, entryId) => {
    const plan = state?.plans?.[entry.planId];
    if (!plan || !plan.startMonth) return 0;
    const last = entry.date.slice(0, 7);
    let saved = Number(plan.openingBalanceCents ?? 0);
    for (let n = Number(plan.startMonth.slice(0, 4)) * 12 + Number(plan.startMonth.slice(5, 7)) - 1, end = Number(last.slice(0, 4)) * 12 + Number(last.slice(5, 7)) - 1; n <= end; n++)
      saved += setAside(plan, `${Math.floor(n / 12)}-${String(n % 12 + 1).padStart(2, '0')}`);
    const spent = Object.entries(state.payments || {}).filter(([pid, x]) => x.planId === plan.id && ['posted', 'deleting'].includes(x.status) && pid !== entryId
      && (x.date < entry.date || x.date === entry.date && pid < entryId)).reduce((n, [, x]) => n + x.amountCents, 0);
    return Math.max(0, saved - spent);
  };
  const add = (id, period, savingsCents = 0, entry = null, entryId = null) => {
    if (!period) return;
    const row = rows.get(Number(id));
    if (!row || row.movement_type !== 'Spesa' || row.status !== 'Eseguito' || Number(row.amount) >= 0) return;
    if (!['Trade Republic', 'Revolut'].includes(row.account)) return;
    const total = Math.round(-Number(row.amount) * 100);
    if (bills.has(Number(id))) throw Error('La bolletta ha più periodi attivi: completa prima la riconciliazione.');
    const date = String(row.actual_date).slice(0, 10);
    if (entry && (entry.billRule === 2 || date >= ruleFrom)) {
      const fromPlan = entry.planId ? Math.min(total, entry.coveredCents != null ? Math.max(0, Number(entry.coveredCents)) : fundBefore({ ...entry, date }, entryId)) : 0;
      const fromSavings = Math.min(Math.max(0, Math.round(Number(savingsCents) || 0)), total - fromPlan);
      const rest = total - fromPlan - fromSavings;
      const chosen = Array.isArray(entry.billBudgetMonths) ? [...new Set(entry.billBudgetMonths.map(String))].filter(m => /^20\d\d-(0[1-9]|1[0-2])$/.test(m)).sort() : [];
      const months = chosen.length ? chosen : [date.slice(0, 7)];
      const shares = rest > 0 ? months.map((month, i) => ({ month, amountCents: Math.floor(rest / months.length) + (i < rest % months.length ? 1 : 0) })) : [];
      bills.set(Number(id), { movementId: Number(id), category: row.category, period, shares, addsToBudget: true, fromPlanCents: fromPlan, fromSavingsCents: fromSavings });
      return;
    }
    const fromSavings = Math.min(Math.max(0, Math.round(Number(savingsCents) || 0)), total - 1);
    const shares = utilityShares(total - fromSavings, period);
    bills.set(Number(id), { movementId: Number(id), category: row.category, period, shares });
  };
  const confirmedPendingRow = (entry, requestId) => {
    const row = entry.existingMovementId ? rows.get(Number(entry.existingMovementId)) : imports.get('APP-' + requestId);
    return row && Math.round(-Number(row.amount) * 100) === entry.amountCents
      && String(row.actual_date).slice(0, 10) === entry.date && (!entry.category || row.category === entry.category) ? row.source_row : null;
  };
  for (const [id, payment] of Object.entries(state?.payments || {})) {
    if (['posted', 'deleting'].includes(payment.status)) add(payment.movementId, payment.utilityPeriod, payment.utilitySavingsCents, payment, id);
    else if (payment.status === 'pending') add(confirmedPendingRow(payment, payment.requestId || id), payment.utilityPeriod, payment.utilitySavingsCents, payment, id);
  }
  for (const [id, command] of Object.entries(state?.expenseRoutingCommands || {})) {
    if (command.kind === 'ordinary' && !command.cancelled && command.active !== false)
      add(command.pending ? confirmedPendingRow(command, id) : command.movementId, command.utilityPeriod, command.utilitySavingsCents, command, id);
  }
  return { version: 1, bills: [...bills.values()], profiles: Object.values(state?.plans || {}).filter(isUtilityCostFund) };
}

export function utilityMonthlyCost(context, category, month, fallbackCents, contribution) {
  const bills = (context?.bills || []).filter(b => b.category === category);
  const sum = list => list.flatMap(b => b.shares.filter(s => s.month === month)).reduce((n, s) => n + s.amountCents, 0);
  const older = bills.filter(b => !b.addsToBudget), oldShares = older.flatMap(b => b.shares.filter(s => s.month === month));
  // BILL-PAST-MONTHS-2026-11-24: the part of a new bill not paid by the plan or by savings adds to the chosen months.
  const extra = sum(bills.filter(b => b.addsToBudget));
  if (oldShares.length) return { amountCents: sum(older) + extra, source: 'actual' };
  const profiles = (context?.profiles || []).filter(p => p.category === category && p.status !== 'cancelled'
    && month >= p.startMonth && (!p.stopAfter || month <= p.stopAfter) && (!p.closedMonth || month <= p.closedMonth));
  const estimate = profiles.reduce((n, p) => n + (p.budgetEstimates?.[month] ?? contribution(p, month)), 0);
  if (profiles.length) return { amountCents: estimate + extra, source: extra ? 'actual' : 'estimate' };
  return extra ? { amountCents: extra, source: 'actual' } : { amountCents: fallbackCents, source: 'estimate' };
}

export function hasUtilityBill(context, movementId) {
  return (context?.bills || []).some(b => b.movementId === Number(movementId));
}

export async function readUtilityCompetence(db, movements) {
  const present = await db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='finance_plans_v2_state'").first();
  if (!present) return { version: 1, bills: [], profiles: [] };
  const row = await db.prepare('SELECT document FROM finance_plans_v2_state WHERE id=1').first();
  return utilityCompetenceContext(row ? JSON.parse(row.document) : {}, movements);
}

export function utilityMovementMetadata(row, state) {
  const item = Object.values(state?.expenseRoutingCommands || {}).find(c => c.kind === 'ordinary' && c.active !== false
    && !c.pending && c.movementId === Number(row.source_row) && c.utilityPeriod);
  return item ? { ...row, utilityCompetenceStartMonth: item.utilityPeriod.start, utilityCompetenceEndMonth: item.utilityPeriod.end } : row;
}

// At rollover use the preceding paid month, never an arbitrarily stale salary.
// Missing older income or a gap in the 12-month window retains the configured fallback.
export function salaryReferenceMonth(credited, cutoff) {
  if (credited.has(cutoff)) return cutoff;
  const n = Number(cutoff.slice(0, 4)) * 12 + Number(cutoff.slice(-2)) - 2;
  const previous = `${Math.floor(n / 12)}-${String(n % 12 + 1).padStart(2, '0')}`;
  return credited.has(previous) ? previous : cutoff;
}

export function refreshUtilityEstimate(state, planId, today) {
  const plan = state.plans[planId];
  if (plan?.kind !== 'estimated' || plan.status !== 'active') return;
  const history = Object.values(state.payments).filter(p => p.planId === planId && p.status === 'posted')
    .sort((a, b) => a.date.localeCompare(b.date)).slice(-12);
  if (!history.length) return;
  const count = history.reduce((n, p) => n + p.competenceMonths, 0);
  const amountCents = Math.max(1, Math.round(history.reduce((n, p) => n + p.amountCents, 0) / count));
  // A period correction updates this month's budget estimate. Fund contributions use rateChanges.
  plan.budgetEstimates ??= {};
  plan.budgetEstimates[today.slice(0, 7)] = amountCents;
  const fromMonth = new Date(Date.UTC(Number(today.slice(0, 4)), Number(today.slice(5, 7)), 1)).toISOString().slice(0, 7);
  plan.rateChanges = (plan.rateChanges || []).filter(c => c.fromMonth !== fromMonth);
  plan.rateChanges.push({ fromMonth, amountCents });
  plan.rateChanges.sort((a, b) => a.fromMonth.localeCompare(b.fromMonth));
}
