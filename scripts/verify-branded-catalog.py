"""Check provenance, unit bases and complete inventory accounting before shipping."""
import argparse
import json
import math
from pathlib import Path
from urllib.parse import urlparse


def valid_barcode(code):
    if not isinstance(code, str) or not code.isdigit() or len(code) not in (8, 12, 13, 14):
        return False
    total = sum(int(digit) * (3 if (len(code) - index) % 2 == 0 else 1)
                for index, digit in enumerate(code[:-1]))
    return (10 - total % 10) % 10 == int(code[-1])


def verify(products):
    seen = set()
    barcodes = set()
    for food in products:
        key = food['id']
        assert key not in seen, f'Duplicate identity: {key}'
        seen.add(key)
        assert food['name'].strip() and food['brand'].strip(), key
        url = urlparse(food['sourceURL'])
        assert url.scheme == 'https' and url.hostname in ('coop.it', 'www.coop.it'), key
        assert food.get('measurementBasis') in ('g', 'ml'), f'Unspecified quantity basis: {key}'
        if code := food.get('barcode'):
            assert valid_barcode(code), f'Invalid GTIN: {key}'
            assert code not in barcodes, f'Duplicate GTIN: {code}'
            barcodes.add(code)
        for field in ('calories', 'protein', 'carbohydrate', 'fat', 'fibre'):
            value = food.get(field)
            if value is None and field == 'fibre':
                continue
            assert isinstance(value, (int, float)) and math.isfinite(value), (key, field)
            assert 0 <= value <= (1000 if field == 'calories' else 100), (key, field, value)
        if food['calories'] == 0 and any(food[field] for field in ('protein', 'carbohydrate', 'fat')):
            assert food.get('zeroEnergyLabelVerified') is True, f'Unverified zero-energy label: {key}'
        if food.get('nutritionNotDeclared'):
            assert food.get('dataNote'), f'Missing explanation for unknown nutrition: {key}'
            assert all(food[field] == 0 for field in ('calories', 'protein', 'carbohydrate', 'fat')), key
        if bounds := food.get('estimatedMacroBounds'):
            assert food.get('dataNote'), f'Unmarked label bounds: {key}'
            assert all(field in ('calories', 'protein', 'carbohydrate', 'fat', 'fibre')
                       and isinstance(value, str) and value.strip() for field, value in bounds.items()), key


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--catalog', default='native-next/Resources/branded-foods.json')
    parser.add_argument('--coverage')
    parser.add_argument('--require-complete', action='store_true')
    args = parser.parse_args()
    products = json.loads(Path(args.catalog).read_text(encoding='utf-8-sig'))
    verify(products)
    if args.require_complete:
        assert args.coverage, 'Complete inventory evidence is required'
        coverage = json.loads(Path(args.coverage).read_text(encoding='utf-8-sig'))
        assert coverage['retrievalComplete'] is True
        assert coverage['inventoryPages'] == coverage['expectedPages']
        assert coverage['inventoryUniqueProducts'] == coverage['reportedCatalogProducts']
        assert not coverage['inventoryErrors']
        assert coverage['catalogEntries'] == len(products)
        counts = coverage['perURLStatusCounts']
        assert counts.get('not_processed', 0) == 0 and counts.get('error', 0) == 0
        assert sum(counts.values()) == coverage['inventoryUniqueProducts']
    print(f'BRANDED_CATALOG_OK: {len(products)} entries; complete={args.require_complete}')
