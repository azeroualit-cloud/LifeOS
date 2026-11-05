# LifeOS — punto di ingresso per qualsiasi IA

Aggiornamento 5 novembre: run focused nutrizione 41894390397 passato, dettagli in STATUS; revisione video e prova fisica restano aperte. HEALTH-GRID-02 approvata con eccezione limitata al riepilogo; implementazione in corso, nessuna IPA o deploy. Le sezioni precedenti su retry non verificato e conferma Salute pendente sono storiche.

T01: pipeline finale manuale senza IPA e selettore attività/calendario/turni in verifica; consultare STATUS per prova runner e stato esatto. La suite finale non è stata eseguita.

**Capacità CI aggiornata:** run 41873100610 tentativo 2 riuscito su macos-15-arm64, Xcode 26.3, SDK/runtime iOS 26.2. È una prova di disponibilità runner, non un test dell’app; il retry nutrizionale resta non verificato.

## Aggiornamento operativo — piano approvato, 4 novembre 2026

Il piano completo è autorizzato ed è in corso: [piano](PROJECT-RELEASE-PLAN.md), [copertura](REQUIREMENT-COVERAGE.json), [manifesto](EXECUTION-MANIFEST.json). I precedenti passaggi che indicano solo pianificazione o accettazione Bloom pendente sono storici e superati. Bloom è accettato visivamente, non per produzione; retry nutrizione resta non verificato; IPA 78 non accettata. Nessuna nuova IPA né deploy autorizzati. T07 prevede anteprima e conferma dei conflitti prima della modifica di Salute.

## Mandato Astra aggiornato — piano dell’intero progetto

L’utente richiede il piano completo di tutte le modifiche mancanti fino all’IPA finale, non solo Salute. Leggere [PROJECT-PLAN-BRIEF.md](PROJECT-PLAN-BRIEF.md); il brief Salute è un allegato. Includere una proposta di task per Terra e sottoagenti con modelli economici, verificando costi e capacità reali. Nessun agente avviato o configurato da questo aggiornamento, nessuna implementazione e nessuna IPA autorizzate.

## Passaggio pianificazione Salute — 4 novembre 2026

Nuovo obiettivo HEALTH-UX-01: Salute per bodybuilding, dati immediati e minimo attrito. Aggiornamento documentale autorizzato, nuovi inserimenti/database NON implementati o approvati. Leggere [checklist unificata](PROJECT-CHECKLIST.md) e [brief Astra → Terra](HEALTH-BODYBUILDING-BRIEF.md): distinguere obiettivo fermo, layout/catalogo non vincolanti e conflitti da confermare. Nessuna nuova chat creata automaticamente, nessuna IPA.

Ultimi controlli 41871989512 e 41873100610 terminati senza runner assegnato: annotazioni GitHub confermano capacità macOS arm64 insufficiente, nessuno step eseguito. I riferimenti «in coda» nelle note cronologiche sotto sono superati da questo aggiornamento; nessun nuovo test avviato per il passaggio.

## Incremento corrente — nutrizione rapida (4 novembre 2026)

NUTRITION-DIRECT-01: render approvato con «ok approvo», implementazione autorizzata. Dashboard con solo pulsante Nutrizione; foglio con proteine/carboidrati/grassi/fibre effettivi, calorie automatiche e data. Il flusso per 100 g è sospeso; storico non migrato. Fonte e prove: [NUTRITION-QUICK-REVIEW.md](NUTRITION-QUICK-REVIEW.md).

Compilazione riuscita, 271 unitari e quattro UI passati nel run 41853040353; un UI accessibilità fallito nella ricerca del campo disabilitato. Video nativo mostra valori conservati, errore e Riprova visibili, foglio aperto dopo scroll. Il run 41856609394 è terminato senza runner assegnato e senza eseguire test (annotazione GitHub: “The job was not acquired by Runner of type hosted even after multiple attempts”). Anche 41859714562 è terminato senza runner acquisito, nessun test eseguito. Workflow sviluppo spostato su macos-26 standard, mantenendo il selettore compatibile già esistente; verifica 41871989512 sul commit cad0a7b5 in coda. Nessuna IPA autorizzata (IPA-GATE-01). Non dichiarare ancora completato il retry di questa versione. Nessuna nuova IPA, nessun deploy, nessuna verifica HealthKit su dispositivo fisico. Il render approvato non costituisce accettazione dell’implementazione.

