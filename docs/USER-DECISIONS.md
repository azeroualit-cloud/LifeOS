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


### Aggiornamento continuo, senza promemoria dell’utente

META-01 e META-02 sono obblighi permanenti di ogni sessione LifeOS, non task da eseguire una volta sola. Non aspettare che l’utente chieda di nuovo «salva», «aggiorna il report» o «aggiorna GitHub».

- A ogni nuovo input: rileggere le decisioni pertinenti, distinguere domanda/task/decisione e controllare i conflitti. Salvare automaticamente decisioni, richieste pendenti e conferme; un conflitto resta sospeso fino alla risposta richiesta da META-01.
- Durante il lavoro: aggiornare i documenti interessati quando cambiano codice, difetti, flussi, tecnologie, esiti dei controlli o stato della build. Pubblicare i checkpoint significativi senza accumulare tutto fino all’ultima consegna.
- Prima di ogni risposta finale o passaggio di sessione: verificare che regole, report e repository descrivano lo stato attuale; se ci sono cambiamenti da conservare, eseguire commit/push e confrontare lo SHA remoto. Se nulla è cambiato, non creare commit vuoti.
- Se la sincronizzazione fallisce, registrare e dichiarare il mancato aggiornamento; non affermare che GitHub sia sincronizzato. Preservare il lavoro e non forzare il push.
- La procedura opera mentre un agente lavora su LifeOS. Non promettere aggiornamenti spontanei quando nessun agente è in esecuzione.

Richiesta di chiarimento dell’utente del 4 novembre 2026:

> ma deve essere una cosa che aggiorni continuamente come le regole e non solo ora che te l'ho deatto

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
- **F03 — SUSPENDED:** Inserire i nutrienti come valori per 100 g.
- **F04 — SUSPENDED:** Scegliere sotto i grammi effettivamente consumati.
- **F05 — SUSPENDED:** Inserire anche le kcal dell’etichetta per 100 g, come da tua risposta esplicita.
- **F06 — SUSPENDED:** Scalare nutrienti, fibre e kcal sulla porzione effettiva.
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

## Ambiente disponibile — fatto operativo, non nuova funzione

Il 4 novembre 2026 l’utente precisa: «non ho ne mac locali ne mac remoti però, è li il problema».
Lavora da Windows e non dispone di un Mac locale o remoto. Il percorso iOS già utilizzato è la CI GitHub con runner macOS `xcode-27`. Non presupporre un Mac a sua disposizione o un acquisto/noleggio approvato. Il precedente consiglio di un Mac persistente resta una proposta.

## DEV-01 — ciclo di sviluppo da Windows (ACTIVE)

Approvato il 4 novembre 2026: «implementiamo in questo modo allora». Anteprima reale, verifiche mirate e IPA finale separati. Dettagli in [DEVELOPMENT-CYCLE.md](DEVELOPMENT-CYCLE.md). Compatibile con le regole attive; nessuna accettazione automatica del prodotto.

## DEV-02 / H-GRID-01 — approvazione correzioni e griglia Bloom

ACTIVE, 4 novembre 2026. Proporre le modifiche di prodotto e attendere approvazione. Prima correzione approvata: due colonne, immagini contenute nelle card e altezza adattata al contenuto, con anteprime dei link. Fonte: «approvo con l’unica accortezza di per i link mostrare le anteprime». Nessun conflitto con le regole attive.

### Accettazione visiva H-GRID-01

4 novembre 2026: «ok, procediamo con la prossima correzzione», dopo la cattura Bloom. Accettato il risultato visivo mostrato; nessuna accettazione globale per produzione o prova sul telefono. Prossima modifica di prodotto da proporre e approvare (DEV-02).

## NUTRITION-DIRECT-01 — PENDING_CONFIRMATION

Richiesto il 4 novembre: quick add Dashboard con quantità effettive di proteine/carboidrati/grassi/fibre e kcal automatiche; abbandonare per ora il percorso per 100 g. Conflitto con F03, F04, F05, F06. Attendere conferma della sospensione temporanea prima di modificare il prodotto; conservare dati storici. Nessuna implementazione avviata.

