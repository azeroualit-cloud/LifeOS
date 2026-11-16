# Build 91 — piano e stato

Ramo: `codex/build91`, creato da `codex/perf-efficiency-01` (a sua volta da `codex/revision77` al commit `04ad889`, sorgente della build 90 pubblicata). Autorizzazione: IPA-DELIVERY-91-2026-11-16. Nessun compilatore Swift in locale: ogni passo vale solo dopo l'esito della CI.

| Passo | Stato |
| --- | --- |
| Efficienza, primo incremento | Verde in CI (323 e 329 test, run 43887359860 e 43894770211) |
| Efficienza, secondo incremento (`c851a8c`) | Scritto. Run 43899176279 non partito per mancanza di runner macOS; rilanciato come 43904664512, esito da acquisire |
| Barra a cinque voci (NAVIGATION-FIVE) | Scritta su questo ramo, test di navigazione e aree di tocco aggiornati. Non compilata |
| Schermata Finanza (FINANCE-SCREEN-REDESIGN) | Da fare. I test usano `finance-more` e la voce «Nuovo piano» del menu: vanno aggiornati insieme |
| Pagamento dai risparmi, app | Da fare |
| Pagamento dai risparmi, Worker e deploy | Da fare. Tocca denaro reale: test del Worker contro SQLite isolato prima del deploy |
| Bloom, variante B | Da fare. L'estensione Condividi dipende dalla firma Signulous: da verificare |
| Workflow di produzione 91 | Da fare. `lifeos-candidate90.yml` è vincolato a `codex/revision77` e al numero 90 |
| Suite completa, 4 avvii Release, IPA | Dopo tutti i passi sopra, sullo stesso commit |
