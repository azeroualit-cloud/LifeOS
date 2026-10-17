# Coerenza web / iOS — 17 ottobre 2026

Base: `feature/plans-v2`, commit `21fb534`. Il sorgente installato della foto è in questo ramo, non in `main`.

## Errore Piani

Riprodotta la chiamata autenticata `POST /api/getFinancePlans ["2026-10"]` sul Worker precedente: HTTP 400, `Operazione non disponibile.`. Il bundle con adapter Piani restituisce HTTP 200, contratto versione 2 e gli stessi piani dell’overview. Il test D1 ora verifica esplicitamente questa route e l’header `X-LifeOS-Plans-Version: 2`.

L’app e il sito possono utilizzare lo stesso D1 attraverso Worker differenti. Aggiornare soltanto `lifeos` non aggiorna il codice di `lifeos-native-test`. Il Worker effettivamente configurato nell’app deve includere lo stesso adapter Piani. Il messaggio iOS identifica ora questa incompatibilità e mostra l’host collegato. Nessun errore viene convertito in una lista vuota o in una migrazione fittizia.

La distribuzione manuale scelta dall’utente rimane necessaria. Conservare binding DB, password, secret e protezioni Access esistenti. Non creare database nuovi, non cancellare marcatori e non registrare pagamenti di prova reali. Questa verifica locale non certifica il Worker già pubblicato.

## Contratto condiviso

`shared/platform-contract.json` definisce categorie spesa/entrata, ordine ed etichette dei sei tipi di piano, stati e messaggio di incompatibilità. `scripts/platform-contract.py` genera il modulo server/web e `NativePlatformContract.swift` nello ZIP iOS; `--check` blocca differenze. Categorie storiche e personalizzate conservano il loro valore originale nell’editor.

L’HTML pubblicato è `backend/worker/app.html`. `runtime.mjs` contiene esclusivamente il backend sanificato e un segnaposto HTML; `build.mjs` incorpora HTML e moduli dell’interfaccia e produce `worker.js`. Non modificare il bundle a mano e non ricreare il runtime dal sorgente privato.

## Flussi allineati

- Dashboard: settimana mobile di sette giorni, apertura del giorno in Calendario, riepilogo turni/appuntamenti, prossimo orario neutro con dettaglio e abitudini verticali. Apple Health rimane nell’app.
- Attività: categorie dal medesimo endpoint, gestione e riordino espliciti, gruppi Da fare / In attesa / Completate.
- Finanza: Budget / Piani / Spesa nello stesso ordine; budget giornaliero del mese consultato, saldo distinto, lista completa movimenti, categorie identiche e trattamenti Automatico / Da risparmi. Mesi coperti e note disponibili anche nel nuovo movimento web.
- Budget: stesse componenti dell’obiettivo di risparmio, fondo emergenza e quota necessaria fino a dicembre; editor separato con conferma tramite rilettura. Ogni ricorrente apre stima, pagamento, data e mesi coperti.
- Piani: lista → dettaglio → pagamento/collegamento/modifica futura/interruzione. Stesse etichette, scelta categoria, periodicità 1–12 mesi, anteprima in centesimi, storico pagamenti, ripresa e guida. Un fondo resta pagabile dopo una registrazione; una scadenza già pagata non mostra un secondo pagamento.
- Analisi: Spese per categoria, Previsione patrimonio, Patrimonio, Stipendi per competenza. Periodi categorie 3/6/12 mesi con totali firmati, cache, errore esplicito e ripresa dai mesi mancanti. La previsione web è confrontata direttamente con il modello Swift compilato, incluse fasce bootstrap e pagamenti futuri.
- Errori: un mese non caricato non mostra i valori del precedente; retry disponibile. Spese rapide web conservate prima dell’invio, identità/payload immutabili dopo risposta persa, coda ripristinata dopo reload, nessuna conferma bancaria prematura. Il backup include la coda.
- Impostazioni web: tema Automatico/Chiaro/Scuro, sincronizzazione e backup dei dati caricati sul dispositivo.

La parità descritta riguarda i flussi applicativi collegati al server. Gli strumenti locali di configurazione nativi (scelta endpoint, demo e importazione snapshot) non sono stati replicati sul browser. Non considerare questa revisione una certificazione di parità totale di ogni funzione locale. La lettura e scrittura Apple Health restano native; la richiesta ammette l’eccezione per la lettura, mentre la scrittura richiederebbe un’integrazione separata per il browser.

## Verifiche eseguite

- 34 test server, incluso Worker completo/D1 sintetico e route della schermata Piani: superati.
- 99 test Foundation Swift su Linux: superati.
- Due test dei modelli web, incluso confronto col modello Swift compilato: superati.
- Due suite Chromium sull’HTML realmente servito: sei tipi di piano, categorie, pagamenti, retry/idempotenza, backup della coda locale, sette viste a 320/390/1280 px, categorie 3/6/12 mesi e recupero da errori. Superate; nessun errore JavaScript.
- TypeScript sul Worker consegnato, parsing Swift, controllo design system, generazione contratto e integrità ZIP: superati localmente.

Le fixture sono sintetiche. Compilazione SwiftUI, prove su simulatore Apple, prova fisica e stato del servizio pubblicato sono verifiche distinte. Nessun IPA generato per questa revisione. I sorgenti sono predisposti come 0.9.5 build 56; l’ultima IPA già consegnata resta la build 55.
