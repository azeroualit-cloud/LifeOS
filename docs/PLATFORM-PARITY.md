# Coerenza web / iOS — 18 ottobre 2026

Base: `feature/plans-v2`, commit `21fb534`. Il sorgente installato della foto è in questo ramo, non in `main`.

## Errore Piani

Riprodotta la chiamata autenticata `POST /api/getFinancePlans ["2026-10"]` sul Worker precedente: HTTP 400, `Operazione non disponibile.`. Il bundle con adapter Piani restituisce HTTP 200, contratto versione 2 e gli stessi piani dell’overview. Il test D1 ora verifica esplicitamente questa route e l’header `X-LifeOS-Plans-Version: 2`.

L’app e il sito possono utilizzare lo stesso D1 attraverso Worker differenti. Aggiornare soltanto `lifeos` non aggiorna il codice di `lifeos-native-test`. Il Worker effettivamente configurato nell’app deve includere lo stesso adapter Piani. Il messaggio iOS identifica ora questa incompatibilità e mostra l’host collegato. Nessun errore viene convertito in una lista vuota o in una migrazione fittizia.

La distribuzione manuale scelta dall’utente rimane necessaria. Conservare binding DB, password, secret e protezioni Access esistenti. Non creare database nuovi, non cancellare marcatori e non registrare pagamenti di prova reali. Questa verifica locale non certifica il Worker già pubblicato.

## Contratto condiviso

`shared/platform-contract.json` definisce categorie spesa/entrata, ordine ed etichette dei sei tipi di piano, stati e messaggio di incompatibilità. `scripts/platform-contract.py` genera il modulo server/web e `NativePlatformContract.swift` nello ZIP iOS; `--check` blocca differenze. Categorie storiche e personalizzate conservano il loro valore originale nell’editor.

L’HTML pubblicato è `backend/worker/app.html`. `runtime.mjs` contiene esclusivamente il backend sanificato e un segnaposto HTML; `build.mjs` incorpora HTML e moduli dell’interfaccia e produce `worker.js`. Non modificare il bundle a mano e non ricreare il runtime dal sorgente privato.

## Flussi allineati

- Dashboard: settimana mobile di sette giorni, apertura del giorno in Calendario, riepilogo turni/appuntamenti, prossimo orario neutro con dettaglio e abitudini verticali. La lettura Apple Health rimane nell’app; il browser prepara una pesata da confermare nell’editor nativo.
- Attività: categorie dal medesimo endpoint, gestione e riordino espliciti, gruppi Da fare / In attesa / Completate.
- Finanza: Budget / Piani / Spesa nello stesso ordine; budget giornaliero del mese consultato, saldo distinto, lista completa movimenti, categorie identiche e trattamenti Automatico / Da risparmi. Mesi coperti e note disponibili anche nel nuovo movimento web.
- Budget: stesse componenti dell’obiettivo di risparmio, fondo emergenza e quota necessaria fino a dicembre; editor separato con conferma tramite rilettura. Ogni ricorrente apre stima, pagamento, data e mesi coperti.
- Piani: lista → dettaglio → pagamento/collegamento/modifica futura/interruzione. Stesse etichette, scelta categoria, periodicità 1–12 mesi, anteprima in centesimi, storico pagamenti, ripresa e guida. Un fondo resta pagabile dopo una registrazione; una scadenza già pagata non mostra un secondo pagamento.
- Analisi: Spese per categoria, Previsione patrimonio, Patrimonio, Stipendi per competenza. Periodi categorie 3/6/12 mesi con totali firmati, cache, errore esplicito e ripresa dai mesi mancanti. La previsione web è confrontata direttamente con il modello Swift compilato, incluse fasce bootstrap e pagamenti futuri.
- Errori: un mese non caricato non mostra i valori del precedente; retry disponibile. Spese rapide web conservate prima dell’invio, identità/payload immutabili dopo risposta persa, coda ripristinata dopo reload, nessuna conferma bancaria prematura. Il backup include la coda.
- Impostazioni: tema Automatico/Chiaro/Scuro, scelta endpoint HTTPS e collegamento, sincronizzazione, demo persistente separata dal server, importazione snapshot in sola lettura, ripristino collegamento e backup con archivio precedente/coda. La demo web deriva dal medesimo DemoData.swift sintetico e usa il motore Piani reale per quote e pagamenti locali.

