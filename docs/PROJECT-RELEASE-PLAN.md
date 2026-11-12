# Piano operativo LifeOS

**Candidato pronto per il gate completo senza IPA:** [prova mirata 43229809175](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43229809175), sorgente ff2a894, passata (1 unitario e 2 UI). Ispezionate catture reali di marca Spesotti, 250 ml = 117,5 kcal, cronologia per giorno ed eliminazione del solo giorno selezionato. Le precedenti prove mirate coprono capsule/polveri, identità personale e palette standard/grande. Nel riepilogo storico le fibre non dichiarate restano “—”. La nuova suite completa e i quattro avvii Release sono il prossimo gate; non c’è autorizzazione IPA.

**Checkpoint catalogo completo e diagnosi, 12 novembre:** inventario ufficiale 5.323/5.323 URL, 222/222 pagine, ora **2.893 alimenti** dopo verifica di tre esclusioni errate (un vegetale e due prodotti di pollo/tacchino senza suino); **208 Gli Spesotti**, 305 tabelle non disponibili, 5 limiti di etichetta espliciti, un EAN duplicato coerente unificato. Coverage e manifesto in COOP-CATALOG-COVERAGE.json / COOP-CATALOG-MANIFEST.json. Voci locali senza macro non inviano zeri in HealthKit.

Il collaudo completo precedente 43178362187 sul commit 7087d91 ha completato 390 test: 389 passati, un fallimento nel vecchio vincolo di larghezza 60 pt della palette. Quattro avvii Release passati; IPA esclusa. La verifica 43189745646 sul commit 5e05fa3 ha compilato e rilevato un’aspettativa unitaria sulla rimozione della porzione in modifica manuale e due errori UI: propagazione dell’identificatore del diario sul pulsante e helper test che scriveva 300200 invece di sostituire 200 con 300. Correzioni preparate; nessuna nuova suite completa finché non passa la verifica mirata dei soli casi interessati e del latte Spesotti in ml. Non sono esiti verdi del nuovo candidato.

**Nuovo incremento autorizzato il 12 novembre (catalogo e flussi):** richiesta aggiuntiva e conferma META-01 per marche Coop/Spesotti, conservando generici, esclusioni maiale/creatina e gate IPA. Implementati nel sorgente unità capsule/compresse/grammi e ml per etichette liquide, modifica/copia personale, composizioni pubbliche degli integratori, preview eliminabile del solo giorno, cronologia per giorno e palette Liquid Glass compatta. Verifica mirata `catalog-review` da eseguire. Importazione catalogo ufficiale ancora in acquisizione: inventario completo 5.323 URL, schede nutrizionali in elaborazione; il file branded-foods attuale è un segnaposto e NON rappresenta catalogo completato. Il collaudo 43178362187 riguarda esclusivamente il sorgente precedente 7087d91 e non certifica queste modifiche. Nessuna nuova IPA e nessun deploy backend.

**Prova mirata conclusa:** [43176199615](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43176199615), sorgente `d91aa380d821498cb7722639c0489a2d3318c59c`: 288 unitari e 4 UI passati, zero fallimenti. Ispezionate catture del riferimento Apple Salute (2.200 kcal, 80 kg) e palette standard/grande. Il candidato aggiunge soltanto una protezione alla ricerca dei processi non avviati e salta tale ricerca se la fixture è già pronta; nessun sorgente prodotto modificato. Prossimo gate: singolo workflow manuale lifeos-validate80 con suite completa e quattro avvii Release. Su workflow_dispatch package89/publish89 sono esclusi dalle condizioni evento push.

## Stato corrente — audit del 12 novembre 2026

Questa sezione prevale sulle note cronologiche successive. La nuova chat autorizza il proseguimento e il collaudo finale completo, compresi quattro avvii Release, **senza creare, confezionare o distribuire IPA** e senza deploy backend. Occorre una nuova richiesta IPA esplicita in questa chat. DEV-02 resta applicabile ai nuovi difetti di prodotto; non ripetere approvazioni già registrate per lo stesso ambito.

Checkpoint osservato: `codex/revision77` remoto a `6a8826d`, `main` a `1b80e58`; il checkpoint `2d33d8a` è storico. Sorgente dell'ultimo tentativo: `db6d6f5e03e4d5cd5bf1dca850372d50063345b6`. Il [run 43113799496](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43113799496) ha eseguito 299 prove: 298 passate, 1 fallita, zero saltate. Il preflight si è fermato su `The Health authorization dialog did not become ready`; la restante suite non è stata completata. Quattro avvii Release passati; packaging e pubblicazione saltati. Questi 299 risultati non equivalgono a una suite completa verde.

