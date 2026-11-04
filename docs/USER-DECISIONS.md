# LifeOS — registro persistente delle decisioni utente

Registrato il 4 novembre 2026. Ambito: solo progetto LifeOS.

## META-01 — salva le decisioni; chiedi conferma sui conflitti

Stato: ACTIVE. Approvazione: messaggio esplicito dell’utente in questa chat.

> facciamo che una volta che ti dico qualcosa te te la salvi così persiste tra le sessioni, e se io ti do un nuovo input te mi farai da ora in poi sempre una domanda cheidendomi se voglio procedere dato che va in conflitto con regola x ok?

Per ogni nuovo input:

1. Distinguere decisione persistente, richiesta una tantum, domanda, esempio e proposta.
2. Confrontare le decisioni con le regole attive prima di procedere.
3. Senza conflitto: salvare la decisione e continuare nel perimetro autorizzato.
4. Con conflitto: salvare l’input come PENDING_CONFIRMATION; citare ID e testo della regola e chiedere se sostituirla. Attendere risposta sulla parte coinvolta.
5. Dopo conferma: conservare la versione precedente come SUPERSEDED, registrare conferma e nuova regola ACTIVE. Un’eccezione resta limitata al suo ambito.

Formula della domanda:

> Il nuovo input «…» è in conflitto con **[ID]**: «…». Vuoi sostituire questa regola e procedere con il nuovo input?

Questa procedura sostituisce la precedente applicazione automatica dell’ultima istruzione confliggente. La richiesta corrente costituisce l’approvazione di questo cambio; non serve chiederla di nuovo.

## META-02 — GitHub e passaggio di consegne sempre aggiornati

Stato: ACTIVE. Richiesta esplicita del 4 novembre 2026, in due messaggi consecutivi:

> inoltre devia aggiungere una regola che aggiorna il github remoto con lo stato attuale della build sempre, così se voglio posso far leggere a un altra qualasiasi IA il repo, e già sapr
>
> saprò come ccomporarsi e lavoraci, integrando il report con regole, elenchi, flussi e tecnlogie, tutto up to date

Ad ogni incremento significativo o nuova decisione, e prima del passaggio di sessione:

1. Aggiornare codice e documenti pertinenti: stato build, regole, correzioni, flussi e tecnologie.
2. Registrare fonte, ramo, commit verificato, risultato dei controlli, artefatto e limiti effettivi.
3. Fare fetch, preservare lavoro concorrente, commit e push nel solo repository LifeOS; verificare lo SHA remoto. Niente force push.
4. Rendere lo stato corrente raggiungibile dal README del ramo predefinito, indicando il ramo di lavoro quando diverso.
5. Non pubblicare segreti, dati personali o backup. Ispezionare la CI per evitare deploy involontari.
6. Un aggiornamento del repository non equivale a una nuova build o a un deploy. Non cambiare il valore dei risultati di QA per far apparire pronto il prodotto.

Questa regola si aggiunge a META-01; un futuro conflitto di prodotto richiede comunque la tua conferma. È una procedura delle sessioni di lavoro, non una promessa di sincronizzazione quando nessun agente è attivo.

## Regole attive ricostruite dalle richieste dirette

Le seguenti sono parafrasi, non citazioni letterali. Gli ID corrispondono all’inventario precedente. ACTIVE indica una decisione, non la qualità o il completamento della sua implementazione.

