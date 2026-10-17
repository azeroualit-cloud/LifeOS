# Correzioni Finanza e dashboard — 17 ottobre 2026

- Il selettore dei mesi non torna più all’ultima risposta salvata dopo un errore. I saldi di un mese differente non vengono mostrati sotto il mese richiesto.
- L’Analisi inizializza le categorie con una richiesta separata prima della lettura completa. Gli errori mostrano la causa restituita dal server e conservano i mesi già caricati.
- La previsione patrimonio usa `wealthHistory.measured` / `estimated`, i campi effettivamente forniti dal Worker, con fallback al formato precedente.
- Il grafico salute collega tendenza e scenario tramite un breve raccordo continuo, senza modificare misure o previsione; kcal a sinistra, peso a destra. Restano soltanto previsione tra un mese e scenario indicativo sotto il grafico.

## Worker privato

Il primo caricamento completo precedente usava 133 query SQL su fixture sintetica, oltre il limite di 50 richieste D1 del piano gratuito. La classificazione ora usa inserimenti JSON in blocco; i marcatori di schema impediscono ripetizioni a ogni cold start e le impostazioni vengono lette insieme. La stima storica già registrata e tutti i marcatori precedenti vengono preservati.

Il modulo completo aggiornato è conservato solo nel repository e nell’archivio privato. L’utente lo carica manualmente su Cloudflare. I test sintetici non provano che il server pubblicato sia aggiornato o che l’accesso reale sia valido. Il badge “Da aggiornare” resta veritiero finché una sincronizzazione non riesce.

## Verifica locale

95 test dei modelli Swift; 34 test server, incluso Worker completo e controllo del numero di query per ogni lettura provata. Inizializzazione categorie: 30 query; lettura corrente completa: 27; lettura storica: 39; lettura storica dopo cold start: 43; anno precedente dopo cold start: 47. Riclassificazione di 300 nuovi movimenti: 4 query. Nessun dato reale modificato.

Verifica iOS in corso: workflow `lifeos-plans-tests.yml`, modalità `regressions`, run 39042248365.