| Task | Evidenza ricostruita | Stato e lavoro residuo |
| --- | --- | --- |
| T00 | Registro, copertura e manifesto disponibili; copertura con 238 voci storiche più 30 aggiuntive | Audit e riallineamento documenti in corso; verificare sincronizzazione SHA al checkpoint finale |
| T01 | Suite e quattro avvii passati nel run 43094447884, precedente agli ultimi incrementi; quattro avvii passati anche nel 43113799496 | Pipeline disponibile; collaudo completo del candidato attuale ancora aperto |
| T02 | Retry accessibile 41894390397; QA-012 testo grande e tastiera 41944119975; regressioni nutrizione successive | Verifiche sintetiche disponibili; revisione finale e HealthKit fisico aperti |
| T03 | Dashboard e QA-004 standard/grande 42044400960, compatto 42056808149; incremento 42573602745 | Verifiche simulatore disponibili; regressione finale e revisione utente aperte |
| T04 | Bloom 42005224764: frame 44 pt, bordo, importazione e persistenza sintetica; sezioni aggiornate nei collaudi successivi | Parità privata di note, allegati e hash e verifica iPhone non dimostrate |
| T05 | Calendario GMT/riapertura 42116279080; 19 test sintetici Attività; palette standard/grande 43111876770 | Regressioni simulate disponibili; sveglie, AlarmKit e suono fisici aperti |
| T06 | 35 test sintetici Finanza; audit non mutante 41949645412 con tre test trasformazione | Importi personali/E10 e parità integrale Worker non dimostrati; nessun deploy autorizzato |
| T07 | HEALTH-GRID-02 conferma la deroga; checklist 9 novembre aggiorna la sola disposizione a 3×2 | Approvazioni già registrate: non riaprire il vecchio conflitto per lo stesso ambito |
| T08 | Letture macro/fonti e deduplica coperte da prove sintetiche precedenti | Blocco corrente della fixture Apple Salute da diagnosticare; HealthKit fisico aperto |
| T09 | Griglia, storico, medie e Dashboard: 42573602745; diario storico e omega-3: 42575533916 | Implementazione e prove mirate disponibili; regressione finale e revisione utente aperte |
| T10 | QA-004 su simulatore principale e compatto, standard e testo grande; persistenza sintetica | App Group, widget e continuità dati sul dispositivo non verificati |
| T11 | Ultima suite verde 43094447884 precede palette e integratori finali | **Aperto**: risolvere prima il blocco mirato, poi una sola suite completa e quattro avvii Release senza IPA sul candidato pronto |
| T12 | Nessuna nuova autorizzazione IPA in questa chat | Sospeso fino alla richiesta esplicita; firma/installazione, prove fisiche e accettazione separate |

Ordine delle attività dell'utente al termine del lavoro autonomo: revisione delle schermate correnti ed eventuali sole nuove approvazioni DEV-02; richiesta esplicita IPA quando T11 è superato; dopo produzione, firma e installazione conservando i dati; verifica parità Bloom/Finanza e prove HealthKit, App Group/widget, AlarmKit/suono; accettazione esplicita. Le prove automatiche non sostituiscono nessuno di questi esiti.

## Cronologia fino al precedente checkpoint

Le autorizzazioni IPA e gli stati “corrente”, “da avviare” o “in corso” sotto sono storici. Per questa chat usare il perimetro e la matrice sopra; il backlog storico non autorizza nuove funzioni.

**LifeOS 0.10.19 build 80 consegnata.** [IPA](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.19-build80/LifeOS-80.ipa), SHA-256 80a4e4759c810e2f2f69ef860a128d8cd020cf133cfa2e223cc4d51edf9f60c0. Sorgente 5aba0d5b888471025a45568d6ff567199b5a4fec. [Suite 368/368](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516), [avvii Release 4/4](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516), [confezionamento verificato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42235788082). Restano firma Signulous, aggiornamento sul telefono, parità dei dati personali, verifiche fisiche e accettazione esplicita.

**Collaudo pre-IPA superato.** Sorgente 5aba0d5b888471025a45568d6ff567199b5a4fec. [Suite completa](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516): 368/368, zero falliti e zero saltati. [Avvii Release](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516): 4/4 sullo stesso sorgente in un job separato. Confezionamento della build 80 autorizzato.

**LifeOS 0.10.18 build 79 consegnata.** [IPA](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.18-build79/LifeOS-79.ipa), SHA-256 f7a9155e27fc27fd30a39e8422a43bfa26bdfdae69f0920ed87cf4c1d22a6f15. Sorgente 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. [Suite 368/368](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946), [avvii Release 4/4](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42189948045), [confezionamento verificato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42194114583). Restano firma Signulous, aggiornamento sul telefono, parità dei dati personali, verifiche fisiche e accettazione esplicita.

