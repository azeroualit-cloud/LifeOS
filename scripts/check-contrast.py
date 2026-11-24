#!/usr/bin/env python3
"""Contrast audit of the app's colour tokens (REVIEW-95B point 10, 24/11/2026).

WCAG 2.x: text 4.5:1 (large/bold text 3:1), graphics and icons 3:1.
Token values are copied from NativeDesign.swift and iOS system colours; the script reads
NativeDesign.swift to make sure the copied values are still the ones in the code.
Run: python3 scripts/check-contrast.py   (exit 1 when a text token is under its minimum)
"""
import re
import sys
from pathlib import Path

DESIGN = Path(__file__).resolve().parent.parent / "native-next/Sources/NativeDesign.swift"

def rgb(v):
    if isinstance(v, str):
        v = v.lstrip('#'); return tuple(int(v[i:i + 2], 16) / 255 for i in (0, 2, 4))
    if isinstance(v, (int, float)): return (v, v, v)
    return v

def lum(c):
    def ch(x): return x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(x) for x in rgb(c)); return 0.2126 * r + 0.7152 * g + 0.0722 * b

def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True); return (la + 0.05) / (lb + 0.05)

# Backgrounds (system grouped colours; glass approximated by its usual fill on the canvas).
BG = {
    'light': {'canvas': '#F2F2F7', 'card': '#FFFFFF', 'glass': '#E9E9EE'},
    'dark': {'canvas': '#000000', 'card': '#1C1C1E', 'glass': '#2A2A2D', 'nutrition canvas': 0.09, 'nutrition input': 0.16},
}
# The bar track (tertiary fill) is decoration: the filled part carries the value, so it is not measured.
# token: (light, dark, kind, where) — kind 'text' needs 4.5, 'large' 3.0 (titles ≥ 20 pt bold), 'graphic' 3.0.
TOKENS = {
    'secondary': (0.37, 0.68, 'text', 'testo secondario ovunque'),
    'financeTitle': ((0.09, 0.30, 0.67), (0.66, 0.78, 1.0), 'large', 'titolo Finanza'),
    'nutritionTitle': ((0.08, 0.40, 0.28), (0.55, 0.88, 0.71), 'text', 'titolo Nutrizione, proteine, quantità «avena 63»'),
    'calendarTitle': ((0.45, 0.31, 0.14), (0.95, 0.73, 0.53), 'large', 'titolo Calendario'),
    'healthWeight': ((0.50, 0.20, 0.68), (0.90, 0.45, 0.98), 'text', 'peso'),
    'macroCarbohydrate': ((0.60, 0.33, 0.0), (0.96, 0.63, 0.24), 'text', 'carboidrati'),
    'macroFat': ((0.45, 0.27, 0.70), (0.71, 0.55, 0.92), 'text', 'grassi'),
    'overGoal': ((0.62, 0.29, 0.0), '#FF9F0A', 'text', 'sopra obiettivo'),
    'goalMet': ((0.10, 0.47, 0.22), '#30D158', 'text', 'obiettivo raggiunto'),
    'emptyMark': (0.50, 0.47, 'graphic', 'pallini senza pasti'),
    'estimate': ((0.0, 0.45, 0.56), (0.36, 0.77, 0.88), 'text', 'stime e previsioni'),
    'financialRed': ((0.63, 0.29, 0.28), (0.83, 0.57, 0.56), 'text', 'uscite'),
    'financialGreen': ((0.22, 0.45, 0.33), (0.55, 0.73, 0.63), 'text', 'entrate / disponibile'),
    'warning': ((0.52, 0.28, 0.02), (0.95, 0.68, 0.25), 'text', 'avvisi'),
    'danger': ((0.80, 0.0, 0.07), (1, 0.41, 0.38), 'text', 'Elimina, errori'),
    'calendarAccent': ((0.0, 0.25, 0.87), (0.25, 0.61, 1), 'text', 'link e azioni del Calendario'),
    'healthAccent': ((0.72, 0.33, 0.0), '#FF9F0A', 'large', 'titoli e valori Salute'),
}
# Text drawn on a coloured fill: (fill light, fill dark, text light, text dark).
ON_FILL = {
    'salary tiles 1 (viola)': ('#6d4bbf', '#b9a0f2', '#FFFFFF', 0.07),
    'salary tiles 2 (ambra)': ('#9a5d0c', '#f2b65c', '#FFFFFF', 0.07),
    'salary tiles 3 (corallo)': ('#b03a32', '#f08c82', '#FFFFFF', 0.07),
    'salary tiles 4 (verde)': ('#2b7a4f', '#86d3a6', '#FFFFFF', 0.07),
    'chip selezionato (accent)': ((0.110, 0.110, 0.118), (0.949, 0.949, 0.969), '#FFFFFF', '#000000'),
}

def check_source():
    src = DESIGN.read_text(encoding='utf-8')
    needles = ['0.37', '0.68', 'red: 0.09, green: 0.30, blue: 0.67', 'red: 0.08, green: 0.40, blue: 0.28', 'red: 0.45, green: 0.31, blue: 0.14',
               'red: 0.50, green: 0.20, blue: 0.68', 'red: 0.60, green: 0.33, blue: 0.0', 'red: 0.45, green: 0.27, blue: 0.70', 'red: 0.10, green: 0.47, blue: 0.22',
               '0.47 : 0.50', 'red: 0.63, green: 0.29, blue: 0.28', 'red: 0.22, green: 0.45, blue: 0.33', 'red: 0.52, green: 0.28, blue: 0.02', '0x6d4bbf', 'red: 0.80, green: 0.0, blue: 0.07', 'red: 0.0, green: 0.25, blue: 0.87']
    missing = [n for n in needles if n not in src]
    if missing: print('ATTENZIONE: valori cambiati in NativeDesign.swift, aggiornare lo script:', missing)

def main():
    check_source()
    failures = []
    print(f"{'token':34} {'tema':5} " + '  '.join(f'{k:>16}' for k in ['canvas', 'card', 'glass']) + '  minimo')
    for name, (light, dark, kind, where) in TOKENS.items():
        need = 4.5 if kind == 'text' else 3.0
        for theme, value in (('light', light), ('dark', dark)):
            cells = []
            for bg_name, bg in BG[theme].items():
                r = ratio(value, bg); ok = r >= need
                cells.append(f"{bg_name[:7]} {r:4.1f}{'' if ok else ' ✗'}")
                if not ok: failures.append((name, theme, bg_name, round(r, 2), need, where))
            print(f'{name:34} {theme:5} ' + '  '.join(f'{c:>16}' for c in cells) + f'  {need}')
    print('\nTesto su riempimento colorato (4,5:1):')
    for name, (fl, fd, tl, td) in ON_FILL.items():
        for theme, fill, text in (('light', fl, tl), ('dark', fd, td)):
            r = ratio(fill, text); ok = r >= 4.5
            print(f'  {name:30} {theme:5} {r:4.1f}{"" if ok else " ✗"}')
            if not ok: failures.append((name, theme, 'fill', round(r, 2), 4.5, 'testo sul riquadro'))
    print('\nSotto il minimo:' if failures else '\nTutto sopra il minimo.')
    for f in failures: print('  ', f)
    return 1 if any(f[4] == 4.5 for f in failures) else 0

if __name__ == '__main__':
    sys.exit(main())
