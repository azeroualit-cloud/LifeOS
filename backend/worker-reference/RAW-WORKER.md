# Worker completo per aggiornare Cloudflare

File: `/worker.js`, ES module con binding D1 `DB`. Conservare database, secret e impostazioni del Worker esistente.

Questa versione aggiorna un database LifeOS già configurato con la riconciliazione storica versione 2. Non importa né pubblica estratti conto, IBAN, attività personali o turni iniziali. Le regole storiche riservate sono cifrate; vengono aperte usando i dati già presenti nel D1 privato e conservate soltanto in memoria. Una configurazione storica mancante o non riconosciuta produce un errore esplicito. Il database resta la fonte dei dati.

Include l’integrazione Piani e le correzioni delle letture SQL per Analisi. Le modifiche native a navigazione e grafici richiedono la build iOS 55; il caricamento del Worker non aggiorna da solo l’app installata.

Verifica: 34 test server superati sul bundle completo con SQLite sintetico; decifratura verificata contro la configurazione originale privata; 48 confronti delle riconciliazioni con risultati identici. Scansione del bundle senza identificativi bancari in chiaro o seed personali.

Lo SHA-256 del bundle corrente è incluso nella consegna locale `work/delivery/SHA256SUMS`; i riferimenti ai test privati qui sopra documentano la verifica originaria della sanificazione, non una nuova esecuzione del confronto privato.

Il sorgente originale integrale e la procedura di generazione restano nell’archivio privato indicato in AGENTS.md. Nessun deploy Cloudflare eseguito: caricamento manuale scelto dall’utente.

Editor correction: all seven reported diagnostics reproduced with TypeScript 5.9.3, then resolved. `tsc --allowJs --checkJs --noEmit --target es2022 --module esnext --lib es2022,webworker worker.js` passes without diagnostics. Map grouping uses a compatible loop; optional integration callbacks default to null; monthly calculated fields are declared when each record is created. All 34 server tests and 48 private reconciliation comparisons pass.

Build pubblica riproducibile: `node backend/worker/build.mjs`. Il runtime sanificato è versionato in `backend/worker/runtime.mjs`; le integrazioni provengono direttamente da `backend/plans/`. Il workflow `lifeos-worker.yml` ricompila e confronta byte per byte con worker.js, controlla TypeScript e prova il bundle consegnato contro D1 sintetico. Se i sorgenti cambiano senza rigenerare worker.js, la verifica fallisce. Il workflow produce una copia verificata, senza modificare Cloudflare.

## Interfaccia web Piani v2

Il frontend servito dal Worker ora usa Piani v2: Obiettivo, Fondo, Ricorrenza fissa, Utenza stimata, Anticipo budget, Recupero spesa. Il build incorpora `backend/worker/plans-web.js` e abilita il contratto versione 2 nelle richieste. Il modulo Nuova straordinaria è sostituito dal modulo Nuovo piano; le letture Extra passano all’overview v2 per adottare le voci esistenti senza quote duplicate. Pagamento, collegamento, modifica futura, interruzione e ripresa usano gli endpoint v2. Ogni tentativo dopo un errore conserva lo stesso ID e payload.

Il test `backend/worker/plans-web.test.mjs` apre in Chromium l’HTML realmente restituito dal Worker (dati API sintetici), verifica i sei tipi, l’assenza di chiamate legacy, retry, collegamento, modifica, stop, fondi con pagamenti ripetuti, ripresa e layout mobile. Il workflow esegue questa prova e salva screenshot desktop e mobile. I test SQLite separati verificano il registro reale sul bundle completo con dati sintetici.

Revisione di coerenza web/iOS: vedere `docs/PLATFORM-PARITY.md`. Le categorie derivano dal contratto condiviso; Home, Budget, Analisi, Piani e coda spese web sono verificati sul bundle servito. Anche il Worker collegato all’app deve includere Piani v2.

Revisione locale 18 ottobre: scelta endpoint, demo/importazione snapshot, backup con archivio precedente e preparazione pesata per conferma nativa. Sorgenti iOS 0.9.5/56, compilazione Apple ancora da eseguire. Nessun nuovo link Raw pubblicato: push bloccato dal controllo automatico in attesa di autorizzazione esplicita. Non usare il vecchio Raw come se contenesse questa revisione.
