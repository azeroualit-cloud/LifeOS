"""FOOD-CATALOG-92: complete micronutrients, piece portions, new USDA generic foods."""
import json, statistics, sys
from new_foods import NEW
F = json.load(open('sr.json'))['foods']
BY = {v['d']: k for k, v in F.items()}
MATCH = json.load(open('existing_match.json'))
PATH = sys.argv[1]
foods = json.load(open(PATH))
KEY = {  # app key -> (usda nutrient id, factor)
 'vitaminC': ('1162', 1), 'zinc': ('1095', 1), 'vitaminA': ('1106', 1), 'vitaminD': ('1114', 1), 'vitaminE': ('1109', 1),
 'vitaminK1': ('1185', 1), 'vitaminK2': ('1183', 1), 'vitaminB1': ('1165', 1), 'vitaminB2': ('1166', 1), 'vitaminB3': ('1167', 1),
 'vitaminB5': ('1170', 1), 'vitaminB6': ('1175', 1), 'folate': ('1190', 1), 'folateMass': ('1177', 1), 'vitaminB12': ('1178', 1),
 'calcium': ('1087', 1), 'chloride': ('1088', 1), 'copper': ('1098', 1), 'iron': ('1089', 1), 'iodine': ('1100', 1),
 'magnesium': ('1090', 1), 'manganese': ('1101', 1), 'phosphorus': ('1091', 1), 'potassium': ('1092', 1), 'selenium': ('1103', 1),
 'sodium': ('1093', 1), 'ala': ('1404', 1000), 'epa': ('1278', 1000), 'dha': ('1272', 1000),
}
REQUIRED = [k for k in KEY if k not in ('folate', 'folateMass')]
PLANT = {'vegetable', 'fruit', 'legume', 'nut', 'grain', 'drink', 'fat', 'pantry'}
PIECES = {
 'Uova': [('uovo', 50)], 'Uova sode': [('uovo', 50)], 'Uovo al tegamino': [('uovo', 46)],
 'Mela': [('mela media', 150)], 'Banana': [('banana media', 120)], 'Pera': [('pera media', 150)], 'Arancia': [('arancia media', 150)],
 'Kiwi': [('kiwi', 75)], 'Pesca': [('pesca media', 150)], 'Limone': [('limone', 60)], 'Avocado': [('avocado', 140)], 'Mango': [('mango', 200)],
 'Fette biscottate': [('fetta', 8)], 'Fette biscottate integrali': [('fetta', 9)], 'Pane bianco': [('fetta', 30)], 'Pane integrale': [('fetta', 30)],
 'Pita': [('pita', 60)], 'Croissant': [('croissant', 50)], 'Biscotti': [('biscotto', 8)], 'Biscotti al burro': [('biscotto', 7)],
 'Yogurt bianco': [('vasetto', 125)], 'Yogurt magro': [('vasetto', 125)], 'Yogurt greco': [('vasetto', 150)],
 'Mozzarella': [('mozzarella', 125)], 'Mozzarella di bufala': [('mozzarella', 125)], 'Burrata': [('burrata', 125)],
 'Formaggio fuso a fette': [('fetta', 20)], 'Muffin al cioccolato': [('muffin', 60)], 'Brownie': [('brownie', 50)],
 'Gelato stecco ricoperto di cioccolato': [('stecco', 70)], 'Gelato cono': [('cono', 75)], 'Gelato cono mini': [('cono mini', 40)],
 'Sorbetto stecco': [('stecco', 60)], 'Gelato barretta al cioccolato': [('barretta', 50)], 'Gelato coppetta': [('coppetta', 60)],
 'Barretta ai cereali e cioccolato': [('barretta', 25)], 'Wafer al cioccolato': [('wafer', 20)],
}
def fmt(x): return round(float(x), 4)
def usda_values(fid, scale=1.0):
    n = F[fid]['n']; out = {}
    for key, (nid, factor) in KEY.items():
        if nid in n: out[key] = fmt(n[nid] * factor * scale)
    return out
