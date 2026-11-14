# Revisione animazioni e dettagli LifeOS — 14 novembre 2026

## Ambito e prova disponibile

Revisione assegnata esplicitamente a un agente dall’utente: «rifai un check di tutte le animazioni valutale con un agente e migliora i dettagli minori di tutta l’app». Letti AGENTS e registro in entrambi i formati; rispettati HEALTH-WEEK-REVIEW-01, Reduce Motion e le sei destinazioni già approvate. Nessun cambiamento a struttura, ordine, dati o logica di prodotto.

**Questa prima valutazione riguarda il codice, non la fluidità osservata sul dispositivo.** Sono stati controllati durate, cancellazione, transazioni e accessibilità. Non sono stati misurati FPS né dichiarati superati controlli fisici. Le vecchie catture restano riferimenti sul relativo codice, non prova delle modifiche nuove.

## Ritocchi applicati

- `NativeComponents.swift`: animazioni predefinite di spunte e cifre sostituite da `easeOut(selectionDuration)` (0,16 s), coerente con gli altri comandi. Nessuna nuova scala o animazione sull’intera pagina; Reduce Motion continua a disabilitare transizione e transazione numerica.
- Stesso file: opacità di pressione dei pulsanti primari compatti (aggiunta nutrizione/import Bloom) con rilascio breve e uniforme. Sotto Reduce Motion resta immediata. Stati disabilitati, geometria e aree tattili invariati.
- `NativeMicronutrients.swift`: riordino con `easeInOut(layoutDuration)` (0,26 s), oppure nessuna animazione con Reduce Motion. Ordinamento e persistenza invariati.
- `NativeHealthViews.swift`: i due cambi di periodo dei grafici peso/previsione ed energia usano una durata esplicita di 0,26 s. Conservate le protezioni Reduce Motion, la selezione e lo scorrimento.

Questi cambiamenti toccano componenti condivisi del prodotto: **il controllo di riuso “prodotto identico” deve rifiutare i vecchi due risultati UI**. Non allentarlo per dichiararli validi. Servono nuove prove mirate dei percorsi interessati. Le prove storiche sui dati non dimostrano il nuovo movimento.

## Valutazione per area

| Area | Valutazione del codice | Controllo visivo necessario |
| --- | --- | --- |
| Dashboard | Transizione locale della fase, breve e protetta; niente animazione globale ad ogni minuto del TimelineView. La barra turno interpola la frazione e usa il ledger per limitare il richiamo all’attivazione. | Cambio fase/ritorno in primo piano: nessuna pulsazione ripetuta in ciclo. |
| Attività | Espansione completate e lista a 0,26 s; spunte e pressione condivise. Nessuno stagger o repeatForever trovato. | Completamento rapido, tastiera, focus e Reduce Motion. |
| Salute | Cambio giorno a 0,16 s, grafici a 0,26 s, numeri e riordino protetti. | Cambio periodo, selezione e scroll verticale insieme; testo grande. |
| Bloom | Sezioni mantenute e commutate con visibilità/hit testing. Gallerie, MapKit e ricerca usano movimento di sistema; import usa il ritorno condiviso. | Ricerca nativa, chiusura tastiera e passaggi fra sezioni; non aggiungere transizioni decorative. |
| Finanza | Numeri condivisi, nessun involucro animato globale su liste o analisi. | Importi lunghi, mascheramento, cambio mese e analisi. |
| Calendario | Giorno/mese direzionale a 0,30 s; selezione/cambio turno a 0,16 s. Palette protetta anche a testo accessibile. | Ritorno al giorno/mese, pittura rapida e annullamento, testo grande e Reduce Motion. |
| Sei sezioni | Haptica locale; ingresso direzionale in App.swift. | Segnalata al coordinatore la Task d’ingresso non cancellabile che poteva terminare dopo un altro cambio sezione; App.swift è di sua competenza. |
| Impostazioni, moduli e fogli | Presentazioni, tastiera, alert e selettori nativi; comandi con stili condivisi. | Apertura/chiusura e tastiera, evitando sostituzioni dei comportamenti nativi. |
| Widget | Nessuna animazione custom nella proiezione snapshot; aggiornamenti gestiti da WidgetKit. | Prova iPhone/App Group separata. |

