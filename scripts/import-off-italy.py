"""Import a bounded OFF Italy dataset from supported per-brand CSV exports.
Raw exports remain in ignored work cache; only screened factual records ship.
Open Food Facts database derivative: ODbL 1.0, see docs/ITALIAN-BRANDS-2026-11-13.md.
"""
import argparse, collections, csv, hashlib, html, json, math, re, time, unicodedata
import urllib.parse, urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'work'/'off-italy'
BRANDS=['Barilla','Mulino Bianco','Pavesi','Milka','Kinder','Ferrero','Nutella','Oreo','Loacker','Balocco','Granarolo','Parmalat','Galbani','Danone','Muller','Fage','Alpro','Valsoia','De Cecco','Rummo','Garofalo','Riso Scotti','Riso Gallo','Mutti','Valfrutta','Bonduelle','Orogel','Findus','Rio Mare','San Carlo','Pringles','Lay\'s','Pepsi','Coca-Cola','Fanta','Sprite','Santal','Yoga','Estathe','Kellogg\'s','Nestle','Nescafe','Lavazza','Illy','Misura','Cameo','Star','Knorr']
BRANDS += ['Bauli','Doria','Motta','Colussi','Galbusera','Saiwa','Oro Saiwa','Tuc','Ritz','Philadelphia','Sottilette','Buitoni','Gentilini','Tre Marie','Yomo','Activia','Danette','Yakult','Fruttolo','Exquisa','Nesquik','Cornetto','Algida','Magnum','Carte d Or','Zuegg','Hero','Novi','Perugina','Lindt']
AGENT='LifeOSCatalog/1.0 (https://github.com/azeroualit-cloud/LifeOS)'
# Conservative exclusions, not a halal certification. Unknown meat or gelatin is omitted.
FORBIDDEN=re.compile(r'\b(?:suin\w*|maial\w*|porc\w*|pork|strutto|lardo|lard|pancetta|prosciutto|salame|salumi|speck|bacon|salsicc\w*|wurstel|wuerstel|mortadella|chorizo|creatina|creatine|gelatin\w*|collagen\w*|carmine|cocciniglia|e\s*120|alcol\w*|alcool\w*|alcohol\w*|etanol\w*|vino|wine|birra|beer|rum|rhum|brandy|whisk\w*|vodka|liquor\w*|marsala|cognac|grappa|pollo|tacchino|chicken|turkey|manzo|bovin\w*|vitell\w*|beef|carne|meat|anatra|duck|agnello|lamb|coniglio|rabbit)\b',re.I)
FORBIDDEN_EXTRA=re.compile(r'\b(?:ham|tocino|schinken|schweinefett|sangria|sake|schnaps|saindoux|jambon|viande|volaille|poulet|boeuf|bœuf|agneau|vin|biere|bière|schwein\w*|schmalz|fleisch|rind\w*|huhn|huhner\w*|hähnchen|wein|bier|alkohol\w*|cerdo|jamon|jamón|manteca|carne|pollo|cordero|ternera|vino|cerveza|grassi? animali?|animal fats?|tallow|extracto de carne|estratto di carne)\b',re.I)
FORBIDDEN_CATEGORIES=re.compile(r'(alcoholic|beers|wines|spirits|liqueurs|pork|meats|poultr|sausages|hams|gelatin|supplements|pet-food|non-food)',re.I)
NUMBER=re.compile(r'^-?\d+(?:[.,]\d+)?$')
SIZE=re.compile(r'\b(?:\d+(?:[.,]\d+)?\s*[x×]\s*)?\d+(?:[.,]\d+)?\s*(?:kg|g|gr|grammi|ml|cl|litri|l)\b|\b\d+\s*(?:pezzi|pz|biscotti|bottiglie|lattine|porzioni)\b',re.I)

def norm(s):
    return re.sub(r'[^a-z0-9]+',' ',unicodedata.normalize('NFKD',s).encode('ascii','ignore').decode().lower()).strip()

def formulation_name(name, brand):
    words=norm(SIZE.sub('',name)).split()
    brand_words=set(norm(brand).split())
    return ' '.join(w for w in words if w not in brand_words)

def valid_barcode(code):
    if not code.isdigit() or len(code) not in (8,12,13,14): return False
    total=sum(int(v)*(3 if (len(code)-i)%2==0 else 1) for i,v in enumerate(code[:-1]))
    return (10-total%10)%10==int(code[-1])

def export_url(brand):
    return 'https://world.openfoodfacts.org/cgi/search.pl?'+urllib.parse.urlencode({'action':'process','tagtype_0':'countries','tag_contains_0':'contains','tag_0':'italy','tagtype_1':'brands','tag_contains_1':'contains','tag_1':brand,'sort_by':'unique_scans_n','download':'Download','format':'csv'})

