"""Validate shipped OFF derivative and preserve source attribution."""
import importlib.util,json,math
from pathlib import Path
from urllib.parse import urlparse

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('off_import',Path(__file__).with_name('import-off-italy.py'))
MODULE=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(MODULE)

def verify():
    foods=json.loads((ROOT/'native-next/Resources/open-food-facts-italy.json').read_text(encoding='utf-8-sig'))
    ids=set();codes=set();names=set()
    existing_codes=set()
    for source in ('branded-foods','branded-supplements','italian-brands'):
        path=ROOT/('native-next/Resources/'+source+'.json')
        existing_codes.update(f.get('barcode') for f in json.loads(path.read_text(encoding='utf-8-sig')) if f.get('barcode'))
    for f in foods:
        code=f['barcode'];key=f['id']
        assert MODULE.valid_barcode(code) and key=='off-it-'+code, key
        assert key not in ids and code not in codes and code not in existing_codes,key
        ids.add(key);codes.add(code)
        assert f['sourceURL']=='https://world.openfoodfacts.org/product/'+code,key
        assert 'dati collaborativi' in f['dataNote'] and 'etichetta' in f['dataNote'],key
        assert f['detail']=='Open Food Facts · ODbL 1.0',key
        assert f['brand'] in MODULE.BRANDS and f['name'].strip(),key
        assert not MODULE.FORBIDDEN.search(f['name']) and not MODULE.FORBIDDEN_EXTRA.search(f['name']),key
        formulation=(f['brand'],MODULE.formulation_name(f['name'],f['brand']))
        assert formulation not in names,key
        names.add(formulation)
        assert f['measurementBasis'] in ('g','ml'),key
        for field in ('calories','protein','carbohydrate','fat','fibre'):
            value=f.get(field)
            if value is None and field=='fibre':continue
            assert isinstance(value,(int,float)) and math.isfinite(value) and 0<=value<=(1000 if field=='calories' else 100),(key,field)
        assert f['calories']>0 or all(f[k]==0 for k in ('protein','carbohydrate','fat','fibre') if k in f),key
        assert sum(f.get(k,0) for k in ('protein','carbohydrate','fat','fibre'))<=101,key
        for field,value in f.get('estimatedMacroBounds',{}).items():
            assert field in ('calories','protein','carbohydrate','fat','fibre') and value.startswith(('<','≤')),key
    return len(foods),len({f['brand'] for f in foods})

if __name__=='__main__':
    count,brands=verify()
    print(f'OFF_ITALY_OK: {count} formulations, {brands} familiar brands; collaborative source')

