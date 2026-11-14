# Audit indipendente UI, animazioni e validità delle prove — 14 novembre 2026

Revisione in sola lettura effettuata da un sottoagente su richiesta dell’utente. Questo documento separa risultati osservati, ipotesi e verifiche ancora necessarie. Non autorizza una nuova dichiarazione di accettazione del prodotto.

## Risultati effettivi

| Run e sorgente | Risultato osservato | Limite |
| --- | --- | --- |
| 43618379858, `82d56cf` | Compilazione passata; preflight compatto 2 UI passati e 1 fallito. Passano testo grande/tastiera e catalogo. Il primo accesso al Calendario fallisce a NativeNavigationUITests:38. | Suite restante, quattro avvii Release, packaging e pubblicazione non eseguiti. |
| 43522275345, `47cc00e` | Preflight riparato passato; suite restante: 406 passati, 12 falliti, zero saltati su 418 casi. Tutti i 311 unitari passano. | I due casi UI storici erano conservati e dichiarati separatamente. La somma aggregata del candidato era 409 passati e 12 falliti su 421 casi coperti, non 421 test nuovi nello stesso run. |

I numeri derivano dai riepiloghi xcresult e dai log scaricati; non dalla sola conclusione del job `full-suite`.

## Ultimo fallimento: fatti e ipotesi

Nel run `43618379858`, il log registra il tap corretto su `main-tab-5` (Calendario) a t=55,44 s. Il record evento sintetizzato indica il punto (337,637) sullo schermo da 375×667 pt, al centro del target. La gerarchia esportata `3F9E7138-9912-44A9-BFF6-634D84FD51CC.txt` mostra invece ancora `dashboard-scroll`, la barra Dashboard e Dashboard selezionata. Non è dunque dimostrato un semplice cambio dell’identificatore del calendario.

È confermato il mancato arrivo alla destinazione attesa. Non è ancora provato, dalle sole catture, se il gesto venga perso o se la selezione ritorni indietro. Non aumentare il timeout per nascondere questo risultato. Il test successivo con testo grande passa attraverso le sei destinazioni: il confronto fra primo utilizzo, dimensione normale e riutilizzo è rilevante.

## Matrice delle anomalie conosciute

Tutti i selettori sotto hanno prefisso `LifeOSProbeUITests/`.

| Selettore | Evidenza / classificazione | Regressione da richiedere |
| --- | --- | --- |
| NativeNavigationUITests/testSixVisibleTabsPreserveCalendarFinanceAndDashboardStacks | Ultimo run: mancato accesso diretto iniziale al Calendario, Dashboard ancora selezionata. Prodotto/interazione da isolare, non selettore obsoleto accertato. | Primo tap e tap ripetuti raggiungono il calendario; stato selezionato e contenuto concordano; stati delle sei destinazioni e stack Dashboard conservati. |
| NativeNavigationUITests/testSixVisibleTabsWithLargeTextAndKeyboard | Ultimo run passato. Le precedenti query test della X erano errate: «chiudi» è un ramo fratello del SearchField, non un suo discendente. | Sei target raggiungibili con testo grande; tastiera nasconde la barra; chiusura ricerca ripristina una barra interattiva. |
| NativePersonalFoodUITests/testSupplementTabSeparatesFoodsAndSearchesKnownBrands | Ultimo run passato, dopo la correzione dell’ambiente fra host. | Catalogo aperto durante il focus e la digitazione; Integratori separati; risultati delle marche corretti. |
| NativeBloomGridUITests/testMixedLibraryStaysInTwoColumnsAndShowsLinkPreviews | Suite precedente: le card non si muovono dopo il drag. Tutti i drag osservati partono dal gap fra colonne. | Due colonne senza sovrapposizioni e scorrimento effettivo, mantenendo le asserzioni di progresso. |
| NativeBloomGridUITests/testMixedLibraryWithLargeTextRemainsBounded | Stessa anomalia con testo grande. | Layout entro i limiti e progresso effettivo anche con Dynamic Type accessibile. |
| NativeBloomScrollProbeUITests/testDraggingInsideColumnMovesLibrary | Nuovo caso discriminante, non ancora eseguito nei run fermi al preflight. | Trascinamento dal centro di una colonna muove la libreria. |
| NativeBloomScrollProbeUITests/testDraggingBetweenColumnsMovesLibrary | Nuovo caso discriminante, non ancora eseguito. | Identico gesto dal gap muove la libreria; confronto con il caso precedente per distinguere hit area e blocco generale. |
| NativeInterfaceTests/testCalendarEventCanBeCreatedAfterBoundaryScroll | Suite precedente: event loop non torna idle dopo swipe; scadenza di tre minuti. | Scroll ai confini resta reattivo e permette di aprire/salvare l’evento. |
| NativeInterfaceTests/testCalendarRepeatedScrollingKeepsMonthAnchorsAndReturnsToToday | Stesso schema di blocco dopo swipe. | Finestre/ancore mese coerenti; ritorno a Oggi funzionante. |
| NativeInterfaceTests/testCalendarScrollPerformance | Timeout, non prova di sola lentezza del selettore. | Completamento entro il limite esistente con app reattiva; non aumentare il limite senza causa misurata. |
| NativeInterfaceTests/testRepeatedBoundaryScrollingKeepsNavigationStable | Timeout a cinque minuti nella suite precedente. | Scorrimenti ripetuti non bloccano l’app e lasciano navigazione raggiungibile. |
| NativeInterfaceTests/testFinanceMonthButtonsMoveIndependentlyInBothDirections | Il percorso via Dashboard raggiunge Ottobre ma non ritrova Novembre dopo il comando successivo. | Entrambe le direzioni cambiano il mese corretto senza confondere altri controlli/stati. |
| NativeInterfaceTests/testFinanceOverviewSupportsLargeTextAndEmptySnapshot | Dopo apertura e annullamento del movimento, la gerarchia contiene solo dashboard-scroll. | Annullare il movimento conserva la schermata Finanza e i valori inseriti non vengono applicati. |
| NativeNutritionQuickUITests/testRenderCocktailAndBoneInPortions | Errore riportato: Button legacy contro PopUpButton moderno; voce Con osso non trovata. Query aggiornata a tipo generico nel candidato successivo, non ancora eseguita nella suite restante. | Aprire davvero il selettore e scegliere Con osso; comparsa della parte edibile stimata obbligatoria. |
| NativeNutritionQuickUITests/testSupermarketFoodsAndSupplementEditor | Analoga incompatibilità del tipo AX per il picker famiglia. Query `.any` attuale mantiene le asserzioni funzionali ma non è ancora validata in questo percorso. | Selezione Integratori, unità per capsula, salvataggio e successiva porzione funzionano. |
| NativeRevision78UITests/testSafeAreaLastContentStandard | La nota finale della fixture non viene raggiunta. | Scorrimento reale fino all’ultima nota senza intercettare barra o controlli. |
| NativeRevision78UITests/testSafeAreaLastContentLargeText | Stessa anomalia con testo grande. | Ultima nota raggiungibile con testo accessibile, senza ridurre le asserzioni. |

