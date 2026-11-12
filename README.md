# LifeOS

**IPA 0.10.27 build 89 pubblicata e verificata — 12 novembre 2026.** [Scarica IPA](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.27-build89/LifeOS-89.ipa) · [Produzione riuscita](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43252634146). Sorgente `62533a1afb3295d70aad305339eacfd5d0554ec1`. Scaricato il file pubblico e verificati checksum `3932dda37cc8d65a0dfb4d21a084ae6a626861487f41a25e870b86fca52a4974`, versione/build di app e widget iPhone arm64, compatibilità import di avvio e presenza di 2.893 alimenti Coop e sette integratori con marca. Riutilizzate le 405 prove aggregate e i quattro avvii Release sul medesimo prodotto; nessun test ripetuto. Nessun deploy backend. IPA da firmare con Signulous; installazione conservando dati, prove fisiche e accettazione restano aperte. Le note sottostanti sono cronologia.


**Produzione IPA avviata — 12 novembre 2026:** [run 43252634146](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43252634146), sorgente `62533a1`, versione 0.10.27 build 89. Richiesta IPA-DELIVERY-2026-11-12. Controllo identità candidato e prove concluse, archivio iPhone, verifica pacchetto e pubblicazione; nessun test ripetuto, nessun deploy backend. Pubblicazione ancora da verificare.


**Candidato finale verificato senza IPA — 12 novembre 2026.** Prodotto `8ac2d4f`; sorgente dei test corretti `f901529`. Il run 43232065358 ha completato 405 test: 403 passati e due errori UI. Il [recupero mirato 43249620310](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43249620310) ha superato entrambi i casi, senza ripetere i 403 test passati né i quattro avvii Release già verdi. Copertura aggregata: **405/405 casi verificati**, non una nuova suite monolitica. Modificati soltanto test e selezione CI; codice/risorse/configurazione dell’app invariati. Catture finali ispezionate. **Nessuna IPA e nessun deploy backend.** Restano revisione utente, prove fisiche, parità dei dati personali e accettazione. Dettagli: [FINAL-CANDIDATE-2026-11-12.md](docs/FINAL-CANDIDATE-2026-11-12.md). Le note sottostanti sono cronologia.


**Verifica mirata avviata:** [43249620310](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43249620310), sorgente test `f901529`, solo macro decimali e annullamento File Bloom. Prodotto invariato rispetto a `8ac2d4f`; 403 test già passati e quattro avvii Release non ripetuti. Video originale: File cambia cartella e posizione del controllo Annulla mentre XCTest lo risolve. Attesa della Libreria interattiva da verificare, non ancora dimostrata.


## Stato corrente — 12 novembre 2026

Candidato su **codex/revision77** con **2.893 alimenti Coop, inclusi 208 Spesotti**, sette integratori con marca, unità capsule/compresse/grammi, modifica personale, cronologia per giorno e palette Liquid Glass compatta. [Gate finale senza IPA](https://github.com/azeroualit-cloud/LifeOS/actions/runs/43232065358) sul sorgente `8ac2d4f`, dopo verifiche mirate e catture ispezionate. [Report corrente](https://github.com/azeroualit-cloud/LifeOS/blob/codex/revision77/docs/AI-HANDOFF.md) · [copertura catalogo](https://github.com/azeroualit-cloud/LifeOS/blob/codex/revision77/docs/COOP-CATALOG-COVERAGE.json). **Nessuna IPA né deploy backend autorizzati nella nuova chat.** Prove fisiche e accettazione restano aperte. Le note successive sono cronologia.

**LifeOS 0.10.19 build 80 consegnata.** [IPA](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.19-build80/LifeOS-80.ipa), SHA-256 80a4e4759c810e2f2f69ef860a128d8cd020cf133cfa2e223cc4d51edf9f60c0. Sorgente 5aba0d5b888471025a45568d6ff567199b5a4fec. [Suite 368/368](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516), [avvii Release 4/4](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516), [confezionamento verificato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42235788082). Restano firma Signulous, aggiornamento sul telefono, parità dei dati personali, verifiche fisiche e accettazione esplicita.

**LifeOS 0.10.18 build 79 consegnata.** [IPA](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.18-build79/LifeOS-79.ipa), SHA-256 f7a9155e27fc27fd30a39e8422a43bfa26bdfdae69f0920ed87cf4c1d22a6f15. Sorgente 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. [Suite 368/368](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946), [avvii Release 4/4](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42189948045), [confezionamento verificato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42194114583). Restano firma Signulous, aggiornamento sul telefono, parità dei dati personali, verifiche fisiche e accettazione esplicita.

**Start here / Inizia da qui:** [report corrente per qualsiasi IA](docs/AI-HANDOFF.md).

Applicazione iPhone nativa per attività, turni, finanza, salute e raccolta di contenuti Bloom, con web/backend Cloudflare separati.

## Stato attuale — 4 novembre 2026

Ultima IPA distribuita: **0.10.17 / build 78**. Test tecnici superati sul simulatore, ma **l’utente ha rifiutato la build come pronta per la produzione**. Restano difetti UI/UX da correggere. Nessuna nuova IPA prodotta dall’aggiornamento dei documenti.

- [Piano operativo approvato e gate](docs/PROJECT-RELEASE-PLAN.md) · [copertura requisiti](docs/REQUIREMENT-COVERAGE.json) · [manifesto](docs/EXECUTION-MANIFEST.json).
- [Checklist unificata](docs/PROJECT-CHECKLIST.md) · [Brief Salute bodybuilding per Astra → Terra](docs/HEALTH-BODYBUILDING-BRIEF.md).
- [Stato corrente e limiti](docs/STATUS.md) · [stato build strutturato](docs/BUILD-STATE.json).
- [Istruzioni di lavoro](AGENTS.md) · [decisioni utente e conferme sui conflitti](docs/USER-DECISIONS.md).
- [Correzioni e difetti aperti](docs/OPEN-ISSUES.md) · [inventario storico delle 238 voci](docs/decision-history/2026-11-04-inventory.md).
- [Flussi e tecnologie](docs/ARCHITECTURE-CURRENT.md) · [prove della build 78](docs/native/REVISIONE-78.md).

## Dove lavorare

`native-next/` è la sorgente canonica corrente dell’app. Il workflow la applica a una base fissata e verificata: non sviluppare soltanto sul vecchio ZIP. `web/` e `backend/` sono componenti distinti; non assumere che `web/worker.mjs` sia identico al Worker live senza un confronto.

Ramo predefinito: `main`. Ramo di lavoro corrente: `codex/revision77`; il nome storico del ramo non indica la versione della build. Leggere sempre HEAD e stato corrente prima di partire. Le istruzioni META-01 richiedono conferma prima di sostituire una regola attiva in conflitto; META-02 richiede aggiornamento del repository e dei report ai checkpoint.

Lo [storico precedente del README](README-HISTORY-2026-11-04.md) è conservato come documento storico, non come stato corrente.
