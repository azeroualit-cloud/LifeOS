## Revisione 53 — implementata, verifica Apple in corso

Icone scelte Budget C / Extra B / Spesa A, tradotte in tracciati vettoriali bianchi minimali (nessuna immagine generata inclusa nell’app) con Liquid Glass nativo sui pulsanti e fallback materiale. Movimenti ordinati per identificativo crescente di inserimento, dal più recente, inclusi i movimenti in coda; l’API non espone il timestamp di creazione, quindi non è stata inventata un’ora. Calendario diviso in due regioni indipendenti con pannello giornaliero ancorato e intestazione fissa; ritorno a oggi al cambio tab/riattivazione, preservando i tocchi espliciti dalla Dashboard. Su schermi compatti/testo grande il mese può scorrere nella sua regione senza spostare il pannello.

Dashboard: barra nel colore del turno, segmenti proporzionali da due ore (notturni e cambio ora inclusi), traccia grigia inattiva, piccolo scaling/schiarita/quattro particelle soltanto all’apertura e sull’ultimo blocco completato; memoria persistente e Riduci movimento. Aggiunti tre test del modello turno, uno dell’ordine di inserimento e uno UI sul pannello/calendario di oggi; quest’ultimo entra anche nella verifica compatta. Parsing Swift, design system e sintassi del workflow passati. Compilazione, test e schermate Apple ancora da verificare. Ultima IPA consegnata: build 52 sotto.

## Widget — build 52, IPA disponibile

**Build Apple e pacchetto IPA riusciti.** [IPA per Signulous](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41025472277/artifacts/12963700996) · [run finale](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41025472277). Versione 0.9.0 build 52, con estensione WidgetKit incorporata. Verificati integrità ZIP, versioni coerenti e binari arm64 di app/widget.

Copertura verificata: 82 unitari, 31 UI principali e 14 UI compatti. Gli esiti sono distribuiti tra esecuzioni: i controlli di provenienza confrontano tutti i file pertinenti e riusano solo suite passate su codice identico; l’ultima modifica riguarda esclusivamente i metadati della versione del widget. Nessuna asserzione funzionale rimossa. Dettagli ed esecuzioni: native/WIDGET-0.9.0-build52.md.

**Da verificare sul telefono:** firma Signulous con estensione e App Group conservati, comparsa del widget, layout 2×2 e azione + dalla Home. La prova fisica non è stata eseguita. Artefatto disponibile fino al 6 novembre 2026, ore 09:20 italiane. Aggiornare senza disinstallare.

## Webapp — revisione locale 17 ottobre 2026

Sorgente completo recuperato dal file allegato e versionato in `web/worker.mjs`, HTML leggibile in `web/app.html`. Palette platino, Finanza aperta senza card, Budget/Extra/Spesa (Spesa a destra), Budget separato, grafici esistenti in Analisi; calendario uniforme senza fondi weekend e selezione sul numero; più contestuale nell’intestazione e microanimazioni con Riduci movimento. Rimossi dalla UI il Sankey storico e il riepilogo annuale. Backend identico alla baseline allegata.

Build JavaScript/HTML e verifica Playwright su Chromium passate a 320, 375 e 1280 px senza errori JS o overflow nelle viste esercitate. Fixture locali, nessun test su dati reali. Screenshot dark in `web/previews`. Dettagli e limiti in `web/README.md`: parità funzionale completa Analisi ancora da implementare. **Non distribuito su Cloudflare**: token runtime assente; necessario confronto baseline/live prima del deploy. IPA 0.9.0 build 51 invariata.

## Consegna verificata — 0.9.0 build 51

