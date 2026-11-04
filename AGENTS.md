# LifeOS — istruzioni persistenti del progetto

Queste istruzioni valgono esclusivamente per LifeOS, non per altri progetti.

## Decisioni dell’utente e conflitti

Prima di iniziare una nuova sessione o modificare il prodotto, leggere `docs/AI-HANDOFF.md`, lo stato attuale e il registro indicato sotto.
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

## META-02 — sincronizzazione e report per altre IA

Leggere `docs/AI-HANDOFF.md` e `docs/STATUS.md` all’avvio. Mantenere aggiornati GitHub e i documenti di stato dopo incrementi significativi, decisioni e verifiche, e prima della consegna: commit e push del solo progetto LifeOS, poi confronto SHA locale/remoto. Fare fetch e preservare il lavoro concorrente; non forzare il push.

Aggiornare `docs/BUILD-STATE.json` quando cambia lo stato della build e `docs/OPEN-ISSUES.md` quando cambia un difetto o la sua prova. Il README del ramo predefinito deve indicare lo stato e l’eventuale ramo corrente. Regole, elenchi, flussi, tecnologie e limiti devono essere leggibili anche da una IA diversa da Codex.

Distinguere risultato tecnico dei test e accettazione del prodotto. La build 78 è stata rifiutata dall’utente come pronta per la produzione: non dichiararla pronta grazie ai vecchi test verdi. Non pubblicare backup, credenziali o dati personali. Ispezionare i workflow: sincronizzare il repository non autorizza un deploy backend o una nuova release.

### Aggiornamento continuo, senza promemoria dell’utente

META-01 e META-02 sono obblighi permanenti di ogni sessione LifeOS, non task da eseguire una volta sola. Non aspettare che l’utente chieda di nuovo «salva», «aggiorna il report» o «aggiorna GitHub».

- A ogni nuovo input: rileggere le decisioni pertinenti, distinguere domanda/task/decisione e controllare i conflitti. Salvare automaticamente decisioni, richieste pendenti e conferme; un conflitto resta sospeso fino alla risposta richiesta da META-01.
- Durante il lavoro: aggiornare i documenti interessati quando cambiano codice, difetti, flussi, tecnologie, esiti dei controlli o stato della build. Pubblicare i checkpoint significativi senza accumulare tutto fino all’ultima consegna.
- Prima di ogni risposta finale o passaggio di sessione: verificare che regole, report e repository descrivano lo stato attuale; se ci sono cambiamenti da conservare, eseguire commit/push e confrontare lo SHA remoto. Se nulla è cambiato, non creare commit vuoti.
- Se la sincronizzazione fallisce, registrare e dichiarare il mancato aggiornamento; non affermare che GitHub sia sincronizzato. Preservare il lavoro e non forzare il push.
- La procedura opera mentre un agente lavora su LifeOS. Non promettere aggiornamenti spontanei quando nessun agente è in esecuzione.

## IPA-GATE-01 — nessuna IPA senza richiesta esplicita

Non produrre, confezionare o distribuire nuove IPA finché l’utente non lo richiede esplicitamente. Le approvazioni di design, implementazione, test o prosecuzione non sono autorizzazione IPA. Consentite le verifiche al simulatore senza packaging. Fonte nel registro USER-DECISIONS.
