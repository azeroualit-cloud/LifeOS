# Stato corrente — Life OS, 24 ottobre 2026

[PR](https://github.com/azeroualit-cloud/LifeOS/pull/1) · [IPA, prove e limiti build 53](native/BUILD-53.md).

La direzione corrente torna a Life OS unificato su iPhone: Dashboard, Attività e Finanza; calendario dalla Dashboard, eventi e abitudini ripristinati. Storico e archivio locale conservati. Il client web della build 52 resta separato e non è stato distribuito.

La build 53 salva localmente i setter frequenti con coda persistente e sincronizzazione senza blocco globale per queste azioni. Aggiunge recupero degli invii rifiutati, notifiche locali opzionali, Siri per peso/preparazione attività e widget di accesso rapido. Creazioni offline, widget dinamici, push remote e HealthKit non sono inclusi.

## Verifica conclusa

Compilazione e archivio Apple riusciti: 98 unitari, 26 UI standard e 12 UI compatti passati, oltre a 3 prove mirate. Verifica indipendente di IPA e log riuscita: checksum, CRC, bundle/versione, schema URL, metadati Siri italiani, widget incorporato e due eseguibili arm64. Sorgenti e IPA in native/BUILD-53.md. L’IPA build 53 è quella corrente; aggiornare via Signulous senza disinstallare.

## Da attivare e provare

Nessun deploy Cloudflare o collaudo fisico eseguito. Le API salute/turni introdotte nella build 52 restano da attivare: eventuali misurazioni rimangono sul dispositivo/in coda se il server non le supporta. Siri e widget dopo firma Signulous richiedono prova su iPhone; i promemoria locali vanno abilitati nelle impostazioni dell’app.

Template originale web/worker.mjs invariato; nuovo codice backend in estensioni, Worker completo assemblato localmente in dist e ignorato da Git. Nessuna nuova copia dello storico finanziario caricata. CI solo fixture, senza accesso live con credenziali.
