# Deploy del sito (Worker `lifeos`) - procedura manuale

Stato: preparata, NON eseguita. Nessun deploy senza conferma esplicita di Nas.
File da distribuire: `web/dist/worker-release.mjs` (generato da `python web/build-release.py`, non versionato).
SHA256 del file online dal 2026-11-21 (versione 7cda51d0-3720-4c99-8d3e-535a813603a1), preparato il 2026-11-21 (mappa stipendio con dettaglio, grafico a linee, popup moderni, colori Salute uguali a dashboard): AE30DE6D6E7990733A00E87A163E24DBD01DD7F90C39919C02CB1E10F8719AC9

Pronto al deploy dal 2026-11-22 (commit 0fc9a96: testo in ogni riquadro di "Dove va lo stipendio", popup della voce al clic), generato con `python -X utf8 web/build-release.py` e lo stesso `manual/build-75/worker.js` locale: SHA256 0F6DE610B2A8FEB00F71DEF85124C71031AF853BD8B99163B4A0CCEB661C8949. Non distribuito.

Il Worker contiene backend build-75 (lo stesso dell'app), UI web aggiornata e i metodi Admin in sola lettura.
Sito e app usano lo stesso D1 (confermato da Nas il 2026-11-19).

## 1. Backup e configurazione attuale (sola lettura)
```
mkdir lifeos-deploy && cd lifeos-deploy
npx wrangler login
npx wrangler init --from-dash lifeos
```
Crea una cartella con il codice attuale e un wrangler.toml con i binding (D1, variabili). Conserva la cartella come punto di ritorno.
Controlla nel wrangler.toml che il database D1 sia lo stesso di lifeos-native-test.

## 2. Prova senza pubblicare
Copia worker-release.mjs sopra il file `main` indicato nel wrangler.toml, poi:
```
npx wrangler deploy --dry-run
```
Verifica che i binding elencati siano gli stessi del punto 1. I secret (APP_PASSWORD) restano su Cloudflare e non vengono toccati da deploy.

## 3. Pubblicazione (solo dopo conferma)
```
npx wrangler deploy
```

## 4. Controlli manuali
- Login e Panoramica si aprono con i dati reali.
- Selettore del mese: cliccare il mese in alto, scegliere un mese passato.
- Nuova spesa in una categoria con piano attivo: compare "Da dove viene pagata".
- Sezione Admin (in fondo alla sidebar): stato tabelle, backup JSON.
- L'app iPhone continua a sincronizzare.

## Ritorno indietro
Dashboard Cloudflare, Workers, lifeos, Deployments: rollback alla versione precedente. In alternativa rideploy della cartella salvata al punto 1.
