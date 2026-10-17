# Piani finanziari v2

Moduli aggiuntivi per il Worker esistente. Non sostituiscono il registro bancario.

- `engine.mjs`: regole in centesimi, quote, anticipi, fondi, ricorrenze, recuperi.
- `service.mjs`: archivio D1 separato con controllo versione e pagamenti riprendibili.
- `worker-adapter.mjs`: integrazione con l'autenticazione e gli endpoint legacy.
- `plans.test.mjs`: test su SQLite in memoria e adapter HTTP; nessun dato reale.

Esecuzione: `node --test --test-isolation=none backend/plans/plans.test.mjs` (Node 24).

Per il packaging del Worker utilizzare come entrypoint un modulo che importa il suo export originale e fa `export default withFinancePlans(original)`. Conservare tutti i binding e i secret esistenti. Il wrapper inizializza soltanto la propria tabella `finance_plans_v2_state`; nessuna migrazione di piani o movimenti legacy.

## Condizioni necessarie prima della distribuzione

Il contratto del Worker 11.63 è conservato in [worker-reference](../worker-reference/README.md). `saveTransaction` restituisce true e usa `APP-<requestId>` come import_id: l’adapter legge la riga effettiva da D1 e verifica importo, conto, tipo, stato e data. Una risposta true senza riga compatibile conserva il pagamento in sospeso. Il replay usa lo stesso identificatore e non aggiunge un secondo evento saldo.

L'autenticazione è verificata attraverso una chiamata interna al read endpoint già protetto del Worker; per le letture finanziarie si riusa direttamente la risposta autenticata. Origine e metodo sono verificati prima di ogni operazione nuova. Le modifiche o eliminazioni dirette di movimenti collegati a questi piani sono bloccate per evitare incoerenze; i movimenti precedenti restano gestiti dal Worker originale.

La risposta finanziaria comprende `plansV2`; budget mensile e ripartizione sono corretti con le quote del mese richiesto, saldo bancario invariato per quote e anticipi, riserva corrente incrementata soltanto dei fondi effettivamente maturati e non spesi. I pagamenti sono registrati una sola volta dal registro originale con trattamento savings. Gli obiettivi v2 sono inclusi nella previsione del patrimonio del client.

I piani precedenti non sono migrati automaticamente. Un nome già usato dagli accantonamenti legacy viene rifiutato in creazione per ridurre duplicazioni. L'adozione di affitto, utenze e accantonamenti esistenti richiede ancora la sostituzione esplicita delle singole quote legacy con una decorrenza verificata; non cancellare né ricreare quei piani automaticamente.

Nessun deployment o migrazione di dati reali è stato eseguito da questi test. Prima di abilitarlo, completare l’adozione dei piani esistenti e verificare il packaging con il Worker completo. Il successivo allegato completo è conservato nel repository Git privato locale indicato in worker-reference. Questo repository pubblico mantiene soltanto estratti e contratto; il backup remoto completo è autorizzato e verificato su Google Drive, con file ID e istruzioni di aggiornamento in worker-reference.
