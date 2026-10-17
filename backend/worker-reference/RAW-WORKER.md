# Worker completo per aggiornare Cloudflare

File: `/worker.js`, ES module con binding D1 `DB`. Conservare database, secret e impostazioni del Worker esistente.

Questa versione aggiorna un database LifeOS già configurato con la riconciliazione storica versione 2. Non importa né pubblica estratti conto, IBAN, attività personali o turni iniziali. Le regole storiche riservate sono cifrate; vengono aperte usando i dati già presenti nel D1 privato e conservate soltanto in memoria. Una configurazione storica mancante o non riconosciuta produce un errore esplicito. Il database resta la fonte dei dati.

Include l’integrazione Piani e le correzioni delle letture SQL per Analisi. Le modifiche native a navigazione e grafici richiedono la build iOS 55; il caricamento del Worker non aggiorna da solo l’app installata.

Verifica: 34 test server superati sul bundle completo con SQLite sintetico; decifratura verificata contro la configurazione originale privata; 48 confronti delle riconciliazioni con risultati identici. Scansione del bundle senza identificativi bancari in chiaro o seed personali.

SHA-256: `b9e50b2b3e68c31f431209c2dc7e62cb4a8d488f57fc1f87649a24f69711bcaf`.

Il sorgente originale integrale e la procedura di generazione restano nell’archivio privato indicato in AGENTS.md. Nessun deploy Cloudflare eseguito: caricamento manuale scelto dall’utente.

Editor correction: all seven reported diagnostics reproduced with TypeScript 5.9.3, then resolved. `tsc --allowJs --checkJs --noEmit --target es2022 --module esnext --lib es2022,webworker worker.js` passes without diagnostics. Map grouping uses a compatible loop; optional integration callbacks default to null; monthly calculated fields are declared when each record is created. All 34 server tests and 48 private reconciliation comparisons pass.

Build pubblica riproducibile: `node backend/worker/build.mjs`. Il runtime sanificato è versionato in `backend/worker/runtime.mjs`; le integrazioni provengono direttamente da `backend/plans/`. Il workflow `lifeos-worker.yml` ricompila e confronta byte per byte con worker.js, controlla TypeScript e prova il bundle consegnato contro D1 sintetico. Se i sorgenti cambiano senza rigenerare worker.js, la verifica fallisce. Il workflow produce una copia verificata, senza modificare Cloudflare.
