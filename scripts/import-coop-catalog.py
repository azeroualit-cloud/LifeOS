"""Reproducible public Coop label import. No authentication or access-block bypass.

Run inventory, then details; responses are cached after inline images are removed.
Missing/inequality nutritional values are never converted to zero.
"""
import os
import argparse, concurrent.futures, datetime, gzip, hashlib, html, json, pathlib, re, time, urllib.error, urllib.request

ROOT = pathlib.Path(os.environ.get("LIFEOS_COOP_CACHE", pathlib.Path(__file__).resolve().parents[1] / "work" / "coop-catalog"))
BASE = 'https://www.coop.it'
HEADERS = {'User-Agent':'LifeOS-Catalog-Research/1.0', 'Accept-Encoding':'gzip'}
INLINE_IMAGE = re.compile(r'data:image[^"\s>]+', re.I)
TAG = re.compile(r'<[^>]+>')

def plain(value):
    return ' '.join(html.unescape(TAG.sub(' ', value)).split())

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def request(url, data=None):
    headers = dict(HEADERS)
    if data is not None: headers['Content-Type']='application/json'
    req=urllib.request.Request(url, data=None if data is None else json.dumps(data).encode(), headers=headers)
    with urllib.request.urlopen(req, timeout=60) as response:
        raw=response.read()
        if response.headers.get('Content-Encoding')=='gzip': raw=gzip.decompress(raw)
        return raw.decode('utf-8')

def index_page(page):
    cache=ROOT/'index'/f'{page:04}.json'
    if cache.exists(): return json.loads(cache.read_text(encoding='utf-8'))
    data={'query':'*','index':'2','order':'DESC','page':page,'paging':0,'filters':[{'id':'status','type':'EXACT','value':'1'}],'facets':[]}
    response=json.loads(request(BASE+'/api/search?_format=json',data))
    for item in response.get('results',[]): item['render']=INLINE_IMAGE.sub('[IMAGE]',item.get('render',''))
    write(cache,response)
    return response

def inventory():
    first=index_page(0); pages=first['totalPages']; responses={0:first}; errors=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures={pool.submit(index_page,page):page for page in range(1,pages)}
        for n,future in enumerate(concurrent.futures.as_completed(futures),1):
            page=futures[future]
            try: responses[page]=future.result()
            except Exception as error: errors.append({'page':page,'error':str(error)})
            if n%20==0: print('inventory',n+1,'/',pages,'errors',len(errors),flush=True)
    items={}
    for page in sorted(responses):
        for raw in responses[page].get('results',[]):
            render=raw.get('render',''); url=raw.get('url')
            if not url:
                match=re.search(r'href="([^"]+)"',render)
                if match: url=html.unescape(match.group(1))
            if not url: continue
            if url.startswith('/'): url=BASE+url
            title=re.search(r'<h[1-6][^>]*>(.*?)</h[1-6]>',render,re.S)
            # API result IDs are shared across different products; URLs identify cards.
            key=hashlib.sha256(url.encode()).hexdigest()[:20]
            items[url]={'id':key,'sourceResultID':str(raw['id']),'url':url,'name':plain(title.group(1)) if title else plain(render),'inventoryPage':page}
    output={'source':BASE+'/prodotti-coop/catalogo-prodotti','retrievedOn':str(datetime.date.today()),'reportedCount':first['count'],'reportedCountsObserved':sorted(set(r['count'] for r in responses.values())),'reportedPages':pages,'fetchedPages':len(responses),'uniqueProducts':len(items),'errors':errors,'items':list(items.values())}
    write(ROOT/'inventory.json',output)
    print('INVENTORY_COMPLETE',len(items),'expected',first['count'],'errors',len(errors),flush=True)

def field(document,name):
    match=re.search(r'<div[^>]*class="[^"]*field--name-'+re.escape(name)+r'\b[^"]*"[^>]*>(.*?)</div>',document,re.S|re.I)
    return plain(match.group(1)) if match else None

