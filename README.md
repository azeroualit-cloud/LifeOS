# LifeOS

## Stato corrente — 12 novembre 2026

Il candidato finale prosegue su **codex/revision77**: [report corrente](https://github.com/azeroualit-cloud/LifeOS/blob/codex/revision77/docs/AI-HANDOFF.md), [checklist di tutte le aree](https://github.com/azeroualit-cloud/LifeOS/blob/codex/revision77/docs/PROJECT-CHECKLIST.md). Verifica mirata Apple Salute prima della suite completa e quattro avvii Release. **Nessuna IPA né deploy backend autorizzati nella nuova chat.** Le note successive sono cronologia; test e build non equivalgono ad accettazione.


**LifeOS 0.10.19 build 80 consegnata.** [IPA](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.19-build80/LifeOS-80.ipa), SHA-256 80a4e4759c810e2f2f69ef860a128d8cd020cf133cfa2e223cc4d51edf9f60c0. Sorgente 5aba0d5b888471025a45568d6ff567199b5a4fec. [Suite 368/368](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516), [avvii Release 4/4](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42224387516), [confezionamento verificato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42235788082). Restano firma Signulous, aggiornamento sul telefono, parità dei dati personali, verifiche fisiche e accettazione esplicita.

**LifeOS 0.10.18 build 79 consegnata.** [IPA](https://github.com/azeroualit-cloud/LifeOS/releases/download/ios-0.10.18-build79/LifeOS-79.ipa), SHA-256 f7a9155e27fc27fd30a39e8422a43bfa26bdfdae69f0920ed87cf4c1d22a6f15. Sorgente 2d33d8aba9dad6d996cbaff81b99a1212a53ba20. [Suite 368/368](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42124676946), [avvii Release 4/4](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42189948045), [confezionamento verificato](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42194114583). Restano firma Signulous, aggiornamento sul telefono, parità dei dati personali, verifiche fisiche e accettazione esplicita.

**Start here / Inizia da qui:** [report corrente per qualsiasi IA](https://github.com/azeroualit-cloud/LifeOS/blob/codex/revision77/docs/AI-HANDOFF.md).

Applicazione iPhone nativa per attività, turni, finanza, salute e raccolta di contenuti Bloom, con web/backend Cloudflare separati.

## Stato del progetto

Il lavoro corrente prosegue su **codex/revision77**. Quel ramo contiene il catalogo alimenti in italiano e i pulsanti Salute sopra la barra di navigazione. Il collaudo iOS di questo incremento è consultabile su [GitHub Actions](https://github.com/azeroualit-cloud/LifeOS/actions/runs/42387125517).

Per lo stato aggiornato delle build e dell’accettazione, consultare il [report del ramo di lavoro](https://github.com/azeroualit-cloud/LifeOS/blob/codex/revision77/docs/STATUS.md) e il relativo [registro decisioni](https://github.com/azeroualit-cloud/LifeOS/blob/codex/revision77/docs/USER-DECISIONS.md).

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
