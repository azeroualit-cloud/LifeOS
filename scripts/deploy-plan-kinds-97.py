"""PLAN-KINDS-97 and FUNDS-PAY-FROM-SAVINGS-97 on both Workers (DEPLOY-WORKERS-93).

1. A Fondo may have an end month: `saveFinancePlan` keeps `endMonth` for kind «fund» when given.
2. `setFinanceFundEnd(planId, endMonth|null)`: sets, moves or removes the end of an active Fondo. Past months never
   change: the new end is the current month or later, and a Fondo already ended before last month is not reopened.
3. `convertFixedPlansToFunds()`: every active «Spesa ricorrente fissa» becomes a Fondo without end with the same quota
   per month (amount / interval). The months up to the current one keep exactly the old contributions (`pastSchedule`),
   the original kind, amount, interval and rate changes stay in `convertedFrom` (reversible). Recurring payments from
   the site still match the converted plans.
Plans live in one JSON document (finance_plans_v2_state) with an optimistic revision, as for renameFinancePlan.
Every fragment must be found exactly once in the plan module of each Worker; otherwise nothing is written.
Upload verified with rollback (shared helper). Never logs source.
"""
from pathlib import Path
import importlib.util, posixpath, re

MARKER = '// LIFEOS_PLAN_KINDS_97'
RENAME_ROUTE = 'if (method === "renameFinancePlan") return response(await renameFinancePlan(env, args[0], args[1]));'
ROUTES = ('if (method === "setFinanceFundEnd") return response(await setFinanceFundEnd(env, args[0], args[1]));\n      '
          'if (method === "convertFixedPlansToFunds") return response(await convertFixedPlansToFunds(env));\n      ')
