"""Add immutable insertion timestamps; preserve live modules, bindings and auth."""
from pathlib import Path
import importlib.util
spec = importlib.util.spec_from_file_location('activities68', Path(__file__).with_name('deploy-unified-activities.py'))
base = importlib.util.module_from_spec(spec); spec.loader.exec_module(base)
payload = Path('backend/movement-order/creation.mjs').read_text().replace('export async function ', 'async function ').replace('export function ', 'function ')
marker = '// LIFEOS_MOVEMENT_CREATION_70\n' + payload

def transform(source):
    if '// LIFEOS_MOVEMENT_CREATION_70' in source:
        if not source.endswith(marker): raise RuntimeError('Versione timestamp diversa; nessuna scrittura.')
        return source
    patches = [
      ('async function ensureTrStatement(env) {', 'async function ensureTrStatement(env) {\n  await ensureMovementCreation(env.DB);'),
      ('async function ensureBudgetPolicies(env) {', 'async function ensureBudgetPolicies(env) {\n  await ensureMovementCreation(env.DB);'),
      ('Math.max(1, sheet.getLastRow() - 1), 23).getValues()', 'Math.max(1, sheet.getLastRow() - 1), 24).getValues()'),
      ('        row: number_(row[19]),\n        date:', '        row: number_(row[19]),\n        created_at: row[23] || null,\n        date:'),
      ('  selectedTransactions.sort((a, b) => b.date.localeCompare(a.date));', '  sortMovementCreation(selectedTransactions);'),
      ('    r.financial_category_id\n  ];', '    r.financial_category_id,\n    r.created_at || null\n  ];'),
    ]
    for old,new in patches:
        if source.count(old) != 1: raise RuntimeError('Contesto inserimento movimenti diverso; nessuna scrittura.')
        source = source.replace(old,new,1)
    return source + '\n' + marker

if __name__ == '__main__':
    base.transform = transform
    base.main()
    print('MOVEMENT_CREATION_70_CONTEXT_AND_DEPLOYMENT_VERIFIED')
