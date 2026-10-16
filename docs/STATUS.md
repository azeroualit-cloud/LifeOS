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
