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
- Run 43887359860 (focused, area nutrition, commit `25a314e`): passato. 311 test unitari e 12 test UI di Nutrizione, 0 fallimenti, 11 minuti.
- Run 43894770211 (focused, area bloom, commit `1172890`): passato. 317 test unitari, inclusi i 6 di `Tests/NativeEfficiencyTests.swift` (equivalenza delle proiezioni in cache, ordine del catalogo, due misure), e 12 test UI tra smoke e Bloom, 0 fallimenti.
- Tempi medi di `testFoodSearchTime` e `testShiftLookupTime`: non acquisiti. Il log pubblico non li riporta e lo scaricamento dell'artefatto è stato rifiutato dalla sessione.
- Non coperti: test UI di Calendario, Attività, Finanza, Salute e Dashboard; nessuna prova su iPhone. L'esito CI non è accettazione del prodotto.

## Secondo incremento (16 novembre 2026)

Richiesta utente: «fai tutto in uno». Tutto ciò che resta e non cambia il comportamento è in un solo commit; le voci escluse sono motivate sotto. Non compilato in locale.

- `NativeStore.swift`: in cache anche `events` (solo archivio reale; la demo dipende dal mese) e `transactions` (per mese di Finanza). `sync` non ripubblica `error` quando è già vuoto.
- `NativeFoodPicker.swift`: la lista ordinata per uso recente viene ricalcolata solo se cambiano ambito, alimenti personali, diario o giorno; digitare nella ricerca non riordina più l'intero catalogo a ogni lettera. Confronto esatto dei dati, nessun hash.
- `NativeBloomScreen.swift`: filtro e ordinamento delle note calcolati una volta per render e condivisi tra Libreria, Riscopri e Mappa.
- `Tests/NativeEfficiencyTests.swift`: equivalenza di `transactions` al cambio mese, tetti larghi sui tempi di ricerca alimenti e salvataggio archivio.

## Escluso di proposito

- **Salvataggio fuori dal main thread.** Oggi `save` fallisce in modo sincrono e lo stato non cambia se il file non viene scritto; la coda offline dei movimenti dipende da questa garanzia. Renderlo asincrono cambia il comportamento in caso di errore o chiusura dell'app, quindi non rientra in «senza cambi di funzionalità». Prima serve il tempo reale di `save` su iPhone.
- **Cadenza della sincronizzazione e risposta "nessuna modifica" dal Worker.** Cambia la freschezza dei dati condivisi col sito e richiede un deploy backend non autorizzato.
- **Store diviso in parti osservabili.** Tocca `App.swift`, `CalendarScreen.swift` e la barra, in correzione per il candidato 90: da fare dopo la sua chiusura.
- **Ricerca alimenti asincrona.** I test UI leggono i risultati subito dopo la digitazione; un ritardo li renderebbe instabili.
