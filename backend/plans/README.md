# Piani finanziari v2

Estensione del Worker LifeOS 11.63 e client iOS. Saldo reale e budget mensile restano distinti.

- `engine.mjs`: regole in centesimi, quote, anticipi, fondi, ricorrenze, recuperi e modifiche future.
- `legacy.mjs`: adozione idempotente di affitto, utenze e straordinarie esistenti; sostituzione delle quote dalla decorrenza, senza cancellare righe legacy o movimenti.
- `service.mjs`: archivio D1 con controllo versione e pagamenti riprendibili.
- `worker-adapter.mjs`: autenticazione legacy, integrazione dei budget e del registro bancario, collegamento a movimenti esistenti e compatibilità con spesa rapida.
- `build-worker.mjs`: packaging del Worker completo in un solo modulo, fuori dal repository pubblico.
- `plans.test.mjs`: regole e API su SQLite sintetico.
- `private-worker.test.mjs`: integrazione col Worker completo privato, su un database esclusivamente sintetico.

## Comportamenti

Anticipo: somma zero fra mesi, nessun movimento bancario. Obiettivo: quote finite, pagamento effettivo e chiusura delle sole quote future; recupero facoltativo della sola eccedenza. Fondo: accumulo continuo e pagamenti senza chiusura. Ricorrenza fissa: una scadenza per intervallo, con quote mensili esatte. Utenza: importi normalizzati per mesi coperti, nuova stima dal mese successivo. Recupero: una spesa e quote future, senza un secondo Paga.

Un movimento già registrato può essere collegato senza un nuovo addebito. Sono disponibili quelli dai risparmi e quelli del mese corrente non già collegati. Una spesa ordinaria di un mese chiuso non viene riclassificata retroattivamente. La modifica delle quote decorre da un mese futuro; per gli obiettivi conserva le quote precedenti e distribuisce solo il residuo rispetto al nuovo totale.

## Adozione e compatibilità

La nuova app invia `X-LifeOS-Plans-Version: 2`. Solo quel segnale, o una richiesta esplicita a un endpoint Piani, attiva l’adozione. Le sole letture dei vecchi client non la avviano. I nomi/sorgenti esistenti hanno identità stabili, senza una seconda quota; il codice conserva la separazione affitto/condominio già presente. I mesi precedenti alla decorrenza usano il motore storico.

Manutenzione annuale diventa un fondo senza scadenza conservando l’accumulato verificabile. Le altre ricorrenze annuali mantengono periodo e quote al centesimo. Gli obiettivi pagati in parte espongono solo il residuo da saldare. Gli anticipi storici rimangono nel motore legacy perché non se ne inventa un mese beneficiario.

L’adapter legge `APP-<requestId>` dopo `saveTransaction`, che nel Worker originale restituisce true. Verifica riga, importo, conto, stato e data prima di confermare il collegamento. Un errore dopo il salvataggio si riprende con lo stesso ID. Le scritture dirette che altererebbero un pagamento collegato sono bloccate, anche mentre la conferma è in sospeso.

## Verifica e packaging

```sh
node --test --test-isolation=none backend/plans/*.test.mjs
node backend/plans/build-worker.mjs /private/worker.mjs /private/worker-plans.mjs
LIFEOS_PRIVATE_WORKER=/private/worker-plans.mjs node --test --test-isolation=none backend/plans/private-worker.test.mjs
```

Node 24. Il build usa esbuild 0.25.12. Il sorgente completo privato e la sua cronologia sono indicati in [worker-reference](../worker-reference/README.md); non copiarli nel repository pubblico. Il modulo risultante conserva frontend, autenticazione, binding `DB`, secret, migrazioni e marcatori originali. Non creare un nuovo D1 né azzerare marcatori durante la distribuzione.

Il workflow `lifeos-plans-tests.yml` compila app e test per simulatore e verifica i flussi senza archivio né IPA. Il test col Worker completo è eseguito localmente: il repository pubblico non contiene i dati privati necessari al suo caricamento.

Il packaging collega direttamente la funzione originale `saveTransaction` dopo l’autenticazione. Il pagamento conserva la transazione bancaria e l’idempotenza originali e rinvia il ricalcolo delle categorie alla lettura Analisi: il test sul Worker completo verifica 32 query per la prima registrazione e 39 dopo un cold start, entro 50. Non usare un wrapper privo di questo collegamento per il pacchetto distribuito.

Il resoconto delle verifiche e lo stato della distribuzione sono in [VERIFICATION.md](VERIFICATION.md).
