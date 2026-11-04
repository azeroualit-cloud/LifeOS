# Ciclo di sviluppo iOS da Windows

Approvato dall’utente il 4 novembre 2026: «implementiamo in questo modo allora».

## Tre percorsi

1. **Anteprima**: `LifeOS development preview and focused checks` parte sui push dei rami `codex/**` che modificano app/pipeline. Compila una volta, esegue smoke e UI pertinenti, esporta screenshot e risultato XCTest. Nessuna IPA, REA o compilazione Release.
2. **Verifiche mirate**: stesso workflow, Run workflow → mode `focused`, area pertinente, dispositivo `primary` o `compact`. Aggiunge tutti gli unitari e, per Bloom, importazione/annullamento/persistenza. La selezione è salvata nell’artefatto; `all` per componenti condivisi. Non è un gate di produzione.
3. **Candidato IPA**: `LifeOS 78 isolated validation`, avvio manuale sul commit candidato. Conserva suite completa, riferimento Apple Health verificato, quattro avvii Release e verifica pacchetto. Produce artefatto IPA senza pubblicare release. Il workflow mantiene nome/versione 78 storici: prima di una nuova distribuzione aggiornare coerentemente app, widget e verificatori, senza spacciare un nuovo candidato per la vecchia IPA.

## Selezione, osservazione e costi

`scripts/select-development-tests.py` usa il diff del push; file sconosciuti, condivisi o base mancante allargano a tutte le aree. Il dispatch manuale parte da `all`; la riduzione esplicita richiede impact analysis. Preview include navigazione, screenshot, casi di testo grande e tastiera quando pertinenti. Usa soltanto fixture sintetiche esistenti, mai backup personali. Le fixture attuali non coprono ancora la libreria Bloom eterogenea di 122 note: resta un difetto di copertura da risolvere insieme alla griglia.

Scaricare l’artefatto del commit esatto, osservare screenshot, verificare allineamenti/ritagli/testi/tap/scroll e registrare esito e limiti. Un test verde non approva la grafica. L’anteprima non è una correzione dei difetti attuali dell’app.

Le anteprime obsolete dello stesso ramo/modalità vengono cancellate. I workflow nativi storici sovrapposti sono ora manuali; backend/deploy non modificati. Le modifiche documentali non lanciano una compilazione. Dipendenze e baseline restano verificate come prima. Nessuna cache DerivedData introdotta senza misurare toolchain e invalidazione; il primo ciclo serve a misurare tempi reali. La velocità nuova non è ancora garantita.

Sintassi workflow: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax

## Verifica della selezione

Eseguire `python scripts/test_development_selection.py`: copre file condivisi/sconosciuti, più aree, escalation mirata e presenza dei selettori XCTest. La verifica sintattica dei workflow è eseguita con actionlint 1.7.12 (etichetta runner personalizzata `xcode-27` ammessa).

## Prima misura reale

Run [41800947855](https://github.com/azeroualit-cloud/LifeOS/actions/runs/41800947855), sorgente `9fd78770`: SUCCESS, 11 UI / 0 errori, 21 screenshot esportati e scaricati. Selezione conservativa di tutte le aree per modifica della pipeline. Durata 20m39s: compilazione da zero 8m36s, fase test 10m11s. Non è una misura di una modifica locale a una sola area e non garantisce un’anteprima rapida. Il runner differisce nei tempi dal precedente run completo; non attribuire tutta la variazione alla pipeline.

Aperto campione di tre screenshot (Bloom, riepilogo Salute, calendario): export valido, non un’approvazione grafica. Fixture Bloom con poche note testuali insufficiente per QA-001/002. Nel riepilogo Salute `7EA9FE4E-5F0D-42DC-B046-D24DCA45FD24.png` le etichette Dashboard/Attività non sono visibili: QA-011 richiede riproduzione per distinguere cattura/transizione e difetto persistente.

La modalità focused ha selezione coperta dai test locali; non è stata eseguita una seconda build macOS identica soltanto per questa verifica. Il percorso completo IPA non è stato rilanciato né pubblicato.

## Annullamento delle anteprime superate

Il 4 novembre un run annullato continuava il caricamento degli artefatti con `always()`, ritardando il nuovo run dello stesso ramo. Export, riepilogo e upload usano ora `!cancelled()`: conservano le prove dei test falliti ma non trattengono la coda quando una prova viene sostituita. Sintassi verificata con actionlint; normale percorso di esecuzione invariato. Riferimento: https://docs.github.com/en/actions/how-tos/troubleshoot-workflows