La webapp può preparare peso e data senza inviare dati sanitari al Worker. Un link `lifeos://weight` apre l’editor iOS; il salvataggio richiede il pulsante Salva nell’app e usa un identificatore HealthKit stabile per i tentativi ripetuti. Non viene mostrata una falsa conferma sul browser. Servono i sorgenti 0.9.5/56 per questa apertura. La lettura Apple Health è l’eccezione web richiesta; la scrittura passa quindi dall’app installata e non può essere completata su un dispositivo privo di Life OS/HealthKit.

Il parser del link e la conversione del fuso Roma sono verificati localmente. La compilazione Apple e la presenza dello schema URL nell’Info.plist del pacchetto sono verificate dal run IPA `39081406881`. Apertura reale del link e scrittura HealthKit su dispositivo richiedono ancora una prova fisica. API consultate: [Apple, Synchronize health data with HealthKit](https://developer.apple.com/videos/play/wwdc2020/10184/) e [XcodeGen ProjectSpec](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md).

Il Worker singolo conserva le modalità gateway `NATIVE_DATA_MODE=shared/maintenance`, l’header origine e la risposta manutenzione. I binding e l’autenticazione esistenti non devono cambiare.

## Verifiche eseguite

- 34 test server, incluso Worker completo/D1 sintetico e route della schermata Piani: superati.
- 103 test Foundation Swift su Linux: superati. Su Apple: 122 test unitari e 7 prove UI superati nel run `39081388601`, con compilazione simulatore riuscita.
- Nove test dei modelli web, inclusi confronto col modello Swift compilato, demo/snapshot e trasferimento pesata: superati.
- Due suite Chromium sull’HTML realmente servito: sei tipi di piano, categorie, pagamenti, retry/idempotenza, backup della coda locale, sette viste a 320/390/1280 px, categorie 3/6/12 mesi e recupero da errori. Verificano inoltre demo persistente isolata, importazione snapshot e link pesata con conferma nativa. Superate; nessun errore JavaScript.
- TypeScript sul Worker consegnato, parsing Swift, controllo design system, generazione contratto e integrità ZIP: superati localmente.

Le fixture sono sintetiche. Compilazione SwiftUI/iPhone arm64 e simulatore riuscite. IPA 0.9.5 build 56 generata dal run `39081406881`, scaricata e verificata per integrità, versione, origine ZIP, privacy HealthKit e schema URL. Provenienza in `backend/plans/IPA-build56.json`. Test simulatore superati nel run `39081388601`; prova fisica e stato del servizio pubblicato restano verifiche distinte. Nessun deploy Cloudflare eseguito.

## Consegna e stato esterno

Il 18 ottobre l’utente ha autorizzato il push del ramo `fix/platform-parity` e richiesto IPA e GitHub Raw. Pubblicato il commit sorgente `48693689cf2449e41a85c7342022db9aa5fc9928`. Il [Raw fissato al commit](https://raw.githubusercontent.com/azeroualit-cloud/LifeOS/48693689cf2449e41a85c7342022db9aa5fc9928/worker.js) è stato riscaricato e confrontato: SHA-256 `2a3e46862dcd6ad313cc7ed6a7cd43c9d2ce2ca76031940db2f96f05c91bce46`, identico al bundle verificato. Il workflow Worker `39081388607` è riuscito, compresi i test browser su GitHub. Nessun deploy Cloudflare eseguito. I risultati Apple e la provenienza dell’IPA sono registrati separatamente in `backend/plans/IPA-build56.json` al completamento.