def fetch(brands, cache, stop_at=None):
    cache.mkdir(parents=True,exist_ok=True)
    report_file=cache/'download-report.json'
    report=json.loads(report_file.read_text(encoding='utf-8')) if report_file.exists() else []
    for brand in brands:
        file=cache/(norm(brand).replace(' ','-')+'.tsv')
        if file.exists():
            report.append({'brand':brand,'status':'cached','bytes':file.stat().st_size}); continue
        url=export_url(brand)
        start=time.monotonic()
        try:
            with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':AGENT}),timeout=100) as response:
                data=response.read()
                if not data.startswith(b'code\t'): raise ValueError('Expected supported TSV export')
                file.write_bytes(data)
                report.append({'brand':brand,'status':'downloaded','bytes':len(data),'url':url})
                print('EXPORT',brand,len(data),flush=True)
                if stop_at and build(cache,stop_at)['included']>=stop_at:break
        except Exception as error:
            report.append({'brand':brand,'status':'error','error':str(error),'url':url})
            print('EXPORT_ERROR',brand,str(error),flush=True)
            if getattr(error,'code',None) in (401,403,429): break
        # Search endpoints max10/min; exports spaced by at least6.5sec, no parallel requests.
        remaining=6.5-(time.monotonic()-start)
        if remaining>0: time.sleep(remaining)
    (cache/'download-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def nutrition(row):
    for source in ('packaging','manufacturer'):
        for basis in ('100g','100ml'):
            prefix='nutrition.input_sets.'+source+'.as_sold.'+basis+'.'
            if row.get(prefix+'per_quantity')!='100': continue
            unit=row.get(prefix+'per_unit')
            if unit not in ('g','ml'): continue
            values={};bounds={};bad=False
            for field,key in [('calories','energy-kcal'),('protein','proteins'),('carbohydrate','carbohydrates'),('fat','fat'),('fibre','fiber')]:
                val=row.get(prefix+'nutrients.'+key+'.value','')
                modifier=row.get(prefix+'nutrients.'+key+'.modifier','')
                if not val and field=='fibre': continue
                if not NUMBER.fullmatch(val) or modifier not in ('','<','<=','≤'): bad=True;break
                value=float(val.replace(',','.'))
                if not math.isfinite(value) or not 0<=value<=(1000 if field=='calories' else 100):bad=True;break
                values[field]=value
                if modifier:bounds[field]=modifier+val+' / 100 '+unit
            if bad or len(values)<4:continue
            if values['calories']==0 and any(values[k]>0 for k in ('protein','carbohydrate','fat')):continue
            if sum(values.get(k,0) for k in ('protein','carbohydrate','fat','fibre'))>101:continue
            return values,unit,bounds,source
    return None

def family(categories):
    tags=set(categories.split(','))
    if tags.intersection({'en:beverages','en:waters','en:fruit-juices','en:sodas','en:iced-teas','en:energy-drinks','en:plant-milks'}): return 'drink'
    pairs=[('dairy',['milks','yogurts','dairies']),('cheese',['cheeses']),('grain',['pastas','rices','cereals','flours']),('bakery',['breads','crackers','rusks']),('sweet',['biscuits','chocolates','candies','desserts','cakes','sweet-snacks']),('vegetable',['vegetables']),('legume',['legumes']),('fish',['fishes','tunas','salmons','seafoods']),('fruit',['fruits','jams']),('nut',['nuts']),('fat',['oils','butters'])]
    return next((name for name,parts in pairs if any(p in categories for p in parts)),'pantry')

def build(cache, target):
    rejected=collections.Counter(); candidates=[]; all_codes=set(); exported=0
    official=json.loads((ROOT/'native-next/Resources/italian-brands.json').read_text(encoding='utf-8-sig'))
    existing_barcodes=set()
    for existing_name in ('branded-foods','italian-brands','branded-supplements'):
        existing_file=ROOT/('native-next/Resources/'+existing_name+'.json')
        if existing_file.exists(): existing_barcodes.update(x.get('barcode') for x in json.loads(existing_file.read_text(encoding='utf-8-sig')) if x.get('barcode'))
    official_names={(norm(f['brand']),formulation_name(f['name'],f['brand'])) for f in official}
    official_nutrition={(norm(f['brand']),f.get('measurementBasis','g'),tuple(float(f[k]) for k in ('calories','protein','carbohydrate','fat'))) for f in official}
    brands=collections.Counter();seen_formulations=set();manifest=[]
    for file in sorted(cache.glob('*.tsv')):
        with file.open(encoding='utf-8-sig',newline='') as stream:
            for row in csv.DictReader(stream,delimiter='\t'):
                exported+=1
                code=row.get('code','')
                if code in all_codes:rejected['duplicate_barcode']+=1;continue
                all_codes.add(code)
                if code in existing_barcodes:rejected['existing_official_barcode']+=1;continue
                if not valid_barcode(code):rejected['invalid_barcode']+=1;continue
                if 'en:italy' not in row.get('countries_tags','').split(','):rejected['not_italy']+=1;continue
                name=next((html.unescape(row.get('product_name_'+lang,'')).strip() for lang in ('it','en','fr','de','es') if row.get('product_name_'+lang,'').strip()),'')
                ingredient_language=next((lang for lang in ('it','en','fr','de','es') if len(row.get('ingredients_text_'+lang,'').strip())>=15),None)
                ingredients=html.unescape(row.get('ingredients_text_'+ingredient_language,'')).strip() if ingredient_language else ''
                brand_raw=html.unescape(row.get('brands','') or row.get('brands_tags','')).strip()
                tokens={norm(x.replace('xx:','').replace('en:','')) for x in brand_raw.split(',')}
                known=[b for b in BRANDS if norm(b) in tokens]
                brand=max(known,key=len) if known else ''
                category=row.get('categories_tags','')
                if not name or not brand:rejected['missing_supported_name_or_known_brand']+=1;continue
                if len(ingredients)<15:rejected['missing_supported_ingredients']+=1;continue
                if row.get('obsolete')=='on':rejected['obsolete']+=1;continue
                if FORBIDDEN_CATEGORIES.search(category) or (FORBIDDEN.search(name+' '+ingredients) or FORBIDDEN_EXTRA.search(name+' '+ingredients)):
                    rejected['excluded_ingredients_or_category']+=1;continue
                found=nutrition(row)
                if not found:rejected['missing_or_invalid_label_nutrition']+=1;continue
                values,unit,bounds,nsource=found
                # No density inference: beverages need an explicit ml label basis.
                fam=family(category)
                if fam=='drink' and unit!='ml':rejected['ambiguous_beverage_basis']+=1;continue
                clean=SIZE.sub('',name)
                clean=re.sub(r'\s+',' ',clean).strip(' -,.')
                brand_key=norm(brand.split(',')[0])
                key=(brand_key,formulation_name(clean,brand))
                if not key[1]:rejected['empty_normalized_name']+=1;continue
                if key in official_names or (brand_key,unit,tuple(values[k] for k in ('calories','protein','carbohydrate','fat'))) in official_nutrition:
                    rejected['official_duplicate']+=1;continue
                # Dedup independent of package size/name noise: same brand, normalized
                # formulation name OR same ingredient sequence and macro profile.
                recipe=(brand_key,norm(ingredients),unit,tuple(values.get(k) for k in ('calories','protein','carbohydrate','fat','fibre')))
                candidates.append((key,recipe,code,clean,brand,fam,values,unit,bounds,nsource,ingredients,file.name,category,ingredient_language))
    # Stable round-robin across known brands prevents one prolific exporter filling target.
    pools=collections.defaultdict(list)
    for c in candidates:pools[c[4].split(',')[0].strip()].append(c)
    for pool in pools.values():pool.sort(key=lambda c:(norm(c[3]),c[2]))
    result=[];recipes=set()
    while pools and len(result)<target:
        for brand in sorted(list(pools)):
            if len(result)>=target:break
            pool=pools[brand]
            if not pool:del pools[brand];continue
            c=pool.pop(0);key,recipe,code,name,brand,fam,values,unit,bounds,nsource,ingredients,file,category,ingredient_language=c
            if key in seen_formulations or recipe in recipes:rejected['duplicate_formulation_or_size']+=1;continue
            seen_formulations.add(key);recipes.add(recipe)
            f={'id':'off-it-'+code,'name':name,'brand':brand,'family':fam,'sourceURL':'https://world.openfoodfacts.org/product/'+code,'barcode':code,'measurementBasis':unit,**values,'dataNote':'Open Food Facts · dati collaborativi, da verificare sull’etichetta','detail':'Open Food Facts · ODbL 1.0'}
            if bounds:
                f['estimatedMacroBounds']=bounds;f['dataNote']+='; limiti di etichetta conteggiati al limite superiore.'
            result.append(f);brands[brand]+=1
            manifest.append({'id':f['id'],'sourceExport':file,'sourceURL':f['sourceURL'],'nutritionInput':nsource,'ingredientsLanguage':ingredient_language,'ingredientsSHA256':hashlib.sha256(ingredients.encode()).hexdigest(),'normalizedFormulation':list(key),'categories':category})
    output=ROOT/'native-next/Resources/open-food-facts-italy.json'
    output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    report={'retrievedOn':'2026-11-13','target':target,'included':len(result),'exportFiles':len(list(cache.glob('*.tsv'))),'candidateRowsBeforeDedup':len(candidates),'unexaminedCandidatesAfterTarget':sum(len(v) for v in pools.values()),'exportedRows':exported,'uniqueBarcodes':len(all_codes),'rejected':dict(rejected),'brands':dict(brands),'license':'ODbL-1.0','licenseURL':'https://opendatacommons.org/licenses/odbl/1.0/','attribution':'Open Food Facts and contributors','sourceURL':'https://openfoodfacts.org','certifiedHalal':False,'records':manifest}
    (cache/'screening-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('SCREENED',len(result),'rows',exported,'brands',len(brands),'rejected',json.dumps(dict(rejected)),flush=True)
    return report

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('mode',choices=['fetch','build'])
    parser.add_argument('--cache',type=Path,default=CACHE)
    parser.add_argument('--brands',nargs='*',default=BRANDS)
    parser.add_argument('--target',type=int,default=1000)
    parser.add_argument('--stop-at-target',action='store_true')
    args=parser.parse_args()
    if args.mode=='fetch':fetch(args.brands,args.cache,args.target if args.stop_at_target else None)
    else:build(args.cache,args.target)

