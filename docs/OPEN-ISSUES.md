# LifeOS — correzioni e difetti aperti

## Aggiornamento operativo — piano approvato, 4 novembre 2026

Il piano completo è autorizzato ed è in corso: [piano](PROJECT-RELEASE-PLAN.md), [copertura](REQUIREMENT-COVERAGE.json), [manifesto](EXECUTION-MANIFEST.json). I precedenti passaggi che indicano solo pianificazione o accettazione Bloom pendente sono storici e superati. Bloom è accettato visivamente, non per produzione; retry nutrizione resta non verificato; IPA 78 non accettata. Nessuna nuova IPA né deploy autorizzati. T07 prevede anteprima e conferma dei conflitti prima della modifica di Salute.

Aggiornato il 4 novembre 2026. Questa è una lista di lavoro con stato e provenienza, non un’attestazione di risoluzione. La build 78 non è accettata per la produzione.

## Difetti osservati nelle foto dell’app installata

| ID | Stato | Problema / prova necessaria per chiuderlo |
|---|---|---|
| QA-001 | OPEN — visibile | Bloom: immagini/card oltre le colonne e sovrapposizioni. Riprodurre con molte note, immagini verticali/orizzontali e titoli lunghi; nessuna card deve uscire dalla propria colonna o interferire con le altre. |
| QA-002 | OPEN — osservazione UI | Bloom: vuoti e gerarchia irregolare nella griglia. Stabilire il layout coerente con le richieste, poi verificare libreria popolata, scorrimento e miniature. |
| QA-003 | IMPLEMENTED — verifica recupero accessibilità pendente | NUTRITION-DIRECT-01 sostituisce il modulo inline con quick add, quattro campi riconoscibili, unità e calorie automatiche. Standard con tastiera e salvataggio verificato; testo grande con valori conservati e recupero visibile osservato nel video. Retry automatico ultima versione da confermare nel run 41871989512 su macos-26 (41856609394 e 41859714562 non eseguiti: runner non acquisito). Percorso porzione sospeso; approvato il render, accettazione dell’implementazione pendente. |
| QA-004 | OPEN — osservazione UI | Contenuti sotto la tab bar: verificare che l’ultimo elemento e ogni azione siano completamente raggiungibili sopra la barra, anche con tastiera e testo grande. |
| QA-005 | OPEN — osservazione UI | Salute: calorie odierne mancanti e grafico storico con punto/barra colorata richiedono semantica chiara. Applicare G12; se si propone una deroga alla regola del colore, chiedere conferma prima. |
| QA-006 | OPEN — revisione complessiva | Margini, densità, proporzioni, selezioni, icone e feedback dell’app installabile devono essere controllati con casi rappresentativi. I test esistenti non dimostrano qualità complessiva. |

Le osservazioni non autorizzano di per sé un redesign arbitrario. Il conflitto del quick add con il percorso per 100 g è già stato risolto esplicitamente: NUTRITION-DIRECT-01 ACTIVE e F03–F06 SUSPENDED. Non riproporre la vecchia restrizione come ancora attiva.

## Verifiche funzionali ancora distinte dalle prove già passate

| ID | Stato | Verifica |
|---|---|---|
| QA-007 | NOT VERIFIED | Confronto completo fra contenuti/allegati personali di Bloom originale e importazione nel telefono. Il conteggio 122 non basta per certificare tutti i contenuti. Non pubblicare il backup nel repository. |
| QA-008 | NOT VERIFIED BY AGENT | HealthKit sul telefono dopo rifirma: permessi, scrittura/modifica/eliminazione dei soli campioni LifeOS e recupero errori. I test con writer sintetico non equivalgono alla prova fisica. |
| QA-009 | NOT VERIFIED BY AGENT | App Group e widget dopo firma Signulous; AlarmKit e suono effettivo sul dispositivo. |
| QA-010 | NOT REAUDITED | Parità del Worker versionato con quello live prima di qualunque nuovo deploy. Verificare baseline, binding e autenticazione senza esportare dati personali. |

## Decisioni e proposte

- [Regole attive](USER-DECISIONS.md): decisioni esplicite, indipendenti dallo stato di implementazione.
- [Inventario completo](decision-history/2026-11-04-inventory.md): 238 voci con fonte e conflitti; 53 proposte dell’assistente restano distinguibili.
- I concept, i suggerimenti di nuove funzioni e la tabella di riconciliazione dell’assistente non sono automaticamente un’autorizzazione a implementare ogni proposta.
- Una richiesta storica sostituita non è un conflitto aperto da risolvere ogni volta. Per un nuovo input che contraddice una regola ACTIVE si applica META-01.

## Come chiudere una voce

Registrare requisito, riproduzione, cambiamento, commit, controllo pertinente, schermata reale dell’app e limiti. Controllare regressioni pertinenti e contenuti rappresentativi. Un mockup generato, il solo conteggio dei test o l’assenza di errori di compilazione non chiudono un difetto visivo.

## Nuova osservazione del ciclo anteprima

- **QA-011 — OBSERVED / riproduzione necessaria**: nel riepilogo Salute esportato dal run 41800947855 (`7EA9FE4E-5F0D-42DC-B046-D24DCA45FD24.png`) mancano visivamente le etichette Dashboard/Attività della tab bar. Verificare dopo stabilizzazione della schermata, con testo standard/grande, per distinguere transizione di cattura da difetto persistente. Nessuna causa o correzione ancora stabilita.

## H-GRID-01 — verifica della correzione approvata

QA-001/002: correzione implementata e verificata su 122 contenuti sintetici nel run [41816351684](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41816351684): 19 unitari e 4 UI passati, immagini contenute nelle card, due colonne e nessuna sovrapposizione nei quattro scorrimenti standard/testo grande. Anteprime link presenti nel caso sintetico. **Accettazione utente e prova con la libreria personale/telefono ancora pendenti**; non chiudere le voci come accettate. Rete dei singoli siti non certificata dalla fixture. Dettagli in [BLOOM-GRID-REVIEW.md](BLOOM-GRID-REVIEW.md).

## Pianificazione Salute per bodybuilding

HEALTH-UX-01 / HEALTH-PLAN-01 aggiungono l’obiettivo al backlog, non chiudono QA-005 o QA-006. Layout, azioni e catalogo alimentare locale sono proposte non vincolanti da valutare con Astra; nessun nuovo inserimento/database da implementare ora. Leggere [brief](HEALTH-BODYBUILDING-BRIEF.md) e [checklist unificata](PROJECT-CHECKLIST.md). Quick add esistente conservato; eventuali conflitti G05–G13 richiedono conferma prima di attuarli. Ultimi tentativi Mac 41871989512 e 41873100610 terminati senza runner, nessuno step eseguito; verifica finale quick add ancora mancante.
