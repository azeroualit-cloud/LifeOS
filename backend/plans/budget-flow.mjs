// Presentation in integer cents; the confirmed monthly summary remains authoritative.
export function budgetFlow(summary, plans, month) {
  const cents = value => Math.round(Number(value || 0) * 100);
  const current = plans.filter(p => p.contributionCents !== 0 ||
    (p.status === 'active' && p.startMonth <= month && (!p.endMonth || p.endMonth >= month)));
  const rows = current.map(p => ({name:p.name, planId:p.id, amountCents:p.contributionCents}));
  for (const item of summary.monthlyBudgetBreakdown || []) {
    if (!item.planId && cents(item.amount)) rows.push({name:item.name, amountCents:cents(item.amount)});
  }
  const salaryCents=cents(summary.monthlySalary), spentCents=cents(summary.monthlySpent), remainingCents=cents(summary.monthlyRemaining);
  const difference=salaryCents-spentCents-remainingCents-rows.reduce((n,r)=>n+r.amountCents,0);
  if(difference) rows.push({name:'Altri impegni del mese',amountCents:difference});
  let remaining=salaryCents;
  return {salaryCents,spentCents,remainingCents,rows:rows.map(r=>({...r,remainingCents:remaining-=r.amountCents}))};
}
