"""Behavioral tests of conservative OFF screening; no network."""
import csv
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

SPEC=importlib.util.spec_from_file_location('off_import',Path(__file__).with_name('import-off-italy.py'))
MODULE=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(MODULE)

def barcode(n):
    digits=f'800000{n:06d}'
    total=sum(int(d)*(3 if (13-i)%2==0 else 1) for i,d in enumerate(digits))
    return digits+str((10-total%10)%10)

def row(n,name='Biscotto cacao',ingredients='Farina di frumento, zucchero, cacao magro, olio di girasole.'):
    r={'code':barcode(n),'product_name_it':name,'brands':'Barilla','countries_tags':'en:italy','categories_tags':'en:biscuits','ingredients_text_it':ingredients}
    prefix='nutrition.input_sets.packaging.as_sold.100g.'
    r[prefix+'per_quantity']='100';r[prefix+'per_unit']='g'
    for key,value in [('energy-kcal','400'),('proteins','8'),('carbohydrates','60'),('fat','14'),('fiber','4')]:
        r[prefix+'nutrients.'+key+'.value']=value
    return r

class ImportScreeningTests(unittest.TestCase):
    def screen(self,rows,official=None):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);resource=root/'native-next/Resources';resource.mkdir(parents=True)
            (resource/'italian-brands.json').write_text(json.dumps(official or []),encoding='utf-8')
            cache=root/'cache';cache.mkdir()
            fields=sorted({k for r in rows for k in r})
            with (cache/'barilla.tsv').open('w',encoding='utf-8',newline='') as f:
                writer=csv.DictWriter(f,fieldnames=fields,delimiter='\t');writer.writeheader();writer.writerows(rows)
            old=MODULE.ROOT
            try:
                MODULE.ROOT=root
                report=MODULE.build(cache,1000)
                foods=json.loads((resource/'open-food-facts-italy.json').read_text())
                return foods,report
            finally:MODULE.ROOT=old

    def testRejectsAlcoholHiddenInIngredientsOrCategory(self):
        a=row(1,ingredients='Zucchero, farina di frumento, liquore al rum, cacao.')
        b=row(2);b['categories_tags']='en:alcoholic-beverages,en:wines'
        c=row(3);c['ingredients_text_it']='';c['ingredients_text_de']='Weizenmehl, Zucker, Milch, Alkohol, Kakao.'
        extra=[row(i+10,ingredients='Farina, zucchero, '+term+', cacao magro.') for i,term in enumerate(('sangria','sake','schnaps'))]
        foods,report=self.screen([a,b,c]+extra)
        self.assertEqual(foods,[])
        self.assertEqual(report['rejected']['excluded_ingredients_or_category'],6)

    def testRejectsPorkDerivativesGelatinAndUncertainMeat(self):
        bad=['Farina di frumento, zucchero, strutto, cacao.',
             'Farina di frumento, zucchero, gelatina alimentare.',
             'Riso, pollo, verdure e sale, olio di girasole.',
             'Farina di frumento, grassi animali, sale.',
             'Sucre, farine de blé, saindoux, cacao.',
             'Harina de trigo, azúcar, jamón de cerdo.']
        rows=[]
        for i,ingredients in enumerate(bad,1):
            r=row(i,ingredients=ingredients)
            if i==5:r['ingredients_text_fr']=r.pop('ingredients_text_it')
            if i==6:r['ingredients_text_es']=r.pop('ingredients_text_it')
            rows.append(r)
        rows += [row(i+20,ingredients='Flour, sugar, '+term+', cocoa powder.') for i,term in enumerate(('ham','tocino','schinken','schweinefett','manteca de cerdo'))]
        self.assertEqual(self.screen(rows)[0],[])

    def testRejectsNonItalyMissingIngredientsAndIncompleteOrEstimatedNutrition(self):
        a=row(1);a['countries_tags']='en:france'
        b=row(2);b['ingredients_text_it']=''
        c=row(3);del c['nutrition.input_sets.packaging.as_sold.100g.nutrients.proteins.value']
        d=row(4);d['nutrition.input_sets.packaging.as_sold.100g.nutrients.energy-kcal.modifier']='~'
        self.assertEqual(self.screen([a,b,c,d])[0],[])

    def testDeduplicatesSizesRecipesAndOfficialSources(self):
        a=row(1,'Biscotti 200 g')
        b=row(2,'Biscotti 500 g')
        c=row(3,'Confezione famiglia',ingredients=a['ingredients_text_it'])
        d=row(4,'Barilla Spaghetti 500 g',ingredients='Semola di grano duro, acqua.')
        official=[{'brand':'Barilla','name':'Spaghetti','calories':350,'protein':12,'carbohydrate':62,'fat':1.4}]
        foods,report=self.screen([a,b,c,d],official)
        self.assertEqual(len(foods),1)
        self.assertEqual(report['rejected']['official_duplicate'],1)
        self.assertEqual(report['rejected']['duplicate_formulation_or_size'],2)

    def testOfficialFormulationWinsAcrossDifferentLanguageAndName(self):
        a=row(1,'Chocolate biscuits')
        official=[{'brand':'Barilla','name':'Biscotti cacao','calories':400,'protein':8,'carbohydrate':60,'fat':14}]
        foods,report=self.screen([a],official)
        self.assertEqual(foods,[])
        self.assertEqual(report['rejected']['official_duplicate'],1)

    def testSupportedLanguageAndTagBrandFallbackKeepAttribution(self):
        a=row(1);a['product_name_en']=a.pop('product_name_it')
        a['ingredients_text_en']=a.pop('ingredients_text_it')
        a['brands_tags']='xx:Barilla';del a['brands']
        foods,report=self.screen([a])
        self.assertEqual(len(foods),1)
        self.assertEqual(foods[0]['barcode'],a['code'])
        self.assertIn('dati collaborativi',foods[0]['dataNote'])
        self.assertEqual(report['records'][0]['ingredientsLanguage'],'en')

    def testExplicitMlAndBoundsPreservedWithoutDensityInference(self):
        a=row(1,'Bibita');a['categories_tags']='en:beverages'
        b=row(2,'Bibita seconda');b['categories_tags']='en:beverages'
        prefix='nutrition.input_sets.packaging.as_sold.100g.'
        b[prefix+'per_unit']='ml'
        b[prefix+'nutrients.proteins.value']='0.1'
        b[prefix+'nutrients.proteins.modifier']='<'
        foods,report=self.screen([a,b])
        self.assertEqual(len(foods),1)
        self.assertEqual(foods[0]['measurementBasis'],'ml')
        self.assertTrue(foods[0]['estimatedMacroBounds']['protein'].startswith('<'))
        self.assertEqual(report['rejected']['ambiguous_beverage_basis'],1)

if __name__=='__main__':unittest.main()

