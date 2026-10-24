# Life OS — passaggio corrente, 24 ottobre 2026

Leggere [STATUS.md](STATUS.md) e [native/BUILD-53.md](native/BUILD-53.md). La richiesta più recente ripristina Life OS unificato dopo una prova con le app Apple: prevale sulla navigazione ridotta della build 52.

## Consegnato e sorgenti

[PR 1](https://github.com/azeroualit-cloud/LifeOS/pull/1), ramo dedicato non unito a main. Pacchetto canonico lifeos-native.zip, 0.9.0 build 53, sorgenti verificati nel commit eb3c04b27c356ae70eebd4d044745e081f4284c8. Il ramo codex/native-build53-retry contiene lo stesso commit ed è stato usato per la build riuscita 40115963503. Verifica indipendente IPA/log riuscita 40119827193. Prove e unica IPA per Signulous in native/BUILD-53.md.

98 unitari, 26 UI standard, 12 UI compatti e 3 prove mirate passati; archivio Release e controllo di checksum, ZIP, versione, bundle, metadati App Intents italiani e widget arm64 completati. È l’ultima IPA verificata, da aggiornare senza disinstallare. L’autorizzazione esplicita dell’utente alla pubblicazione dei sorgenti aggiornati è stata ricevuta: non richiederla di nuovo.

Unpack del pacchetto in una cartella nuova; evitare vecchie directory della build 47/52. scripts/package-native.py genera ZIP, digest CI e diff dalla build 52. I successivi commit di documentazione/verifica non modificano il pacchetto. Il codice non è ancora unito a main e il sito non è stato distribuito.

## Contratti e limiti

Client iOS: Dashboard/Attività/Finanza, calendario dalla Dashboard con eventi e attività pianificate, abitudini ripristinate. Setter assoluti di stato attività, abitudini, turni, occorrenze e salute persistiti con coda prima della rete. Creazioni/cancellazioni restano confermate dal server. La sincronizzazione riproietta la coda sulle letture tardive, conserva conferme e ordine per chiave, mantiene UUID dei movimenti. Non estendere la coda ad API prive di idempotenza. Conflitti tra dispositivi ancora con ultimo valore inviato prevalente. Le spunte di un giorno passato possono essere rifiutate dal backend: restano in coda con recupero dalle impostazioni.

Notifiche locali opzionali dai dati caricati; Siri in primo piano per peso e preparazione attività; widget con accessi rapidi senza App Groups e senza dati personali. Widget dinamici, push remote e HealthKit non implementati. Firma Signulous, registrazione Siri/widget e funzionamento fisico richiedono collaudo sul telefono. I simulatori non attestano le capability del profilo Signulous.

## Backend e web

Nessun deploy Cloudflare. Le nuove API salute/turni richiedono attivazione separata; le misure rimangono locali/in coda finché il server non le supporta. La dashboard web della build 52 è nel ramo ma non distribuita: non confonderla con il client iOS unificato. Per i contratti server: DASHBOARD-SALUTE.md e APPLE-CALENDAR.md.

web/worker.mjs resta invariato. Estensioni e build generano web/dist/worker.mjs, ignorato da Git. Pubblicare solo codice aggiunto, senza ricopiare lo storico incorporato. Prima del deploy confrontare il sorgente live e conservare binding, segreti, autenticazione, dati e marcatori di migrazione. CI solo fixture, nessuna verifica live con credenziali.
