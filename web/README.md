# Webapp Life OS

`worker.mjs` è l'export del Worker live ricevuto il 3 novembre 2026 (marcatori LIFEOS_UNIFIED_ACTIVITIES_68, LIFEOS_MOVEMENT_CREATION_70, LIFEOS_UTILITY_COMPETENCE_75). `app.html` è il suo APP_HTML decodificato: modificare l'HTML e rigenerare la costante con `python3 build.py` prima del deploy. Non distribuire con nuovi binding: il worker `lifeos` deve mantenere DB, segreti, `NATIVE_DATA_MODE` e Cloudflare Access esistenti.

Questa baseline sostituisce quella del 17 ottobre 2026. Le modifiche di allineamento grafico fatte sulla vecchia base (palette platino, Finanza Budget / Extra / Spesa, calendario uniforme) NON sono in questa versione e vanno riapplicate sopra il live. Il commit precedente le conserva nella cronologia git.

## Verifica locale

`npm ci` poi `npm run build` e `npm test` nella cartella `web`. Browser Chromium richiesto (`CHROMIUM_PATH` se diverso da `/usr/bin/chromium`). Playwright è fissato nel lockfile. Il test usa soltanto fixture locali: verifica navigazione Finanza/Budget/Analisi/Calendario, posizione Spesa, assenza di overflow a 320/375/1280 px e Riduci movimento. Non esegue scritture reali e non certifica la connessione al D1 live.

Anteprime dark a 375 px: `previews/finanza.png`, `previews/calendario.png` (dati simulati). Il pulsante `+` contestuale è nell’intestazione; il web usa blur CSS con fallback, non le API Liquid Glass native.

Backend dell'export live, esclusa la costante APP_HTML: SHA-256 `caf0abe178bb6aec71f430eb62da38768f9b3e5590d0ad2daa7aabca3b7f19f4`. Il build riproduce questo hash. Prima di ogni deploy esportare di nuovo il Worker live e confrontarlo con questa baseline: ogni modifica fatta dalla dashboard Cloudflare apre un nuovo divario. Token Cloudflare non presente nel runtime di Claude.
