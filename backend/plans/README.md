# Piani finanziari v2

Moduli aggiuntivi per il Worker esistente. Non sostituiscono il registro bancario.

- `engine.mjs`: regole in centesimi, quote, anticipi, fondi, ricorrenze, recuperi.
- `service.mjs`: archivio D1 separato con controllo versione e pagamenti riprendibili.
- `worker-adapter.mjs`: integrazione con l'autenticazione e gli endpoint legacy.
- `plans.test.mjs`: test su SQLite in memoria e adapter HTTP; nessun dato reale.

Esecuzione: `node --test --test-isolation=none backend/plans/plans.test.mjs` (Node 24).

Per il packaging del Worker utilizzare come entrypoint un modulo che importa il suo export originale e fa `export default withFinancePlans(original)`. Conservare tutti i binding e i secret esistenti. Il wrapper inizializza soltanto la propria tabella `finance_plans_v2_state`; nessuna migrazione di piani o movimenti legacy.

## Condizioni necessarie prima della distribuzione

Il sorgente effettivo del Worker va confrontato con l'adapter: `getFinanceOverview` e `getFinanceData` devono restituire summary e transactions; `saveTransaction` deve rispettare l'idempotenza di requestId e confermare un movementId numerico stabile. Se restituisce solo true l'adapter fallisce in sicurezza e conserva il pagamento in sospeso: non simulare un successo o inventare un identificatore. In quel caso aggiungere al Worker la conferma del movimento e verificarla sul suo database di test prima dell'attivazione.

L'autenticazione è verificata attraverso una chiamata interna al read endpoint già protetto del Worker; per le letture finanziarie si riusa direttamente la risposta autenticata. Origine e metodo sono verificati prima di ogni operazione nuova. Le modifiche o eliminazioni dirette di movimenti collegati a questi piani sono bloccate per evitare incoerenze; i movimenti precedenti restano gestiti dal Worker originale.

La risposta finanziaria comprende `plansV2`; budget mensile e ripartizione sono corretti con le quote del mese richiesto, saldo bancario invariato per quote e anticipi, riserva corrente incrementata soltanto dei fondi effettivamente maturati e non spesi. I pagamenti sono registrati una sola volta dal registro originale con trattamento savings. Gli obiettivi v2 sono inclusi nella previsione del patrimonio del client.

I piani precedenti non sono migrati automaticamente. Un nome già usato dagli accantonamenti legacy viene rifiutato in creazione per ridurre duplicazioni. L'adozione di affitto, utenze e accantonamenti esistenti richiede il confronto con le singole voci di budget del sorgente reale; non cancellare né ricreare quei piani automaticamente.

Nessun deployment o migrazione di dati reali è stato eseguito da questi test. Prima di abilitarlo, verificare conferma/idempotenza di saveTransaction e adozione dei piani esistenti con il Worker effettivo. Questo repository contiene il nuovo codice e il contratto, non una copia del Worker distribuito.