def family(item):
    # Use the immediate category and product slug, not broad mixed departments
    # such as "latticini-e-bevande-vegetali-yogurt-e-uova".
    path='/'.join(item['url'].lower().rstrip('/').split('/')[-2:])
    if '/integratori/' in item['url'].lower(): return 'supplement'
    groups=[('fish',['pesce','ittic','tonno','salmone','frutti-di-mare']),('poultry',['pollame','pollo','tacchino','carni-bianche']),('meat',['carne','carni-','bresaola','scottona','manzo','vitello','bovin']),('dairy',['latte','yogurt','latticini']),('cheese',['formagg']),('bakery',['pane','biscott','forno','cracker']),('grain',['pasta','riso','cereal','farin']),('nut',['frutta-secca','mandorl','pistacch','anacard','arachid','noci']),('fruit',['frutta','marmellat','confettur']),('vegetable',['verdure','ortaggi','sottoli','sottaceti']),('drink',['bevande','succhi','acqua','caffe','infusi','birr','vini']),('sweet',['dolci','gelati','cioccolat','pasticc']),('fat',['olio','burro']),('legume',['legumi']),('egg',['uova']),('meal',['preparati','piatti'])]
    return next((key for key,words in groups if any(word in path for word in words)),'pantry')

def exclude_path(item):
    path=item['url'].lower()
    food=any(word in path for word in ['/alimentari-confezionati/','/alimenti-freschi/','/latte-biscotti-e-pastine/','/omogeneizzati/'])
    return not food or any(word in path for word in ['cura-della-casa','cura-della-persona','gli-animali','alimenti-cani','alimenti-gatti','amici-speciali','tessile','abbigliamento','brico','giardinaggio','giocattoli','pannolini','salviette','accessori-bimbo'])

def number(text):
    # Bound or trace quantities cannot become exact zeros or fabricated values.
    if re.search(r'[<>≤≥]|inferiore|tracce|n\.d',text,re.I): return None
    match=re.search(r'(-?\d+(?:[.,]\d+)?)',text)
    return float(match.group(1).replace(',','.')) if match else None

def valid_barcode(value):
    if not value or not re.fullmatch(r'(?:\d{8}|\d{12}|\d{13}|\d{14})',value): return False
    total=sum(int(char)*(3 if index%2==0 else 1) for index,char in enumerate(value[-2::-1]))
    return (10-total%10)%10==int(value[-1])

def brand_for(url):
    segment=url.split('/il-prodotto-coop/')[-1].split('/')[0]
    names={'coop':'Coop','gli-spesotti':'Gli Spesotti · Coop','spesotti':'Gli Spesotti · Coop','fior-fiore':'Fior Fiore · Coop','vivi-verde':'Vivi Verde · Coop','viviverde':'Vivi Verde · Coop','bene-si':'Bene.sì · Coop','benesi':'Bene.sì · Coop','crescendo':'Crescendo · Coop','solidal':'Solidal · Coop','origine':'Origine · Coop','dosa':"D’Osa · Coop"}
    return names.get(segment,segment.replace('-',' ').title()+' · Coop')

