# Life OS — passaggio corrente, 23 ottobre 2026

Leggere [STATUS.md](STATUS.md), [native/BUILD-52.md](native/BUILD-52.md), [DASHBOARD-SALUTE.md](DASHBOARD-SALUTE.md) e [APPLE-CALENDAR.md](APPLE-CALENDAR.md). Questi documenti descrivono lo stato corrente; le revisioni precedenti restano nella storia Git.

## Consegnato

Codice nella [PR 1](https://github.com/azeroualit-cloud/LifeOS/pull/1), su ramo dedicato non unito a main. IPA 0.9.0 build 52: compilazione e archivio Apple riusciti, 83 unitari, 26 UI standard e 12 UI compatti passati. Verifica separata di checksum, ZIP, versione, bundle e arm64 conclusa con successo. Le evidenze e l’unica IPA per Signulous sono in native/BUILD-52.md.

Navigazione Dashboard/Finanza. La Dashboard contiene settimana, riepilogo turni/meteo senza attività o abitudini, Aggiungi peso e Calendario, grafico peso/calorie. Calendario dei turni come destinazione secondaria, con pubblicazione mensile e collegamento Apple in abbonamento. Misure manuali; HealthKit escluso. Dati storici preservati.

## Prossimo passo concreto

Attivazione backend con accesso Cloudflare ancora necessario. Nessun deploy, abbonamento Apple live o prova su dispositivo fisico eseguito. Non dichiarare complete le integrazioni live sulla base delle sole prove locali e dei simulatori.

Il template web/worker.mjs resta invariato. Nuovo codice in web/backend-extensions.mjs e web/backend_update.py; npm run build assembla web/dist/worker.mjs, ignorato da Git. Pubblicare soltanto il codice aggiunto, senza ricopiare lo storico incorporato. Prima di qualsiasi deploy confrontare il sorgente live, conservare binding, segreti, autenticazione, dati e marcatori di migrazione esistenti. La CI corrente usa solo fixture e non accede al backend con credenziali.

La build 52 è l’ultima IPA verificata. Per l’eventuale aggiornamento tramite Signulous mantenere il bundle e non disinstallare l’app. Le nuove API salute/turni devono essere attivate prima dell’uso reale delle nuove funzioni.
