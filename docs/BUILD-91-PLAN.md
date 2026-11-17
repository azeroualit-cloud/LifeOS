# Build 91 (0.10.29) — piano e stato

Ramo: `codex/build91`, da `codex/perf-efficiency-01`, a sua volta da `codex/revision77` al commit `04ad889` (sorgente della build 90 pubblicata). Autorizzazione: IPA-DELIVERY-91-2026-11-16, consegna unica. Nessun compilatore Swift in locale: il codice Swift vale solo dopo l'esito della CI.

## Contenuto

| Parte | Stato al 16 novembre, sera |
| --- | --- |
| Efficienza, primo incremento | Verde in CI (run 43887359860 e 43894770211) |
| Efficienza, secondo incremento | Scritto, non ancora eseguito in CI: due run non hanno ottenuto un runner macOS |
| Barra a cinque voci | Scritta; run 43904913733 (six-glass) in corso |
| Schermata Finanza: quattro azioni visibili, Aggiungi spesa in basso | Scritta, non compilata |
| Pagamento dai risparmi, app | Scritto, non compilato. L'opzione compare solo se il server dichiara `savingsDestination` |
| Pagamento dai risparmi, Worker | Scritto e provato: 18 test di routing in locale e nel run 43906045163 |
| Deploy del Worker | Non eseguito. Audit senza scritture 43906811690: il routing live dei due Worker coincide con la versione attesa |
| Bloom variante B | Scritta, non compilata: filtri automatici per fonte e tipo al posto delle categorie, link catturati salvati in un passaggio con titolo preso dalla pagina |
| Versione e gate di produzione | `project.yml` a 0.10.29 (91); `lifeos-candidate91.yml` e `verify-candidate91.py` pronti. Il workflow va aggiunto anche a `main` per poterlo avviare |
| Run focused su tutte le aree | 43906818640 in coda sul commit `e2594c4` |

## Differenze dichiarate rispetto ai mockup approvati

- Finanza: il selettore del mese resta su una riga propria e l'ingranaggio resta nell'intestazione; nel mockup il mese era nell'intestazione.
- Nuova spesa: Risparmi è una voce del menu «Destinazione» esistente, non un controllo a tre segmenti. Stessa funzione, percorso di test invariato.
- Bloom: la ricerca copre titolo, testo, note e indirizzo. Non legge il testo della pagina salvata e non mostra l'estratto. La barra di ricerca resta in alto. Il salvataggio da Condividi usa il comando rapido «Salva link in Bloom» già esistente, senza estensione nuova. Le categorie esistenti restano nei dati ma non sono più mostrate.
- Pagare dai risparmi vale per una spesa nuova. Cambiare la destinazione di una spesa già registrata resta Budget o Piano.

## Ordine di chiusura

