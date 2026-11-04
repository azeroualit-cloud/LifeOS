# LifeOS — stato corrente

Aggiornato il 4 novembre 2026. Questo documento prevale come riepilogo di stato sui vecchi handoff e sui rapporti cronologici. Le istruzioni dell’utente restano nel registro delle decisioni.

## Valutazione del prodotto

**Build 78 distribuita; non accettata dall’utente per la produzione.** Le foto del telefono mostrano difetti che la precedente verifica non ha coperto adeguatamente: griglia Bloom con card fuori colonna/sovrapposte, modulo nutrizione ingombrante e poco riconoscibile, gerarchia/contesto da correggere. I test verdi non chiudono questi problemi.

## Codice, artefatto e prove

| Campo | Stato |
|---|---|
| Sorgenti app correnti | `native-next/`; correzione Bloom e anteprime link successive alla build 78, verifica in corso |
| Versione app e widget | 0.10.17 / 78 |
| Commit sorgente IPA | `33574a2114ea6e0d378f69d06aadf60378cf55e9` |
| Commit attuale repository | Leggere HEAD; include anche regole e report, non una nuova build |
| Validazione | [41721041653](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41721041653), riuscita |
| Prove | 267 unitari, 15 UI, 4 avvii Release; iPhone 15 Pro simulato, SDK/runtime 27.0 |
| Firma e telefono reale | Rifirma Signulous; nessuna prova fisica eseguita dall’agente |
| Artefatto | [Release build 78](https://github.com/azeroualit-cloud/LifeOS/releases/tag/ios-0.10.17-build78) |
| SHA-256 IPA | `d281d9d885ea4cc221022d3c52bf3fe00b876f77273821867d617a2be2b911e7` |
| Accettazione per produzione | **NO — rifiuto esplicito dell’utente** |

## Che cosa è stato effettivamente osservato

- L’utente ha mostrato importazione di 122 note completata. Questo non certifica da solo la parità di ogni contenuto/allegato con l’app Bloom originale.
- La prova UI sintetica copre File → anteprima → importazione → riavvio e dato ancora visibile; non copre sufficientemente una libreria eterogenea di 122 elementi.
- Sono presenti le modifiche richieste a Dashboard, nutrizione per 100 g e schede Salute, ma qualità visiva e UX sono ancora da correggere e rivalidare con casi rappresentativi.
- I concept generati dopo la consegna sono proposte visive: non sono stati implementati come nuova versione dell’app.

## Backend e web

L’ultimo deploy utenze documentato è il run 41630715615, riportato in [REVISIONE-77](native/REVISIONE-77.md). Questo aggiornamento non riesegue un audit live e non distribuisce Worker. La corrispondenza integrale fra `web/worker.mjs` e produzione non è stabilita: non effettuare deploy da una baseline presunta.

## Prossimo lavoro e fonti

Leggere [difetti aperti](OPEN-ISSUES.md), [regole attive](USER-DECISIONS.md), [report di passaggio](AI-HANDOFF.md) e [architettura/flussi](ARCHITECTURE-CURRENT.md). Le 238 voci storiche distinguono richieste dirette, ricostruzioni e proposte; non sono tutte requisiti attivi né tutte correzioni ancora da fare.

Lo [storico di stato fino alla build 76 e precedenti](STATUS-HISTORY-2026-11-04.md) è conservato senza usarlo come stato attuale.

## Ciclo CI separato

Implementati anteprima automatica e verifiche mirate manuali, con screenshot e selezione test tracciabile. Il percorso completo IPA è manuale; pipeline native storiche sovrapposte non partono più a ogni push. Nessuna modifica al codice app o ai deploy. Prima anteprima [41800947855](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41800947855) passata: 11 test UI, 0 errori, 21 screenshot esportati; durata 20m39s. Cinque test locali della selezione e lint dei workflow passati. Focused e IPA completa non rieseguiti. Nessun difetto grafico dichiarato chiuso. Leggere [DEVELOPMENT-CYCLE.md](DEVELOPMENT-CYCLE.md).

## Correzione approvata Bloom H-GRID-01

Due colonne indipendenti con larghezza esplicita, immagini proporzionate e anteprime link tramite LinkPresentation (cache separata dalle note, fallback e timeout). Fixture sintetica di 122 contenuti misti; verifiche standard/testo grande previste. Stato: implementata, compilazione e QA visuale ancora da eseguire. Ultima IPA invariata.

Verifica Bloom intermedia: 19 unitari e 3 UI passati; correzione del gesto del test con testo grande in verifica nel run 41816351684. Prove e limiti in [BLOOM-GRID-REVIEW.md](BLOOM-GRID-REVIEW.md). Accettazione pendente.
