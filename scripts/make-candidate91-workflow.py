"""Genera .github/workflows/lifeos-candidate91.yml dal workflow 90 gia presente (solo sostituzioni di versione)."""
from pathlib import Path
pairs = [('candidate90','candidate91'),('package90','package91'),('publish90','publish91'),('archive90','archive91'),
         ('build90','build91'),('BUILD90','BUILD91'),('LifeOS-90','LifeOS-91'),('LifeOS 90','LifeOS 91'),('Build 90','Build 91'),
         ('build 90','build 91'),('candidate 90','candidate 91'),('CANDIDATE90','CANDIDATE91'),('0.10.28','0.10.29'),
         ('==90','==91'),('"build": 90','"build": 91'),('CURRENT_PROJECT_VERSION=90','CURRENT_PROJECT_VERSION=91'),
         ('IPA-DELIVERY-2026-11-13','IPA-DELIVERY-2026-11-20')]
s = Path('.github/workflows/lifeos-candidate90.yml').read_text(encoding='utf-8')
for a, b in pairs: s = s.replace(a, b)
Path('.github/workflows/lifeos-candidate91.yml').write_text(s, encoding='utf-8', newline='\n')
print('creato lifeos-candidate91.yml')
