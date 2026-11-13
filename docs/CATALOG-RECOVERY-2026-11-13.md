# Diagnosi e recupero catalogo — 13 novembre 2026

Run fallito43440966964, sorgente e16e83c77a7d2477f9550cf37e9428d8f24573f5: compilazione passata,18 unitari (17passati/1fallito),5UI (4passati/1fallito). Non attribuire il fallimento alla compilazione o a un nuovo difetto del prodotto.

Cause osservate:
- NativeCatalogNavigationTests:22: fixture Caffè salvata con codifica errata, query senza accento corretta non poteva corrispondere al testo corrotto. Corretto solo testo fixture UTF8.
- NativePersonalFoodUITests:152: riapertura catalogo riparte correttamente da Tutti; il test cercava la polvere senza selezionare nuovamente Integratori. Corretto il percorso test, nessun cambiamento del contratto del prodotto.

Recupero dei soli2casi: https://github.com/azeroualit-cloud/LifeOS/actions/runs/43446654736 ; sorgente57a23afa7bcb0554f1a2c012eeb5c1199806ae02. Esito acquisito: entrambi i casi passati,1unitario+1UI,zero fallimenti. Riepilogo diagnostico14047859791 verificato. Non ripetere i21casi passati.

Catture del primo run scaricate/ispezionate: navigazione diretta Calendario/Finanza/overflow, nuovo simbolo turni, scheda integratori, Milka/Pepsi e preview widget. Root locale work/audit78/final-2026-11-13/catalog-navigation. Non rappresentano un nuovo import di mille prodotti né prove fisiche.

Nuovo target richiesto: circa1000 formulazioni di marche riconoscibili; non il precedente suggerimento100–200. Escludere dalle nuove importazioni alcol/vino/maiale, mantenendo creatina esclusa. Lo screening conservativo dei dati collaborativi non certifica halal. Richiesta META01 pendente sulla rimozione anche di cocktail/alcolici già approvati nel catalogo esistente; nessuna cancellazione dello storico.

## Nuovo import

1000formulazioni collaborative/39marchi, sorgente20f604a0accaca626a8699aaece37ceb50d9da5d. Verifica mirata https://github.com/azeroualit-cloud/LifeOS/actions/runs/43448734353 avviata senza IPA;2testunitari+1UI selezionati. Esito/catture nuovi da acquisire alla ripresa. Nessuna suite già passata ripetuta.
