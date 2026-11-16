# PERF-EFFICIENCY-01 — efficientamento senza cambi funzionali

Ramo: `codex/perf-efficiency-01`, creato da `codex/revision77` al commit `04ad889`. Separato dal candidato 90: nessun file del contenitore schede, della barra o del Calendario è toccato. Non compilato né provato in locale (nessun compilatore Swift disponibile); serve l'esito della CI `lifeos-development`. Nessuna IPA, nessun deploy backend.

Autorizzazione: PERF-AUTONOMY-2026-11-16 in `USER-DECISIONS.md`.

## Primo incremento (16 novembre 2026)

Comportamento visibile invariato; cambiano solo quante volte lo stesso lavoro viene ripetuto.

- `NativeStore.swift`: `tasks`, `categories` e `shift(_:)` usano proiezioni in cache azzerate a ogni modifica di `state`. Prima ogni accesso riconvertiva l'array JSON e `shift` scorreva tutti i turni per ogni cella. La prima riga per giorno continua a prevalere.
- `NativeFoodPicker.swift`: alimenti personali decodificati una volta per render invece che una volta per riga; catalogo già diviso tra alimenti e integratori; `ranked` restituisce l'ordine originale quando non ci sono usi recenti (stesso risultato dell'ordinamento a parità). `preload()` decodifica catalogo e indice di ricerca fuori dal main thread.
- `NativeNutritionQuickEntry.swift`: avvia `preload()` quando compare la scheda Nutrizione.
- `NativeBloomLinkPreview.swift`: immagine dell'anteprima decodificata una volta per snapshot invece che a ogni render; snapshot freschi tenuti in memoria (massimo 200) per evitare una lettura da disco per ogni card visibile. Stessa scadenza di 7 giorni.

## Verifica in CI

- Run 43880951454 (push, commit `25a314e`): compilazione passata; passo dei test annullato al limite di 35 minuti senza esiti, perché la modifica allo store seleziona tutte le aree. Non è una prova né a favore né contro.
- Run 43887359860 (focused, area nutrition, stesso commit): esito da acquisire.
- `Tests/NativeEfficiencyTests.swift`: confronta le proiezioni in cache con le espressioni originali prima e dopo ogni modifica dell'archivio, verifica l'ordine del catalogo e misura ricerca alimenti e lettura turni. Non ancora eseguito.

## Non ancora fatto, in ordine

1. Salvataggio dell'archivio fuori dal main thread. Tocca le garanzie di durabilità della coda offline: richiede prima una misura e test dedicati.
2. Store diviso in parti osservabili per ridurre i ridisegni.
3. Ricerca alimenti fuori dal main thread.
4. Cadenza della sincronizzazione automatica e risposta "nessuna modifica" dal Worker (richiede deploy backend, non autorizzato qui).
5. Bloom: filtro, ordinamento e gruppi mappa calcolati una volta per modifica dell'archivio.
6. Misure in CI su tre flussi: apertura ricerca alimenti, tap su checkbox, cambio scheda.