## NUTRITION-DIRECT-01 — ACTIVE, conflitto confermato

Conferma 4 novembre: «si, prima di procedere quindi come lo vuoi implementare lato design». F03–F06 sospese per ora; storico conservato. Approvato pulsante + Nutrizione in Dashboard → pannello dal basso con proteine/carboidrati/grassi/fibre effettivi in g, kcal automatiche, data Oggi modificabile, Aggiungi sopra tastiera. «seguiamo la tua idea, non appena hai l’immagine del render mostramela subito prima di procedere con altro»: mostrare il render prima di altre attività, nessuna implementazione applicativa in questo passo. La precedente sezione PENDING_CONFIRMATION è storica e risolta.

Render NUTRITION-DIRECT-01 approvato con «ok approvo». Lo stop al solo render è soddisfatto; autorizzata implementazione del design mostrato e relative verifiche, non una nuova distribuzione.

## IPA-GATE-01 — ACTIVE

4 novembre 2026, testo utente: «ok ma non produciamo ipa finché non te lo dico io». Nessuna nuova IPA prodotta, confezionata o distribuita senza richiesta esplicita dell’utente. Approvare design, implementazione, test o prosecuzione non autorizza IPA. Compilazione e verifiche al simulatore consentite senza packaging IPA. Compatibile con DEV-01/DEV-02.

## HEALTH-UX-01 / HEALTH-PLAN-01 — ACTIVE, 4 novembre 2026

Obiettivo esplicito: Salute per bodybuilding con dati subito visibili, consultazione e futura registrazione pasti con minimo attrito e movimento del dito. Ora soltanto aggiornamento checklist e passaggio Astra (pianificazione) → Terra (esecuzione di incrementi successivamente approvati), senza implementare nuovi inserimenti o database e senza rimuovere il quick add. Nessuna IPA.

Griglia, nutrienti in fila, due pulsanti e catalogo locale sono proposte non obbligatorie: l’utente dice «Però tutto ciò che ho detto non è obbligatorio». «4x4» con quattro celle descritte in due righe è interpretato provvisoriamente come 2×2, da esplicitare nel piano. Regole G05–G13 conservate; prima di attuare scelte incompatibili chiedere conferma. F03–F06 restano sospese per il quick add. Dettagli e domande aperte in [HEALTH-BODYBUILDING-BRIEF.md](HEALTH-BODYBUILDING-BRIEF.md); stato completo in [PROJECT-CHECKLIST.md](PROJECT-CHECKLIST.md).

## PROJECT-PLAN-01 — ACTIVE

Mandato Astra ampliato all’intero LifeOS: ricostruire tutte le modifiche discusse ancora pertinenti e mancanti fino alla consegna IPA, con task per Terra. [Brief globale](PROJECT-PLAN-BRIEF.md). Nessuna IPA autorizzata dal mandato. La domanda sui sottoagenti economici è registrata come proposta da valutare nel piano, non come obbligo di delegare ogni lavoro o configurazione già applicata. Nessun conflitto con le regole di approvazione esistenti.

## Esecuzione del piano — 4 novembre 2026

- **PROJECT-EXECUTION-01 — ACTIVE:** «PLEASE IMPLEMENT THIS PLAN», seguito da «continua», autorizza gli incrementi nel [piano operativo](PROJECT-RELEASE-PLAN.md), non IPA, deploy o sostituzioni delle regole di layout.
- **HEALTH-GRID-PLAN-02 — ACTIVE:** «Progettare la griglia» prima della IPA autorizza l’anteprima T07, non la modifica del layout in conflitto.
- **HEALTH-MACROS-SOURCES-01 — ACTIVE:** «Tutte le app (Recommended)» per letture HealthKit di proteine, carboidrati, grassi e fibre; evitare doppi conteggi.
- **HEALTH-GRID-CONFLICT-01 — PENDING_CONFIRMATION:** griglia e grafici proposti possono confliggere con G08, G09, G12 e G13. Le regole restano ACTIVE; l’anteprima precede la domanda e nessun codice relativo alla deroga è autorizzato senza conferma.

