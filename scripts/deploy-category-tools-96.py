"""Site Worker `lifeos`: category usage and bulk move for Admin > Categorie della Finanza (CATEGORY-TOOLS-96).

26/11/2026: «Sposta ... nulla è stato spostato» and the D1 daily limit at 91 %. The site page read 36 whole
months to find the categories in use (about 700,000 D1 rows per search) and moved movements one request at a
time, each followed by a full category reconciliation. Two methods replace that:
  - getFinanceCategoryUsage(): one grouped query (category shown, category stored, type, count, first, last);
  - moveFinanceCategory(from, to): one UPDATE of every movement of the last 3 years shown or stored as `from`,
    marked as a manual category (rules no longer change it), then one reconciliation; returns moved/remaining.
Starts from the live module, adds a marked block once and two routes after the Bloom routes; anything not
found exactly once: nothing is written. Upload verified with rollback (shared helper). Never logs source.
"""
from pathlib import Path
import importlib.util

MARKER = '// LIFEOS_CATEGORY_TOOLS_96'
# Before the category reconciliation, outside the diary block (deploy-site-93 rewrites the span up to getFinanceMeta).
ANCHOR = 'async function ensureFinanceCategories(env) {'
ROUTE_AFTER = 'if (method === "importBloom") return response(await importBloom(env, args[0]));'
ROUTES = ('\n      if (method === "getFinanceCategoryUsage") return response(await getFinanceCategoryUsage(env));'
          '\n      if (method === "moveFinanceCategory") return response(await moveFinanceCategory(env, args[0], args[1]));')
BLOCK = MARKER + r'''
const CATEGORY_TOOLS_WHERE = "FROM movements m LEFT JOIN movement_financial_categories c ON c.movement_source_row=m.source_row WHERE m.actual_date >= date('now','-3 years')";
async function getFinanceCategoryUsage(env) {
  await ensureFinanceCategories(env);
  const { results } = await env.DB.prepare("SELECT COALESCE(c.detail_category,NULLIF(m.category,''),'Altro') shown, COALESCE(m.category,'') raw, COALESCE(m.movement_type,'') type, COUNT(*) n, MIN(m.actual_date) first, MAX(m.actual_date) last " + CATEGORY_TOOLS_WHERE + " GROUP BY 1,2,3").all();
  return { rows: results || [] };
}
async function moveFinanceCategory(env, from, to) {
  from = String(from || "").trim();
  to = String(to || "").trim();
  if (!from || !to || from.length > 80 || to.length > 80 || from === to) throw Error("Categorie non valide.");
  await ensureFinanceCategories(env);
  const match = " AND (COALESCE(c.detail_category,NULLIF(m.category,''),'Altro')=?1 OR COALESCE(m.category,'')=?1)";
  const result = await env.DB.prepare("UPDATE movements SET category=?2,notes=CASE WHEN instr(COALESCE(notes,''),'[Categoria manuale]')>0 THEN notes ELSE COALESCE(notes,'')||' [Categoria manuale]' END WHERE source_row IN (SELECT m.source_row " + CATEGORY_TOOLS_WHERE + match + ")").bind(from, to).run();
  await ensureFinanceCategories(env);
  const left = await env.DB.prepare("SELECT COUNT(*) n " + CATEGORY_TOOLS_WHERE + match).bind(from).first();
  return { moved: Number(result && result.meta && result.meta.changes) || 0, remaining: Number(left && left.n) || 0 };
}
'''


def transform(source):
    if MARKER in source:
        if source.count(MARKER) == 1 and ROUTES.strip() in source:
            print('CATEGORY_TOOLS_CHECK already=1')
            return source
        raise RuntimeError('Strumenti categorie incompleti; nessuna scrittura.')
    counts = {'anchor': source.count(ANCHOR), 'routes': source.count(ROUTE_AFTER)}
    print('CATEGORY_TOOLS_CHECK ' + ' '.join('%s=%d' % kv for kv in counts.items()))
    if any(v != 1 for v in counts.values()):
        raise RuntimeError('Modulo del sito non riconosciuto; nessuna scrittura.')
    source = source.replace(ROUTE_AFTER, ROUTE_AFTER + ROUTES, 1)
    return source.replace(ANCHOR, BLOCK + ANCHOR, 1)


def page_module(entry, parts):
    holders = [name for name, kind, data in parts
               if 'source-map' not in kind and not name.endswith('.map') and ROUTE_AFTER in data.decode('utf-8', 'ignore')]
    print('CATEGORY_TOOLS_MODULES count=%d' % len(holders))
    if len(holders) != 1:
        raise RuntimeError('Modulo delle rotte non univoco (%d); nessuna scrittura.' % len(holders))
    return holders[0]


if __name__ == '__main__':
    spec = importlib.util.spec_from_file_location('deployment', Path(__file__).with_name('deploy-unified-activities.py'))
    deployment = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(deployment)
    deployment.helpers.WORKERS = ['lifeos']  # the site only: the app gateway does not serve this page
    deployment.transform = transform
    deployment.active_module = page_module
    try:
        deployment.main(label='CATEGORY_TOOLS_96_DEPLOYED_AND_VERIFIED')
    except Exception as error:
        print('::error title=Strumenti categorie::' + type(error).__name__ + ': ' + str(error)[:300])
        raise SystemExit(1)