**Collaudo pre-IPA superato.** Sorgente 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. [Suite completa](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946): 368/368, zero falliti e zero saltati. [Avvii Release](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42189948045): 4/4 sullo stesso sorgente dopo il timeout della fase originale. Confezionamento della build 79 autorizzato.

**Collaudo pre-IPA (6 novembre 2026).** Suite completa passata nel [run 42124676946](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946) sul commit 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. GitHub ha interrotto la fase avvii Release al limite del job (120 minuti). Verifica separata dei quattro avvii sul medesimo sorgente, senza ripetere la suite e senza packaging.

**Consegna corrente (5 novembre 2026).** Autorizzata una singola nuova IPA dopo il superamento del collaudo pre-IPA. Suite completa e quattro avvii Release nel [run 42124676946](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946) sul candidato 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. Esito da acquisire. Ultima release verificata: 0.10.17 build 78. Firma Signulous, verifica iPhone e accettazione utente restano separate. Nessun deploy backend o cancellazione autorizzati.

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

Verifica e condizione di uscita: Confrontare tutti i 238 ID e regole/QA, verificare JSON, provenienza, classificazione, conflitti, diff e SHA remoto. Stop: Conflitto decisionale pertinente, dati necessari non disponibili o prova bloccante non risolta.

### T01 — CI senza packaging, aree attività/calendario/turni, suite completa e quattro avvii Release

Input e file principali: `.github/workflows/lifeos-development.yml`, `scripts/select-development-tests.py`, `scripts/test_development_selection.py`, `scripts/verify-release-launch75.py`. Dipendenze: T00.

Verifica e condizione di uscita: Test selettore e lint workflow; verificare suite completa e quattro avvii Release separati dal packaging su macOS quando disponibile. Stop: Conflitto decisionale pertinente, dati necessari non disponibili o prova bloccante non risolta.

### T02 — Retry quick add accessibile, valori e identità, riavvio e storico

Input e file principali: `native-next/Sources/NativeNutritionQuickEntry.swift`, `native-next/Sources/NativeNutrition.swift`, `native-next/Sources/NativeNutritionUIFixture.swift`, `native-next/UITests/NativeNutritionQuickUITests.swift`, `native-next/Tests/NativeNutritionStoreTests.swift`. Dipendenze: T01.

Verifica e condizione di uscita: Errore e retry con valori/ID/revisione conservati, riavvio e storico; unitari e UI accessibilità su simulatore. Stop: Conflitto decisionale pertinente, dati necessari non disponibili o prova bloccante non risolta.

### T03 — Dashboard: oggi e due date, preghiera, budget, navigazione e turni

Input e file principali: `native-next/Sources/DashboardScreen.swift`, `native-next/Sources/NativeDashboardFocus.swift`, `native-next/Tests/NativeDashboardFocusTests.swift`, `native-next/UITests/NativeRevision78UITests.swift`. Dipendenze: T02.

Verifica e condizione di uscita: Finestra oggi + due date civili, ordine, preghiera, budget, navigazione, turni e accessibilità; prove mirate e screenshot. Stop: Conflitto decisionale pertinente, dati necessari non disponibili o prova bloccante non risolta.

### T04 — Bloom: parità privata ID, contenuti, allegati, hash e funzioni; preservare griglia

Input e file principali: `native-next/Sources/NativeBloomStore.swift`, `native-next/Sources/NativeBloomScreen.swift`, `native-next/Sources/NativeBloomBackupPicker.swift`, `native-next/Tests/NativeBloomStoreTests.swift`, `native-next/UITests/NativeBloomGridUITests.swift`. Dipendenze: T03.

Verifica e condizione di uscita: Parità privata per ID, contenuti, allegati e hash, persistenza e funzioni esistenti; preservare griglia accettata e non pubblicare dati personali. Stop: Conflitto decisionale pertinente, dati necessari non disponibili o prova bloccante non risolta.

### T05 — Editor attività, calendario, turni e sveglie: coda e identità

Input e file principali: `native-next/Sources/NativeActivityEditor.swift`, `native-next/Sources/NativeActivityDraft.swift`, `native-next/Sources/NativeLocalActivity.swift`, `native-next/Sources/CalendarScreen.swift`, `native-next/Sources/NativeUrgentAlarm.swift`, `native-next/Tests/NativeActivityStoreTests.swift`, `native-next/UITests/NativeInterfaceTests.swift`. Dipendenze: T04.

Verifica e condizione di uscita: Editor, completamento, coda, identité, offline/retry, calendrier, turni e sveglie; prova riavvio e regressione mirata. Stop: Conflitto decisionale pertinente, dati necessari non disponibili o prova bloccante non risolta.

### T06 — Finanza audit live in lettura e test sintetici, limite E10

