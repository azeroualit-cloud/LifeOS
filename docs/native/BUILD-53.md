# Life OS 0.9.0 build 53 — app unificata e prime integrazioni native

Sostituisce la direzione della build 52: Dashboard, Attività e Finanza; calendario aperto dalla Dashboard, con eventi e attività pianificate; abitudini nuovamente disponibili. Dati storici conservati, stesso bundle e archivio locale.

## Responsività e integrità

Stato attività, spunte abitudini, turni e misurazioni salute si applicano e si persistono atomicamente sul dispositivo prima della rete. La coda conserva ordine e conferme del server anche dopo riavvio; un aggiornamento tardivo riapplica le modifiche locali pendenti. La sincronizzazione ha uno stato separato dal salvataggio in primo piano. I movimenti finanziari mantengono gli UUID e la conferma remota e chiudono il salvataggio dopo la persistenza locale.

Solo setter assoluti con chiavi stabili vengono accodati. Nuove attività/eventi/abitudini, modifiche e cancellazioni restano confermate dal server: queste API non hanno ancora un contratto per creazioni offline senza duplicati. Le abitudini di un giorno passato possono essere rifiutate dal backend esistente: la modifica resta visibile in coda, senza bloccare le altre. Nelle impostazioni si può riprovare oppure ripristinare il valore del server con una lettura confermata; i movimenti finanziari non sono eliminabili da questo pannello.

## Integrazioni

- Notifiche locali opzionali, autorizzate dall’utente nelle impostazioni: attività alle 9 della scadenza, eventi 15 minuti prima, turni lavorativi un’ora prima. Fuso Europe/Rome, prossimi 48 avvisi dai dati caricati. Completamenti/cancellazioni riprogrammano il piano. Le modifiche dal web arrivano agli avvisi alla successiva apertura/sincronizzazione dell’app; nessuna push remota.
- Siri/Comandi Rapidi: registra il peso di oggi nella coda locale; prepara un’attività dettandone il titolo e apre l’editor per confermare Salva. Esecuzione in primo piano con autenticazione del dispositivo. Un solo store condiviso tra app e intent, nessun secondo writer dell’archivio.
- Estensione WidgetKit: widget piccolo per Nuova attività; medio per attività/peso/calendario. Accessi rapidi tramite URL locali validati; nessun dato finanziario/salute esposto, nessun App Group necessario. Non è ancora un widget dinamico con agenda o completamenti interattivi.

## Verifica e limiti

Design-system guard e controllo diff locali passati. Build Apple e test in corso: non dichiarare ancora l’IPA verificata. Test nuovi per persistenza prima della rete, risposta ritardata, riavvio, ordine dei turni, errore di accesso, ripristino sicuro, replay, validazione salute, notifiche e URL.

La build unsigned contiene l’estensione; registrazione del widget e Siri dopo firma Signulous richiedono prova sull’iPhone. Non è possibile attestare le capability del profilo di firma da questo ambiente. Conservare le estensioni durante la firma se il servizio offre tale opzione; aggiornare senza disinstallare. Nessun deploy Cloudflare effettuato: le API salute della build 52 restano da attivare, eventuali misurazioni restano in coda se il server non le supporta.

Riferimenti Apple consultati: [AppIntent](https://developer.apple.com/documentation/appintents/appintent), [WidgetKit](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension), [notifiche locali](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app). Diff incrementale da build 52: [LOCAL-FIRST-53.diff](LOCAL-FIRST-53.diff).