NEWPLAN_HEAD = '\nfunction newPlan(input, today, id) {\n'
FINITE_OLD = 'const finite = ["advance", "goal", "recovery"].includes(kind), last = finite ? month(input.endMonth) : null;'
FINITE_NEW = 'const finite = ["advance", "goal", "recovery"].includes(kind), last = finite ? month(input.endMonth) : kind === "fund" && input.endMonth ? month(input.endMonth) : null;'
RANGE_OLD = 'if (finite) months(first, last);'
RANGE_NEW = 'if (last) months(first, last);'
CONTRIBUTION_HEAD = '\nfunction contribution(plan, m) {\n'
SCHEDULE_OLD = 'if (plan.legacySchedule) return Number(plan.legacySchedule[m] ?? 0);'
SCHEDULE_NEW = 'if (plan.pastSchedule && plan.pastSchedule[m] !== void 0) return Number(plan.pastSchedule[m]);\n  ' + SCHEDULE_OLD
MATCH_OLD = 'const candidates = Object.values(state.plans).filter((p) => ["fixed", "estimated"].includes(p.kind) && p.category === category'
MATCH_NEW = 'const candidates = Object.values(state.plans).filter((p) => (["fixed", "estimated"].includes(p.kind) || p.convertedFrom?.kind === "fixed") && p.category === category'
ANCHOR = 'async function renameFinancePlan(env, planId, name) {'
BLOCK = MARKER + r'''
function lifeosRomeMonth97() {
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Rome", year: "numeric", month: "2-digit" }).formatToParts(new Date()).map((p) => [p.type, p.value]));
  return parts.year + "-" + parts.month;
}
function lifeosAddMonth97(m, n) {
  const d = new Date(Date.UTC(Number(m.slice(0, 4)), Number(m.slice(5, 7)) - 1 + n, 1));
  return d.toISOString().slice(0, 7);
}
function lifeosMonths97(first, last) {
  const out = [];
  for (let m = first; m <= last && out.length < 600; m = lifeosAddMonth97(m, 1)) out.push(m);
  return out;
}
function lifeosSplit97(total, count) {
  const base = Math.trunc(total / count), rest = total - base * count;
  return Array.from({ length: count }, (_, i) => base + (i < rest ? 1 : 0));
}
/* The old «fixed» contribution of a month (same formula as the plan service). */
function lifeosFixedContribution97(plan, m) {
  if (m < plan.startMonth || plan.endMonth && m > plan.endMonth || plan.stopAfter && m > plan.stopAfter || plan.closedMonth && m > plan.closedMonth) return 0;
  if (plan.legacySchedule) return Number(plan.legacySchedule[m] ?? 0);
  const interval = Number(plan.intervalMonths || 1), anchor = plan.intervalAnchor ?? plan.startMonth;
  const delta = (Number(m.slice(0, 4)) - Number(anchor.slice(0, 4))) * 12 + Number(m.slice(-2)) - Number(anchor.slice(-2));
  let amount = plan.amountCents;
  for (const rate of plan.rateChanges ?? []) if (rate.fromMonth <= m) amount = rate.amountCents;
  return amount === 0 ? 0 : lifeosSplit97(amount, interval)[(delta % interval + interval) % interval];
}
async function lifeosEditPlans97(env, edit) {
  for (let attempt = 0; attempt < 3; attempt++) {
    const row = await env.DB.prepare("SELECT revision,document FROM finance_plans_v2_state WHERE id=1").first();
    if (!row) throw Error("Piani non disponibili.");
    const state = JSON.parse(row.document);
    const result = edit(state);
    if (!result.changed) return result.value;
    const saved = await env.DB.prepare("UPDATE finance_plans_v2_state SET revision=revision+1,document=? WHERE id=1 AND revision=?").bind(JSON.stringify(state), row.revision).run();
    if (saved && saved.meta && saved.meta.changes) return result.value;
  }
  throw Error("I piani sono cambiati nel frattempo: riprova.");
}
async function setFinanceFundEnd(env, planId, endMonth) {
  planId = String(planId || "").trim();
  const end = endMonth == null || endMonth === "" ? null : String(endMonth);
  if (end !== null && !/^20\d\d-(0[1-9]|1[0-2])$/.test(end)) throw Error("Mese non valido.");
  const current = lifeosRomeMonth97();
  return lifeosEditPlans97(env, (state) => {
    const plan = Object.values(state.plans || {}).find((p) => p && p.id === planId);
    if (!plan) throw Error("Piano non trovato.");
    if (plan.kind !== "fund" || plan.status !== "active") throw Error("Solo un fondo attivo ha una fine modificabile.");
    if (end !== null && (end < current || end < plan.startMonth)) throw Error("La fine può essere il mese corrente o uno futuro: i mesi passati non cambiano.");
    if (plan.endMonth && plan.endMonth < lifeosAddMonth97(current, -1)) throw Error("Il fondo è già concluso: i mesi passati non cambiano.");
    if ((plan.endMonth || null) === end) return { changed: false, value: { saved: false, endMonth: end } };
    plan.endMonth = end;
    return { changed: true, value: { saved: true, endMonth: end } };
  });
}
async function convertFixedPlansToFunds(env) {
  const current = lifeosRomeMonth97();
  return lifeosEditPlans97(env, (state) => {
    let converted = 0;
    for (const plan of Object.values(state.plans || {})) {
      if (!plan || plan.kind !== "fixed" || plan.status !== "active" || plan.convertedFrom) continue;
      const interval = Math.max(1, Number(plan.intervalMonths || 1));
      const past = {};
      if (plan.startMonth <= current) for (const m of lifeosMonths97(plan.startMonth, current)) past[m] = lifeosFixedContribution97(plan, m);
      plan.convertedFrom = { kind: "fixed", month: current, amountCents: plan.amountCents, intervalMonths: interval,
        intervalAnchor: plan.intervalAnchor ?? null, rateChanges: structuredClone(plan.rateChanges ?? []) };
      plan.pastSchedule = { ...(plan.pastSchedule || {}), ...past };
      if (!plan.legacySchedule) {
        plan.amountCents = Math.round(plan.amountCents / interval);
        plan.rateChanges = (plan.rateChanges ?? []).map((c) => ({ ...c, amountCents: Math.round(c.amountCents / interval) }));
      }
      plan.intervalMonths = 1;
      plan.kind = "fund";
      converted++;
    }
    return { changed: converted > 0, value: { converted } };
  });
}
'''