## Inventario completo dei siti espliciti

Ricerca su tutti i sorgenti Swift canonici: `withAnimation`, `.animation`, `.transition`, `.contentTransition`, `.sensoryFeedback`. Sono presenti 30 siti espliciti al momento dell’ispezione. Colori/opacità statici non sono animazioni; le transizioni di NavigationStack, sheet, fileImporter, TabView, MapKit, gallerie e tastiera sono native e incluse nella matrice sopra. Le righe si riferiscono al working tree: il coordinatore conserverà il commit effettivamente provato.

| Sorgente (working tree) | Type | Espressione |
| --- | --- | --- |
| `App.swift:352` | Animazione | `withAnimazione(.easeOut(duration: NativeDesign.Motion.selectionDuration)) {` |
| `CalendarScreen.swift:49` | Transition | `.transition(reduceMotion ? .identity : .move(edge: .trailing).combined(with: .opacity))` |
| `CalendarScreen.swift:54` | Animazione | `.animation(reduceMotion ? nil : .smooth(duration: NativeDesign.Motion.navigationResponse), value: showingDay)` |
| `CalendarScreen.swift:55` | Feedback aptico | `.sensoryFeedback(.selection, trigger: selected)` |
| `CalendarScreen.swift:491` | Animazione | `Button { withAnimazione(reduceMotion ∣∣ typeSize.isAccessibilitySize ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration)) { painting.toggle(); brush = painting ? "morning" : "consult" } } label: { Label(painting ? "Fine" : "Dipi` |
| `CalendarScreen.swift:593` | Animazione | `.animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: active)` |
| `CalendarScreen.swift:594` | Animazione | `.animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: item.shift)` |
| `DashboardScreen.swift:32` | Feedback aptico | `}.sensoryFeedback(.success, trigger: routineFeedback)` |
| `DashboardScreen.swift:118` | Transition | `.transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: NativeDesign.Motion.pressedScale)))` |
| `DashboardScreen.swift:120` | Animazione | `}.animation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration), value: model.phase)` |
| `NativeComponents.swift:41` | Animazione | `.animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: configuration.isPressed)` |
| `NativeComponents.swift:124` | Animazione | `.animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: configuration.isPressed)` |
| `NativeComponents.swift:149` | Transition | `.contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))` |
| `NativeComponents.swift:150` | Animazione | `.animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: checked)` |
| `NativeComponents.swift:165` | Feedback aptico | `.sensoryFeedback(.selection, trigger: touchFeedback)` |
| `NativeComponents.swift:192` | Animazione | `.animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: completed)` |
| `NativeComponents.swift:212` | Animazione | `.animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: configuration.isPressed)` |
| `NativeComponents.swift:288` | Feedback aptico | `.sensoryFeedback(.selection, trigger: touchFeedback)` |
| `NativeComponents.swift:388` | Transition | `content.contentTransition(reduceMotion ∣∣ !enabled ? .identity : .numericText())` |
| `NativeComponents.swift:389` | Animazione | `.animation(reduceMotion ∣∣ !enabled ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: value)` |
| `NativeHealthSummary.swift:185` | Animazione | `withAnimazione(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.selectionDuration)) { selectedDate = next }` |
| `NativeHealthViews.swift:240` | Animazione | `.animation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration), value: period)` |
| `NativeHealthViews.swift:307` | Animazione | `.animation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration), value: period)` |
| `NativeMicronutrients.swift:278` | Animazione | `withAnimazione(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration)) { editMode = editMode.isEditing ? .inactive : .active }` |
| `NativeShiftProgressBar.swift:18` | Animazione | `}.animation(reduceMotion ? nil : .smooth(duration: NativeDesign.Motion.layoutDuration), value: fraction)` |
| `NativeShiftProgressBar.swift:26` | Animazione | `withAnimazione(.easeOut(duration: 0.16)) { pulse = 1 }` |
| `NativeShiftProgressBar.swift:28` | Animazione | `withAnimazione(.easeOut(duration: 0.24)) { pulse = 0 }` |
| `NativeSixTabBar.swift:19` | Feedback aptico | `.sensoryFeedback(.selection, trigger: selection)` |
| `TasksScreen.swift:50` | Animazione | `withAnimazione(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration)) { completedExpanded.toggle() }` |
| `TasksScreen.swift:76` | Animazione | `.animation(reduceMotion ? nil : .easeInOut(duration: NativeDesign.Motion.layoutDuration), value: store.tasks)` |

