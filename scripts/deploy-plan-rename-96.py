"""Plan rename (RENAME-EVERYWHERE-2026-11-26): `renameFinancePlan(planId, name)` on both Workers.

Plans live in one JSON document (finance_plans_v2_state). The method changes the name with the same
optimistic revision check the plan service uses, refuses a name already used by another open plan, and for
plans adopted from the old recurring list keeps the original name in `legacy.name`: three places match those
plans to their old rows by name, so they are switched to `legacy.name || name` (otherwise the old row would
come back as a duplicate in the budget). Every fragment must appear exactly once in each module patched;
anything else: nothing is written. Upload verified with rollback (shared helper). Never logs source.
"""
from pathlib import Path
import importlib.util, re

MARKER = '// LIFEOS_PLAN_RENAME_96'
ROUTE = 'if (method === "renameFinancePlan") return response(await renameFinancePlan(env, args[0], args[1]));'
# The app Worker has no Bloom route in the plans module: the route goes right before the general write dispatch.
DISPATCH = re.compile(r'(?:const|let|var)\s+result\s*=\s*await writeAction\(env, method, args\);')
ANCHOR = 'async function ensureFinanceCategories(env) {'
MATCHES = (
    ('p.legacy?.type === "recurring" && view.month >= p.legacy.fromMonth).map((p) => p.name)',
     'p.legacy?.type === "recurring" && view.month >= p.legacy.fromMonth).map((p) => p.legacy.name || p.name)'),
    ('currentView.plans.filter((p) => p.legacy?.type === "recurring").map((p) => p.name)',
     'currentView.plans.filter((p) => p.legacy?.type === "recurring").map((p) => p.legacy.name || p.name)'),
    ('p.legacy?.type === "recurring" && p.name === args[0]',
     'p.legacy?.type === "recurring" && (p.legacy.name || p.name) === args[0]'),
)
BLOCK = MARKER + r'''
async function renameFinancePlan(env, planId, name) {
  planId = String(planId || "").trim();
  name = String(name || "").trim().replace(/\s+/g, " ");
  if (!planId || !name || name.length > 120) throw Error("Nome non valido.");
  for (let attempt = 0; attempt < 3; attempt++) {
    const row = await env.DB.prepare("SELECT revision,document FROM finance_plans_v2_state WHERE id=1").first();
    if (!row) throw Error("Piani non disponibili.");
    const state = JSON.parse(row.document);
    const plans = Object.values(state.plans || {});
    const plan = plans.find((p) => p && p.id === planId);
    if (!plan) throw Error("Piano non trovato.");
    if (plan.name === name) return { renamed: false, name };
    const lower = name.toLocaleLowerCase("it");
    if (plans.some((p) => p && p.id !== planId && String(p.name || "").trim().toLocaleLowerCase("it") === lower && !["closed", "cancelled", "stopped"].includes(p.status)))
      throw Error("Esiste già un piano con questo nome.");
    if (plan.legacy && plan.legacy.type === "recurring" && !plan.legacy.name) plan.legacy.name = plan.name;
    plan.name = name;
    const saved = await env.DB.prepare("UPDATE finance_plans_v2_state SET revision=revision+1,document=? WHERE id=1 AND revision=?").bind(JSON.stringify(state), row.revision).run();
    if (saved && saved.meta && saved.meta.changes) return { renamed: true, name };
  }
  throw Error("I piani sono cambiati nel frattempo: riprova.");
}
'''


def transform(source):
    if MARKER in source:
        if all(new in source for _, new in MATCHES) and ROUTE.strip() in source:
            print('PLAN_RENAME_CHECK already=1')
            return source
        raise RuntimeError('Rinomina dei piani incompleta; nessuna scrittura.')
    dispatch = list(DISPATCH.finditer(source))
    counts = [len(dispatch), source.count(ANCHOR)] + [source.count(old) for old, _ in MATCHES]
    print('PLAN_RENAME_CHECK dispatch=%d anchor=%d m1=%d m2=%d m3=%d' % tuple(counts))
    if any(c != 1 for c in counts) or 'return response(await' not in source[dispatch[0].start() - 4000:dispatch[0].start()]:
        raise RuntimeError('Modulo dei piani non riconosciuto; nessuna scrittura.')
    at = dispatch[0].start()
    source = source[:at] + ROUTE + '\n      ' + source[at:]
    for old, new in MATCHES:
        source = source.replace(old, new, 1)
    return source.replace(ANCHOR, BLOCK + ANCHOR, 1)


def plan_module(entry, parts):
    def has(data):
        text = data.decode('utf-8', 'ignore')
        return MATCHES[0][0] in text or MATCHES[0][1] in text
    holders = [name for name, kind, data in parts if 'source-map' not in kind and not name.endswith('.map') and has(data)]
    print('PLAN_RENAME_MODULES count=%d' % len(holders))
    if len(holders) != 1:
        raise RuntimeError('Modulo delle rotte non univoco (%d); nessuna scrittura.' % len(holders))
    return holders[0]


if __name__ == '__main__':
    spec = importlib.util.spec_from_file_location('deployment', Path(__file__).with_name('deploy-unified-activities.py'))
    deployment = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(deployment)
    deployment.transform = transform
    deployment.active_module = plan_module
    try:
        deployment.main(label='PLAN_RENAME_96_DEPLOYED_AND_VERIFIED')
    except Exception as error:
        print('::error title=Rinomina piani::' + type(error).__name__ + ': ' + str(error)[:300])
        raise SystemExit(1)
