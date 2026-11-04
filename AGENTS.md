# LifeOS — istruzioni persistenti del progetto

Queste istruzioni valgono esclusivamente per LifeOS, non per altri progetti.

## Decisioni dell’utente e conflitti

Prima di iniziare una nuova sessione o modificare il prodotto, leggere il registro indicato sotto.
Ad ogni nuovo input decisionale dell’utente, confrontarlo con le regole ACTIVE del registro.

- Salvare le decisioni esplicite con ID, ambito, provenienza, data di registrazione e stato. Conservare il testo originale quando disponibile; indicare chiaramente le parafrasi.
- Se il nuovo input non contraddice una regola attiva, registrarlo e proseguire nel lavoro autorizzato.
- Se contraddice una regola attiva, registrarlo PENDING_CONFIRMATION e chiedere PRIMA di procedere: «Il nuovo input ... è in conflitto con [ID]: ... . Vuoi sostituire questa regola e procedere?».
- Attendere la risposta per la parte in conflitto. Il tempo trascorso non è una conferma. Non inventare una via di mezzo, non sovrascrivere la regola e non ignorare il conflitto in base alla sola recenza.
- Dopo conferma, conservare la vecchia versione come SUPERSEDED e attivare quella nuova; registrare la fonte della conferma. Se viene approvata solo un’eccezione, limitarla all’ambito indicato.
- Non richiedere nuovamente una conferma già data per il medesimo conflitto e lo stesso ambito.
- Le proposte dell’assistente, i mockup e i vecchi documenti non diventano automaticamente nuove istruzioni dell’utente. Separare decisioni permanenti, task una tantum, esempi e ipotesi.
- Non dichiarare funzionante o pronto per la produzione un requisito soltanto perché compare nel registro o perché passano test automatici.
- Se il registro non è disponibile, segnalare il limite anziché fingere di ricordare decisioni persistenti.

La procedura META-01 è stata approvata esplicitamente dall’utente il 4 novembre 2026 e sostituisce il precedente criterio di applicazione automatica dell’ultima istruzione in conflitto. Il salvataggio iniziale è già autorizzato.

## File da leggere

- `docs/USER-DECISIONS.md`: regole attive e procedura.
- `docs/USER-DECISIONS.json`: registro strutturato, conferme e cronologia.
- `docs/decision-history/2026-11-04-inventory.md`: cronologia delle richieste/proposte, non elenco di requisiti tutti approvati.

I sorgenti canonici dell’app sono `native-next/`. Il salvataggio delle decisioni non autorizza nuove funzioni, deploy o modifiche a dati reali.
