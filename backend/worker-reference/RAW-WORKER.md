# Worker completo per aggiornare Cloudflare

File: `/worker.js`, ES module con binding D1 `DB`. Conservare database, secret e impostazioni del Worker esistente.

Questa versione aggiorna un database LifeOS già configurato con la riconciliazione storica versione 2. Non importa né pubblica estratti conto, IBAN, attività personali o turni iniziali. Le regole storiche riservate sono cifrate; vengono aperte usando i dati già presenti nel D1 privato e conservate soltanto in memoria. Una configurazione storica mancante o non riconosciuta produce un errore esplicito. Il database resta la fonte dei dati.

Include l’integrazione Piani e le correzioni delle letture SQL per Analisi. Le modifiche native a navigazione e grafici richiedono la build iOS 55; il caricamento del Worker non aggiorna da solo l’app installata.

Verifica: 34 test server superati sul bundle completo con SQLite sintetico; decifratura verificata contro la configurazione originale privata; 48 confronti delle riconciliazioni con risultati identici. Scansione del bundle senza identificativi bancari in chiaro o seed personali.

SHA-256: `2225bac83dc6493336f43a168842985bc05858bc9f2ed471bf73c29118d90278`.

Il sorgente originale integrale e la procedura di generazione restano nell’archivio privato indicato in AGENTS.md. Nessun deploy Cloudflare eseguito: caricamento manuale scelto dall’utente.
