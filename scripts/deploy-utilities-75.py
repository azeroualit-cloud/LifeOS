"""Context-guarded utility competence patch; unrelated live modules stay intact."""
from pathlib import Path
import importlib.util
import hashlib

spec = importlib.util.spec_from_file_location('deployment', Path(__file__).with_name('deploy-unified-activities.py'))
deployment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deployment)

def transform(source):
    payload = Path('backend/utilities/competence.mjs').read_text().replace('export async function ', 'async function ').replace('export function ', 'function ')
    marker = '// LIFEOS_UTILITY_COMPETENCE_75\n' + payload
    if source.endswith(marker):
        return source
    previous_marker = '// LIFEOS_UTILITY_COMPETENCE_75\n'
    if previous_marker in source:
        offset = source.rindex(previous_marker)
        previous_digest = hashlib.sha256(source[offset:].encode()).hexdigest()
        if previous_digest != '6597945ef64933b1ca34ea0bed1049a39dba78d7f7c9f693b9a08f10a9c10cfa':
            raise RuntimeError('Versione competenze differente; nessuna scrittura.')
        return source[:offset] + marker
    def patch(old, new):
        nonlocal source
        if source.count(old) != 1: raise RuntimeError('Contesto competenze non riconosciuto; nessuna scrittura.')
        source = source.replace(old, new, 1)
    a = source.index('// Integrates the existing plan service.')
    b = source.index('\nconst expenseRouting = createExpenseRouting(', a)
    reference = Path('manual/build-70/worker.js').read_text()
    ra = reference.index('// Integrates the existing plan service.')
    rb = reference.index('\nconst expenseRouting = createExpenseRouting(', ra)
    if source[a:b] != reference[ra:rb]: raise RuntimeError('Routing live differente; nessuna scrittura.')
    routing = Path('backend/expense-routing/routing.mjs').read_text().replace('export function createExpenseRouting', 'function createExpenseRouting', 1)
    source = source[:a] + routing + source[b:]
    patch('const expenseRouting = createExpenseRouting({ PlanError, balance, command, completePayment, completePaymentDeletion, fingerprint, requestKey, month, cycleKey });',
          'const expenseRouting = createExpenseRouting({ PlanError, balance, command, completePayment, completePaymentDeletion, fingerprint, requestKey, month, cycleKey, utilityPeriod, refreshUtilityEstimate, isUtilityCostFund });')
    patch('  const amount = cents(input.amountCents), date2 = day(input.date, today), covered = Number(input.competenceMonths ?? 1);', '''  let billPeriod;
  try { billPeriod = utilityPeriod(input); } catch (error) { throw new PlanError(error.message); }
  const amount = cents(input.amountCents), date2 = day(input.date, today), covered = billPeriod?.count ?? Number(input.competenceMonths ?? 1);''')
    patch('if (["fixed", "estimated"].includes(plan.kind) && cycle < plan.startMonth)',
          'if (["fixed", "estimated"].includes(plan.kind) && cycle < plan.startMonth && !(billPeriod && isUtilityCostFund(plan)))')
    patch('const settlement = ["goal", "recovery"].includes(plan.kind) ? "once" : ["fixed", "estimated"].includes(plan.kind) ? cycleKey(plan, cycle) : id;',
          'const settlement = ["goal", "recovery"].includes(plan.kind) ? "once" : isUtilityCostFund(plan) && billPeriod ? id : ["fixed", "estimated"].includes(plan.kind) ? cycleKey(plan, cycle) : id;')
    patch('plans: Object.values(state.plans).map((p) => ({ ...p, outstandingCents:', 'plans: Object.values(state.plans).map((p) => ({ ...p, utilityCostFund: isUtilityCostFund(p), outstandingCents:')
    patch('    competenceMonths: covered,\n    recovery,', '    competenceMonths: covered,\n    utilityPeriod: billPeriod,\n    recovery,')
    patch('var METHODS = { saveFinancePlan: "create", recordFinancePlanPayment: "pay",',
          'var METHODS = { saveFinancePlan: "create", recordFinancePlanPayment: "pay", recordUtilityPlanPayment: "pay",')
    patch('if (!["getExpenseRouting", "getExpenseRequestStatus", "changeExpenseDestination", "cancelExpenseRequest"].includes(method)',
          'if (!["getExpenseRouting", "getExpenseRequestStatus", "changeExpenseDestination", "cancelExpenseRequest", "saveUtilityBill", "changeUtilityBill"].includes(method)')
    patch('      const routingContext = { input: args[0] ?? {}, repository, service, db:env.DB, today, recordTransaction, env };', '''      const routingContext = { input: args[0] ?? {}, repository, service, db:env.DB, today, recordTransaction, env };
      if (["saveUtilityBill", "changeUtilityBill", "recordUtilityPlanPayment"].includes(method)) {
        let period;
        try { period = utilityPeriod(args[0] || {}); } catch (error) { throw new PlanError(error.message); }
        if (args[0]?.utilityCompetenceVersion !== 1 || !period) throw new PlanError("Indica il periodo esplicito della bolletta.");
      }
      if (method === "saveUtilityBill") return json(await expenseRouting.save(routingContext));
      if (method === "changeUtilityBill") return json(await expenseRouting.change(routingContext));''')
    patch('financePlanCompetenceMonths: payment.competenceMonths ?? row.competence_months } : row',
          'financePlanCompetenceMonths: payment.competenceMonths ?? row.competence_months, utilityCompetenceStartMonth: payment.utilityPeriod?.start, utilityCompetenceEndMonth: payment.utilityPeriod?.end } : utilityMovementMetadata(row, state)')
    patch('  const latestMonth = today < key ? today : key;',
          '  const latestMonth = salaryReferenceMonth(creditedSalary, today < key ? today : key);')
    patch('  const plan = await getExtraPlan(env, planYear(year));', '''  const plan = await getExtraPlan(env, planYear(year));
  plan.utilityCompetence = await readUtilityCompetence(env.DB, m.results);''')
    patch('function utilityEstimates(recurring, movements, month2, todayDay, settings = {}) {',
          'function utilityEstimates(recurring, movements, month2, todayDay, settings = {}, competence = null) {')
    # Every caller owns the same context; original amounts and cash dates stay unchanged.
    source = source.replace('todayDay, utilitySettings)', 'todayDay, utilitySettings, extraPlan?.utilityCompetence)')
    patch('    const months2 = history.reduce((n, m) => n + Math.max(1, Number(m[8]) || 1), 0);',
          '    const months2 = history.reduce((n, m) => n + (competence?.bills.find(b => b.movementId === Number(m[19]))?.period.count ?? Math.max(1, Number(m[8]) || 1)), 0);')
    patch('    return { ...r, estimate, estimateSource: history.length ? "Media ultime " + history.length + " bollette" : "Stima manuale", estimateSamples: history.length };', '''    const cost = utilityMonthlyCost(competence, r.name, month2, Math.round(estimate * 100), contribution);
    return { ...r, estimate: cost.amountCents / 100, estimateSource: cost.source === 'actual' ? 'Quota effettiva della bolletta' : history.length ? "Media ultime " + history.length + " bollette" : "Stima manuale", estimateSamples: history.length, competenceSource: cost.source };''')
    patch('  const allocations = (extraPlan?.allocations || []).filter((a) => a.month === month2 && a.status !== "Annullato");', '''  const competence = extraPlan?.utilityCompetence;
  for (const category of new Set([...(competence?.bills || []).map(b => b.category), ...(competence?.profiles || []).map(p => p.category)])) {
    const cost = utilityMonthlyCost(competence, category, month2, Math.round((fixed.get(category) || 0) * 100), contribution);
    fixed.set(category, cost.amountCents / 100);
  }
  const allocations = (extraPlan?.allocations || []).filter((a) => a.month === month2 && a.status !== "Annullato");''')
    patch('    if (reconciliation.covered.has(r)) continue;',
          '    if (reconciliation.covered.has(r) || hasUtilityBill(competence, r[19])) continue;')
    patch('    adjustmentCents: adjustment(state.plans, selectedMonth),',
          '    utilityCompetenceVersion: 1,\n    adjustmentCents: adjustment(Object.fromEntries(Object.entries(state.plans).filter(([, p]) => !isUtilityCostFund(p))), selectedMonth),')
    patch('    monthlySalary: round(salary),', '    utilityCompetenceVersion: competence?.version ?? 0,\n    monthlySalary: round(salary),')
    patch('...[...fixed].filter(([, amount]) => amount !== 0).map(([name, amount]) => ({ name, amount: round(amount) })),', '''...[...fixed].filter(([, amount]) => amount !== 0).map(([name, amount]) => {
        const profile = competence?.profiles.find(p => p.category === name && contribution(p, month2) > 0);
        const isUtilityCost = profile || competence?.bills.some(b => b.category === name);
        return { name, amount: round(amount), ...(isUtilityCost ? { budgetRole: 'utilityCost',
          competenceSource: utilityMonthlyCost(competence, name, month2, Math.round(amount * 100), contribution).source,
          ...(profile ? { planId: profile.id } : {}) } : {}) };
      }),''')
    patch('const adopted = view.plans.filter((p) => p.legacy && view.month >= p.legacy.fromMonth)',
          'const adopted = view.plans.filter((p) => p.legacy && (current || !isUtilityCostFund(p)) && view.month >= p.legacy.fromMonth)')
    patch('...view.plans.filter((p) => p.contributionCents !== 0).map',
          '...view.plans.filter((p) => !isUtilityCostFund(p) && p.contributionCents !== 0).map')
    patch('const names = new Set(view.plans.filter((p) => p.legacy?.type === "recurring" && view.month >= p.legacy.fromMonth)',
          'const names = new Set(view.plans.filter((p) => !isUtilityCostFund(p) && p.legacy?.type === "recurring" && view.month >= p.legacy.fromMonth)')
    return source + '\n' + marker

if __name__ == '__main__':
    deployment.transform = transform
    deployment.main(label='UTILITY_COMPETENCE_75_DEPLOYED_AND_VERIFIED')
