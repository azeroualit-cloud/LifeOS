"""SALARY-FROM-MOVEMENTS-97: «Stipendi per competenza» also uses the movements with category Stipendio.

The server built the salary history only from the imported «Cedolini» sheet (it stops in August), so salaries added as
movements never appeared. After the payslips, each month without a payslip gets the Stipendio movements: a salary paid
by the 10th counts for the month before, a later one for its own month. These months carry gross 0 so the payroll
totals that use the payslips' gross do not change. Starts from the live modules of both Workers; anything not found
exactly once: nothing is written. Upload verified with rollback (shared helper). Never logs source.
"""
from pathlib import Path
import importlib.util, posixpath, re

MARKER = '/* LIFEOS_SALARY_MOVEMENTS_97 */'
ANCHOR = 'const payrollGross = salaryHistory.reduce((n, r) => n + r.gross, 0);'
BLOCK = MARKER + r''' (() => {
    const have = new Set(salaryHistory.map((r) => r.month)), extra = new Map();
    for (const m of movements) {
      if (String(m[5] || "").trim().toLowerCase() !== "stipendio" || !(Number(m[3]) > 0)) continue;
      const day = String(dateIso_(m[1]) || "");
      if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) continue;
      let month = day.slice(0, 7);
      if (Number(day.slice(8, 10)) <= 10) month = new Date(Date.UTC(Number(day.slice(0, 4)), Number(day.slice(5, 7)) - 2, 1)).toISOString().slice(0, 7);
      if (have.has(month) || month > today) continue;
      extra.set(month, (extra.get(month) || 0) + Number(m[3]));
    }
    for (const [month, amount] of extra) salaryHistory.push({ month, base: Math.round(amount * 100) / 100, additional: 0, gross: 0, source: "movement" });
    salaryHistory.sort((a, b) => a.month.localeCompare(b.month));
  })();
  '''


def transform(source):
    if MARKER in source:
        print('SALARY_MOVEMENTS_CHECK already=1')
        return source
    counts = {'anchor': source.count(ANCHOR), 'movements': source.count('const movements = sheet.getRange('), 'dateIso': source.count('function dateIso_(')}
    print('SALARY_MOVEMENTS_CHECK ' + ' '.join('%s=%d' % kv for kv in counts.items()))
    if any(v != 1 for v in counts.values()):
        raise RuntimeError('Modulo degli stipendi non riconosciuto; nessuna scrittura.')
    return source.replace(ANCHOR, BLOCK + ANCHOR, 1)


def salary_module(entry, parts):
    """The module holding the salary code that the entry actually imports (closest one); stale copies are ignored."""
    sources = {name: data.decode('utf-8', 'ignore') for name, kind, data in parts if 'source-map' not in kind and not name.endswith('.map')}
    distances, queue = {entry: 0}, [entry]
    while queue:
        name = queue.pop(0)
        for target in re.findall(r'''(?:from\s*|import\s*)['"]([^'"]+)['"]''', sources.get(name, '')):
            resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), target)) if target.startswith('.') else target
            if resolved in sources and resolved not in distances:
                distances[resolved] = distances[name] + 1; queue.append(resolved)
    holders = [name for name in distances if ANCHOR in sources.get(name, '') or MARKER in sources.get(name, '')]
    print('SALARY_MOVEMENTS_MODULES all=%d reachable=%d' % (sum(ANCHOR in d or MARKER in d for d in sources.values()), len(holders)))
    if holders:
        closest = min(distances[name] for name in holders)
        holders = [name for name in holders if distances[name] == closest]
    if len(holders) != 1:
        raise RuntimeError('Modulo degli stipendi non univoco (%d); nessuna scrittura.' % len(holders))
    return holders[0]


if __name__ == '__main__':
    spec = importlib.util.spec_from_file_location('deployment', Path(__file__).with_name('deploy-unified-activities.py'))
    deployment = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(deployment)
    deployment.transform = transform
    deployment.active_module = salary_module
    try:
        deployment.main(label='SALARY_MOVEMENTS_97_DEPLOYED_AND_VERIFIED')
    except Exception as error:
        print('::error title=Stipendi dai movimenti::' + type(error).__name__ + ': ' + str(error)[:300])
        raise SystemExit(1)
