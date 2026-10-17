# Webapp Life OS

`worker.mjs` conserva il backend del sorgente fornito il 17 ottobre 2026; `app.html` è il suo APP_HTML leggibile. Modificare HTML e rigenerare la costante prima del deploy. Non distribuire con nuovi binding: il worker `lifeos` deve mantenere DB, segreti e Cloudflare Access esistenti.

Allineamento: palette platino, tipografia e target44; Finanza aperta con Budget / Extra / Spesa, dettagli Budget separati, grafici in Analisi, riepilogo annuale e Sankey storico rimossi dalla navigazione. Calendario uniforme senza fondi weekend, selezione sul numero. Motion ridotto rispettato.

Analisi conserva per ora i grafici esistenti; previsione patrimonio, stipendi per competenza e aggregazione categorie 3/6/12 mesi richiedono un successivo allineamento funzionale. Non presentare questa revisione come parità funzionale completa. Deploy Cloudflare non eseguito finché accesso e confronto con sorgente live non sono disponibili.

## Verifica locale

`npm ci` poi `npm run build` e `npm test` nella cartella `web`. Browser Chromium richiesto (`CHROMIUM_PATH` se diverso da `/usr/bin/chromium`). Playwright è fissato nel lockfile. Il test usa soltanto fixture locali: verifica navigazione Finanza/Budget/Analisi/Calendario, posizione Spesa, assenza di overflow a 320/375/1280 px e Riduci movimento. Non esegue scritture reali e non certifica la connessione al D1 live.

Anteprime dark a 375 px: `previews/finanza.png`, `previews/calendario.png` (dati simulati). Il pulsante `+` contestuale è nell’intestazione; il web usa blur CSS con fallback, non le API Liquid Glass native.

Backend del file allegato, esclusa la costante APP_HTML: SHA-256 `b2608965c3838aa332ecb6c6015333ebd917508955cd5d7a3533ca2989e8e6ec`. Verificato identico dopo la modifica. Prima del deploy confrontare il sorgente live con questa baseline per conservare eventuali aggiornamenti successivi; mantenere autenticazione, binding D1 e segreti. Il token Cloudflare non è presente nel runtime corrente.