## HEALTH-GRID-02 — ACTIVE, eccezione confermata

4 novembre 2026, risposta esplicita alla domanda sul conflitto: «va bene 2x2 e 1x4, ma voglio i pulsanti come quelli nella versione 2 (nel senso di disposizione, non di colore design ecc)». Nel solo riepilogo Salute sono approvati griglia 2×2, mini grafici sotto i valori, nutrienti 1×4 con reflow accessibile e azioni affiancate come versione 2. La deroga riguarda G08/G09/G12/G13 in questo ambito; altrove rimangono vigenti. G05–G07 restano attive: omino e mela senza testo. Nessuna IPA o deploy.

## QA-012 — correzione approvata

5 novembre 2026: «Sì, correggi» in risposta alla proposta di rendere leggibili e raggiungibili riepilogo calorie e pulsante Aggiungi con testo molto grande e tastiera aperta. Autorizzazione limitata alla correzione; nessuna IPA o deploy.

## QA-014 — approvata; QA-013 — in attesa

5 novembre 2026: «per salute si, per bloom non so se 44pixel é corretto finche non lo vedo». Approvata correzione della leggibilità titoli Salute mantenendo 2×2. Per Bloom non approvata alcuna modifica prima di vedere il risultato; 44 indica punti iOS, non pixel.

## QA-013 — correzione Bloom approvata

5 novembre 2026, dopo screenshot reale: «Sì, mantieni questo aspetto». Conservare dimensione visibile delle pillole Bloom; correggere solo il riquadro riconosciuto dall’accessibilità. Nessuna IPA o deploy.

## EXECUTION-AUTONOMY-01 — ACTIVE

5 novembre 2026: «intanto fai tutte le cose che te puoi fare, e poi una volta fatte lascia tutte  le cose che devo fare io alla fine». Eseguire autonomamente ciò che è autorizzato e possibile; raccogliere alla fine le attività che richiedono l’utente, mantenendo META-01, DEV-02 e IPA-GATE-01.

## CALENDAR-CIVIL-DATE-FIX-01 — correzione approvata

5 novembre 2026: «approvo, ma metterci 5 ore é eccessivo», in risposta alla correzione proposta per la data dell’editor calendario. Autorizzata correzione mirata del fuso civile e verifica con fusi diversi; usare prove mirate per ridurre tempi e attese. Nessuna IPA o deploy autorizzati.

## IPA-DELIVERY-2026-11-05 — autorizzazione per questa consegna

Fonte: richiesta diretta del 5 novembre 2026. «Ti chiedo esplicitamente di produrre e consegnarmi una nuova IPA, ma solo dopo aver completato con successo il collaudo pre-IPA.» IPA-GATE-01 applicata. Deploy backend e cancellazioni esclusi. La release 78 resta intatta. La nuova IPA diventa finale solo dopo prove iPhone e accettazione esplicita.

## UI-80-01 — ACTIVE, deroga confermata

6 novembre 2026, richiesta diretta dopo le quattro schermate su iPhone. Correggere gli allineamenti e usare Liquid Glass neutro per Aggiungi spesa e Aggiungi alimento in Dashboard, con azione alimento dentro la scheda Nutrizione. «Sì, confermo la deroga»: in Salute le due azioni con testo visibile sono centrate nel riquadro Nutrienti, in deroga a G05/G07 e alla disposizione HEALTH-GRID-02; icone G06 conservate. Autorizzata una nuova IPA per questa consegna dopo il collaudo pre-IPA.

## UX-REACH-01 — ACTIVE, 6 novembre 2026

I pulsanti che nel normale utilizzo previsto possono essere premuti molte volte al giorno non devono mai trovarsi in alto a destra. Collocarli dove il pollice li raggiunge comodamente.

Fonte. Richiesta esplicita durante la revisione della bozza Nutrizione.

