"""FOOD-DB-RESET-2026-11-25: curated food base with variants, built from the generic catalog.

Output native-next/Resources/base-foods.json (app format). Foods with several versions share
`group` and carry `variant` (axis -> value): Stato (crudo, cotto, al forno...), Pelle. Bone
weighing stays `boneInEdiblePercent`. Ids are stable: "base-" + generic id.
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'native-next/Resources/generic-foods.json'
OUT = ROOT / 'native-next/Resources/base-foods.json'

# Not in the base: niche cuts, near-duplicate snacks/sweets/drinks, cheeses rarely eaten here.
DROP = {
    'Durelli di pollo', 'Petto d\'anatra', 'Rene di manzo crudo', 'Rene di manzo cotto', 'Cuore di manzo', 'Rognone di vitello',
    'Pita', 'Bagel', 'Biscotti al burro', 'Tortilla di frumento',
    'Confettura di ciliegie', 'Confettura di pesche', 'Confettura di fichi', 'Confettura di prugne', 'Confettura di lamponi', 'Confettura di mirtilli',
    'Confettura di fragole a ridotto contenuto di zuccheri', 'Confettura di albicocche',
    'Patatine rustiche', 'Patatine light', 'Patatine senza sale', 'Tortilla chips aromatizzate', 'Snack di patate', 'Salatini e pretzel',
    'Snack alle arachidi', 'Snack soffiati', 'Snack al formaggio', 'Gelatina alimentare in polvere', 'Sciroppo d\'acero',
    'Cola senza caffeina', 'Cola zero senza caffeina', 'Limonata zero', 'Tè freddo zero', 'Acqua tonica', 'Acqua tonica zero',
    'Acqua aromatizzata senza zucchero', 'Bevanda energetica zero', 'Succo di pompelmo', 'Succo di uva', 'Succo di pomodoro', 'Nettare di frutta light',
    'Gelatine di frutta', 'Caramelle gommose', 'Caramelle dure', 'Caramelle morbide', 'Caramelle senza zucchero', 'Gelatina al latte',
    'Budino al caramello', 'Budino al caffè', 'Crema al caramello', 'Gelato cono', 'Gelato stecco ricoperto di cioccolato', 'Gelato barretta al cioccolato',
    'Gelato in vaschetta', 'Gelato coppetta', 'Gelato cono mini', 'Sorbetto stecco', 'Cereali ripieni al cioccolato', 'Wafer al cioccolato',
    'Roquefort', 'Comté', 'Reblochon', 'Camembert', 'Cheddar', 'Gouda', 'Formaggio spalmabile alle erbe',
    'Olio di mais', 'Olio di arachidi', 'Burro leggero', 'Burro spalmabile', 'Noci pecan', 'Cocco disidratato',
    'Datteri Deglet Nour', 'Spaghetti cotti', 'Lenticchie cotte', 'Tonno fresco',
}

STATES = [  # (pattern, label) checked on name, then on detail
    (r'\bal forno\b', 'Al forno'), (r'\balla piastra\b', 'Alla piastra'), (r'\bal vapore\b', 'Al vapore'), (r'\bal tegamino\b', 'Al tegamino'),
    (r'\bsode\b', 'Sode'), (r'\bless[aeiotu]+\b|\blessat[aeio]\b|\bbollit[aeio]\b', 'Lesso'),
    (r'\bsecc[aheio]+\b', 'Secco'), (r'\bcott[aeio]\b', 'Cotto'), (r'\bcrud[aeio]\b', 'Crudo'),
]
STATE_ORDER = ['Crudo', 'Fresco', 'Cotto', 'Lesso', 'Al vapore', 'Alla piastra', 'Al forno', 'Al tegamino', 'Sode', 'Secco']
SKIN = [(r'\bsenza pelle\b', 'Senza pelle'), (r'\bcon pelle\b', 'Con pelle')]

def clean(text, patterns):
    for p, _ in patterns:
        text = re.sub(p, '', text, flags=re.I)
    return re.sub(r'\s{2,}', ' ', text).strip(' ,')

def first(patterns, *texts):
    # The most specific state wins wherever it appears («cotto» in the name, «alla piastra» in the detail).
    for p, label in patterns:
        for t in texts:
            if t and re.search(p, t, re.I): return label
    return None

def main():
    items = json.loads(SRC.read_text(encoding='utf-8'))
    out, groups = [], {}
    for f in items:
        if f['name'] in DROP or f['family'] == 'supplement': continue
        detail = f.get('detail') or ''
        detail_clean = '' if detail.startswith('Generic') else detail
        state = first(STATES, f['name'], detail_clean)
        skin = first(SKIN, f['name'], detail_clean)
        base = clean(clean(f['name'], SKIN), STATES)
        food = dict(f)
        food['id'] = 'base-' + f['id']
        food['origin'] = 'base'
        if detail.startswith('Generic'):
            food['detail'] = 'Valori stimati' if 'stimati' in detail else None
        variant = {}
        if state: variant['Stato'] = state
        if skin: variant['Pelle'] = skin
        food['_base'] = base
        food['_variant'] = variant
        groups.setdefault((base, f['family']), []).append(food)
        out.append(food)
    for (base, _), members in groups.items():
        if len(members) < 2:
            continue
        # A member without an axis the others have gets its natural default (fresh fruit, skinless cut).
        axes = {k for m in members for k in m['_variant']}
        for m in members:
            if 'Stato' in axes and 'Stato' not in m['_variant']:
                m['_variant']['Stato'] = 'Fresco' if m['family'] == 'fruit' else 'Crudo'
            if 'Pelle' in axes and 'Pelle' not in m['_variant']:
                m['_variant']['Pelle'] = 'Senza pelle'
        # Same key twice (e.g. two «Cotto»): keep the first, the other stays a separate food.
        seen = set()
        for m in members:
            key = json.dumps(m['_variant'], sort_keys=True)
            if not m['_variant'] or key in seen: continue
            seen.add(key)
            m['group'] = base
            m['variant'] = m['_variant']
    # FOOD-VARIANT-DEFAULT-2026-11-25: raw first, cooked second, then the other preparations.
    rank = {v: i for i, v in enumerate(STATE_ORDER)}
    ordered, done = [], set()
    for m in out:
        g = m.get('group')
        if not g: ordered.append(m); continue
        key = (g, m['family'])
        if key in done: continue
        done.add(key)
        members = [x for x in out if x.get('group') == g and x['family'] == m['family']]
        members.sort(key=lambda x: (rank.get(x['variant'].get('Stato'), 50), 0 if x['variant'].get('Pelle') != 'Con pelle' else 1))
        ordered.extend(members)
    out = ordered
    for m in out:
        m.pop('_base'); m.pop('_variant')
        if m.get('detail') is None: m.pop('detail', None)
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    grouped = {}
    for m in out:
        if m.get('group'): grouped.setdefault(m['group'], []).append(m['variant'])
    print('BASE_FOODS', len(out), 'groups', len(grouped))
    return grouped

if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    g = main()
    if '--show' in sys.argv:
        for k, v in g.items(): print(k, v)