**Build Apple riuscita, IPA unica disponibile.** [Pacchetto Signulous](https://github.com/azeroualit-cloud/LifeOS/actions/runs/38978815976/artifacts/12081542774) · [esecuzione CI](https://github.com/azeroualit-cloud/LifeOS/actions/runs/38978815976) · [istruzioni e prove](native/CONSEGNA-0.9.0.md).

Superate le suite: 74 unitari, 30 UI principali, 14 UI compatti (118 esecuzioni, zero fallimenti), oltre alla regressione isolata di Finanza. Archivio Release iOS e upload IPA riusciti. Codice verificato: `850862bea86cb6dc22ce057874e3057585883c24`; backend immutato. Aggiornare via Signulous senza disinstallare. Prova fisica ancora da confermare.

Le sezioni successive documentano le revisioni precedenti e i loro esiti intermedi.

## Build 51 — suite principale superata, verifica compatta di Finanza

Run 38973693215 sul commit 70787bb: compilazione Apple e prova geometria/tocchi toolbar superate; suite UI principale 30/30 superata e fase completa verde. Compatto: 13/14 superati; fallisce testFinanceOverviewSupportsLargeTextAndEmptySnapshot sull’assert expense.isHittable dopo sei swipe sempre verso l’alto. IPA correttamente non prodotta.

La nuova revisione modifica soltanto la prova di scorrimento e la priorità diagnostica CI: trascinamenti brevi, direzione scelta dal frame del controllo rispetto a navbar/tabbar, inversione se già superato. Un controllo visibile ma non premibile continua a fallire; restano premibilità, target minimo e verifica dell’editor aperto. Gli errori riportano argomenti e frame. L’ipotesi di overscroll resta da confermare con il test, non viene dichiarata una correzione del layout.

Verificato byte per byte: Sources, assets e project.yml identici al pacchetto della suite principale passata. Versione app invariata 0.9.0 build 51. La CI esegue prima questa regressione su SE 3, poi la suite completa e tutti i 14 test compatti, infine l’archivio/IPA. Nessuna asserzione tolta, nessuna modifica finanziaria, backend o Calendario. Conteggi XCTest normalizzati nelle annotazioni. Parsing e integrità ZIP superati; esito della revisione del test ancora pendente.

## Build 51 — contenitore toolbar e hit region reale

Seconda esecuzione isolata della build 50, run 38972277972: compilazione build-for-testing riuscita in 64 secondi. Il test dei bordi fallisce in 12,672 secondi sul primo punto superiore: primary-add AX frame (338,62,44,44), offset (0,-21.5). Quindi il frame minimo è rispettato, ma quel punto non esegue l’azione. L’ipotesi che il solo contenuto intrinseco da 44 punti bastasse è smentita. La prima esecuzione su main è rimasta nella fase combinata senza risultato; non se ne attribuisce la durata al codice senza log.

Build 51: i ToolbarItem su iOS 26 nascondono lo shared background; il pulsante usa stile plain, frame e contentShape espliciti da 44 punti e NativeGlass con il materiale interattivo Apple. Rimossa la misura intrinseca fixedSize e la scala custom da questi due controlli. TabView e navigazione rimangono nativi. La rimozione del contenitore condiviso è da confermare mediante la stessa prova, non assunta come risolutiva.

Le coordinate sintetizzate sono ora confrontate anche con screenPoint per escludere errori del riferimento del test. Conservati requisito geometrico, tocchi a ±21,5 punti, apertura/annullamento nei quattro tab, entrambi i temi e compatto. Su main viene integrata anche la diagnostica isolata: compilazione separata (limite 12 minuti), prova UI con timeout (limite fase 15 minuti), log e annotazioni sempre conservati. Suite completa, compatto e IPA restano obbligatori. Parsing, design system e integrità ZIP superati localmente; build Apple 51 ancora da verificare.

## Build 50 — causa verificata, controllo toolbar da 44 punti

Diagnosi Apple run 38967287251: la prova con tocchi reali fallisce a offset (0,-21.5) dal centro di primary-add, AX frame (334,66,48,36). L’area estesa ipotizzata non è sufficiente: è un problema concreto di tocco, non soltanto di misura del test. Non è stato abbassato il requisito.

I pulsanti + e Impostazioni riusano ora NativeIconButton (44×44, NativePressStyle) dentro NativeToolbarButton, un contenitore di dimensione intrinseca che evita la conversione del Button automatico nel piccolo bar item UIKit. TabView e toolbar restano di sistema. Nessuna dimensione aggiunta ai token e nessun backend modificato.

Ripristinata l’asserzione geometrica di almeno 44 punti sul + in tutti i tab e aggiunta anche a entrambi i controlli nella prova dei bordi. Restano i tocchi a coordinate indipendenti nei due temi e nel compatto, con apertura e chiusura degli editor. La diagnosi è verificata; la correzione attende esito Apple. Parsing Swift, design system e integrità ZIP superati localmente. IPA ancora pendente.

## Build 49 — diagnosi funzionale del bersaglio toolbar

Build 48: native + AX frame (334,66,48,36); controlSize(.large) non modifica l’altezza. Fallisce il confronto geometrico, non la compilazione. I tentativi sulla label non hanno risolto; nessuna IPA.

La sola geometria AX di un UIBarButtonItem non prova la sua hit area. Il test dei quattro tab ora apre e annulla ogni editor in entrambi i temi. Un nuovo test verifica realmente il requisito 44 punti con tocchi a coordinate assolute a 21,5 punti dal centro nelle quattro direzioni, per + e Impostazioni e per entrambi i temi. Ogni tocco deve aprire la destinazione corretta e consentire il ritorno. XCTest non sceglie il punto centrale del controllo. Nessuna riduzione della soglia per i componenti personalizzati. Il nuovo test gira anche su dispositivo compatto. La diagnosi dell’area estesa resta da confermare su Apple: un mancato tocco sarà un fallimento reale da correggere.

CI conserva prova toolbar e screenshot anche in caso di blocco iniziale, espone gli errori Swift/XCTest come annotazioni standard e prosegue alla suite completa, al compatto e all’archivio solo se le prove passano. Verificati localmente parsing, design system e integrità ZIP; verifiche Apple e IPA ancora pendenti.

## Build 48 — verifica mirata della dimensione toolbar

Il log completo della build 47 (logs_105592146763.zip) conferma compilazione riuscita, 74 unit test superati e 28/29 UI test superati. Il test home-next-time ora passa. Unico fallimento: testFourSectionsInBothThemes, area accessibile del + pari a 108 pixel (36 punti) anziché almeno 132 pixel (44 punti alla scala 3).

Il frame della label aggiunto in build 47 non è sufficiente a controllare la dimensione resa dalla toolbar. Build 48 richiede controlSize(.large) sui pulsanti nativi + e Impostazioni, mantenendo il frame minimo e lo stile automatico. Esito da confermare su Apple; non si assume risolto sulla sola verifica sintattica.

CI esegue prima lo stesso test dei quattro tab in entrambi i temi, poi l’intera suite se passa; nessun test o requisito minimo rimosso. Bundle Toolbar.xcresult e toolbar-tests.log inclusi nella diagnostica, messaggi UI distinguono larghezza e altezza. Parsing Swift, design system e integrità ZIP superati localmente. IPA non ancora disponibile.

## Build 47 — correzioni dai log Apple della build 46

Log ricevuto: logs_105535413044.zip, commit f2e145408fcae658e0ab5150798b4e980b22cfcf. Compilazione riuscita, 74 test unitari superati, 29 test UI eseguiti con due fallimenti; verifica compatta e IPA non prodotte.

- testFourSectionsInBothThemes: + restituisce 82 pixel anziché almeno 132 (44 punti con scala 3). Dimensione minima esplicita di 44 punti nella label del pulsante toolbar, applicata anche a Impostazioni; controlli e barra restano nativi.
- testHomeRestoresNeutralNextTimeWithoutArabicNames: il pulsante home-next-time non viene trovato dalla query Button. Rimossa la trasformazione accessibilityElement(children: .ignore) dal Button per mantenere la semantica nativa; nome accessibile neutro e identificatore conservati. La conferma della diagnosi richiede il nuovo test UI Apple.

Asserzioni UI conservate. Parsing Swift, design system e integrità ZIP superati localmente. Esito Apple della build 47 ancora da verificare; nessuna nuova IPA dichiarata pronta.

## Build 46 — correzione compilazione Riduci movimento

Il log Apple della build 45 fornito dall’utente identifica App.swift:190: tentativo di scrivere accessibilityReduceMotion, proprietà SwiftUI in sola lettura. Compilazione fallita; test non eseguiti e IPA non generata.

La build 46 usa una chiave scrivibile separata per il solo override DEBUG dei test. Tutti i componenti animati leggono la preferenza di sistema combinata con tale override; in Release vale esclusivamente la preferenza di sistema. Due test Apple verificano comportamento predefinito, attivazione e ripristino. Nessun cast forzato o modifica alle impostazioni del dispositivo.

Verificati localmente parsing Swift, design system e integrità ZIP; compilazione SwiftUI, nuovi test e IPA attendono CI Apple. I 58 test Foundation già superati non verificano questa correzione SwiftUI.

# Build 45 — Calendario compatto ispirato ad Apple

Applicato il nuovo riferimento fornito dall’utente: mese grande con anno secondario e frecce, Oggi e Dipingi turni, griglia compatta con divisori sottili fra settimane e dettagli giornalieri direttamente sullo sfondo. Badge colorati dei turni conservati. Selezione e indicazione di oggi sul solo numero, senza grandi fondi o bordi delle celle weekend. Il componente CalendarDayCell rimane condiviso con la settimana Home.

Altezza base delle celle 54 punti invece di 66, numero scalabile e griglia con dimensione dinamica limitata come prima. Cinque/sei righe non vengono espanse a tutta altezza: il dettaglio resta sotto nello stesso scorrimento. Le proporzioni metà/tre quarti sono un obiettivo visuale da verificare sui dispositivi; testo grande e schermi compatti possono richiedere scorrimento, senza tagliare i contenuti. Turno ed eventi hanno marker verticale e orario distinto; l’azione di completamento rimane separata dall’apertura dell’editor. Per eventi senza orario la dicitura è Tutto il giorno. Selezione immediata e indici mensili restano invariati, senza animazioni globali della griglia.

Aggiunto un test UI per ritorno a oggi e selezione del giorno; i test esistenti restano pertinenti per pennello/Annulla, scorrimento, apertura eventi, sei settimane e testo grande. Verifiche locali: parser Swift completo, design system e integrità ZIP. Confrontati palette turni, editor eventi e NativeStore con la base: invariati. Non è stato implementato un effetto vetro sui badge e non ci sono modifiche a dati o sincronizzazione.

Anteprima generata: /workspace/generated_images/exec-42375cf7-67d4-4266-bd71-955e80b56cfd.png. È un mockup concettuale, non una schermata del simulatore; i colori e i componenti effettivi sono quelli del codice condiviso. Verifica Apple e IPA restano pendenti; il blocco di accesso ai log delle build precedenti non è risolto da questa modifica.

# Build 44 — Analisi con quattro grafici

Analisi contiene soltanto Spese per categoria (selettore 3/6/12 mesi), Previsione patrimonio, Patrimonio e Stipendi per competenza, in questo ordine. Rimossi da questa vista anche Entrate/Uscite, Storico complessivo e Verifica dei dati; i dati restano invariati. La previsione mantiene il metodo e l’orizzonte esistenti; patrimonio e stipendi mostrano i dodici mesi fino al mese selezionato, con intervallo esplicito e stati vuoti.

Le categorie sommano realmente i totali mensili forniti dal server: periodo incluso fino al mese selezionato, aritmetica in centesimi e rettifiche firmate. Letture getFinanceData limitate ai mesi mancanti, sequenziali e cancellabili; cache di consultazione in memoria, senza sovrascrivere lo snapshot del mese aperto o generare scritture. Le generazioni di refresh non azzerano la cache storica né rilanciano 12 richieste: aggiornano l’analisi corrente. Aggiorna categorie svuota esplicitamente la cache. Cambio periodo/sorgente e risposte tardive sono controllati prima di mostrare il totale; un mese mancante non viene scambiato per zero. Offline lo snapshot non viene presentato come copertura completa di più mesi; la demo usa soltanto dati simulati disponibili ed è etichettata.

Verifiche locali: 58 XCTest passati, inclusi cinque nuovi test dell’aggregazione; parser Swift su sorgenti/test, controllo design system e integrità ZIP. Test UI aggiornato ai quattro grafici e ai tre intervalli ma non ancora eseguito; API live dell’aggregazione e build Apple non verificate in questa macchina. Il precedente blocco di accesso ai log GitHub rimane aperto; nessuna nuova IPA dichiarata pronta.

# Build 43 — rimozione Riepilogo annuale

Rimossa anche la sezione Riepilogo annuale da Analisi finanziaria. Dati annuali conservati per i grafici esistenti; nessuna modifica a calcoli, API o altre sezioni. Sintassi Swift e design system verificati; validazione Apple e IPA ancora pendenti.

# Build 42 — rimozione Investimenti storici

Rimossa esclusivamente la sezione Investimenti storici da Analisi finanziaria. Dati, API, altre sezioni e funzionalità finanziarie invariati. Controllo sintattico Swift e design system eseguiti; verifica Apple e consegna IPA ancora pendenti, con il precedente errore da diagnosticare.

# Aggiornamento — build 41: microinterazioni moderate

Implementate nei componenti condivisi: pressione, spunte, selezione e importi, con Riduci movimento e senza animare navigazione/liste/griglie globalmente. Dettagli in docs/native/REVISIONE-0.9.0.md. Parser e design check passati; test UI e nuova IPA non verificati. Il precedente fallimento Apple e l’accesso ai log restano aperti.

# Aggiornamento — build 40: settimana Home condivisa

Richiesta successiva: usare in Home gli stessi componenti e stili del Calendario. Implementata riusando CalendarDayCell; nessun cambiamento visivo al Calendario, solo visibilità internal dei tipi condivisi. Versione 0.9.0 build 40, verifiche locali di sintassi/design passate. Validazione Apple non completata; l’errore della build 39 richiede ancora i log GitHub. Nessuna nuova IPA verificata.

# Aggiornamento 16 ottobre 2026 — 0.9.0 build 39: verifica Apple fallita

Ultima consegna indicata nel passaggio di chat: 0.8.2 build 38 (commit 83ff3f3). La nuova modifica implementa Finanza senza card nel design corrente, Spesa a destra, prossimo orario neutro in Home e tab bar Apple. Calendario invariato. Dettagli e verifiche correnti in docs/native/REVISIONE-0.9.0.md; prova dispositivo in docs/native/PROVA-0.9.0.md. Run 38908116463 fallito nella fase compilazione/test con exit code 65. Test compatti e IPA saltati. Diagnosi bloccata dall’accesso ai log GitHub: api.github.com è salvato nella bozza di rete ma non ancora applicato. Non presentare questa revisione come consegnata e non rilanciare invariata. La build 38 resta il riferimento installabile.

---

# Life OS 0.4.0 build 11 — consegna verificata

Revisione del PDF di Nas del 14 ottobre 2026. Un'unica app con Dashboard, Attività, Calendario e Finanza, stesso bundle `com.nas.lifeos.probe` e archivio locale precedente. Aggiornamento tramite Signulous sopra l'app esistente, senza disinstallarla.

IPA: https://github.com/azeroualit-cloud/LifeOS/actions/runs/38592379062/artifacts/11909985517

Build riuscita: https://github.com/azeroualit-cloud/LifeOS/actions/runs/38592379062

Verificati 53 test Apple senza errori: 36 unitari, 14 UI su iPhone 17 Pro e tre UI su iPhone SE 3. Xcode 26.3, SDK iPhoneOS 26.2; archive iPhone riuscito. Contratto API sul database condiviso riuscito. In locale passati 35 test con adattatori Linux, esclusa la migrazione SQLite eseguita poi su Apple. Servizio meteo pubblico verificato con risposta reale.

IPA scaricata e controllata: ZIP e payload integri, versione 0.4.0 build 11, piattaforma iPhoneOS, binario arm64, minimo iOS 17. SHA-256: `f193cb1e78888ef1248b16fc3ad9f7c63deab400dd2a6358995efee9504daa02`. Artefatto disponibile fino al 21 ottobre 2026. Nessuna installazione intermedia richiesta.

## Risultato

- Turni con badge rettangolari e palette originale; eventi indicati anche nella settimana della Dashboard.
- Pennello visibile: scelta turno, assegnazione ai giorni, Annulla e Fine.
- Attività compatte, categorie scorrevoli, comando Riordina diretto e badge di scadenza.
- Dashboard con meteo attuale/minima/massima, prossimo cambio, prossimo orario discreto e progresso del turno durante il suo svolgimento. Routine prima della finanza.
- Patrimonio con fondo emergenza, altri risparmi e quota ancora da raggiungere; dettaglio al tocco. Traguardi automatici ogni 5.000 €, risparmio necessario diviso per i mesi fino a dicembre incluso quello corrente.
- Mesi precedente/successivo indipendenti, giorni coerenti con il periodo, budget e patrimonio distinti.
- Extra con pianificazione mensile, importo effettivo modificabile al pagamento, chiusura ciclo e quote basate sull'effettivo. Tastiera numerica con Fine per raggiungere il pagamento.
- Grafici con barre compatte, categorie leggibili e dettaglio espandibile.

## Dati e limiti

Sito e app mantengono l'unica fonte D1 attiva già collegata. Worker e dati reali non sono stati modificati da questa revisione. I test UI usano solo demo isolate; il controllo collegato verifica i contratti delle API. Refresh leggero per ambito, cache e coda idempotente restano attivi. Sul sito serve aggiornare la pagina; nessun push istantaneo.

Offline: nuove spese e creazione piani Extra supportate dalla coda esistente. Attività, eventi, modifiche dei movimenti e pagamento dei piani richiedono rete. Nessuna risoluzione automatica dei conflitti simultanei. HealthKit escluso, nessun nuovo servizio a pagamento.

Schermate ispezionate nei due temi, sui due formati e con testo grande. Fluidità fisica, firma Signulous e sessione sul dispositivo restano da confermare. Il precedente problema di importazione JSON sul telefono resta una verifica separata; non serve importare file per questo aggiornamento.

Prove: docs/PROVA-0.4.md. Dettagli: docs/REVISIONE-0.4.md.
