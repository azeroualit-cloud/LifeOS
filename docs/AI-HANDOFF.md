# LifeOS — punto di ingresso per qualsiasi IA

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
- Dopo la build sono cambiati documentazione e workflow CI: nessun nuovo codice app, nessuna nuova IPA distribuita e nessun deploy backend.
- `native-next/` è l’overlay canonico; il vecchio ZIP e i vecchi handoff da soli non sono l’app corrente.
- Un concept generato non prova una funzione o un layout reale; le proposte dell’assistente non sostituiscono le istruzioni dell’utente.

## Ambiente effettivamente disponibile

L’utente lavora da Windows e ha dichiarato di non avere Mac locali o remoti. Per iOS si usa il runner macOS GitHub già configurato (`xcode-27`); non presupporre una macchina Mac interattiva disponibile. Acquisto o noleggio non approvati.

Audit del job `126213552095`, run `41721041653`: setup Node 3m15s, compilazione app/test 2m41s, REA 1m33s, suite completa test 12m58s, compilazione Release + quattro avvii 7m56s. Quindi il tempo del ciclo completo non è il tempo puro per compilare l’app. Il ciclo separato è ora implementato: [DEVELOPMENT-CYCLE.md](DEVELOPMENT-CYCLE.md). La prima esecuzione va verificata; nessuna stima di velocità nuova è ancora validata.

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
