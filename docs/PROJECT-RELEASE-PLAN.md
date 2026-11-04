# Piano operativo LifeOS

Autorizzato 4 novembre 2026. Base `edd60f9e5afcb0db6e1520c183a6a7d0b10de1a1`. La prova tecnica non equivale ad accettazione. Nessuna IPA o deploy autorizzati. DEV-02 richiede proposta concreta prima del codice di nuove correzioni.

| Task | Ambito | Dipendenze | Stato |
|---|---|---|---|
| T00 | Registro, copertura e manifesto | — | verificato localmente; sincronizzazione in corso |
| T01 | CI senza packaging, aree attività/calendario/turni, suite completa e quattro avvii Release | T00 | da avviare |
| T02 | Retry quick add accessibile, valori e identità, riavvio e storico | T01 | da avviare |
| T03 | Dashboard: oggi e due date, preghiera, budget, navigazione e turni | T02 | da avviare |
| T04 | Bloom: parità privata ID, contenuti, allegati, hash e funzioni; preservare griglia | T03 | da avviare |
| T05 | Editor attività, calendario, turni e sveglie: coda e identità | T04 | da avviare |
| T06 | Finanza audit live in lettura e test sintetici, limite E10 | T05 | da avviare |
| T07 | Anteprima Salute standard, compatta e accessibile, contratto e conferma conflitti | T00 | da avviare |
| T08 | Macro HealthKit tutte le app, fonti e assenza di doppia somma locale/HealthKit | T02, T07 approvato | da avviare |
| T09 | Griglia Salute dopo conferma e letture verificate | T07 approvato, T08 | da avviare |
| T10 | UI condivisa, persistenza e widget | T03, T04, T05, T06, T09 | da avviare |
| T11 | Gate suite completa, screenshot e quattro avvii senza IPA | T01–T10 | da avviare |
| T12 | Solo su richiesta IPA separata: packaging e prove fisiche | T11, richiesta esplicita IPA | da avviare |
| F01 | Studio futuro alimenti; non prerequisito release | — | da avviare |

T03–T06 ammettono audit in lettura durante blocchi CI, senza dichiarare completamento. T07 può procedere durante attesa CI. T12 richiede esplicita nuova richiesta IPA. F01 non blocca la release.

## Contratto proposto per T07

Due righe e due colonne: TDEE, peso previsto alla data di un mese civile, ultima pesata con data, calorie di oggi. Nutrienti sotto in quattro colonne con adattamento 2×2/1; due icone Liquid Glass sopra la tab bar, peso verso editor esistente e mela verso quick add e cronologia accessibile. Mini grafici sotto valore: conflitti da sottoporre dopo anteprima con G09 e G12, nonché aspetti G08/G13; G10/G11 restano. Nessun nuovo target o algoritmo: TDEE e soglie invariati, previsione con calibrazione esistente, data civile + mese, nil distinto da zero, tutte le fonti HK e locale pending separato, nessun intervallo di confidenza inventato.

## Gate

T02 richiede prova di errori, retry, valori/ID/revisione, riavvio e storico. T06 richiede prova sintetica 221,79 / 3 = 73,93, movimento unico e capability/retry; E10 personale non è dimostrabile dai sintetici. T07 richiede anteprima e conferma esplicita dei conflitti. T08 richiede valori, presenza, fonte, periodo ed esito e niente doppio conteggio. T11 esige suite e quattro avvii Release verificati. I test non sostituiscono la valutazione utente.

## Contratti operativi e prove

### T00 — Registro, copertura e manifesto

Input e file principali: `AGENTS.md`, `README.md`, `docs/USER-DECISIONS.md`, `docs/USER-DECISIONS.json`, `docs/PROJECT-RELEASE-PLAN.md`, `docs/REQUIREMENT-COVERAGE.json`, `docs/EXECUTION-MANIFEST.json`, `docs/STATUS.md`, `docs/AI-HANDOFF.md`, `docs/BUILD-STATE.json`, `docs/OPEN-ISSUES.md`, `docs/PROJECT-CHECKLIST.md`, `docs/DEVELOPMENT-CYCLE.md`. Dipendenze: nessuna.

