# Life OS 0.9.0 build 53 — verifica Apple completata

[IPA unica per Signulous](https://github.com/azeroualit-cloud/LifeOS/releases/download/native-0.9.0-build53-unified/LifeOS-build53.ipa) · [build e test Apple](https://github.com/azeroualit-cloud/LifeOS/actions/runs/40115963503) · [verifica indipendente](https://github.com/azeroualit-cloud/LifeOS/actions/runs/40119827193) · [PR 1](https://github.com/azeroualit-cloud/LifeOS/pull/1).

## Comportamento

Life OS torna a riunire attività, abitudini, eventi, salute e finanza nel client iOS. Navigazione Dashboard, Attività e Finanza; calendario dalla Dashboard con eventi e attività pianificate. Dati storici, bundle e archivio locale conservati.

Stato attività, spunte abitudini, completamenti eventi, turni e misurazioni si applicano e si persistono sul dispositivo prima della rete. La coda conserva ordine e conferme anche dopo riavvio; le letture tardive riapplicano le modifiche pendenti. La sincronizzazione ha uno stato separato dal salvataggio in primo piano e aggiorna l’ambito modificato. I movimenti finanziari mantengono UUID e conferma remota; il modulo chiude dopo la persistenza locale e il saldo mostra l’ultimo dato del server.

Solo setter assoluti con chiavi stabili vengono accodati. Nuove attività/eventi/abitudini, modifiche e cancellazioni restano confermate dal server, in attesa di un contratto per creazioni offline senza duplicati. I setter inviati in seguito prevalgono sul valore corrente del server: non è ancora presente una risoluzione dei conflitti tra dispositivi. Le abitudini passano al nuovo giorno anche senza rete. Le spunte offline di un giorno passato possono essere rifiutate dal backend esistente: restano in coda senza bloccare altri elementi; dalle impostazioni si può riprovare o ripristinare il valore del server con una lettura confermata. I movimenti finanziari non sono eliminabili da questo pannello.

## Integrazioni

- Notifiche locali opzionali, autorizzate dall’utente: attività alle 9 della scadenza, eventi 15 minuti prima, turni lavorativi un’ora prima. Fuso Europe/Rome, prossimi 48 avvisi dai dati disponibili. Le modifiche dal web aggiornano gli avvisi alla successiva apertura/sincronizzazione; nessuna push remota.
- Siri/Comandi Rapidi: registra il peso di oggi nella coda locale; prepara un’attività dettandone il titolo e apre l’editor per confermare Salva. Esecuzione in primo piano con autenticazione del dispositivo, un solo store condiviso con l’app. Metadati e frasi generati in italiano.
- WidgetKit: widget piccolo per Nuova attività; medio per attività/peso/calendario. URL locali validati, senza App Groups o dati personali. È un widget di accesso rapido, senza agenda dinamica o completamenti interattivi.
- Esportazione dei turni su Apple facoltativa. Il controllo del collegamento non blocca altre azioni; la pubblicazione non parte con turni locali ancora da sincronizzare.

## Evidenze

Compilazione e archivio Release Apple riusciti. Superati **98 test unitari, 26 UI standard e 12 UI compatti**, senza fallimenti, oltre alle prove mirate di peso/calendario (2) e Finanza (1). Verificati persistenza prima della rete, risposta trattenuta, riavvio, ordine per elemento, rifiuti e ripristino sicuro, protezione degli archivi finanziari senza abitudini, cambio di giorno offline, validazione salute, piano notifiche e URL. Le prove UI coprono navigazione ripristinata, editor, calendario, testo grande e movimento ridotto.

Il controllo indipendente con soli permessi actions:read scarica IPA e log dalla stessa build: confermati tutti i conteggi, archivio riuscito, checksum, CRC ZIP, versione 0.9.0 build 53, bundle com.nas.lifeos.probe, schema URL, metadati App Intents italiani ed estensione WidgetKit. Entrambi gli eseguibili sono Mach-O arm64.

- Commit sorgenti verificato: `eb3c04b27c356ae70eebd4d044745e081f4284c8`; il ramo isolato di retry contiene lo stesso commit della PR. I successivi commit di verifica/documentazione conservano il pacchetto nativo.
- SHA-256 sorgenti: `2128d852538cfc3f1bcc7b91b186ff2109f6c0f5b82bbcb5895152bcefd87cad`.
- SHA-256 IPA: `f03526c498984242c0bc80266324ac467299ef15202d4265c6f73fafec315897`.
- IPA diretta pubblicata nella release native-0.9.0-build53-unified, con lo stesso checksum verificato. Il link della release non dipende dalla scadenza degli artefatti CI; la copia negli artefatti rimane disponibile fino al 31 ottobre 2026, salvo modifiche alla conservazione.
- Guard del design system, ZIP sorgenti, digest CI e controlli locali passati. Il controllo whitespace esclude i .diff generati: le righe di contesto vuote contengono per formato uno spazio. Nessuna lettura live del backend con credenziali nella CI.

## Attivazione e limiti

L’IPA è unsigned, da firmare tramite Signulous mantenendo il bundle. **Aggiornare senza disinstallare.** Registrazione del widget e Siri dopo la firma richiedono collaudo sull’iPhone: le capability del profilo Signulous non sono attestabili da questo ambiente. Conservare le estensioni durante la firma se il servizio offre tale opzione. Nessuna prova su dispositivo fisico eseguita; screenshot dei simulatori raccolti negli artefatti, senza ispezione locale delle immagini native a causa dei limiti di rete.

Nessun deploy Cloudflare eseguito. Le API salute/turni della build 52 restano da attivare; eventuali misurazioni rimangono sul dispositivo/in coda se il server non le supporta. Le misure sono manuali, senza HealthKit. La dashboard web della build 52 presente nel ramo non è stata distribuita e non viene ripristinata da questo incremento iOS.

Per il collaudo: verificare una spunta in modalità aereo e dopo riapertura, poi riattivare la rete e controllare la coda. Abilitare i promemoria nelle impostazioni dell’app e concedere il permesso iPhone. Per un avviso di prova, creare un evento tra 20 minuti e attendere il promemoria 15 minuti prima. Provare i due comandi Siri e aggiungere il widget dalla Home.

Riferimenti Apple: [AppIntent](https://developer.apple.com/documentation/appintents/appintent), [WidgetKit](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension), [notifiche locali](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app). Diff incrementale da build 52: [LOCAL-FIRST-53.diff](LOCAL-FIRST-53.diff).