Aggiornato il 4 novembre 2026. Leggere prima di pianificare o modificare il progetto.

## Ordine di lettura

1. `../AGENTS.md` — istruzioni del progetto e obbligo di conferma sui conflitti.
2. `USER-DECISIONS.md` e `.json` — META-01/META-02 e regole utente ACTIVE.
3. `STATUS.md` e `BUILD-STATE.json` — stato effettivo del codice, dell’ultima IPA e dell’accettazione.
4. `OPEN-ISSUES.md` — difetti osservati, verifiche mancanti e criteri di chiusura.
5. `ARCHITECTURE-CURRENT.md` — tecnologie, flussi, dati, build e comandi.
6. `decision-history/2026-11-04-inventory.md` — elenco storico completo con origine e contraddizioni; non sono 238 ordini tutti attivi.

## Manutenzione permanente del report

Non attendere un nuovo promemoria dell’utente: META-01 e META-02 valgono a ogni sessione. Controllare ogni nuovo input, registrare decisioni e conflitti, aggiornare i documenti interessati durante il lavoro. Prima di ogni risposta finale o passaggio di sessione verificare che lo stato documentato sia corrente e che i cambiamenti siano stati sincronizzati e verificati su GitHub. Nessun commit vuoto se lo stato non cambia; nessuna dichiarazione di sincronizzazione se il push fallisce.

## Fatti da non perdere

- L’ultima IPA è 0.10.17 build 78, sorgente `33574a2114ea6e0d378f69d06aadf60378cf55e9`.
- Compilazione, 267 unitari, 15 UI, 4 avvii Release e package verifier sono passati; questi risultati non hanno impedito difetti visibili sul telefono.
- **L’utente ha rifiutato la build come pronta per la produzione.** Non presentarla nuovamente come pronta senza correzioni e prove adeguate.
- Dopo la build sono cambiati documentazione, workflow CI e griglia Bloom con anteprime link (H-GRID-01, approvato). La verifica Bloom al simulatore è passata (19 unitari e 4 UI); accettazione utente pendente; nessuna nuova IPA distribuita e nessun deploy backend.
- `native-next/` è l’overlay canonico; il vecchio ZIP e i vecchi handoff da soli non sono l’app corrente.
- Un concept generato non prova una funzione o un layout reale; le proposte dell’assistente non sostituiscono le istruzioni dell’utente.

## Ambiente effettivamente disponibile

L’utente lavora da Windows e ha dichiarato di non avere Mac locali o remoti. Per iOS si usa il runner macOS GitHub già configurato (`xcode-27`); non presupporre una macchina Mac interattiva disponibile. Acquisto o noleggio non approvati.

Audit del job `126213552095`, run `41721041653`: setup Node 3m15s, compilazione app/test 2m41s, REA 1m33s, suite completa test 12m58s, compilazione Release + quattro avvii 7m56s. Quindi il tempo del ciclo completo non è il tempo puro per compilare l’app. Il ciclo separato è ora implementato: [DEVELOPMENT-CYCLE.md](DEVELOPMENT-CYCLE.md). Prima anteprima verificata nel run 41800947855: 11 UI passati, 21 screenshot esportati, 20m39s. Compilazione da zero 8m36s; nessuna promessa di anteprima immediata. Focused verificato nella selezione locale ma non eseguito su macOS; percorso IPA completo conservato, non rieseguito.

## Come lavorare