### Ipotesi da non trasformare in fatti

Il gap Bloom è una spiegazione plausibile dei drag mancati, non una causa ancora dimostrata: entrambi i probe devono essere eseguiti. Il problema di aggiornamento dei contenitori può spiegare alcune regressioni di navigazione/rendering, ma necessita di un confronto mirato dopo la modifica. La sola riuscita di un tab diretto non dimostra il percorso attraverso Dashboard e ritorno da una sheet.

## Cross-review dei ritocchi al movimento

Riletti `NativeComponents.swift`, `NativeMicronutrients.swift`, `NativeHealthViews.swift` e la cancellazione di `NativeTabArrival` in `App.swift`.

- Spunte, numeri e pressione condivisi usano tempi espliciti coerenti; le protezioni Reduce Motion sono mantenute.
- Il riordino micronutrienti e i due cambi di periodo dei grafici disabilitano l’animazione quando richiesto. Ordinamento, dati e selettori non vengono sostituiti da animazioni decorative.
- L’ingresso delle sezioni cancella la Task precedente, controlla la cancellazione dopo lo yield e ripristina lo stato quando scompare o si attiva Reduce Motion. Non risultano nuovi `repeatForever`, ritardi arbitrari o stagger globali nei ritocchi esaminati.
- Non ho identificato in questi ritocchi un difetto minore certo da correggere ulteriormente. Il primo ingresso di un host e il ritorno in un host conservato possono avere percorsi di lifecycle differenti: devono essere valutati a runtime senza assumere che ogni cambio sezione produca la stessa transizione.

L’inventario di `MOTION-REVIEW-2026-11-14.md` è un riepilogo descrittivo: alcune espressioni sono tradotte come `withAnimazione` e non vanno confuse con frammenti Swift letterali compilabili. Nessuna misurazione FPS, fluidità fisica o accettazione iPhone viene dedotta dall’inventario.

## Validità di test e confezionamento

- Una modifica al prodotto o all’assemblaggio invalida il precedente riuso di due UI basato su identità del prodotto. Non allentare quel controllo per recuperare un gate verde.
- Quando cambiano solo un test e nessun suo helper condiviso, il riuso può essere ammesso soltanto con confronto rigoroso di sorgenti ed evidenze e con provenienza aggregata esplicita.
- In presenza delle regressioni sopra, le prove mirate devono includere i casi che sono realmente falliti, non solo i tre percorsi iniziali. Una suite completa successiva deve evitare duplicazioni dei casi già coperti sullo stesso candidato.
- Quattro avvii Release, confronto del pacchetto con il commit provato, checksum e versione/build restano requisiti separati. Non esiste ancora evidenza di una nuova IPA 90 pubblicata e verificata.
- Installazione senza perdita dati, HealthKit fisico, firma/App Groups/widget, AlarmKit/suono e accettazione restano attività da verificare sul dispositivo.

## Cross-review delle correzioni in preparazione

Il coordinatore ha assegnato a un altro agente una correzione del hit testing della barra e del controllo delle generazioni del contenitore; un agente distinto prepara un gate mirato esteso. Questo documento non ne assume il successo. La versione finale delle modifiche va riletta prima del commit e il nuovo risultato runtime deve essere acquisito prima di dichiarare risolti i problemi.


