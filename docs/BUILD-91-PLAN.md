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
