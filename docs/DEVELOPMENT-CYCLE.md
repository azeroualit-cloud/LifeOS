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
