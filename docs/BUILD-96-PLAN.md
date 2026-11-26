# Build 96 — piano

Voci decise per la 96 (registro: docs/USER-DECISIONS.md). Nessuna IPA senza approvazione esplicita.

1. SALARY-MAP-PLAN-KIND-2026-11-26 — fatto nel codice: «Dove va lo stipendio» nell'app usa la regola del sito per le quote dei piani (`NativeSalaryMap.isMonthlyCommitment`: stima, anticipo, recupero, spesa fissa mensile → Impegni; ripartite su più mesi, obiettivi, fondi → Messo da parte); righe del riepilogo legate a un piano non contate due volte; differenza non spiegata come «Altri impegni del mese». Test: NativeFinance93Tests.testSalaryMapSortsPlansByKindLikeTheSite. Da verificare sull'iPhone con i dati reali.
2. APP-LAG-2026-11-26 — fatto nel codice: sincronizzazione periodica ogni 2 minuti (`App.swift`, ogni 4° tick da 30 s), risposte decodificate fuori dal main thread (`NativeStore.requestOnce`), `refresh` salva e ripubblica solo se attività o finanza cambiano (l'ora del widget avanza comunque ogni ora), Bloom riletta al massimo ogni 5 minuti salvo modifiche locali (`NativeOnlineSync.bloomReadInterval`). Test: NativeStoreTests.testIdenticalRefreshDoesNotRewriteTheArchive, NativeOnlineSyncTests.testBloomIsNotReadAgainBeforeTheIntervalWithoutChanges. Da verificare sull'iPhone.
3. SALUTE-REDESIGN-2026-11-26 — da fare: Salute in un solo verde di Apple Salute nello stile dell'app (schede 21 con l'ombra di `loCardSurface`, `LOCardHeader` verdi, selezione neutra, niente bagliori); scheda calorie simmetrica (arco centrato con il numero dentro, limiti del range ai lati, macro in tre colonne centrate nelle tonalità del verde); `NativeWeightTrendChart` con Swift Charts completo: `AxisMarks` a destra con griglia, mesi, `AreaMark` sfumata, `LineMark` `.catmullRom`, `RuleMark` Oggi con etichetta, ultimo valore evidenziato, previsione nello stesso verde con fascia, `chartXSelection` per leggere i valori, altezza piena; barre delle calorie nello stesso verde; arancio solo come avviso. Mockup https://claude.ai/artifact/XcdUUjRgZQtNwvvgPjmSmz (v5).
4. DASHBOARD-93-2026-11-26 — fatto nel codice: tolte dalla Dashboard le schede Prossimi appuntamenti e Statistiche (LIFE-STATS-2026-11-26: Statistiche solo sul sito); la schermata NativeLifeStatsScreen non ha più ingressi nell'app.
5. SALUTE-SINGLE-ENTRY-2026-11-26 — da fare dopo il mockup https://claude.ai/artifact/QJRYZC7cdtF91T7tHHxu5K: Salute con un solo ingresso per sezione (Statistiche, Micronutrienti, Cronologia, Obiettivi); dentro Statistiche peso e simulazione con le sue impostazioni, TDEE e medie, calorie per giorno. Unito a SALUTE-REDESIGN.
6. RENAME-EVERYWHERE-2026-11-26 — da fare: ✎ Rinomina accanto al nome di piani (serve un metodo nuovo nel server: oggi il nome si sceglie solo alla creazione), spese e movimenti, categorie della Finanza (oggi solo nel sito), attività, routine, raccolte Bloom, alimenti personali, gruppi di integratori.
7. PLAN-DETAIL-RICH-2026-11-26 — da fare dopo il mockup: Dettagli piano con movimenti collegati (getFinancePlanMovements esiste già nel server), storico mese per mese (quota, nel fondo, pagato), grafico del fondo con previsione e prossima scadenza.
8. Finanza più leggera (prima una proposta).
9. Layout della Dashboard dal sito (SITE-LAYOUT-CONFIG-2026-11-25).
10. Analisi del sito più ricca (ANALYSIS-SITE-FREEHAND-2026-11-25).
11. Ricerca alimenti del sito con varianti (mockup non ancora approvato).

Sito e server (senza IPA):
- CATEGORY-TOOLS-96-2026-11-26: Admin > Categorie della Finanza. Audit D1 (lifeos-d1-usage-audit96): il 26/11 4,59 M righe lette su 5 M, quasi tutte tra 01:00 e 02:00 UTC in picchi da 0,5-0,9 M; ogni «Cerca nei movimenti» chiedeva getFinanceData per 36 mesi (ogni mese rilegge tutti i ~2.800 movimenti più volte) e «Sposta» faceva una classifyMovement per movimento, ciascuna seguita da una riconciliazione completa. Ora due metodi nel Worker lifeos (`scripts/deploy-category-tools-96.py`): getFinanceCategoryUsage (una query raggruppata) e moveFinanceCategory (un UPDATE con [Categoria manuale], poi una riconciliazione; risponde spostati/rimasti). Pagina del sito 2f9813e. Workflow `lifeos-category-tools96.yml`. SQL provato su SQLite in memoria; da provare dall'utente sul sito.

Verifica: compilazione e test unitari superati su 81f396c (run 45736287109), voci 1 e 2 comprese. Nessuna prova sull'iPhone.


IPA: nessuna IPA della 96 finché l'utente non la chiede (IPA-HOLD-2026-11-26).