stats = {'usda_fields': 0, 'k2_plant': 0, 'chloride_ratio': 0, 'median': 0, 'pieces': 0, 'new': 0}
# 1) existing: fill gaps from the matched USDA food, scaled by energy when the preparation differs
for f in foods:
    nv = f.setdefault('nutrientValues', {})
    fid = MATCH.get(f['id'])
    if not fid: continue
    e = F[fid]['n'].get('1008') or 0
    scale = 1.0
    if e and f['calories'] and abs(e - f['calories']) / max(f['calories'], 30) > 0.25:
        scale = max(0.2, min(5.0, f['calories'] / e))
    tag = 'usda-sr:' + fid + ('' if scale == 1.0 else ':energia×%.2f' % scale)
    for k, v in usda_values(fid, scale).items():
        if k in nv: continue
        if k in ('folate',) and 'folateMass' in nv: continue
        if k == 'folateMass' and 'folate' in nv: continue
        nv[k] = {'amount': v, 'estimateSource': tag}; stats['usda_fields'] += 1
    for name, pieces in PIECES.items():
        pass
    if f['name'] in PIECES:
        f['pieces'] = [{'name': n, 'grams': g} for n, g in PIECES[f['name']]]; stats['pieces'] += 1
# 2) new foods from USDA (values as published, not estimates; proxies are marked)
existing_ids = {f['id'] for f in foods}
for slug, name, family, aliases, desc, pieces, proxy in NEW:
    fid = BY[desc]; n = F[fid]['n']
    item = {'id': 'usda-' + slug, 'name': name, 'detail': 'Generic', 'aliases': aliases,
            'calories': fmt(n.get('1008', 0)), 'protein': fmt(n.get('1003', 0)), 'carbohydrate': fmt(n.get('1005', 0)),
            'fat': fmt(n.get('1004', 0)), 'fibre': fmt(n.get('1079', 0)), 'family': family,
            'dataNote': 'USDA FoodData Central SR Legacy ' + fid + (' · ' + proxy if proxy else ''),
            'sourceURL': 'https://fdc.nal.usda.gov/food-details/' + fid + '/nutrients'}
    tag = ('usda-sr:' + fid + ':proxy') if proxy else None
    item['nutrientValues'] = {k: ({'amount': v, 'estimateSource': tag} if tag else {'amount': v}) for k, v in usda_values(fid).items()}
    if 'caffeine' not in item['nutrientValues'] and n.get('1057'): item['nutrientValues']['caffeine'] = {'amount': fmt(n['1057'])}
    if pieces: item['pieces'] = [{'name': p, 'grams': g} for p, g in pieces]
    assert item['id'] not in existing_ids, item['id']
    foods.append(item); stats['new'] += 1
# 3) what USDA does not carry: K2 (MK-4) is animal-only, chloride follows sodium, the rest uses the family median
by_family = {}
for f in foods: by_family.setdefault(f['family'], []).append(f)
def median(family, key):
    vals = [x['nutrientValues'][key]['amount'] for x in by_family[family] if key in x.get('nutrientValues', {}) and not str(x['nutrientValues'][key].get('estimateSource') or '').startswith('stima')]
    if len(vals) < 3:
        vals = [x['nutrientValues'][key]['amount'] for x in foods if key in x.get('nutrientValues', {}) and not str(x['nutrientValues'][key].get('estimateSource') or '').startswith('stima')]
    return statistics.median(vals)
ratios = {}
for fam, items in by_family.items():
    r = [x['nutrientValues']['chloride']['amount'] / x['nutrientValues']['sodium']['amount'] for x in items
         if 'chloride' in x['nutrientValues'] and x['nutrientValues'].get('sodium', {}).get('amount', 0) > 20 and x['nutrientValues']['chloride'].get('estimateSource') is None]
    ratios[fam] = statistics.median(r) if len(r) >= 3 else 1.54
for f in foods:
    nv = f['nutrientValues']
    for k in REQUIRED:
        if k in nv: continue
        if k == 'vitaminK2' and f['family'] in PLANT:
            nv[k] = {'amount': 0.0, 'estimateSource': 'stima:k2-assente-nei-vegetali'}; stats['k2_plant'] += 1
        elif k == 'chloride' and 'sodium' in nv:
            nv[k] = {'amount': fmt(nv['sodium']['amount'] * ratios[f['family']]), 'estimateSource': 'stima:cloruro-da-sodio'}; stats['chloride_ratio'] += 1
        else:
            nv[k] = {'amount': fmt(median(f['family'], k)), 'estimateSource': 'stima:mediana-' + f['family']}; stats['median'] += 1
    if 'folate' not in nv and 'folateMass' not in nv:
        nv['folateMass'] = {'amount': fmt(median(f['family'], 'folateMass')), 'estimateSource': 'stima:mediana-' + f['family']}; stats['median'] += 1
open(PATH, 'w').write('[\n' + ',\n'.join('  ' + json.dumps(f, ensure_ascii=False) for f in foods) + '\n]\n')
print(stats, len(foods))