### Cross-review conclusiva del working tree prima del nuovo run

Riletti i cambi finali a `NativeSixTabBar.swift`, `NativeTabHitRegionUITests.swift`, ai due selettori nutrizionali e alla partizione del gate:

- La nuova `contentShape(.interaction, Rectangle())` è applicata dopo lo sfondo condizionale della label completa. Non altera ordine, geometria o azione delle destinazioni; rende esplicita la superficie interattiva finale. È una correzione plausibile da verificare con il test di tocco, non una prova già acquisita della causa del precedente tap perso.
- Il contatore di generazione viene incrementato prima del ritorno anticipato per ambiente uguale. Così la sequenza valore A → B accodato → A invalida correttamente B, invece di pubblicare successivamente preferenze ormai obsolete. Il contenuto conservato non viene sostituito.
- I due nuovi test dei target riproducono per primo il tocco al centro del Calendario su avvio fresco, poi verificano centro, icona e didascalia per ciascuna destinazione; con testo accessibile non cercano didascalie volutamente nascoste. Dopo ogni gesto richiedono sia selezione sia contenuto della destinazione. La gerarchia reale dell’ultimo run contiene le icone e le didascalie usate dalle query normali.
- I picker nutrizionali sono individuati per identificatore senza fissare il ruolo AX legacy Button. Le voci conservano label esplicite e le prove verificano il risultato concreto; non è stato sostituito il flusso utente con chiamate interne.
- Il gate aggiornato contiene 5 UI compatti e 14 UI sul principale, inclusi tutti i 12 precedenti fallimenti e i due probe Bloom. Il passaggio alle prove restanti è subordinato a tutte queste verifiche; i casi coperti sono esclusi dalla fase restante. La provenienza dichiarata è fresca, con zero UI storici riutilizzati.

In questa cross-review non ho individuato ulteriori errori concreti che impongano di bloccare il nuovo tentativo. Non equivale a una compilazione o a un successo dei test: hit testing, primo accesso, navigazione e assenza dei blocchi restano da dimostrare nel nuovo run. La sola riuscita dei primi cinque UI non è sufficiente a dichiarare risolti i problemi presenti nella fase dei quattordici regressivi.


## Diagnosi del run 43623029267 — 14 novembre 2026

Sorgente provato: `0de02872e459f4cb3cfe56684ed83d1cd8d66941`. Compilazione passata, preflight compatto 2/5 UI passati e 3 falliti; quattordici regressioni principali, suite restante, quattro avvii Release e IPA non eseguiti. Artefatti: diagnostica 14125792401, evidenze 14125637973.

Passati catalogo Integratori/ricerca e tutti i 18 tap normali (centro, icona, didascalia delle sei destinazioni). Anche i sei centri con testo grande passano prima del fallimento della query Image. La navigazione normale supera Calendario diretto/palette, Salute, conservazione palette e mese Finanza; fallisce Calendario aperto dalla Dashboard (linea 73). La gerarchia 8EFAC26D mostra ancora dashboard-scroll e Dashboard selezionata. La radice memorizzata conteneva NavigationStack costruito fuori dall'host osservante: estratto NativeDashboardStack con propria osservazione del router e percorso, senza ripubblicare il contenuto di ogni tab.

Due ulteriori errori dei test: query Image figlia assente nel pulsante icon-only grande; controllo immediato isSelected dopo tap Salute. Il primo viene allineato al centro dell'icona visibile (coincide col centro pulsante); il secondo usa attesa condizionata del medesimo tap nativo, senza retry, con diagnostica se la selezione non arriva. Questo non dimostra ancora che il tap grande funzioni: il nuovo run deve confermarlo. Le verifiche di contenuto e conservazione stack restano obbligatorie.

Due sottoagenti hanno separato diagnosi contenitori ed evidenze/test. Correzione nel perimetro funzionale già approvato. Nessun aumento dei timeout di blocco calendario, nessun riuso dei risultati precedenti dopo modifica prodotto, nessun deploy backend e nessuna IPA90 prodotta. Prossimo gate invariato: 5 compatti, 14 regressioni, restante suite, 4 Release, poi IPA autorizzata solo se tutto passa.

Aggiornamento dopo esame del video grande: l'ultimo fotogramma resta su Attività dopo il tap Salute; non è dimostrato un semplice ritardo. La nuova attesa resta una verifica rigorosa, senza secondo tap. Si prova una singola variabile del prodotto: disattivare la reazione interattiva del vetro dell'intera barra, mantenendo Liquid Glass e le azioni dei sei pulsanti. È un'ipotesi di interferenza nei gesti da discriminare, non una causa già dimostrata. La documentazione Apple ammette vetro interattivo sui contenitori: non si dichiara l'API usata scorrettamente ([WWDC25, Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)). Traccia dei tap solo nelle fixture DEBUG per distinguere mancata azione da cambio/reset del router. Il prossimo risultato deve confermare attivazione con tap nativo e contenuto, oltre allo stack Dashboard.