def parse_product(item,document):
    heading=re.search(r'<h1[^>]*>(.*?)</h1>',document,re.S|re.I)
    name=plain(heading.group(1)) if heading else item['name']
    ingredients=field(document,'field-ingredients')
    text=(name+' '+(ingredients or '')).lower()
    vegetarian_name=re.search(r'\b(vegan\w*|vegetal\w*|vegetarian\w*)\b',name,re.I)
    alternative_species = vegetarian_name or (ingredients and re.search(r'pollo|tacchino', name, re.I))
    pork_text=(ingredients or '').lower() if alternative_species else text
    if re.search(r'\b(suin\w*|maial\w*|strutto|lardo|creatina)\b', text):
        return {'status':'excluded','reason':'pork_or_creatine','id':item['id'],'name':name,'sourceURL':item['url']}
    if re.search(r'\b(suin\w*|maial\w*|pancett\w*|prosciutt\w*|speck|salame|salami|salsicc\w*|mortadell\w*|bacon|wurstel|würstel|guanciale|lardo|strutto|creatina)\b',pork_text):
        return {'status':'excluded','reason':'pork_or_creatine','id':item['id'],'name':name,'sourceURL':item['url']}
    meat_category=re.search(r'/carni-|/surgelati-carne/|/salumi-',item['url'],re.I)
    unidentified_ingredient=family(item)!='fish' and re.search(r'\bcarne\b|\bcarni\b',ingredients or '',re.I)
    if (family(item)=='meat' or meat_category or unidentified_ingredient) and not re.search(r'pollo|tacchino|bovin|manzo|vitell|agnell|ovino|capr|coniglio|scottona|bufal|anatra|oca\b|quaglia',text):
        return {'status':'excluded','reason':'unidentified_meat','id':item['id'],'name':name,'sourceURL':item['url']}
    tables=re.findall(r'<table[^>]*class="[^"]*info-table[^"\n]*desktop-only[^"\n]*"[^>]*>(.*?)</table>',document,re.S|re.I)
    nutrition=[t for t in tables if re.search(r'Proteine|Carboidrati|Energia',plain(t),re.I)]
    if not nutrition: return {'status':'missing','reason':'nutrition_table_unavailable','id':item['id'],'name':name,'sourceURL':item['url']}
    table=nutrition[0]; headers=[plain(v) for v in re.findall(r'<th\b[^>]*>(.*?)(?:</th>|(?=<tr))',table,re.S|re.I)]
    basis=' '.join(headers)
    if not re.search(r'100\s*(?:g\b|ml\b)',basis,re.I):
        return {'status':'missing','reason':'unsupported_basis','basis':basis,'id':item['id'],'name':name,'sourceURL':item['url']}
    values={}; raw_values={};bounds={}
    for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>',table,re.S|re.I):
        cells=[plain(v) for v in re.findall(r'<td\b[^>]*>(.*?)</td>',row,re.S|re.I)]
        if len(cells)<2: continue
        label=cells[0].lower(); value=cells[1]; key=None
        if label=='grassi': key='fat'
        elif label=='carboidrati': key='carbohydrate'
        elif label=='proteine': key='protein'
        elif label in ['fibre','fibra']: key='fibre'
        elif (label.startswith('energia') or label.startswith('valore energetico')) and re.search(r'kcal',label+' '+value,re.I): key='calories'
        if key:
            raw_values[key]=value
            if re.search(r'^\s*[<≤]',value):
                values[key]=number(re.sub(r'^\s*[<≤]\s*','',value))
                if values[key] is not None:bounds[key]=value
            else:values[key]=number(value)
    mandatory=['calories','protein','carbohydrate','fat']
    if any(values.get(key) is None for key in mandatory):
        return {'status':'missing','reason':'incomplete_or_bounded_macros','values':values,'rawValues':raw_values,'basis':basis,'id':item['id'],'name':name,'sourceURL':item['url']}
    if any(values[key]<0 for key in mandatory):
        return {'status':'missing','reason':'negative_values','id':item['id'],'name':name,'sourceURL':item['url']}
    brand=brand_for(item['url'])
    barcode=field(document,'field-ean-code')
    result={'id':'coop-'+item['id'],'name':name,'brand':brand,'family':family(item),'sourceURL':item['url'],**{key:values[key] for key in mandatory}}
    if values.get('fibre') is not None: result['fibre']=values['fibre']
    if result['calories']==0 and any(result[key]>0 for key in ['protein','carbohydrate','fat']): result['zeroEnergyLabelVerified']=True
    if valid_barcode(barcode):
        result['barcode']=barcode
        result['id']='coop-ean-'+barcode
    measure='ml' if re.search(r'100\s*ml\b',basis,re.I) else 'g'
    result['labelBasis']=basis;result['labelUnit']=measure;result['measurementBasis']=measure
    result['detail']='Etichetta Coop · '+re.sub(r'^Valori nutrizionali\s*','',basis).strip()
    if bounds:
        result['estimatedMacroBounds']=bounds
        labels={'calories':'energia','protein':'proteine','carbohydrate':'carboidrati','fat':'grassi','fibre':'fibre'}
        result['dataNote']='Etichetta: '+', '.join(labels[key]+' '+value for key,value in bounds.items())+'. Conteggiati al limite superiore dichiarato.'
    return {'status':'importable','product':result,'ingredients':ingredients,'rawValues':raw_values}

def product(item):
    cache=ROOT/'products'/f"{item['id']}.json"
    if cache.exists(): return json.loads(cache.read_text(encoding='utf-8'))
    if exclude_path(item):
        result={'status':'excluded','reason':'nonfood_or_pet','id':item['id'],'name':item['name'],'sourceURL':item['url']}
    else:
        document=INLINE_IMAGE.sub('[IMAGE]',request(item['url']))
        result=parse_product(item,document)
        # Store label-only evidence and no embedded images, account or navigation data.
        if result['status']!='excluded':
            evidence=ROOT/'labels'/f"{item['id']}.html"
            evidence.parent.mkdir(parents=True,exist_ok=True)
            sections=re.findall(r'<table[^>]*class="[^"]*info-table[^"\n]*desktop-only[^"\n]*"[^>]*>.*?</table>',document,re.S|re.I)
            evidence.write_text('\n'.join(sections),encoding='utf-8')
    write(cache,result)
    return result

