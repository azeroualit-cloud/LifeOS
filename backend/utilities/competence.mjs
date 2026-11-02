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
  const add = (id, period) => {
    if (!period) return;
    const row = rows.get(Number(id));
    if (!row || row.movement_type !== 'Spesa' || row.status !== 'Eseguito' || Number(row.amount) >= 0) return;
    if (!['Trade Republic', 'Revolut'].includes(row.account)) return;
    const shares = utilityShares(Math.round(-Number(row.amount) * 100), period);
    if (bills.has(Number(id))) throw Error('La bolletta ha più periodi attivi: completa prima la riconciliazione.');
    bills.set(Number(id), { movementId: Number(id), category: row.category, period, shares });
  };
  const confirmedPendingRow = (entry, requestId) => {
    const row = entry.existingMovementId ? rows.get(Number(entry.existingMovementId)) : imports.get('APP-' + requestId);
    return row && Math.round(-Number(row.amount) * 100) === entry.amountCents
      && String(row.actual_date).slice(0, 10) === entry.date && (!entry.category || row.category === entry.category) ? row.source_row : null;
  };
  for (const [id, payment] of Object.entries(state?.payments || {})) {
    if (['posted', 'deleting'].includes(payment.status)) add(payment.movementId, payment.utilityPeriod);
    else if (payment.status === 'pending') add(confirmedPendingRow(payment, payment.requestId || id), payment.utilityPeriod);
  }
  for (const [id, command] of Object.entries(state?.expenseRoutingCommands || {})) {
    if (command.kind === 'ordinary' && !command.cancelled && command.active !== false)
      add(command.pending ? confirmedPendingRow(command, id) : command.movementId, command.utilityPeriod);
  }
  return { version: 1, bills: [...bills.values()], profiles: Object.values(state?.plans || {}).filter(isUtilityCostFund) };
}

export function utilityMonthlyCost(context, category, month, fallbackCents, contribution) {
  const shares = (context?.bills || []).filter(b => b.category === category)
    .flatMap(b => b.shares.filter(s => s.month === month));
  if (shares.length) return { amountCents: shares.reduce((n, s) => n + s.amountCents, 0), source: 'actual' };
  const profiles = (context?.profiles || []).filter(p => p.category === category && p.status !== 'cancelled'
    && month >= p.startMonth && (!p.stopAfter || month <= p.stopAfter) && (!p.closedMonth || month <= p.closedMonth));
  return { amountCents: profiles.length ? profiles.reduce((n, p) => n + contribution(p, month), 0) : fallbackCents, source: 'estimate' };
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
  const fromMonth = new Date(Date.UTC(Number(today.slice(0, 4)), Number(today.slice(5, 7)), 1)).toISOString().slice(0, 7);
  plan.rateChanges = (plan.rateChanges || []).filter(c => c.fromMonth !== fromMonth);
  plan.rateChanges.push({ fromMonth, amountCents });
  plan.rateChanges.sort((a, b) => a.fromMonth.localeCompare(b.fromMonth));
}