1. Compilazione e test focused verdi su `codex/build91`; correggere ciò che fallisce.
2. `lifeos-candidate91.yml` su `main`, poi avvio su `codex/build91`: 5 casi compatti, regressioni, suite restante, 4 avvii Release, IPA e pubblicazione solo se tutto è verde sullo stesso commit.
3. Deploy del Worker con `scripts/deploy-savings-91.py` (rollback automatico se la verifica dell'upload fallisce). È retrocompatibile: le app precedenti non inviano mai `savings`.
4. Aggiornare `BUILD-STATE.json`, `AI-HANDOFF.md` e questo file con SHA, run e hash dell'IPA.

## Gate 91: stato al 17 novembre, notte

- Start 1 e 2 (43917229527, 43952296245): nessun runner macOS assegnato, nessun test eseguito.
- Start 3 (43957165264, `ece7f35`): 122 test UI eseguiti, 7 falliti. Cinque erano asserzioni rimaste a sei destinazioni o un controllo Finanza cercato dietro la barra fissa «Aggiungi spesa»: corretti in `0cc583e`. Restano `testPaintingPaletteFullNamesWithLargeText` e `testCaptureAppleHealthReference`.
- Start 4 (43980458282): annullato dopo la conferma che il primo dei due fallisce in modo ripetibile.

### Bisezione di `testPaintingPaletteFullNamesWithLargeText` (NativeRevision71UITests.swift:199, timeout della query)

| Sorgente | Run | Immagine runner | Esito |
| --- | --- | --- | --- |
| `codex/build91` (gate) | 43957165264 | 20261104.0514 | fallito |
| `codex/build91` | 43980450408 | non rilevata | fallito |
| `codex/perf-efficiency-01` | 43984901395 | non rilevata | fallito |
| `codex/revision77` `04ad889`, sorgente della build 90 | 43987674222 | 20261112.0539 | fallito |
| `codex/revision77` `04ad889` | 43990368405 | 20261104.0514 | fallito |
| `codex/revision77` `04ad889`, gate 90 del 15 novembre | 43762258716 | 20261104.0514 | passato |

Il test fallisce oggi anche sul sorgente della build 90 e sulla stessa immagine con cui ieri passava: non è attribuibile alle modifiche della build 91. Causa non dimostrata; l'ipotesi è che la schermata con testo grande sia al limite del tempo della query e dipenda dal carico del runner.

`testCaptureAppleHealthReference`: fallito nel gate 43957165264 su `codex/build91`, passato sulla base nel run 43990368405. Un solo campione per parte: non concludente.

Nessun test è stato escluso o indebolito. Decisione utente (17 novembre, 01:50): soluzione permanente, IPA al risveglio. Seguito nella sezione successiva. Nessuna IPA 91, nessun deploy del Worker.
## Gate 91, notte del 17 novembre 2026

Il test `testPaintingPaletteFullNamesWithLargeText` falliva 4 volte su 4 anche sul sorgente esatto della 90 (run 43987674222). Lo spindump del timeout (stampato dal run 43991497657) mostra il thread principale occupato al 100% nel layout del calendario: `LazyStack.measureEstimates`, `LazyLayoutViewCache.updateItemPhases`, transazioni SwiftUI continue. Non era carico del runner: con modalità Dipingi e testo accessibile l'app non tornava mai inattiva.

Prove focused con la stessa selezione di 10 casi calendario/turni (`shift-render` estesa), tre test di NativeRevision71:

| Variante | Run | Esito | Tempo dei 3 test |
| --- | --- | --- | --- |
| Sorgente 91 invariato | 43992189293 | verde, al limite | 274 s |
| Geometria solo per la settimana da posizionare | 43992100054 | rosso, stesso timeout | 274 s |
| VStack al posto di LazyVStack | 43992193382 | 5 casi oltre i 3 minuti | scartata |
| Tavolozza Dipingi limitata a xxxLarge come la griglia | 43997293913 | verde | 173 s |
| Altezze esatte delle righe settimana | 43997295909 | verde | 220 s |

Correzioni portate nella 91, entrambe senza cambi di funzione:
- `brushPanel` (Oggi, Dipingi, frecce mese, tavolozza turni) usa lo stesso tetto di testo `xxxLarge` già applicato alla griglia del mese. Con testo standard nulla cambia; con le taglie accessibili i nomi restano interi.
- Ogni riga settimana ha altezza esatta (riga giorni 88 pt; intestazione mese con altezza della riga `title3` al massimo `xxxLarge`), così le stime del LazyVStack coincidono con le righe reali.

Apple Salute (`testCaptureAppleHealthReference`): l'app Salute esponeva righe con frame vuoto e `isHittable` sollevava «Activation point invalid» invece di restituire falso. Gli accessi nella parte preferiti, già non bloccante per decisione del 15 novembre, passano da un controllo di raggiungibilità; gli assert finali sui valori seminati sono invariati. Verde nel run 43992314220.

Il gate non è stato indebolito: nessun test escluso, nessun nuovo tentativo automatico, verificatore invariato.

### Start 5 (43999971306, `47c7cb4`)

Suite restante verde, compresi `testPaintingPaletteFullNamesWithLargeText` e `testCaptureAppleHealthReference`. Fallite due regressioni Finanza, entrambe navigazioni che non partivano:
- `testCalendarReturnsToDashboardAndFinanceOpens`: dopo una visita al Calendario aperta dal giorno in Dashboard, il tocco su «Finanza» non apriva la schermata. La scheda usa ora una scrittura esplicita del percorso (`dashboardPath = [.finance]`), come l'ingresso al Calendario.
- `testFinanceOverviewSupportsLargeTextAndEmptySnapshot`: con testo accessibile «Movimenti», nella seconda riga della griglia lazy, non apriva l'elenco. Le quattro azioni sono ora due pile semplici (una riga con testo standard, due righe con testo accessibile): stessa disposizione, nessun contenitore lazy.

Start 6 sullo stesso gate, invariato.

### Start 6 (44012183022, `1beb76b`)

Verdi: preflight compatto, `testCalendarReturnsToDashboardAndFinanceOpens`, suite restante (palette con testo grande e Apple Salute compresi). Rosso solo `testFinanceOverviewSupportsLargeTextAndEmptySnapshot`. L'albero di accessibilità stampato nel run 44024746135 mostra la causa: con testo accessibile «Movimenti» (y 699–771) sta sotto la barra fissa «Aggiungi spesa» (y 706–750) quando la schermata è in cima; XCTest lo dichiarava `isHittable`, il tocco colpiva la barra e apriva «Nuovo movimento». Comportamento dell'app corretto (il contenuto scorre sotto la barra fissa come previsto da UX-REACH-01); l'helper del test ora scorre finché il controllo è interamente tra intestazione e barra fissa prima di toccarlo. Assert invariati.

Start 7 sullo stesso gate.
