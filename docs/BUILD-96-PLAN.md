# Build 96 — piano

Voci decise per la 96 (registro: docs/USER-DECISIONS.md). Nessuna IPA senza approvazione esplicita.

1. SALARY-MAP-PLAN-KIND-2026-11-26 — fatto nel codice: «Dove va lo stipendio» nell'app usa la regola del sito per le quote dei piani (`NativeSalaryMap.isMonthlyCommitment`: stima, anticipo, recupero, spesa fissa mensile → Impegni; ripartite su più mesi, obiettivi, fondi → Messo da parte); righe del riepilogo legate a un piano non contate due volte; differenza non spiegata come «Altri impegni del mese». Test: NativeFinance93Tests.testSalaryMapSortsPlansByKindLikeTheSite. Da verificare sull'iPhone con i dati reali.
2. APP-LAG-2026-11-26 — fatto nel codice: sincronizzazione periodica ogni 2 minuti (`App.swift`, ogni 4° tick da 30 s), risposte decodificate fuori dal main thread (`NativeStore.requestOnce`), `refresh` salva e ripubblica solo se attività o finanza cambiano (l'ora del widget avanza comunque ogni ora), Bloom riletta al massimo ogni 5 minuti salvo modifiche locali (`NativeOnlineSync.bloomReadInterval`). Test: NativeStoreTests.testIdenticalRefreshDoesNotRewriteTheArchive, NativeOnlineSyncTests.testBloomIsNotReadAgainBeforeTheIntervalWithoutChanges. Da verificare sull'iPhone.
3. Finanza più leggera (prima una proposta).
4. Layout della Dashboard dal sito (SITE-LAYOUT-CONFIG-2026-11-25).
5. Analisi del sito più ricca (ANALYSIS-SITE-FREEHAND-2026-11-25).
6. Ricerca alimenti del sito con varianti (mockup non ancora approvato).
