# Worker Life OS 11.63 — riferimento conservato

Provenienza: Worker LifeOS 11.63 incollato e poi fornito come allegato `Testo incollato.txt` il 17 ottobre 2026. L’allegato successivo è completo (468291 byte), privo dei troncamenti presenti nel messaggio precedente e sintatticamente valido con `node --check`.

Il sorgente integrale è conservato nel repository Git privato **locale** `/workspace/LifeOS-worker-private`, file `worker.mjs`; il commit iniziale conserva i byte originali, con hash e provenienza in `provenance.json`. SHA-256 originale: `f40e23d3a0e8131c68db8a4962d33002c6d5fce17214e5d3d87019beb10232ce`. Archivio locale comprensivo di Git bundle: `/workspace/work/worker-archive-check/LifeOS-Worker-privato.zip`.

Backup remoto completo autorizzato dall’utente e verificato su Google Drive: [LifeOS-Worker-privato.zip](https://drive.google.com/file/d/1-P5BQ7XNiSizY_NF368BG61fyiZa4T7q/view). File ID: `1-P5BQ7XNiSizY_NF368BG61fyiZa4T7q`; dimensione della prima copia con istruzioni: 241784 byte; l’archivio viene aggiornato con le revisioni successive. La verifica dei metadati conferma `shared=false` e il solo permesso owner. L’archivio contiene sorgente integrale, provenienza, istruzioni e bundle Git; il commit iniziale conserva i byte originali.

Nelle prossime sessioni recuperare lo ZIP tramite Drive. Per modifiche future: aggiornare il sorgente nel Git privato, creare un nuovo bundle e ZIP e sostituire i byte dello stesso file Drive, mantenendo privati i permessi. Non richiedere all’utente di incollare di nuovo il codice. La creazione di un nuovo repository privato GitHub resta non disponibile con i permessi attuali; questo non impedisce di usare la cronologia Git contenuta nell’archivio.

Questo repository pubblico conserva soltanto il contratto e gli estratti privi di movimenti personali. Il Worker completo non va aggiunto al repository pubblico. Non richiedere nuovamente all’utente lo stesso codice se è ancora accessibile nel repository locale o nel futuro archivio remoto autorizzato.

La funzione originale di registrazione è in `save-transaction.mjs`; il test in `plans.test.mjs` la esegue su SQLite simulando una risposta persa dopo il commit e verifica un solo movimento e un solo delta saldo.

Il Worker originale contiene anche movimenti bancari, IBAN e attività personali. Questi dati non sono riprodotti nel repository pubblico. Le future modifiche all’integrazione partono da `backend/plans/` e da questo riferimento, con cronologia Git; il Worker completo distribuito resta distinto.

## Registro reale dei pagamenti

`saveTransaction(env,input)` accetta Spesa, Entrata, Rimborso e il trasferimento finale Revolut → Trade Republic. Il conto operativo è Trade Republic. Restituisce `true`, anche al replay idempotente, senza restituire il numero del movimento.

- `requestId`: 8–80 caratteri alfanumerici o trattini.
- `finance_write_requests(id,fingerprint)`: chiave unica e controllo che una richiesta ripetuta abbia gli stessi dati.
- `movements.import_id = 'APP-' + requestId`.
- `movements.source_row`: identità effettiva da leggere dopo il pagamento.
- Spesa: importo negativo, `movement_type='Spesa'`, `status='Eseguito'`.
- `insertOnce`: inserisce soltanto se import_id manca e il fingerprint coincide con la richiesta prenotata.
- Movimento, evento saldo e politica di budget sono registrati nello stesso `env.DB.batch`.
- `account_balance_events`: evento aggiunto soltanto se assente per quel movimento; non aggiungere un secondo delta nell’adapter Piani.
- Descrizione massimo 120 caratteri, categoria massimo 60, importo massimo 1.000.000 euro e due decimali, data valida non futura.
- `budgetTreatment='savings'` separa il pagamento dal budget mensile; il saldo reale cambia tramite il registro esistente.

L’adapter verifica riga, importo in centesimi, conto, tipo, stato e data prima di confermare il collegamento. Una risposta true senza riga compatibile mantiene il pagamento in sospeso. La ripresa usa lo stesso requestId.

## Budget e pianificazioni preesistenti

`summary.budget` è il saldo bancario reale; `monthlyRemaining` è un indicatore di pianificazione. Quote e anticipi non modificano il primo.

`loadFinance` legge movements, extraordinary, source_rows, account_balance_snapshots, account_balance_events e le politiche di budget, poi chiama computeFinance. Le letture leggere restituiscono summary, recurring, extras, transactions ed extraPlan.

`extraPlan.allocations` contiene cycle_id, month, amount_cents, kind, status, name, extraordinary_source_row, start_month, end_month, total_cents, payment_account, paid_date. Le quote esistenti sono già conteggiate dal motore legacy: non aggiungere una seconda quota. Links e settlements sono letti globalmente; le allocazioni sono lette per anno.

Affitto e utenze sono già voci del budget. Il codice mantiene la separazione storica affitto/condominio mediante `rent_condominium_split_v1158`: dal 2026-10, se il valore originale è 575, l’affitto è 550 e il condominio 25. Non sottrarre nuovamente il condominio.

Le stime utenze sono aggiornate dai pagamenti precedenti normalizzati per mesi coperti e dalle modifiche manuali con mese di decorrenza. `utility_estimates_v1` e `condominium_estimates_v1` sono metadati esistenti da conservare.

Adottare i piani precedenti richiede una decorrenza e la sostituzione esplicita della relativa quota legacy; la sola creazione di un nuovo piano non realizza un’adozione. L’adozione è ora implementata in backend/plans/legacy.mjs: attivazione dal client Piani v2, identità per sorgente, decorrenza dal mese corrente e sostituzione delle quote legacy. Gli anticipi storici non vengono ricostruiti senza un beneficiario verificabile.

## Autenticazione, schema e distribuzione

Preservare Cloudflare Access (ACCESS_EMAIL e ctx.access) oppure APP_PASSWORD, cookie HMAC, autenticazione Basic, controllo Origin sui POST e whitelist RPC. Non cambiare binding D1 `DB`, credenziali o marcatori seed/migrazione os_meta. Il modulo originale esporta un oggetto con fetch(request,env,ctx).

Le scritture dirette si chiamano editMovement e deleteMovement. I pagamenti Piani v2 collegati sono protetti dall’adapter. I pagamenti legacy restano gestiti dalle tabelle extraordinary_movement_links e extraordinary_settlements.

Il codice ricevuto non è stato distribuito e il database reale non è stato modificato. Il packaging del Worker completo privato con l’entrypoint withFinancePlans e l’adozione legacy sono pronti; la distribuzione resta a carico dell’utente, come concordato.

Il pacchetto privato aggiornato contiene `worker-plans.mjs` (modulo completo), `worker.mjs` (baseline originale), entrypoint/moduli sorgente, Git bundle, test sintetico e `lifeos-native-source.zip`. L’utente ha scelto il caricamento manuale sul Worker Cloudflare esistente: non richiedere ulteriormente credenziali o autorizzazione alla stessa distribuzione. Lo stato effettivo va confermato dal caricamento dell’utente o da una verifica autorizzata del servizio; non dichiararlo già distribuito.
