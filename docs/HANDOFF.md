# Life OS — passaggio corrente, 24 ottobre 2026

Leggere [STATUS.md](STATUS.md) e [native/BUILD-53.md](native/BUILD-53.md). La richiesta più recente ripristina Life OS unificato dopo una prova con le app Apple: prevale sulla navigazione ridotta della build 52.

## Sorgenti e direzione

[PR 1](https://github.com/azeroualit-cloud/LifeOS/pull/1), ramo dedicato non unito a main. Pacchetto nativo canonico lifeos-native.zip, build 53. Unpack in una cartella nuova; evitare vecchie directory della build 47/52. scripts/package-native.py prepara ZIP, digest CI e diff incrementale dalla build 52. La app mantiene bundle e archivio esistenti: aggiornare senza disinstallare.

Client iOS: Dashboard/Attività/Finanza, calendario dalla Dashboard con eventi e attività pianificate, abitudini ripristinate. Setter assoluti di stato attività, abitudini, turni, occorrenze e salute vengono persistiti con coda prima della rete. Creazioni e cancellazioni restano confermate dal server. La sincronizzazione riproietta la coda sulle letture tardive, conserva conferme e ordine per chiave, non duplica i movimenti finanziari con UUID. Non estendere la coda ad API prive di idempotenza.

Notifiche locali opzionali dai dati caricati; Siri in primo piano per peso e preparazione attività; widget con accessi rapidi senza App Groups e senza dati personali. Widget dinamici, push remote e HealthKit non implementati. La firma Signulous e il funzionamento fisico richiedono verifica sul telefono.

## Verifica e deploy

La prima compilazione Apple della build 53 è riuscita; test completi e archivio definitivo in corso. L’ultima IPA interamente verificata rimane quella documentata in native/BUILD-52.md finché BUILD-53.md non registra evidenze concluse.

Nessun deploy Cloudflare eseguito. La dashboard web della build 52 è ancora nel ramo ma non distribuita: non confonderla con il nuovo client iOS unificato. Le nuove API salute/turni richiedono attivazione separata. Per i contratti server: DASHBOARD-SALUTE.md e APPLE-CALENDAR.md.

web/worker.mjs resta invariato. Le estensioni backend e il build generano web/dist/worker.mjs, ignorato da Git. Pubblicare solo codice aggiunto, senza ricopiare lo storico incorporato. Prima del deploy confrontare il sorgente live e conservare binding, segreti, autenticazione, dati e marcatori di migrazione. CI solo fixture, nessuna verifica live con credenziali.