def details(limit=None):
    inventory=json.loads((ROOT/'inventory.json').read_text(encoding='utf-8'));items=inventory['items']
    if limit:items=items[:limit]
    results=[];errors=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures={pool.submit(product,item):item for item in items}
        for n,future in enumerate(concurrent.futures.as_completed(futures),1):
            item=futures[future]
            try: results.append(future.result())
            except Exception as error:
                # Never retry forbidden or blocked responses through another identity.
                errors.append({'id':item['id'],'url':item['url'],'error':str(error)})
                if isinstance(error,urllib.error.HTTPError) and error.code in (401,403,429):
                    for pending in futures: pending.cancel()
                    print('ACCESS_STOP',error.code,'pending requests cancelled',flush=True)
                    break
            if n%50==0:print('details',n,'/',len(items),'importable',sum(r['status']=='importable' for r in results),'errors',len(errors),flush=True)
    results.sort(key=lambda r:r.get('id',r.get('product',{}).get('id','')))
    products=[];duplicate_conflicts=[];seen={};duplicate_count=0
    for result in results:
        if result['status']!='importable': continue
        food=result['product'];key=food['id']
        if key in seen:
            duplicate_count+=1
            previous=seen[key]
            if any(previous.get(field)!=food.get(field) for field in ['calories','protein','carbohydrate','fat','fibre','measurementBasis']):
                duplicate_conflicts.append({'id':key,'first':previous,'second':food})
        else:seen[key]=food
    conflicts={r['id'] for r in duplicate_conflicts}
    products=[seen[key] for key in sorted(seen) if key not in conflicts]
    write(ROOT/'products-importable.json',products)
    write(ROOT/'coverage.json',{'retrievedOn':str(datetime.date.today()),'source':inventory['source'],'reportedCatalogProducts':inventory['reportedCount'],'inventoryUniqueProducts':inventory['uniqueProducts'],'detailRequested':len(items),'detailProcessed':len(results),'importable':len(products),'gramBasis':sum(p['labelUnit']=='g' for p in products),'millilitreBasis':sum(p['labelUnit']=='ml' for p in products),'duplicateBarcodeRows':duplicate_count,'conflictingBarcodesExcluded':duplicate_conflicts,'excluded':sum(r['status']=='excluded' for r in results),'missing':sum(r['status']=='missing' for r in results),'errors':errors,'notImported':[r for r in results if r['status']!='importable']})
    print('DETAILS_COMPLETE',len(products),'importable,',len(errors),'errors',flush=True)