1. Leggere regole e stato; verificare branch, HEAD, working tree e remoto. Preservare modifiche di altre sessioni.
2. Registrare il nuovo input. Se contraddice una regola ACTIVE, citare ID/testo e chiedere se sostituirla: attendere la risposta sulla parte coinvolta. Non inventare compromessi.
3. Riprodurre il difetto su contenuti rappresentativi. Una sola nota sintetica non copre la griglia Bloom con una libreria eterogenea.
4. Correggere i requisiti autorizzati. Eseguire controlli pertinenti, verificare schermate dell’app reale, tastiera, scorrimento e testo grande quando coinvolti. Non indebolire gli assert per far passare un’interfaccia rotta.
5. Aggiornare regole, difetti, report e stato della build; distinguere risultati nuovi da prove storiche, pending e limiti.
6. Fare commit e push del lavoro di progetto; verificare lo SHA remoto e rendere tutto rintracciabile da main/README. Se il push è bloccato, segnalarlo senza dichiarare il remoto aggiornato.

La sincronizzazione del repository è autorizzata da META-02; non equivale a un’autorizzazione a distribuire codice ai Worker o pubblicare automaticamente una nuova IPA. Non pubblicare backup, credenziali o dati personali.

## Stato del repository

Ramo predefinito `main`; ramo di lavoro storico `codex/revision77`. Il nome del ramo non indica la build. `main` viene riallineato senza force push alla cronologia corrente, così una IA che clona il default trova anche i sorgenti e questo report. Se in futuro main e ramo di lavoro divergono, il README e STATUS devono indicare chiaramente dove si trova il lavoro corrente; non perdere commit concorrenti.

L’ultimo aggiornamento di documentazione non cambia il fingerprint applicativo della build verificata. Per il commit esatto del repository leggere HEAD, evitando un hash auto-referenziale nel report. Stato macchina in BUILD-STATE.json.

## Storico

I vecchi `HANDOFF.md`, README e rapporti di revisione sono evidenze storiche. Quando divergono dal registro attivo o dallo stato corrente, non usarli per ripristinare una scelta superata o dichiarare risolto un difetto aperto.

## Revisione Bloom corrente

Leggere [BLOOM-GRID-REVIEW.md](BLOOM-GRID-REVIEW.md): H-GRID-01 implementato e in verifica. Run 41813899400: 19 unitari e 3 UI passati, 1 UI fallito per gesto sulla tab bar, corretto nel test; run 41816351684 PASSATO: 19 unitari, 4 UI, 16 screenshot; controllo visivo di standard e testo grande completato. Richiedere accettazione del risultato visivo prima della prossima modifica di prodotto (DEV-02). Nessuna nuova IPA.

## Cronologia delle decisioni — gli stati successivi sostituiscono i precedenti

Le note sotto conservano la sequenza; per lo stato operativo leggere l’incremento corrente in apertura e il registro ACTIVE.

Aggiornamento 4 novembre: risultato visivo H-GRID-01 accettato tramite «ok, procediamo con la prossima correzzione». Prossima proposta: riconoscibilità e compattezza del modulo nutrizione in Dashboard; non ancora approvata né implementata. Accettazione globale per produzione invariata.

Nuovo input NUTRITION-DIRECT-01 in PENDING_CONFIRMATION: quick add con nutrienti effettivi e kcal automatiche, sospendendo per ora percorso 100 g/porzione/kcal etichetta. Conflitto F03–F06: chiedere conferma ai sensi META-01. La precedente proposta di restyling nutrizione non è stata approvata. Non implementare la parte confliggente prima della risposta.

Aggiornamento nutrizione: conflitto NUTRITION-DIRECT-01 confermato, F03–F06 SUSPENDED per ora; nessuna migrazione/cancellazione dello storico. Design del quick add a pannello approvato come idea; ora soltanto render da mostrare immediatamente, poi fermarsi prima di implementare altro. Il precedente pending è risolto. App e build invariati.

## Nutrizione: render approvato e implementazione corrente

L’utente ha approvato il render con «ok approvo». Pannello quick add e inserimento diretto implementati, controlli locali della selezione passati, verifica macOS da avviare. Il precedente stop al render è soddisfatto. Leggere `NUTRITION-QUICK-REVIEW.md`: salvare lo storico senza ricalcolarlo, nessuna nuova IPA. La scelta manuale area nutrition è motivata dall’impatto limitato ai componenti nutrizione e ai relativi test (i nuovi token non cambiano altri componenti); eseguire focused con tutti gli unitari per la persistenza.
