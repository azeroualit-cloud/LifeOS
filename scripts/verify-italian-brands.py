"""Validate the bounded official-Italy brand catalog, without network or credentials."""
import json
import math
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
ALLOWED = {'www.milka.com', 'www.pepsi.it', 'www.mulinobianco.it', 'www.kinder.com', 'www.nutella.com'}

def verify():
    path = ROOT / 'native-next/Resources/italian-brands.json'
    foods = json.loads(path.read_text(encoding='utf-8-sig'))
    identities = set()
    formulations = set()
    existing = set()
    for name in ('generic-foods', 'branded-foods', 'supplements', 'branded-supplements', 'cocktails'):
        existing.update(x['id'] for x in json.loads((path.parent / (name + '.json')).read_text(encoding='utf-8-sig')))
    for food in foods:
        key = food['id']
        assert key.startswith('it-brand-') and key not in identities and key not in existing, key
        identities.add(key)
        formulation = (food['brand'].casefold(), food['name'].casefold())
        assert formulation not in formulations, formulation
        formulations.add(formulation)
        source = urlparse(food['sourceURL'])
        assert source.scheme == 'https' and source.hostname in ALLOWED, key
        assert food['measurementBasis'] in ('g', 'ml'), key
        assert food['family'] in ('sweet', 'drink', 'bakery', 'grain', 'dairy', 'pantry'), key
        assert not any(x in (food['name'] + ' ' + food['brand']).casefold() for x in ('maiale', 'strutto', 'creatina')), key
        for field in ('calories', 'protein', 'carbohydrate', 'fat', 'fibre'):
            value = food.get(field)
            if value is None and field == 'fibre':
                continue
            assert isinstance(value, (int, float)) and math.isfinite(value), (key, field)
            assert 0 <= value <= (1000 if field == 'calories' else 100), (key, field)
        assert food['protein'] + food['carbohydrate'] + food['fat'] + food.get('fibre', 0) <= 101, key
        for field, bound in food.get('estimatedMacroBounds', {}).items():
            assert field in ('protein', 'carbohydrate', 'fat', 'fibre') and bound.startswith('<'), key
            assert food.get('dataNote'), key
    assert {'Milka', 'Pepsi'}.issubset({x['brand'] for x in foods})
    return len(foods), len({x['brand'] for x in foods})

if __name__ == '__main__':
    count, brands = verify()
    print(f'ITALIAN_BRANDS_OK: {count} formulations, {brands} brands')