def transform(source):
    if MARKER in source:
        if all(x in source for x in (FINITE_NEW, RANGE_NEW, 'if (plan.pastSchedule && plan.pastSchedule[m]', MATCH_NEW, 'if (method === "setFinanceFundEnd")')):
            print('PLAN_KINDS_CHECK already=1')
            return source
        raise RuntimeError('Tipi di piano incompleti; nessuna scrittura.')
    route = list(re.finditer(re.escape(RENAME_ROUTE), source))
    counts = {'route': len(route), 'anchor': source.count(ANCHOR), 'newplan': source.count(NEWPLAN_HEAD),
              'finite': source.count(FINITE_OLD), 'contribution': source.count(CONTRIBUTION_HEAD), 'match': source.count(MATCH_OLD)}
    print('PLAN_KINDS_CHECK ' + ' '.join('%s=%d' % kv for kv in counts.items()))
    if any(v != 1 for v in counts.values()):
        raise RuntimeError('Modulo dei piani non riconosciuto; nessuna scrittura.')
    # newPlan: the two lines right after its header (the copy inside the page HTML is left alone).
    head = source.index(NEWPLAN_HEAD)
    finite = source.index(FINITE_OLD, head)
    rng = source.index(RANGE_OLD, finite)
    if finite - head > 1200 or rng - finite > 800:
        raise RuntimeError('newPlan non riconosciuto; nessuna scrittura.')
    source = source[:finite] + FINITE_NEW + source[finite + len(FINITE_OLD):]
    rng = source.index(RANGE_OLD, finite)
    source = source[:rng] + RANGE_NEW + source[rng + len(RANGE_OLD):]
    head = source.index(CONTRIBUTION_HEAD)
    sched = source.index(SCHEDULE_OLD, head)
    if sched - head > 1000:
        raise RuntimeError('contribution non riconosciuta; nessuna scrittura.')
    source = source[:sched] + SCHEDULE_NEW + source[sched + len(SCHEDULE_OLD):]
    source = source.replace(MATCH_OLD, MATCH_NEW, 1)
    at = source.index(RENAME_ROUTE)
    source = source[:at] + ROUTES + source[at:]
    return source.replace(ANCHOR, BLOCK + ANCHOR, 1)


def plan_module(entry, parts):
    """The plan module the entry actually imports (closest one holding the rename route); stale copies are ignored."""
    sources = {name: data.decode('utf-8', 'ignore') for name, kind, data in parts if 'source-map' not in kind and not name.endswith('.map')}
    distances, queue = {entry: 0}, [entry]
    while queue:
        name = queue.pop(0)
        for target in re.findall(r'''(?:from\s*|import\s*)['"]([^'"]+)['"]''', sources.get(name, '')):
            resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), target)) if target.startswith('.') else target
            if resolved in sources and resolved not in distances:
                distances[resolved] = distances[name] + 1; queue.append(resolved)
    holders = [name for name in distances if RENAME_ROUTE in sources.get(name, '')]
    print('PLAN_KINDS_MODULES all=%d reachable=%d' % (sum(RENAME_ROUTE in d for d in sources.values()), len(holders)))
    if holders:
        closest = min(distances[name] for name in holders)
        holders = [name for name in holders if distances[name] == closest]
    if len(holders) != 1:
        raise RuntimeError('Modulo dei piani non univoco (%d); nessuna scrittura.' % len(holders))
    return holders[0]


if __name__ == '__main__':
    spec = importlib.util.spec_from_file_location('deployment', Path(__file__).with_name('deploy-unified-activities.py'))
    deployment = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(deployment)
    deployment.transform = transform
    deployment.active_module = plan_module
    try:
        deployment.main(label='PLAN_KINDS_97_DEPLOYED_AND_VERIFIED')
    except Exception as error:
        print('::error title=Tipi di piano::' + type(error).__name__ + ': ' + str(error)[:300])
        raise SystemExit(1)
