# LifeOS — riferimenti persistenti

L’utente chiede di conservare sorgenti e modifiche nel progetto e di non richiedere ogni volta il medesimo codice incollato.

- Piani finanziari: `backend/plans/`; contratto verificato del Worker 11.63: `backend/worker-reference/README.md`.
- La funzione originale `saveTransaction` ricevuta il 2026-10-17 è conservata in `backend/worker-reference/save-transaction.mjs` ed è eseguita da un test SQLite. Restituisce true; il movimento è identificato da `import_id = 'APP-' + requestId`. Non inventare un movementId.
- La copia arrivata in chat è troncata nella parte centrale. Gli estratti non sono un Worker completo distribuibile. Non sostenere che il Worker integrale sia archiviato qui. Non ricostruire parti mancanti come se fossero originali.
- Il sorgente completo incollato includeva dati bancari e personali: non pubblicare movimenti reali, IBAN, credenziali o seed personali nel repository pubblico. I test usano dati sintetici.
- Sorgente iOS versionato: `lifeos-native.zip`. Estrarlo in una nuova directory `work/` per modificarlo, poi aggiornare ZIP e checksum fissato nel workflow. Non usare estrazioni precedenti senza confrontarle con lo ZIP corrente.
- Non generare IPA per il lavoro Piani senza una nuova istruzione dell’utente. Il workflow `lifeos-plans-tests.yml` compila e verifica sul simulatore senza archivio/IPA.
- Saldo bancario e budget sono distinti. Non azzerare marcatori os_meta né creare una seconda spesa per una quota, un anticipo o un replay.
- L’adozione completa delle voci legacy non è ancora implementata: non duplicare affitto, utenze o accantonamenti esistenti aggiungendo un piano con la stessa finalità.