- **A01 — ACTIVE:** Rendere l’app realmente utilizzabile e sufficientemente curata per la produzione, non soltanto compilabile.
- **A16 — ACTIVE:** Verificare margini, padding e bottoni per proporzioni ed esperienza iOS migliorate.
- **C01 — ACTIVE:** Mostrare soltanto HH:mm della prossima preghiera a destra della data, anche quando è del giorno dopo.
- **C02 — ACTIVE:** Aprire tutti gli orari delle preghiere toccando quell’ora.
- **C04 — ACTIVE:** Ridurre il padding e l’ingombro dei tasti Impostazioni e +.
- **C05 — ACTIVE:** Mostrare prima gli eventi di oggi.
- **C06 — ACTIVE:** Mostrare subito dopo le abitudini di oggi.
- **C07 — ACTIVE:** Mostrare poi soltanto gli eventi a meno di tre giorni, senza estendere la lista a tutta la settimana.
- **C08 — ACTIVE:** Escludere dalla Dashboard le attività generiche e tutto ciò che non rientra nella finestra richiesta.
- **C15 — ACTIVE:** Nel blocco Finanza mostrare soltanto titolo, icona e freccia nell’intestazione.
- **C16 — ACTIVE:** Sotto l’intestazione mostrare il numero del budget con Budget sotto.
- **C17 — ACTIVE:** Affiancare Aggiungi spesa sulla destra del budget, facilmente raggiungibile con il dito.
- **C21 — ACTIVE:** Integrare nella Dashboard un inserimento nutrizionale rapido e compatto.
- **F02 — ACTIVE:** Aggiungere il campo fibre.
- **F03 — ACTIVE:** Inserire i nutrienti come valori per 100 g.
- **F04 — ACTIVE:** Scegliere sotto i grammi effettivamente consumati.
- **F05 — ACTIVE:** Inserire anche le kcal dell’etichetta per 100 g, come da tua risposta esplicita.
- **F06 — ACTIVE:** Scalare nutrienti, fibre e kcal sulla porzione effettiva.
- **F07 — ACTIVE:** Esporre soltanto la data, senza campo ora.
- **G01 — ACTIVE:** Togliere i pulsanti Collega/Gestisci Apple Salute dalla pagina.
- **G02 — ACTIVE:** Togliere la sezione di selezione della fonte calorie.
- **G03 — ACTIVE:** Contare tutte le registrazioni caloriche di tutte le app presenti in Apple Salute.
- **G05 — ACTIVE:** Aggiunta peso e registrazione macro come due azioni grafiche senza testo.
- **G06 — ACTIVE:** Usare omino per peso e mela per nutrizione.
- **G07 — ACTIVE:** Applicare Liquid Glass alle due azioni e collocarle sopra la barra inferiore.
- **G08 — ACTIVE:** Applicare lo stile della dashboard Apple Salute alle quattro schede.
- **G09 — ACTIVE:** Dare alle quattro righe la stessa altezza.
- **G10 — ACTIVE:** Usare icona e titolo piccoli e colorati in alto a sinistra.
- **G11 — ACTIVE:** Usare valore grande e bianco in basso a sinistra, con unità piccola e grigia adiacente.
- **G12 — ACTIVE:** Collocare il mini grafico sulla destra, grigio con l’ultima parte colorata.
- **G13 — ACTIVE:** Applicare questo trattamento a TDEE, Peso, Calorie e Simulazione.
- **G14 — ACTIVE:** Usare la skill REA da GitHub per analizzare il riferimento reale Apple Salute.
- **H01 — ACTIVE:** Ridurre dimensioni e padding eccessivi dei pulsanti Bloom.
- **H02 — ACTIVE:** Correggere selezione del backup in File che si chiude senza procedere.
- **H03 — ACTIVE:** Rendere trasferibili e visibili in LifeOS i contenuti locali conservati nell’app Bloom originale.
- **L04 — ACTIVE:** Ridurre cicli lunghi di lavoro che terminano con una versione ancora piena di difetti visibili.
- **L05 — ACTIVE:** Non scaricare sull’utente il collaudo iniziale né costringerlo a ripetere continuamente le stesse correzioni.
- **L06 — ACTIVE:** Intervenire sull’app installabile effettiva: un mockup non risolve i difetti della build.
- **L08 — ACTIVE:** Operare autonomamente entro il progetto senza impattare risorse esterne al progetto.

## Conservazione della cronologia

- Registro strutturato: `USER-DECISIONS.json`.
- Inventario completo di 238 voci: `decision-history/2026-11-04-inventory.md` e `.json`.
- Le richieste dei vecchi documenti, le proposte dell’assistente e i concept restano distinguibili nell’inventario; non sono stati tutti promossi a regole attive.
- Le richieste una tantum L01/L02 riguardavano l’inventario ora prodotto, non un vincolo a lavorare sempre su tutta l’app in ogni futura richiesta.
- La voce L07 era una precisazione interpretativa dell’inventario e non è stata convertita in una tua regola esplicita.
- Conferme in attesa al salvataggio iniziale: nessuna.

## Limite della persistenza

Questi file sono versionati nel repository LifeOS e richiamati dai suoi AGENTS.md. La sincronizzazione remota segue META-02. Non costituiscono memoria globale garantita di ogni chat o di altri progetti. Nessuna istruzione generale dell’utente è stata modificata. Nessun codice applicativo, dato o rilascio è stato cambiato per salvare questo registro.