def finalize():
    """Reparse cached label fragments, recover header variants, retain unknown foods.

    No second network fetch. Runtime ingestion may still be running; coverage
    explicitly reports any unprocessed URLs and such a snapshot is not final.
    """
    inventory=json.loads((ROOT/'inventory.json').read_text(encoding='utf-8'))
    manifest=[];candidates=[]
    for item in inventory['items']:
        cache=ROOT/'products'/f"{item['id']}.json"
        if not cache.exists():
            manifest.append({'sourceURL':item['url'],'status':'not_processed','id':item['id']})
            continue
        cached=json.loads(cache.read_text(encoding='utf-8'))
        if cached['status']=='excluded':
            manifest.append({'sourceURL':item['url'],'status':'excluded','reason':cached['reason'],'id':item['id']})
            continue
        previous=cached.get('product',{})
        name=previous.get('name',cached.get('name',item['name']))
        barcode=previous.get('barcode')
        ingredients=cached.get('ingredients')
        label=ROOT/'labels'/f"{item['id']}.html"
        document='<h1>'+html.escape(name)+'</h1>'
        if ingredients:document+='<div class="field--name-field-ingredients">'+html.escape(ingredients)+'</div>'
        if barcode:document+='<div class="field--name-field-ean-code">'+html.escape(barcode)+'</div>'
        if label.exists():document+=label.read_text(encoding='utf-8')
        parsed=parse_product(item,document)
        if parsed['status']=='excluded':
            manifest.append({'sourceURL':item['url'],'status':'excluded','reason':parsed['reason'],'id':item['id']})
            continue
        if parsed['status']=='importable':
            food=parsed['product'];status='bounded' if food.get('estimatedMacroBounds') else 'label_exact'
        else:
            volume_pack=re.search(r'\b(?:\d+(?:[.,]\d+)?\s*(?:ml|cl|l|litri|litro)|(?:ml|cl|litri|litro)\s*\d+)\b',name,re.I)
            mass_pack=re.search(r'\b\d+(?:[.,]\d+)?\s*(?:g|gr|kg|grammi)\b',name,re.I)
            unit='ml' if volume_pack or (not mass_pack and family(item)=='drink') else 'g'
            food={'id':'coop-'+item['id'],'name':name,'brand':brand_for(item['url']),'family':family(item),'sourceURL':item['url'],'measurementBasis':unit,'calories':0,'protein':0,'carbohydrate':0,'fat':0,'nutritionNotDeclared':True,'dataNote':'Tabella nutrizionale non disponibile nella scheda ufficiale','detail':'Valori nutrizionali non dichiarati'}
            if parsed.get('reason') in ('incomplete_or_bounded_macros','negative_values','unsupported_basis'):
                food['dataNote']='Tabella nutrizionale incompleta o non utilizzabile nella scheda ufficiale'
            if barcode:food['barcode']=barcode;food['id']='coop-ean-'+barcode
            status='nutrition_not_declared'
        candidates.append(food)
        manifest.append({'sourceURL':item['url'],'status':status,'id':food['id'],'name':name,'reason':parsed.get('reason'),'barcode':food.get('barcode')})
    for food in candidates:
        if food['family']=='supplement':
            food.update(supplementUnit='millilitre' if food.get('measurementBasis')=='ml' else 'gram',defaultQuantity=1)
    by_id={};duplicates=[];conflicts=[]
    fields=['calories','protein','carbohydrate','fat','fibre','measurementBasis','nutritionNotDeclared','estimatedMacroBounds']
    for food in candidates:
        key=food['id']
        if key not in by_id:by_id[key]=food;continue
        previous=by_id[key]
        duplicates.append({'id':key,'firstURL':previous['sourceURL'],'secondURL':food['sourceURL']})
        if any(previous.get(field)!=food.get(field) for field in fields):
            conflicts.append({'id':key,'first':previous,'second':food})
            merged=dict(previous)
            for field in ('fibre','estimatedMacroBounds'):merged.pop(field,None)
            merged.update({'calories':0,'protein':0,'carbohydrate':0,'fat':0,'nutritionNotDeclared':True,'dataNote':'Schede ufficiali con valori nutrizionali discordanti per lo stesso codice a barre','detail':'Valori nutrizionali da verificare'})
            by_id[key]=merged
    products=[by_id[key] for key in sorted(by_id)]
    statuses={status:sum(row['status']==status for row in manifest) for status in sorted(set(r['status'] for r in manifest))}
    coverage={'source':inventory['source'],'retrievedOn':str(datetime.date.today()),'reportedCatalogProducts':inventory['reportedCount'],'reportedCountsObserved':inventory.get('reportedCountsObserved'),'inventoryPages':inventory['fetchedPages'],'expectedPages':inventory['reportedPages'],'inventoryUniqueProducts':inventory['uniqueProducts'],'inventoryErrors':inventory['errors'],'perURLStatusCounts':statuses,'catalogEntries':len(products),'entriesNutritionNotDeclared':sum(bool(p.get('nutritionNotDeclared')) for p in products),'entriesBounded':sum(bool(p.get('estimatedMacroBounds')) for p in products),'gramBasis':sum(p.get('measurementBasis')=='g' for p in products),'millilitreBasis':sum(p.get('measurementBasis')=='ml' for p in products),'barcodeDuplicateRows':duplicates,'barcodeConflicts':conflicts,'retrievalComplete':statuses.get('not_processed',0)==0 and not inventory['errors']}
    write(ROOT/'catalog-complete.json',products);write(ROOT/'manifest.json',manifest);write(ROOT/'coverage-complete.json',coverage)
    print(json.dumps({key:value for key,value in coverage.items() if key not in ('barcodeDuplicateRows','barcodeConflicts')},ensure_ascii=False,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['inventory','details','finalize']);parser.add_argument('--limit',type=int);args=parser.parse_args()
    if args.mode=='inventory':inventory()
    elif args.mode=='details':details(args.limit)
    else:finalize()
