# Life OS 0.10.6 (67) — interfaccia compatta e destinazione delle spese

## Contratto

Il calendario e la tab bar mantengono la struttura esistente. La Dashboard mette le abitudini quotidiane prima degli impegni futuri. Il turno compare solo durante il lavoro, in un indicatore compatto nel riepilogo; niente scheda grande o lettera duplicata. La settimana perde il titolo mensile ridondante. Gli appuntamenti mostrano titolo e una sola riga secondaria con data e ora; luogo e altri dettagli sono nell’editor.

Le attività espanse usano pulsanti da almeno 44 punti in una griglia adattiva, senza scorrimento orizzontale. I comandi possono andare a capo su schermi stretti. Sfondo della riga uniforme, simboli SF Symbols e accento platino; Finanza usa scorciatoie più compatte senza grandi fondi circolari.

## Inserimento di una spesa

- L’ingresso normale propone un piano attivo della stessa categoria e compatibile con la data. Un solo piano viene suggerito; più piani richiedono una scelta esplicita. I macrogruppi non vengono confusi con le sottocategorie.
- La destinazione rimane modificabile: piano oppure budget mensile. L’anteprima distingue fondo accantonato e altri risparmi. Le bollette possono indicare i mesi coperti; cambiando destinazione a un pagamento esistente, il form conserva il periodo originale.
- Nessun piano compatibile: destinazione budget mensile visibile, senza inventare un accantonamento.
- La disponibilità mostrata è ricontrollata prima di avviare il pagamento, sottraendo anche i pagamenti in corso sullo stesso fondo. Se cambia, l’operazione non inizia con una ripartizione diversa da quella mostrata.
- La cifra digitata aggiorna l’anteprima localmente: niente chiamata al server per ogni cifra.
- Note, descrizione e scelta Già inclusa nel saldo rilevato restano associate al pagamento.

## Movimento unico, salvataggi e recupero

Il nuovo flusso usa la coda e gli identificativi stabili dell’app e il servizio Piani esistente. Una richiesta pianificata viene riservata, il movimento è registrato in modo idempotente e il pagamento viene confermato; soltanto dopo il completamento il server risponde con successo. Un’interruzione dopo la registrazione del movimento si riprende con lo stesso identificativo, senza un nuovo addebito. La UI distingue copia locale in attesa e conferma del server.

Per una spesa già registrata, Cambia destinazione è nei dettagli del movimento. Il Worker mantiene riga, importo, data, conto e registrazione bancaria: modifica soltanto collegamento al piano e trattamento budget, nella stessa transazione D1 con controllo di revisione. È possibile tornare al budget ordinario o scegliere un altro piano compatibile. Il movimento liberato resta modificabile e riutilizzabile. I dati cambiati su un altro dispositivo provocano un errore, non una sovrascrittura silenziosa.

Le spese rifiutate prima dell’inizio si possono correggere dai movimenti in attesa, conservando i campi. Il server registra l’annullamento dell’identificativo: un vecchio invio offline non potrà comparire dopo la correzione. Un pagamento già iniziato va completato con Riprova invio, non cancellato come se non fosse mai stato ricevuto.

## Limiti deliberati

Nessuna riscrittura automatica dei movimenti reali dell’utente. I collegamenti ai piani precedenti si gestiscono dal piano originale. Per ricollegare spese ordinarie di mesi passati, non già dai risparmi o da un piano, il server richiede prima una verifica del budget storico. I pagamenti di un piano di recupero mantengono il loro percorso dedicato. I flussi di entrata, trasferimento e investimento non cambiano.

Il nuovo form è nell’app nativa; il bundle web precedente rimane invariato. La configurazione finanziaria cifrata del Worker è identica a quella già pubblicata nella build 63; nessuna credenziale o archivio utente è stato aggiunto.

## Verifiche

17 test Worker su SQLite reale, con adattatore D1: anteprime, categorie, piani ambigui, budget ordinario, fondo e risparmi, risposta persa, replay, corse fra destinazioni, transazione con rollback, movimento modificato altrove, collegamento/rilascio/nuovo collegamento, possibilità di modifica dopo rilascio, annullamento con protezione dagli invii ritardati, riserve pendenti, inclusione nello snapshot bancario, note vuote conservate, periodo originale delle bollette e controlli HTTP/origine/sessione.

Quattro test del modello nativo eseguiti anche su Linux, con i sorgenti Foundation effettivi: suggerimento e ripartizione; pagamento Acqua senza doppio impatto sul budget; cambio di destinazione senza variazioni del conto o dell’identità; conservazione dei mesi coperti dalla bolletta. Parsing Swift e design system superati. La revisione finale ha superato 183 test unitari e 18 esecuzioni UI nella verifica Apple su iPhone 15 Pro e iPhone SE di terza generazione (simulatori iOS 26.2), inclusi i flussi di spesa, i comandi delle attività, il calendario, il cambio scheda e la geometria del testo durante la modifica. Le esecuzioni annullate non sono conteggiate come superate.

Documentazione verificata: https://developers.cloudflare.com/d1/worker-api/d1-database/#batch — batch ordinati e rollback dell’intera sequenza se una scrittura fallisce.

Non verificato su iPhone fisico/iOS 27. Le schermate reali del simulatore iPhone 15 Pro sono parte della revisione visiva.

## Installazione manuale

Pubblicare prima il Worker 67 mantenendo binding e secret esistenti; poi firmare e installare l’IPA 67. Nessun deploy Cloudflare eseguito dall’assistente. Nessun widget avanzato aggiunto in questa build.

## Tracciabilità

Sorgenti finali: `d3205b59d6df2ef9267260dcbee15e22bf29271a`.

Worker SHA-256: `491154a7c543f97faddf623bb9d4c4003ec17275cfbe818beab6975312cb3ec0`.

Verifica Worker: https://github.com/azeroualit-cloud/LifeOS/actions/runs/40747868274

Verifica Apple finale: https://github.com/azeroualit-cloud/LifeOS/actions/runs/40747868369

IPA SHA-256: `b6be5f745b991390fd1281740d279174454b9b3d373d47c7e87233feadf58b4a`. IPA non firmata, da firmare con il servizio utilizzato dall’utente. App e widget: `0.10.6 (67)`.
