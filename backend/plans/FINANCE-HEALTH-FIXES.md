# Correzioni Finanza e dashboard — 17 ottobre 2026

- Il selettore dei mesi non torna più all’ultima risposta salvata dopo un errore. I saldi di un mese differente non vengono mostrati sotto il mese richiesto.
- L’Analisi inizializza le categorie con una richiesta separata prima della lettura completa. Gli errori mostrano la causa restituita dal server e conservano i mesi già caricati.
- La previsione patrimonio usa `wealthHistory.measured` / `estimated`, i campi effettivamente forniti dal Worker, con fallback al formato precedente e storico conservato a cavallo dell’anno.
- Il grafico salute collega tendenza e scenario tramite un breve raccordo continuo, senza modificare misure o previsione; kcal a sinistra, peso a destra. Restano soltanto previsione tra un mese e scenario indicativo sotto il grafico.

## Worker privato

Il primo caricamento completo precedente usava 133 query SQL su fixture sintetica, oltre il limite di 50 richieste D1 del piano gratuito. La classificazione ora usa inserimenti JSON in blocco; i marcatori di schema impediscono ripetizioni a ogni cold start e le impostazioni vengono lette insieme. La stima storica già registrata e tutti i marcatori precedenti vengono preservati.

Il modulo completo aggiornato è conservato solo nel repository e nell’archivio privato. L’utente lo carica manualmente su Cloudflare. I test sintetici non provano che il server pubblicato sia aggiornato o che l’accesso reale sia valido. Il badge “Da aggiornare” resta veritiero finché una sincronizzazione non riesce.

## Verifica locale

96 test dei modelli Swift; 34 test server, incluso Worker completo e controllo del numero di query per ogni lettura provata. Inizializzazione categorie: 30 query; lettura corrente completa: 27; lettura storica: 39; lettura storica dopo cold start: 43; anno precedente dopo cold start: 47; configurazione con affitto già separato dal condominio: 48. Riclassificazione di 300 nuovi movimenti: 4 query. Nessun dato reale modificato.

Verifica iOS finale riuscita: workflow `lifeos-plans-tests.yml`, modalità `regressions`, run 39043117966, sorgenti fd06e9d. Compilazione, 115 test unitari e due flussi UI passati: Analisi con intervalli 3/6/12 mesi e navigazione mesi avanti/indietro con etichette salute aggiornate.

IPA 0.9.4 build 55 verificata per iPhoneOS arm64: run 39043121169, artifact 12104892606. SHA-256 e provenienza in IPA-build55.json. Consegna soltanto GitHub; nessun binario IPA nel backup Drive.

Controllo visivo aggiuntivo dell’intera scheda: primo tentativo 39043315482 fermato da un timeout durante app.launch, prima delle verifiche della scheda. Ripetizione 39043992563 riuscita: test breve e cattura dell’intera scheda passati. Screenshot esaminato: raccordo continuo, kcal a sinistra, kg a destra, valori superiori invertiti e testi semplificati.