## Campione runtime storico effettivamente ispezionato

Acquisite le registrazioni del run **43522275345**, sorgente **47cc00e** (prodotto equivalente ad aa3fb83, prima dei ritocchi del 14 novembre). Esaminati fotogrammi sequenziali estratti con ffmpeg: non è una misurazione dei frame persi o della latenza tattile. Percorso locale esterno al repository: `work/audit78/final-2026-11-14/validation/final-screenshots/Final/`.

| Caso / registrazione | Cosa è osservabile | Conclusione limitata |
| --- | --- | --- |
| `testSafeAreaLastContentStandard` — `69A5557B-9744-4F83-9FE8-F9E4DF24F006.mp4` | Dashboard, ingresso Bloom e tentativi ripetuti di scorrere le prime card. | La griglia resta ferma sulle prime card: va diagnosticata come problema di interazione/contenimento, non “risolta” aggiungendo un’animazione. |
| `testSafeAreaLastContentLargeText` — `6D8B62C7-A901-476F-92BF-D62AD6F39AE2.mp4` | Dashboard, Salute, azioni inferiori, Bloom a testo grande. | Le sei icone rimangono presenti; la registrazione termina sullo stesso blocco di scorrimento Bloom. Non dimostra la leggibilità di ogni modulo né fluidità universale. |
| `testMixedLibraryStaysInTwoColumnsAndShowsLinkPreviews` — `E280EB85-EAE0-4F54-84A9-FB4516B2E4CD.mp4` | Ritorno da Apple Salute alla Dashboard all’inizio del filmato. | La clip è corta e non fornisce un ciclo completo di animazioni Bloom; nessuna valutazione di timing deducibile. |
| `testFinanceMonthButtonsMoveIndependentlyInBothDirections` — `76EA60F9-248B-4D90-A65B-1BFFDB1C3EEF.mp4` | Dashboard → Finanza → dettaglio Budget/Ottobre. | Sequenza da correlare al log del test: non attribuire il cambio di destinazione a un’animazione decorativa e non dichiarare provati entrambi i versi del cambio mese. |
| `testRenderCocktailAndBoneInPortions` — `64219916-EBBC-4EC9-9265-AF9E17E3327E.mp4` | Apertura nutrizione, selezione, catalogo con tastiera visibile e testo digitato. | Il campione mostra il percorso di presentazione/ricerca; non verifica ancora le nuove durate dei pulsanti o i calcoli del test fallito. |

L’audit dei sorgenti copre tutte le aree; la valutazione runtime disponibile è **parziale** e riguarda il vecchio codice. Attività, Calendario, impostazioni, tutti i percorsi di riduzione movimento e le modifiche nuove richiedono la nuova cattura mirata. Il coordinatore ha separato le nuove regressioni di scroll/interazione dalla richiesta di rifinitura e gestisce le proposte DEV-02.

## Verifica mirata suggerita

- Nuovo giro registrato attraverso le sei sezioni, cambi rapidi avanti/indietro e riapertura dei fogli; il task d’arrivo cancellabile è gestito dal coordinatore in App.swift.
- `NativeInterfaceTests/testReducedMotionKeepsChecklistAndFinanceActionsFunctional` per completamento e Finanza sotto Reduce Motion.
- `NativeRevision71UITests/testReducedMotionAndLargeTextKeepMonthDayAndEditorUsable` per Calendario e editor con testo grande.
- Riordino Micronutrienti e cambio periodo grafici: verificare movimento normale e ridotto, con scorrimento verticale e selezione ancora funzionanti.
- Pressione e rilascio di Aggiungi nutrizione e Importa Bloom; nessun salto di dimensione, area tattile invariata, feedback disabilitato leggibile.
- Confrontare su video i ritocchi nuovi prima di giudicarli riusciti. Le screenshot statiche dimostrano la geometria, non la qualità temporale.
