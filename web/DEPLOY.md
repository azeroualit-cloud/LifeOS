# Deploy del sito (Worker `lifeos`) - procedura manuale

Stato: preparata, NON eseguita. Nessun deploy senza conferma esplicita di Nas.
File da distribuire: `web/dist/worker-release.mjs` (generato da `python web/build-release.py`, non versionato).
SHA256 del file preparato il 2026-11-19 (dashboard recap, grafici Finanza, cascata Budget): 780B04ABDC6209EFA7AF3433608F31BF0FB5AF25A85B6FBDC57FCE510354961A

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
