import json, re, unicodedata, collections, sys
R = '/home/claude/lifeos/native-next/Resources/'
G = json.load(open(R + 'generic-foods.json'))
STOP = set('di del della dei delle al alla allo ai agli alle con e in per da a il la lo le gli un una gr g kg ml cl l x pz senza gusto intero interi intera integrale integrali nero nera neri bianco bianca rosso rossa sale secco secca secchi zuccheri zucchero mista misto mix ricca ricco gourmet italiano italiana italiani italiane naturale fresco fresca preparato tramezzini base pasta tipo classico classica bio biologico biologica coop fior fiore'.split())
def toks(s):
    s = unicodedata.normalize('NFKD', s.lower()); s = ''.join(c for c in s if not unicodedata.combining(c))
    return [t for t in re.findall(r'[a-z]+', s) if len(t) > 2 and t not in STOP]
def stem(t): return t[:-1] if len(t) > 4 and t[-1] in 'aeio' else t
index = []
for g in G:
    words = collections.Counter()
    for t in toks(g['name']): words[stem(t)] += 3
    for a in g.get('aliases', []):
        for t in toks(a):
            if stem(t) not in words: words[stem(t)] = 1
    index.append((g, words, {stem(t) for t in toks(g['name'])}))
def best(item):
    words = [stem(t) for t in toks(item['name'])]
    if not words: return None
    scored = []
    for g, w, own in index:
        score = sum(w.get(t, 0) * (2 if i == 0 else 1) for i, t in enumerate(words))
        if not score: continue
        if len(own) >= 2 and own <= set(words): score += 4
        # generic's name words the product lacks make it a worse stand-in
        score -= len(own - set(words))
        contained = len(own) >= 2 and own <= set(words)
        if g['family'] != item.get('family') and not contained: continue
        # the product's main noun (first word) must agree, unless the generic name is fully contained
        if not contained and words[0] not in w: continue
        scored.append((score, -len(g['name']), g['id']))
    if not scored: return None
    top = max(scored)
    return top[2] if top[0] >= 3 else None
def family_default(fam):
    # most common generic in that family acts as a neutral profile
    cands = [g for g in G if g['family'] == fam]
    return cands[0]['id'] if cands else None
stats = collections.Counter(); samples = []
for name, ascii_ in (('branded-foods', False), ('open-food-facts-italy', False), ('italian-brands', False)):
    path = R + name + '.json'; data = json.load(open(path))
    for item in data:
        item.pop('nutrientEstimateFrom', None)
        if item.get('nutrientValues') or item.get('nutritionNotDeclared') or item.get('family') == 'supplement': stats['skip'] += 1; continue
        if re.search(r'\b(docg?|igt|vino|vini|birra|spumante|prosecco|liquore|grappa|amaro|rum|gin|vodka|whisky)\b', item['name'].lower()): stats['alcohol'] += 1; continue
        ref = best(item)
        if ref: stats['match'] += 1
        else:
            stats['unmatched'] += 1  # no reliable stand-in: leave undeclared rather than guess
        if ref:
            item['nutrientEstimateFrom'] = ref
            if len(samples) < 400: samples.append((item['name'], next(g['name'] for g in G if g['id'] == ref)))
    open(path, 'w').write(json.dumps(data, indent=2, ensure_ascii=ascii_) + '\n')
print(stats)
import random; random.seed(3)
for s in random.sample(samples, 40): print(s)