Input e file principali: `native-next/Sources/NativeFinanceViews.swift`, `native-next/Sources/FinanceScreen.swift`, `native-next/Sources/FinanceAnalysisScreen.swift`, `backend/expense-routing`, `docs/ARCHITECTURE-CURRENT.md`. Dipendenze: T05.

Verifica e condizione di uscita: Audit live non mutante; test sintetico 221.79/3=73.93, unico movimento, capability e retry; E10 personale non dimostrabile da sintetici. Stop: Conflitto decisionale pertinente, dati necessari non disponibili o prova bloccante non risolta.

### T07 — Anteprima Salute standard, compatta e accessibile, contratto e conferma conflitti

Input e file principali: `docs/HEALTH-BODYBUILDING-BRIEF.md`, `docs/USER-DECISIONS.md`, `native-next/Sources/NativeHealthViews.swift`, `native-next/Sources/NativeHealthSummary.swift`. Dipendenze: T00.

Verifica e condizione di uscita: Anteprime standard, compatta e accessibile e contratto; presentare conflitti G08/G09/G12/G13, attendere conferma prima della modifica. Stop: Conflitto decisionale pertinente, dati necessari non disponibili o prova bloccante non risolta.

### T08 — Macro HealthKit tutte le app, fonti e assenza di doppia somma locale/HealthKit

Input e file principali: `native-next/Sources/NativeHealthStore.swift`, `native-next/Sources/NativeHealthModel.swift`, `native-next/Sources/NativeNutrition.swift`, `native-next/Tests/NativeNutritionHealthKitTests.swift`, `native-next/Tests/NativeHealthTests.swift`. Dipendenze: T02, T07 approvato.

Verifica e condizione di uscita: Verificare valori, presenza, fonte, periodo ed esito; tutte le app, assenza di doppia somma locale/HealthKit, dati mancanti e date civili. Stop: Conflitto decisionale pertinente, dati necessari non disponibili o prova bloccante non risolta.

### T09 — Griglia Salute dopo conferma e letture verificate

Input e file principali: `native-next/Sources/NativeHealthViews.swift`, `native-next/Sources/NativeHealthSummary.swift`, `native-next/Sources/NativeHealthChartInteraction.swift`, `native-next/Tests/NativeHealthTests.swift`. Dipendenze: T07 approvato, T08.

Verifica e condizione di uscita: Solo dopo conferma T07 e verifica T08; screenshot standard/compatto/Dynamic Type, navigazione e semantica. Stop: Conflitto decisionale pertinente, dati necessari non disponibili o prova bloccante non risolta.

### T10 — UI condivisa, persistenza e widget

Input e file principali: `native-next/Shared/LifeOSWidgetData.swift`, `native-next/Shared/LifeOSWidgetView.swift`, `native-next/Widget/LifeOSWidget.swift`, `native-next/Sources/NativeWidgetBridge.swift`, `native-next/Sources/NativeWidgetPreview.swift`. Dipendenze: T03, T04, T05, T06, T09.

Verifica e condizione di uscita: UI condivisa, persistenza, App Group e widget; verificare dipendenze e riavvio senza perdere dati. Stop: Conflitto decisionale pertinente, dati necessari non disponibili o prova bloccante non risolta.

### T11 — Gate suite completa, screenshot e quattro avvii senza IPA

Input e file principali: `.github/workflows/lifeos-development.yml`, `scripts/verify-release-launch75.py`, `docs/PROJECT-CHECKLIST.md`, `docs/BUILD-STATE.json`. Dipendenze: T01–T10.

Verifica e condizione di uscita: Suite completa, screenshot esaminati e quattro avvii Release; nessuna IPA; registrare risultati e limiti. Stop: Conflitto decisionale pertinente, dati necessari non disponibili o prova bloccante non risolta.

### T12 — Solo su richiesta IPA separata: packaging e prove fisiche

Input e file principali: `docs/BUILD-STATE.json`, `docs/PROJECT-CHECKLIST.md`, `scripts/verify-native-package.py`, `scripts/verify-startup-imports.py`. Dipendenze: T11, richiesta esplicita IPA.

Verifica e condizione di uscita: Solo richiesta IPA separata dopo T11; verificare pacchetto e versione, aggiornamento, prove fisiche e accettazione. Stop: Conflitto decisionale pertinente, dati necessari non disponibili o prova bloccante non risolta.

### F01 — Studio futuro alimenti; non prerequisito release

Input e file principali: `docs/HEALTH-BODYBUILDING-BRIEF.md`. Dipendenze: nessuna.

Verifica e condizione di uscita: Studio futuro fonti/licenze e alimenti; nessuna implementazione o dipendenza release. Stop: Conflitto decisionale pertinente, dati necessari non disponibili o prova bloccante non risolta.

