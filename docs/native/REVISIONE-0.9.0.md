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

# LifeOS 0.9.0 build 41 — microinterazioni moderate

Intervento sui componenti UI condivisi: feedback di pressione già esistente esteso a icone, selettori mese/categoria e controlli Home; sostituzione breve del simbolo di completamento; dissolvenza di sfondo/bordo nella selezione dei chip; transizione numerica per MoneyText e budget in Home/Finanza. Durate condivise esistenti: 0,16–0,18 secondi. Feedback tattile di selezione soltanto sul tocco delle spunte e sul cambio esplicito di categoria; non su refresh o caricamenti. La spunta cambia solo con lo stato effettivo, senza simulare il successo della scrittura. Il feedback di successo delle abitudini rimane quello precedente e non è duplicato.

Nessuna animazione globale, ritardo nelle azioni, ripetizione decorativa, movimento della griglia, transizione delle liste o sostituzione delle animazioni native di tab, fogli, tastiera e controlli dei Form. I pulsanti indipendenti delle checklist mantengono lo stile borderless per evitare di coinvolgere l’intera riga. Riduci movimento disabilita le animazioni custom spaziali, dei simboli, dei numeri e dei colori; la pressione conserva soltanto il feedback di opacità immediato. I feedback aptici sono affidati alle API di sistema. Quando gli importi sono nascosti la transizione è disabilitata immediatamente.

Aggiunta una modalità DEBUG --reduce-motion che imposta solo l’ambiente SwiftUI e non altera le preferenze del dispositivo; le altre esecuzioni e la release rispettano le impostazioni reali. Nuovo test UI per cambio categoria, completamento separato dall’apertura, navigazione e inserimento spesa con l’override attivo. Non equivale a una prova fisica delle animazioni native o dell’aptica.

Verifiche eseguite: parser Swift su tutti i sorgenti e test, controllo design system e integrità ZIP. Test UI aggiunto ma non ancora eseguito; build Apple e IPA non ancora verificate. La precedente suite locale di 53 test riguarda modelli rimasti invariati, non verifica queste animazioni. Layout, colori, badge del Calendario e sincronizzazione invariati rispetto alla build 40; non è stato implementato un nuovo effetto vetro sui badge.

Il fallimento Apple della build 39 rimane da diagnosticare dai log: non è dichiarato risolto da questa modifica. L’accesso API resta un prerequisito per leggere log e artefatti da questa macchina.

---

# LifeOS 0.9.0 build 40 — settimana Home allineata al Calendario

La settimana della Home riusa direttamente CalendarDayCell e CalendarDayPresentation: badge pieni dei turni, colori, sfondi weekend, bordo del giorno corrente, puntini e opacità tra mesi sono gli stessi del Calendario. Conserva sette giorni con oggi al centro e il tocco per aprire il giorno nel Calendario. Nessun nuovo stile parallelo.

Il file CalendarScreen.swift cambia soltanto due dichiarazioni da private a internal per rendere riusabili i tipi: layout e comportamento del Calendario restano invariati. Il controllo di packaging confronta il file con la base normalizzando esclusivamente queste due dichiarazioni. NativeStore e NativeDesign restano identici.

Verifiche specifiche: parser Swift su tutti i sorgenti e test, controllo design system e integrità dell’archivio. Nessuna modifica ai modelli coperti dai 53 test locali precedentemente superati. La verifica iOS della build 40 resta da eseguire. Il fallimento della build 39 sotto documentato rimane da diagnosticare: non attribuire a questa modifica una correzione non dimostrata.

---

# LifeOS 0.9.0 build 39 — verifica Apple fallita, nessuna IPA

Base: 0.8.2 build 38, main 83ff3f35789b2906b7c090292e92575f29f5211c. Richiesta del 16 ottobre 2026.

## Risultato implementato

Finanza usa una panoramica aperta senza card: selettore mese, budget rimanente, disponibilità giornaliera e saldo attuale separato. Conserva palette platino, tipografia semantica e componenti del design system corrente. Azioni da sinistra: Budget, Extra, Spesa (prima da destra). Movimenti direttamente sullo sfondo; accesso all’elenco completo e ai filtri. Ripartizione stipendio, ricorrenti e obiettivi sono in Budget; storico e previsione sono in Analisi, accessibile nella barra superiore. Extra conserva navigazione mensile e operazioni esistenti. Nessuna modifica ai calcoli finanziari o al backend.

La barra inferiore è il TabView Apple a quattro destinazioni, con effetti di sistema su iOS 26; non nasconde più la tab bar per disegnare capsule e animazioni sostitutive. Il + contestuale torna nella barra superiore; Extra espone il proprio +. Nessun tab di ricerca fittizio o quinta destinazione.

Home recupera una riga discreta con nome italiano e ora (es. Pomeriggio · 16:42); dopo l’ultimo orario mostra Domani. Nessun riferimento religioso o nome arabo nell’interfaccia. Il dettaglio Orari mostra i cinque orari locali di Empoli, escludendo l’alba. Riusa senza variazioni il calcolo locale già presente; non introduce servizi, posizione GPS o costi. Il dato rimane indicativo, non una nuova certificazione del metodo astronomico.

Nella build 39 CalendarScreen.swift era identico alla build 38; NativeStore.swift e i contratti di sincronizzazione sono identici. La barra globale nativa sostituisce quella personalizzata anche quando è aperto il Calendario.

## Verifiche della sessione

53 test XCTest di modelli e azioni demo eseguiti con Swift 6.2.1 su Linux, senza adattare i sorgenti selezionati: 0 errori. Inclusi nuovi casi per budget negativo/mancante, saldo corrente distinto dal mese selezionato, giorni di mesi passati/futuri e prossimi orari su cambio anno, anno bisestile e cambio DST. Questa suite non include NativeStoreTests o test UI.

Parser Swift eseguito su tutti i sorgenti e test; controllo design system passato. Archivio verificato con SHA-256 e CRC; CalendarScreen e NativeStore confrontati byte per byte con la base. UI test aggiornati ai nuovi percorsi, con casi Dynamic Type, snapshot vuoto, azione Spesa a destra, tab bar nativa e aggiunta ripetuta.

Run Apple: https://github.com/azeroualit-cloud/LifeOS/actions/runs/38908116463, codice 10c8dd1099fa6a2a806dbaaada304537c09aaf33. Preparazione, design system, generazione Xcode e contratto API condiviso riusciti. La fase Compila ed esegui tutti i test è fallita con exit code 65 dopo circa 24 minuti; la pagina pubblica non identifica la verifica fallita. Schermate e diagnostica sono state caricate (LifeOS-anteprima, LifeOS-anteprima-principale, LifeOS-diagnostica). Test compatti, archive e caricamento IPA saltati: nessuna nuova IPA consegnabile.

Il dettaglio del fallimento non è diagnosticato: i log richiedono autenticazione GitHub e api.github.com è escluso dalla policy di rete dell’ambiente. Git read e push funzionano tramite il proxy, ma non provano accesso API. L’aggiunta del dominio è salvata nella bozza; non è applicata al runtime. Dopo l’applicazione nelle impostazioni, ritestare l’accesso esistente prima di chiedere nuove credenziali. In alternativa il tests.log nell’artefatto diagnostico consente la diagnosi se fornito dall’utente. Non alterare le asserzioni né indovinare una correzione senza il risultato preciso. Non avviare la stessa build senza cambiamenti giustificati.

La versione installabile di riferimento resta 0.8.2 build 38. Nessun risultato storico viene attribuito a questa build. Installazione e animazioni fisiche richiedono comunque la prova su iPhone dopo una nuova build verificata.