Verifica e condizione di uscita: Confrontare tutti i 238 ID e regole/QA, verificare JSON, provenienza, classificazione, conflitti, diff e SHA remoto. Stop: Conflitto decisionale, dati non disponibili, test bloccanti o autorizzazione IPA mancante.

### T01 — CI senza packaging, aree attività/calendario/turni, suite completa e quattro avvii Release

Input e file principali: `.github/workflows/lifeos-development.yml`, `scripts/select-development-tests.py`, `scripts/test_development_selection.py`, `scripts/verify-release-launch75.py`. Dipendenze: T00.

Verifica e condizione di uscita: Test selettore e lint workflow; verificare suite completa e quattro avvii Release separati dal packaging su macOS quando disponibile. Stop: Conflitto decisionale, dati non disponibili, test bloccanti o autorizzazione IPA mancante.

### T02 — Retry quick add accessibile, valori e identità, riavvio e storico

Input e file principali: `native-next/Sources/NativeNutritionQuickEntry.swift`, `native-next/Sources/NativeNutrition.swift`, `native-next/Sources/NativeNutritionUIFixture.swift`, `native-next/UITests/NativeNutritionQuickUITests.swift`, `native-next/Tests/NativeNutritionStoreTests.swift`. Dipendenze: T01.

Verifica e condizione di uscita: Errore e retry con valori/ID/revisione conservati, riavvio e storico; unitari e UI accessibilità su simulatore. Stop: Conflitto decisionale, dati non disponibili, test bloccanti o autorizzazione IPA mancante.

### T03 — Dashboard: oggi e due date, preghiera, budget, navigazione e turni

Input e file principali: `native-next/Sources/DashboardScreen.swift`, `native-next/Sources/NativeDashboardFocus.swift`, `native-next/Tests/NativeDashboardFocusTests.swift`, `native-next/UITests/NativeRevision78UITests.swift`. Dipendenze: T02.

Verifica e condizione di uscita: Finestra oggi + due date civili, ordine, preghiera, budget, navigazione, turni e accessibilità; prove mirate e screenshot. Stop: Conflitto decisionale, dati non disponibili, test bloccanti o autorizzazione IPA mancante.

### T04 — Bloom: parità privata ID, contenuti, allegati, hash e funzioni; preservare griglia

Input e file principali: `native-next/Sources/NativeBloomStore.swift`, `native-next/Sources/NativeBloomScreen.swift`, `native-next/Sources/NativeBloomBackupPicker.swift`, `native-next/Tests/NativeBloomStoreTests.swift`, `native-next/UITests/NativeBloomGridUITests.swift`. Dipendenze: T03.

Verifica e condizione di uscita: Parità privata per ID, contenuti, allegati e hash, persistenza e funzioni esistenti; preservare griglia accettata e non pubblicare dati personali. Stop: Conflitto decisionale, dati non disponibili, test bloccanti o autorizzazione IPA mancante.

### T05 — Editor attività, calendario, turni e sveglie: coda e identità

Input e file principali: `native-next/Sources/NativeActivityEditor.swift`, `native-next/Sources/NativeActivityDraft.swift`, `native-next/Sources/NativeLocalActivity.swift`, `native-next/Sources/CalendarScreen.swift`, `native-next/Sources/NativeUrgentAlarm.swift`, `native-next/Tests/NativeActivityStoreTests.swift`, `native-next/UITests/NativeInterfaceTests.swift`. Dipendenze: T04.

Verifica e condizione di uscita: Editor, completamento, coda, identité, offline/retry, calendrier, turni e sveglie; prova riavvio e regressione mirata. Stop: Conflitto decisionale, dati non disponibili, test bloccanti o autorizzazione IPA mancante.

### T06 — Finanza audit live in lettura e test sintetici, limite E10

Input e file principali: `native-next/Sources/NativeFinanceViews.swift`, `native-next/Sources/FinanceScreen.swift`, `native-next/Sources/FinanceAnalysisScreen.swift`, `backend/expense-routing`, `docs/ARCHITECTURE-CURRENT.md`. Dipendenze: T05.

Verifica e condizione di uscita: Audit live non mutante; test sintetico 221.79/3=73.93, unico movimento, capability e retry; E10 personale non dimostrabile da sintetici. Stop: Conflitto decisionale, dati non disponibili, test bloccanti o autorizzazione IPA mancante.