## IPA-REDESIGN-82 — consegna autorizzata, 6 novembre 2026

«no voglio l'ipa di tutto il redesign, e lasciami il link actions per capire se é prodotto o meno cosí te non sorechi token». Autorizzazione per questa consegna, con suite completa e quattro avvii Release prima del confezionamento. Ordine Dashboard esistente e percorsi manuali preservati.

## UTILITY-CURRENT-BUDGET-01 — ACTIVE, 7 novembre 2026

Approvato con «si» il ricalcolo della stima nel budget del mese corrente quando si corregge il periodo di una bolletta collegata a un piano stimato.

Deploy Cloudflare autorizzato con la successiva conferma «si» per entrambi i Worker, `lifeos` e `lifeos-native-test`.

## NUTRITION-GENERIC-IT-01 — ACTIVE, 7 novembre 2026

Fonte utente: «gli alimenti generici sono migliaia, in inglese, e troppo complicati da trovare, e sono basati su usda quando io volevo un database generico che coprisse i cibi in modo generico come fa fitia (quindi cerco Biscotti, e trovo Biscotti, cerco Petto di Pollo e trovo quello)»

Per gli alimenti generici, usare nomi italiani di uso comune e mostrare subito la voce cercata. Sostituire il catalogo USDA. Fitia è il riferimento per la semplicità della ricerca.

**Attuazione del catalogo e della ricerca dopo la revisione dell’utente.** La proposta è una selezione offline da Ciqual 2025, con sinonimi e precedenza al nome esatto. Tipo o preparazione compaiono sotto il nome quando servono a distinguere i valori per 100 g. I primi riferimenti verificati nel dataset sono Biscotti semplici (24001) e Petto di pollo crudo senza pelle (36017). [Fonte Ciqual 2025](https://zenodo.org/records/17550133).

Revisione utente del 7 novembre 2026: «invece di "Semplici" usa "Generic", e poi deve essereci una lente con una barra di ricerca al posto di "Alimenti Generici" scritto in quel modo, e i 2 tasti aggiungi peso e aggiungi alimento sostali sopra la barra di navigazioni e guori dalla scheda nutrienti»

La revisione è stata interpretata come via libera al catalogo con le modifiche indicate. Implementate 145 voci locali, dicitura «Generic» per Biscotti e barra «Cerca alimento» con lente. Compilazione e prove al simulatore superate nel [run 42387125517](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42387125517).

## HEALTH-ACTIONS-BOTTOM-01 — ACTIVE, 7 novembre 2026

La revisione chiede di spostare «Aggiungi peso» e «Aggiungi alimento» fuori da Nutrienti e subito sopra la barra di navigazione di Salute. L’utente ha risposto «si» alla domanda META-01. La posizione al centro di Nutrienti prevista da UI-80-01 è SUPERSEDED per le due azioni Salute. Le etichette visibili e le icone restano previste.

## IPA-DELIVERY-2026-11-07 — consegna autorizzata, 7 novembre 2026

Richiesta diretta: «e manda i produzione lìipa allora». Autorizzata la pubblicazione della build 83 (0.10.21) su GitHub Releases dopo suite completa, quattro avvii Release e verifica del pacchetto. L’IPA è destinata a Signulous. Prova fisica e accettazione utente restano distinte.

## UX-DATE-PICKER-01 — ACTIVE, 8 novembre 2026

Fonte utente: «si, e non é la prima volta che cé sto errore quindi aggiungila come regola».

Su iPhone, aprire i selettori grafici della data in un foglio a tutta larghezza. Tutte e sette le colonne del calendario devono essere visibili e raggiungibili con testo standard e grande. Evitare i popover ancorati su larghezza compatta e preservare i dati del modulo quando si torna dal calendario.

Correzione approvata per NUTRITION-DATE-CLIP-01. Il pulsante Data in Aggiungi nutrienti apre il calendario con Fine e Annulla. Verificare il layout su iPhone a larghezza compatta, anche con testo grande, e controllare che la bozza dei nutrienti sia conservata.
