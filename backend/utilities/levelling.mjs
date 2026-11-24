// LIFEOS_LEVEL_ESTIMATE_95 (BILL-PAST-MONTHS-2026-11-24, replaces UTILITY-LEVELLING-2026-11-24)
// A "Ricorrente stimato" plan is a monthly commitment that follows its bills: after every bill the quota
// becomes the average of the last 12 months (bills over their competence months), from next month.
// No hidden recovery: the excess of a bill is settled when it is paid (savings, this month or next months).
// The current month's quota is aligned with what its budget carries, so the plan counter matches it.
// Self-contained on purpose: it is injected in bundled Workers whose helper names may differ.
export function lifeosLevelEstimate95(state, plan, today) {
  if (!plan || plan.kind !== 'estimated' || plan.status !== 'active') return null;
  const index = m => Number(m.slice(0, 4)) * 12 + Number(m.slice(5, 7)) - 1;
  const key = n => `${Math.floor(n / 12)}-${String(n % 12 + 1).padStart(2, '0')}`;
  const history = Object.values(state.payments || {}).filter(p => p.planId === plan.id && p.status === 'posted')
    .sort((a, b) => String(a.date).localeCompare(String(b.date))).slice(-12);
  if (!history.length) return null;
  const covered = history.reduce((n, p) => n + (p.utilityPeriod?.count ?? p.competenceMonths ?? 1), 0);
  const average = Math.max(1, Math.round(history.reduce((n, p) => n + p.amountCents, 0) / covered));
  const now = index(today.slice(0, 7)), current = key(now), fromMonth = key(now + 1);
  const changes = (plan.rateChanges || []).filter(c => c.fromMonth !== fromMonth && !(c.levelled && c.fromMonth > fromMonth));
  const budgeted = plan.budgetEstimates?.[current];
  if (budgeted != null) {
    let rate = plan.amountCents;
    for (const c of changes) if (c.fromMonth <= current) rate = c.amountCents;
    if (rate !== Number(budgeted)) {
      const kept = changes.filter(c => c.fromMonth !== current);
      changes.length = 0; changes.push(...kept, { fromMonth: current, amountCents: Number(budgeted), levelled: true });
    }
  }
  changes.push({ fromMonth, amountCents: average, levelled: true });
  plan.rateChanges = changes.sort((a, b) => a.fromMonth.localeCompare(b.fromMonth));
  plan.levelling = { averageCents: average, quotaCents: average, fromMonth, day: today };
  return plan.levelling;
}

// Wrappers installed around the live functions (renamed to *Base95 in the Worker).
export function wrapLevelling({ completePaymentBase, completePaymentDeletionBase, refreshUtilityEstimateBase }) {
  return {
    completePayment(state, id, movementId, today) {
      const next = completePaymentBase(state, id, movementId, today), payment = next.payments?.[id];
      if (payment) lifeosLevelEstimate95(next, next.plans[payment.planId], today);
      return next;
    },
    completePaymentDeletion(state, id, today) {
      const next = completePaymentDeletionBase(state, id, today), payment = next.payments?.[id];
      if (payment) lifeosLevelEstimate95(next, next.plans[payment.planId], today);
      return next;
    },
    refreshUtilityEstimate(state, planId, today) {
      refreshUtilityEstimateBase(state, planId, today);
      lifeosLevelEstimate95(state, state.plans?.[planId], today);
    }
  };
}
