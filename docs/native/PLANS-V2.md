# Piani finanziari v2 — flusso approvato

## Requisiti e accettazione

Il + di Piani ignora il mese visualizzato e apre un modulo con intento esplicito: anticipa budget, metti da parte, rateizza una spesa. Gli intervalli usano soltanto mese e anno. Il giorno è un dato del pagamento effettivo. Anteprima dei budget prima del salvataggio. La spesa rapida offre Automatico e Da risparmi; i trattamenti dei movimenti storici sono conservati, non convertiti silenziosamente.

Accantonamenti: obiettivo finito (totale/intervallo), fondo continuativo (quota mensile), ricorrente fissa (importo per scadenza), ricorrente stimata (quota iniziale aggiornata dai pagamenti per mese di competenza). Pagamento unico, piano e scadenza con stati distinti; solo un obiettivo finito si chiude pagando. Lo stop conserva le quote maturate, annulla quelle future e non genera movimenti. Recupero dell'eccedenza di un obiettivo finito facoltativo e separato dal pagamento. I recuperi di spese già pagate non offrono un secondo pagamento.

## Wireframe e componenti

Finanza > Piani: intestazione con i e +; mese consultato e relativo impatto; elenco di tutti i piani, anche quelli che non incidono sul mese visualizzato. Scheda piano: stato, impatto mensile, storico pagamenti; azione pagamento per obiettivi/fondi/ricorrenti, stop per fondi/ricorrenti/recuperi. Il + apre un Form nativo con sezioni Nome/importo, Mesi, Anteprima, Salva. Il flusso di pagamento è un Form distinto: importo effettivo, giorno, competenza/scadenza, eventuale recupero dell'eccedenza. Foglio Info con esempi e regole del flusso. Token e superfici nativi esistenti, nessuna nuova tab.

## Contratto e invarianti

Importi interi in centesimi; ripartizione esatta dei centesimi residui. Gli anticipi sommano a zero; non sono movimenti bancari. Quote e recuperi riducono solo il budget; un pagamento è un unico movimento Da risparmi. I periodi incompleti non producono totali completi fittizi. Niente modifiche retroattive dei budget chiusi. Utenze: media degli importi / mesi coperti dai pagamenti, applicata dal prossimo mese. Nessun cambio delle quote storiche. Il saldo e le categorie reali dei pagamenti restano gestiti dal motore esistente.

L'estensione server è separata dal Worker legacy: autenticazione delegata al Worker esistente, origini e metodi verificati, archivio D1 dedicato, aggiornamenti con confronto versione, pagamenti riservati prima della scrittura bancaria, requestId stabile e recupero dopo errori. Richiede il contratto idempotente saveTransaction già usato dal client. Sorgente e deployment reali del Worker non sono disponibili in questo ambiente. Non si presume una migrazione dei piani legacy: restano consultabili/modificabili attraverso il percorso esistente. L'adozione di affitto/utenze/piani precedenti deve essere verificata contro le voci del Worker prima di rimuovere o sostituire alcun accantonamento esistente.

## Incrementi e verifica

1. Motore server e invarianti: anticipi, quote, recuperi, fondo, ricorrenze, chiusura, eccedenze.
2. Persistenza/idempotenza/autorizzazione con adapter al Worker e test SQLite in memoria.
3. Form e lista nativi, anteprime, pagamenti, info e riduzione trattamenti spesa rapida.
4. Test dei calcoli Swift e del motore server, regressioni esistenti, controlli sintattici/design e integrità ZIP. CI iOS e integrazione sul Worker reale distinte dai controlli locali. Nessuna IPA richiesta.

## Stato della verifica

I test locali del motore passano su SQLite in memoria e adapter HTTP: anticipi +250/-250, quote -125/-125, centesimi residui, chiusura obiettivo, differenza 100 €, fondo continuativo, affitto, media per competenza utenze, errore dopo scrittura, richieste concorrenti, idempotenza, persistenza, autenticazione, protezione movimenti collegati e nomi legacy duplicati. Il percorso di errore in cui il Worker conferma solo true senza movementId è testato e resta bloccante per l'integrazione reale, non viene dichiarato un pagamento riuscito.

Suite Foundation locale: 90 test passati. Motore server: 22 test passati. Parsing di tutti i sorgenti/test e controllo design passati. Verifica Apple senza archive/IPA nel workflow `lifeos-plans-tests.yml`: esito da registrare dopo il completamento. Nessuna scrittura sul database reale o distribuzione del Worker.

Il ramo feature/plans-v2 esclude intenzionalmente il workflow di creazione IPA e usa solo il workflow di test. Il sorgente reale del Worker e l'adozione degli accantonamenti legacy rimangono da collegare/verificare; i relativi record non vengono cancellati o convertiti automaticamente. La UI reale mostra la necessità dell'aggiornamento server e disabilita il salvataggio v2 finché non riceve un contratto versione 2 valido.
