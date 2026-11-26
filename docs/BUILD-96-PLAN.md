# Build 96 — piano

Voci decise per la 96 (registro: docs/USER-DECISIONS.md). Nessuna IPA senza approvazione esplicita.

1. SALARY-MAP-PLAN-KIND-2026-11-26 — fatto nel codice: «Dove va lo stipendio» nell'app usa la regola del sito per le quote dei piani (`NativeSalaryMap.isMonthlyCommitment`: stima, anticipo, recupero, spesa fissa mensile → Impegni; ripartite su più mesi, obiettivi, fondi → Messo da parte); righe del riepilogo legate a un piano non contate due volte; differenza non spiegata come «Altri impegni del mese». Test: NativeFinance93Tests.testSalaryMapSortsPlansByKindLikeTheSite. Da verificare sull'iPhone con i dati reali.
2. Finanza più leggera (prima una proposta).
3. Layout della Dashboard dal sito (SITE-LAYOUT-CONFIG-2026-11-25).
4. Analisi del sito più ricca (ANALYSIS-SITE-FREEHAND-2026-11-25).
5. Ricerca alimenti del sito con varianti (mockup non ancora approvato).
