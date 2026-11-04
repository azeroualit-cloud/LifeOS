# LifeOS

**Start here / Inizia da qui:** [report corrente per qualsiasi IA](docs/AI-HANDOFF.md).

Applicazione iPhone nativa per attività, turni, finanza, salute e raccolta di contenuti Bloom, con web/backend Cloudflare separati.

## Stato attuale — 4 novembre 2026

Ultima IPA distribuita: **0.10.17 / build 78**. Test tecnici superati sul simulatore, ma **l’utente ha rifiutato la build come pronta per la produzione**. Restano difetti UI/UX da correggere. Nessuna nuova IPA prodotta dall’aggiornamento dei documenti.

- [Checklist unificata](docs/PROJECT-CHECKLIST.md) · [Brief Salute bodybuilding per Astra → Terra](docs/HEALTH-BODYBUILDING-BRIEF.md).
- [Stato corrente e limiti](docs/STATUS.md) · [stato build strutturato](docs/BUILD-STATE.json).
- [Istruzioni di lavoro](AGENTS.md) · [decisioni utente e conferme sui conflitti](docs/USER-DECISIONS.md).
- [Correzioni e difetti aperti](docs/OPEN-ISSUES.md) · [inventario storico delle 238 voci](docs/decision-history/2026-11-04-inventory.md).
- [Flussi e tecnologie](docs/ARCHITECTURE-CURRENT.md) · [prove della build 78](docs/native/REVISIONE-78.md).

## Dove lavorare

`native-next/` è la sorgente canonica corrente dell’app. Il workflow la applica a una base fissata e verificata: non sviluppare soltanto sul vecchio ZIP. `web/` e `backend/` sono componenti distinti; non assumere che `web/worker.mjs` sia identico al Worker live senza un confronto.

Ramo predefinito: `main`. Ramo di lavoro corrente: `codex/revision77`; il nome storico del ramo non indica la versione della build. Leggere sempre HEAD e stato corrente prima di partire. Le istruzioni META-01 richiedono conferma prima di sostituire una regola attiva in conflitto; META-02 richiede aggiornamento del repository e dei report ai checkpoint.

Lo [storico precedente del README](README-HISTORY-2026-11-04.md) è conservato come documento storico, non come stato corrente.
