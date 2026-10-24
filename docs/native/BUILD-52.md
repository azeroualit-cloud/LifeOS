# Life OS 0.9.0 build 52 — verifica Apple completata

[IPA unica per Signulous](https://github.com/azeroualit-cloud/LifeOS/actions/runs/39991175624/artifacts/12519324746) · [build e test Apple](https://github.com/azeroualit-cloud/LifeOS/actions/runs/39991175624) · [verifica indipendente IPA](https://github.com/azeroualit-cloud/LifeOS/actions/runs/39996781763) · [PR](https://github.com/azeroualit-cloud/LifeOS/pull/1).

## Comportamento

Navigazione con Dashboard e Finanza. Dashboard con settimana e meteo, azioni Aggiungi peso e Calendario nello stesso componente usato da Finanza, grafico peso/calorie con dati mancanti distinti dallo zero. Attività e abitudini sono rimosse dall’interfaccia; dati storici conservati. Il calendario dei turni si apre dalla Dashboard e prepara una pubblicazione mensile per Calendario Apple in abbonamento. Peso e calorie sono manuali; HealthKit non è integrato.

## Evidenze

Compilazione Apple e archivio Release riusciti. Superati **83 test unitari, 26 test UI standard e 12 test UI compatti**, senza fallimenti, oltre alle due prove mirate di salute e Finanza. La prova dello stato vuoto raggiunge il testo visibile con scorrimento, salva il peso, lo ritrova nell’editor e lo legge dall’elenco.

La verifica indipendente scarica l’artefatto su GitHub con permessi di sola lettura: confermati SHA-256, CRC di tutti i file ZIP, versione 0.9.0, build 52, bundle `com.nas.lifeos.probe` e Mach-O arm64. Nessuna lettura del backend con credenziali nella nuova CI.

- Sorgenti nativi verificati: commit `d9b227c33e1d38e3e2b3c023ba087778db6a21c0`; il pacchetto nativo resta identico nei successivi commit web e documentali della PR.
- SHA-256 pacchetto sorgenti: `61ba8197492e5d139bbd441ef64d94e3eddb7e117e10f96670e554a27e9e4ec3`.
- SHA-256 IPA: `b6a39b6051e0b7bd802393120e0d78d43ddcffbd6c0112d0eac00d8ad50f9165`.
- Artefatto IPA disponibile fino al 30 ottobre 2026, salvo modifiche alla conservazione su GitHub.

Anche build web, SQLite locale e Playwright a 320/375/1280 px sono passati. Il refactor del build backend è stato confrontato byte per byte con il Worker già testato.

## Attivazione e limiti

Il codice è nella PR; **nessun deploy Cloudflare e nessun abbonamento Apple live sono stati eseguiti**. Le nuove funzioni salute/turni sul server richiedono l’attivazione delle nuove API. La demo iPhone funziona e conserva le misurazioni soltanto nel proprio archivio locale. L’IPA verificata non prova l’integrazione live con Calendario Apple o il backend aggiornato.

La revisione automatica aveva bloccato il caricamento del Worker completo con i dati incorporati. La soluzione finale pubblica soltanto il codice nuovo: `web/worker.mjs` resta il template originale invariato; le estensioni e il build producono localmente `web/dist/worker.mjs`, ignorato da Git. Non è necessario ripubblicare una copia modificata dello storico finanziario.

Nessuna prova sul dispositivo fisico eseguita. Le schermate dei simulatori sono negli artefatti; l’ispezione locale delle immagini native è stata limitata dal blocco di rete del servizio file. L’anteprima web con fixture è stata ispezionata localmente. Prima dell’uso reale delle nuove funzioni, completare deploy e prova su iPhone. Per installare l’IPA tramite Signulous mantenere lo stesso bundle e aggiornare senza disinstallare.

Per backend, dati e attivazione: [Dashboard salute](../DASHBOARD-SALUTE.md), [Calendario Apple](../APPLE-CALENDAR.md). Diff cumulativo: [APPLE-TURNI-52.diff](APPLE-TURNI-52.diff).
