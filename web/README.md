# Webapp Life OS

Struttura attuale: navigazione **Dashboard / Finanza**, settimana e meteo in Dashboard, azioni Aggiungi peso e Calendario, grafico peso/calorie da inserimento manuale. Calendario dei turni come pagina secondaria; nessuna pagina Attività o controllo delle abitudini. Dati precedenti conservati. Contratto e verifiche: [DASHBOARD-SALUTE.md](../docs/DASHBOARD-SALUTE.md). Codice preparato per la PR; nessun deploy. Build iPhone in verifica.

## Turni per Calendario Apple — 23 ottobre 2026

Il calendario ora prepara soltanto turni, con pubblicazione mensile, collegamento Apple in abbonamento e rigenerazione del link. Il backend aggiunge schema/snapshot e una rotta ICS protetta da token: la precedente identità byte per byte del backend descritta sotto è **storica**. Stato locale, contratto, verifica e attivazione Cloudflare in [APPLE-CALENDAR.md](../docs/APPLE-CALENDAR.md). Nessun deploy eseguito. Anteprima attuale: `previews/turni-apple.png`. I vecchi dati non sono stati trasferiti né cancellati.

`worker.mjs` resta il template originale già presente nel repository, senza ripubblicare una copia modificata dei dati incorporati. `backend-extensions.mjs` contiene soltanto le nuove funzioni e `backend_update.py` le applica al template. `app.html` è la UI leggibile. `npm run build` produce `dist/worker.mjs`, escluso da Git e dagli artefatti pubblici: è questo il file da valutare per il deploy. Il build non modifica il template. Non distribuire con nuovi binding: il worker `lifeos` deve mantenere DB, segreti e Cloudflare Access esistenti.

Allineamento: palette platino, tipografia e target44; Finanza aperta con Budget / Extra / Spesa, dettagli Budget separati, grafici in Analisi, riepilogo annuale e Sankey storico rimossi dalla navigazione. Calendario uniforme senza fondi weekend, selezione sul numero. Motion ridotto rispettato.

Analisi conserva per ora i grafici esistenti; previsione patrimonio, stipendi per competenza e aggregazione categorie 3/6/12 mesi richiedono un successivo allineamento funzionale. Non presentare questa revisione come parità funzionale completa. Deploy Cloudflare non eseguito finché accesso e confronto con sorgente live non sono disponibili.

## Verifica locale

`npm ci` poi `npm run build` e `npm test` nella cartella `web`. Browser Chromium richiesto (`CHROMIUM_PATH` se diverso da `/usr/bin/chromium`). Playwright è fissato nel lockfile. Il test usa soltanto fixture locali: verifica navigazione Finanza/Budget/Analisi/Calendario, posizione Spesa, assenza di overflow a 320/375/1280 px e Riduci movimento. Non esegue scritture reali e non certifica la connessione al D1 live.

Anteprime dark a 375 px: `previews/finanza.png`, `previews/calendario.png` (dati simulati). Il pulsante `+` contestuale è nell’intestazione; il web usa blur CSS con fallback, non le API Liquid Glass native.

Backend del file allegato, esclusa la costante APP_HTML: SHA-256 `b2608965c3838aa332ecb6c6015333ebd917508955cd5d7a3533ca2989e8e6ec`. Verificato identico dopo la modifica. Prima del deploy confrontare il sorgente live con questa baseline per conservare eventuali aggiornamenti successivi; mantenere autenticazione, binding D1 e segreti. Il token Cloudflare non è presente nel runtime corrente.
