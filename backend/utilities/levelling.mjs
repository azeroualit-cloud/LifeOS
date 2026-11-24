// LIFEOS_LEVEL_ESTIMATE_95 (UTILITY-LEVELLING-2026-11-24)
// A "Ricorrente stimato" plan is a monthly commitment: the quota stays in savings and the bills are
// paid from there. After every bill the quota becomes the 12-month average plus the recovery of the
// gap between what the covered months set aside and what their bills cost, spread over the next
// months (at least 3, or the usual length of a bill). Then the quota returns to the average.
// Self-contained on purpose: it is injected in bundled Workers whose helper names may differ.
export function lifeosLevelEstimate95(state, plan, today) {
  if (!plan || plan.kind !== 'estimated' || plan.status !== 'active') return null;
  const index = m => Number(m.slice(0, 4)) * 12 + Number(m.slice(5, 7)) - 1;
  const key = n => `${Math.floor(n / 12)}-${String(n % 12 + 1).padStart(2, '0')}`;
  const posted = Object.values(state.payments || {}).filter(p => p.planId === plan.id && p.status === 'posted')
    .sort((a, b) => String(a.date).localeCompare(String(b.date)));
  const history = posted.slice(-12);
  if (!history.length) return null;
  const covered = history.reduce((n, p) => n + (p.utilityPeriod?.count ?? p.competenceMonths ?? 1), 0);
  const average = Math.max(1, Math.round(history.reduce((n, p) => n + p.amountCents, 0) / covered));
  const start = index(plan.startMonth), now = index(today.slice(0, 7));
  // What the budget carried for a month: the period estimate if one was written, otherwise the quota.
  const setAside = m => {
    const month = key(m);
    if (plan.budgetEstimates && plan.budgetEstimates[month] != null) return Number(plan.budgetEstimates[month]);
    if (plan.legacySchedule) return Number(plan.legacySchedule[month] ?? 0);
    let rate = plan.amountCents;
    for (const c of plan.rateChanges || []) if (c.fromMonth <= month) rate = c.amountCents;
    return rate;
  };
  // Bills are split over their competence months; a bill without a period covers the months before its cycle.
  let billed = 0, last = -1;
  for (const p of posted) {
    const count = p.utilityPeriod?.count ?? p.competenceMonths ?? 1;
    const end = p.utilityPeriod ? index(p.utilityPeriod.end) : index(p.cycleMonth || p.date.slice(0, 7)) - 1;
    for (let i = 0; i < count; i++) {
      const m = end - count + 1 + i;
      if (m < start || m > now) continue;
      billed += Math.floor(p.amountCents / count) + (i < p.amountCents % count ? 1 : 0);
      last = Math.max(last, m);
    }
  }
  let gapCents = 0;
  if (last >= start) {
    let saved = Number(plan.openingBalanceCents ?? 0);
    for (let m = start; m <= last; m++) saved += Math.max(0, setAside(m));
    gapCents = saved - billed;
  }
  const cycle = Math.round(covered / history.length);
  const window = Math.min(12, Math.max(3, cycle));
  const quotaCents = Math.max(0, average + Math.round(-gapCents / window));
  const fromMonth = key(now + 1), untilMonth = key(now + window);
  plan.rateChanges = (plan.rateChanges || []).filter(c => c.fromMonth !== fromMonth && !(c.levelled && c.fromMonth > fromMonth));
  plan.rateChanges.push({ fromMonth, amountCents: quotaCents, levelled: true });
  if (quotaCents !== average) plan.rateChanges.push({ fromMonth: key(now + window + 1), amountCents: average, levelled: true });
  plan.rateChanges.sort((a, b) => a.fromMonth.localeCompare(b.fromMonth));
  plan.levelling = { averageCents: average, gapCents, quotaCents, fromMonth, untilMonth: quotaCents !== average ? untilMonth : null, day: today };
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
