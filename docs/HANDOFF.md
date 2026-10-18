# Revisione coerenza web / iOS — 17 ottobre 2026

Lavoro nel ramo fix/platform-parity, basato sulla versione Piani v2 effettivamente installata. Diagnosi, flussi modificati e limiti in [PLATFORM-PARITY.md](PLATFORM-PARITY.md). 34 test server, 103 Foundation, 9 modelli web e confronto diretto JS/Swift superati localmente; due suite browser verificano il bundle realmente servito. Il 18 ottobre, dopo autorizzazione esplicita, pubblicato il ramo e generata IPA 0.9.5/56 nel run 39081406881. Pacchetto scaricato/verificato, provenienza in backend/plans/IPA-build56.json. Raw fissato al commit sorgente 48693689cf2449e41a85c7342022db9aa5fc9928 e riscaricato con checksum identico. Worker CI 39081388607 riuscito; test Apple nel run 39081388601 riusciti: 122 unitari e 7 UI. Nessun deploy Cloudflare eseguito. L’errore della foto è riproducibile sul Worker precedente: anche il gateway configurato nell’app deve includere Piani v2, non basta aggiornare il Worker web.

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

# Revisione grafica richiesta il 14 ottobre 2026

Nas ha fornito un riferimento visivo e segnalato tremolio/lag ai limiti dello scorrimento, comandi poco curati e difficoltà ad aggiungere eventi. I test funzionali svolti dall’utente risultano passati. Richiesta: correggere l’intera interfaccia e consegnare una sola IPA finale, evitando installazioni intermedie.

La revisione 0.3.1 build 8 usa titoli inline, tab bar sempre espansa, ricerca nel contenuto e niente pull-to-refresh nelle quattro sezioni. Calendario eager separato dalla List, comandi sopra la tab bar; palette originale leggermente più satura. Dashboard con settimana e schede compatte, Finanza con asse giornaliero numerico. Modelli finanziari e API preservati.

Build 6: run 38560845482 riuscito, 31 test unitari + 9 UI su iPhone 17 Pro + 3 UI su iPhone SE, contratto API e archive riusciti. Screenshot ispezionati e IPA verificata. Build 8 definitiva: run 38567922673 riuscito, 43 esecuzioni di test senza errori, API condivise e archive riusciti, IPA verificata per integrità, versione e arm64. Artefatto 11897507875. Consegnare soltanto questa build; prova fisica ancora necessaria.

Documenti di revisione: docs/REVISIONE-0.3.1.md; prova mirata: docs/PROVA-0.3.1.md. Fluidità sul dispositivo fisico distinta dalle prove di navigazione e geometria nel simulatore. Nessun Worker o dato reale modificato da questa revisione.

# Priorità attuale — 14 ottobre 2026

Nas ha autorizzato esplicitamente: sincronizzazione più rapida, diagnosi timeout, unica fonte dati per app e web e revisione grafica completa, con risposta finale soltanto dopo una build verificata e istruzioni per i test sul dispositivo. Questa richiesta supera il precedente divieto di usare il database principale: la prova è passata al collegamento condiviso autorizzato. Non avviare nuove copie come fonte attiva.

Fonte unica attiva: D1 `liquidita-4-prova`, UUID `a90a8c6d-d6eb-4dc6-8fdb-382e4ad4485a`. Il Worker web `lifeos` conserva codice e protezione Cloudflare Access originali; il gateway app `lifeos-native-test` ora punta allo stesso D1 con la password dedicata già configurata. La vecchia copia e `lifeos-before-shared-v1` sono archivi di sicurezza, non sorgenti sincronizzate. Modifiche app riconciliate con controlli sulle righe e backup. Verifica: https://github.com/azeroualit-cloud/LifeOS/actions/runs/38544717558 .

# Contesto di continuità

## Richiesta successiva di Nas: intera app nativa

Nas ha installato il prototipo tramite GitHub Actions e Signulous. Il selettore JSON rimane aperto dopo il tocco di un file estratto e selezionabile; non chiedergli di ripetere quel gesto. Ha ora richiesto di avviare l'intera app con le quattro sezioni Life OS e grafica Apple, e di provare una sola IPA integrata. Questo è un ampliamento esplicito e prevale sul precedente limite della prova SwiftUI. HealthKit resta escluso. Stato e verifiche sono in docs/STATUS.md; attività da completare in docs/TODO.md. Non richiedere installazioni intermedie delle singole sezioni.

## Obiettivo più recente visibile

Il 12 ottobre Nas ha approvato la prova di Life OS in SwiftUI per verificare se l'esperienza su iPhone migliori rispetto alla PWA. Ha già chiarito che questa prova non valida HealthKit. Il prototipo recuperato copre Panoramica, inserimento spesa e Movimenti; il suo README descrive funzioni, procedure e verifiche ancora mancanti.

Non ampliare implicitamente la prova a una riscrittura completa di Life OS.

## Correzioni successive al documento allegato

Dal contesto delle chat visibile, l'8 ottobre sono state richieste:

- spostare i contenuti Budget in Panoramica per eliminare la ridondanza;
- calendario senza gradienti, sfondo più scuro per sabato e domenica;
- colori turni forniti in un'immagine, adattati al tema scuro;
- correzione dei pulsanti che si bloccano, incluso l'inserimento spesa.

Sono richieste documentate nel contesto, non una certificazione di ciò che è implementato. L'immagine dei colori non è inclusa. Controllare web/worker.js prima di determinare cosa rimane da fare. L'accento salvia del documento del 7 ottobre non va imposto automaticamente alla 11.63: il README del prototipo riporta #a5aeed / #565f9c.

## Materiali

- web/worker.js: byte originali di Life-OS-11.63.txt, versione recuperata 31.
- native/: contenuto originale di LifeOS-Native-Prototipo.zip, senza modifiche.
- docs/LIFE-OS-PROJECT.md: allegato fornito in questa richiesta, conservato integralmente.
- docs/archive/: documentazione storica, utile come riferimento, non stato attuale.

## Mancanze e verifiche

Mancano l'export del database e la configurazione di distribuzione. Non è verificato che il Worker recuperato coincida con quello in produzione. La SHA-256 11.46 citata nel documento allegato non identifica la 11.63 inclusa.

In questa preparazione sono stati controllati contenuti e integrità dell'archivio. Non sono stati eseguiti build Swift, test iOS, accessi al database, sincronizzazioni o deploy. Le dichiarazioni di verifica presenti nei documenti originali descrivono sessioni precedenti.

## Prompt iniziale per Codex

Leggi AGENTS.md, docs/HANDOFF.md, docs/LIFE-OS-PROJECT.md e native/README.md. Riprendi la prova SwiftUI già approvata per confrontare Life OS nativo con la PWA su iPhone. Esamina prima il codice in native/ e web/worker.js, identifica lo stato reale e porta avanti il prossimo passo verificabile. Non ripartire da zero, non ampliare la prova a HealthKit e non usare il database principale per test sperimentali. Dichiara ciò che manca e non presentare come eseguite build o prove non effettuate.
