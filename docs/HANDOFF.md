# Life OS — passaggio corrente, 24 ottobre 2026

Leggere [STATUS.md](STATUS.md) e [native/BUILD-60.md](native/BUILD-60.md). La build nativa corrente è 0.9.9 build 60, sul ramo codex/native-build60. Non usare main come riferimento visivo: era rimasto alla 51; la release 59 corrisponde esattamente a d88355ba9c10cc57cf7e4ff99e80d8f76ff7e6d9. La 60 recupera da lì HealthKit, struttura a quattro schede e Budget/Piani, mantenendo la sincronizzazione e le integrazioni native della 53.

## Sorgenti e prove

Pacchetto canonico lifeos-native.zip, SHA-256 b09762b88e4dc017d2c89fa7582ac38daf1fddf5aa0dd12fed94d73f6099ef03. Commit del binario verificato 5bf2f3fbb4c306636f55f36a69d5ffc4911c665b. Build riuscita 40129522914, verifica indipendente 40131901858. Link IPA e checksum in BUILD-60.md. Il consenso esplicito dell’utente alla pubblicazione dei sorgenti nativi aggiornati e alla procedura temporanea per il link IPA è già stato ricevuto: non richiederlo genericamente di nuovo.

156 test unitari e 35 UI della baseline sono riusati soltanto perché codice dell’app, risorse, entitlements/progetto, tutti i test unitari e gli altri 35 test UI sono verificati identici tramite digest. I 2 test UI aggiornati e 6 compatti sono passati sulla build finale. Vedere BUILD-60.md per gli esiti e i limiti: non dichiarare 37 UI freschi in un’unica esecuzione. I futuri cambi al codice dell’app/widget/progetto o agli altri test devono ripristinare verifiche appropriate complete; non aggiornare automaticamente i digest per aggirare la guardia. Il workflow IPA temporaneo con contents:write viene rimosso dopo la pubblicazione.

scripts/package-native.py include LifeOS.entitlements, produce ZIP deterministico, digest CI e diff locale RESTORE-60.diff dalla 53, comprese le rimozioni. Estrarre il pacchetto in una cartella nuova, evitando directory native obsolete. I successivi commit di verifica/documentazione non cambiano il binario.

## Contratti

HealthKit legge peso e calorie alimentari per sei mesi; usa una sola fonte alimentare selezionabile. Salvataggi del peso tramite + o Siri con consenso HealthKit, nessun upload al server Life OS. La modalità finanziaria demo non sostituisce i dati salute reali: i dati illustrativi sono limitati alle prove visuali DEBUG. Le vecchie saveHealthEntry valide vengono ritirate dalla coda conservandole nell’archivio locale; nessun invio alla vecchia API e nessuna scrittura automatica in Salute. Payload malformati restano nel backup.

Setter assoluti di attività, abitudini, turni e occorrenze persistiti prima della rete; UUID dei movimenti finanziari conservati. Creazioni/cancellazioni prive di idempotenza attendono il server. Le letture tardive riproiettano la coda; nessun saldo nuovo prima della conferma del server. Il client riprova in primo piano, non garantisce sincronizzazione continua con app sospesa. Conflitti tra dispositivi: ultimo setter inviato prevalente.

Notifiche locali opzionali dai dati caricati, non push remote; Siri in primo piano con autenticazione. Widget 60 solo accessi rapidi senza App Groups/dati privati. Nessuna prova fisica dopo firma: preservare bundle com.nas.lifeos.probe, estensione WidgetKit e HealthKit. Aggiornare senza disinstallare.

## Richiesta widget successiva

L’utente ha chiesto di progettare prima di implementare: 3 concept piccoli 2×2 (Turno, Agenda, Ritmo) e 3 medi 4×2 (Settimana, Moduli, Prossimo) sono stati generati e mostrati. Scelta ancora da consolidare. I widget con dati reali non sono nella 60: verificare condivisione dati/capability e profilo Signulous prima di promettere il funzionamento. Non trattare le immagini come componenti già sviluppati.

## Web/backend

Nessun deploy o merge eseguito. Nessuna modifica web/backend in questo incremento nativo; i dati condivisi possono riflettersi nella webapp alla lettura successiva. HealthKit non è condiviso con il web. Le estensioni server precedenti restano separate e non vengono attivate automaticamente. Conservare web/worker.mjs originale; non ricopiare storico o dettagli operativi in nuove pubblicazioni. CI con fixture isolate, nessun accesso live al backend con credenziali.