### T07 — Anteprima Salute standard, compatta e accessibile, contratto e conferma conflitti

Input e file principali: `docs/HEALTH-BODYBUILDING-BRIEF.md`, `docs/USER-DECISIONS.md`, `native-next/Sources/NativeHealthViews.swift`, `native-next/Sources/NativeHealthSummary.swift`. Dipendenze: T00.

Verifica e condizione di uscita: Anteprime standard, compatta e accessibile e contratto; presentare conflitti G08/G09/G12/G13, attendere conferma prima della modifica. Stop: Conflitto decisionale, dati non disponibili, test bloccanti o autorizzazione IPA mancante.

### T08 — Macro HealthKit tutte le app, fonti e assenza di doppia somma locale/HealthKit

Input e file principali: `native-next/Sources/NativeHealthStore.swift`, `native-next/Sources/NativeHealthModel.swift`, `native-next/Sources/NativeNutrition.swift`, `native-next/Tests/NativeNutritionHealthKitTests.swift`, `native-next/Tests/NativeHealthTests.swift`. Dipendenze: T02, T07 approvato.

Verifica e condizione di uscita: Verificare valori, presenza, fonte, periodo ed esito; tutte le app, assenza di doppia somma locale/HealthKit, dati mancanti e date civili. Stop: Conflitto decisionale, dati non disponibili, test bloccanti o autorizzazione IPA mancante.

### T09 — Griglia Salute dopo conferma e letture verificate

Input e file principali: `native-next/Sources/NativeHealthViews.swift`, `native-next/Sources/NativeHealthSummary.swift`, `native-next/Sources/NativeHealthChartInteraction.swift`, `native-next/Tests/NativeHealthTests.swift`. Dipendenze: T07 approvato, T08.

Verifica e condizione di uscita: Solo dopo conferma T07 e verifica T08; screenshot standard/compatto/Dynamic Type, navigazione e semantica. Stop: Conflitto decisionale, dati non disponibili, test bloccanti o autorizzazione IPA mancante.

### T10 — UI condivisa, persistenza e widget

Input e file principali: `native-next/Shared/LifeOSWidgetData.swift`, `native-next/Shared/LifeOSWidgetView.swift`, `native-next/Widget/LifeOSWidget.swift`, `native-next/Sources/NativeWidgetBridge.swift`, `native-next/Sources/NativeWidgetPreview.swift`. Dipendenze: T03, T04, T05, T06, T09.

Verifica e condizione di uscita: UI condivisa, persistenza, App Group e widget; verificare dipendenze e riavvio senza perdere dati. Stop: Conflitto decisionale, dati non disponibili, test bloccanti o autorizzazione IPA mancante.

### T11 — Gate suite completa, screenshot e quattro avvii senza IPA

Input e file principali: `.github/workflows/lifeos-development.yml`, `scripts/verify-release-launch75.py`, `docs/PROJECT-CHECKLIST.md`, `docs/BUILD-STATE.json`. Dipendenze: T01–T10.

Verifica e condizione di uscita: Suite completa, screenshot esaminati e quattro avvii Release; nessuna IPA; registrare risultati e limiti. Stop: Conflitto decisionale, dati non disponibili, test bloccanti o autorizzazione IPA mancante.

### T12 — Solo su richiesta IPA separata: packaging e prove fisiche

Input e file principali: `docs/BUILD-STATE.json`, `docs/PROJECT-CHECKLIST.md`, `scripts/verify-native-package.py`, `scripts/verify-startup-imports.py`. Dipendenze: T11, richiesta esplicita IPA.

Verifica e condizione di uscita: Solo richiesta IPA separata dopo T11; verificare pacchetto e versione, aggiornamento, prove fisiche e accettazione. Stop: Conflitto decisionale, dati non disponibili, test bloccanti o autorizzazione IPA mancante.

### F01 — Studio futuro alimenti; non prerequisito release

Input e file principali: `docs/HEALTH-BODYBUILDING-BRIEF.md`. Dipendenze: nessuna.

Verifica e condizione di uscita: Studio futuro fonti/licenze e alimenti; nessuna implementazione o dipendenza release. Stop: Conflitto decisionale, dati non disponibili, test bloccanti o autorizzazione IPA mancante.

