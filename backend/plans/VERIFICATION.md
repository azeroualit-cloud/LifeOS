# Verifica Piani — 17 ottobre 2026

## Pacchetto e dati

Il Worker completo è nell’archivio Drive privato indicato in `../worker-reference/README.md`. `worker.mjs` conserva l’originale; `worker-plans.mjs` è il modulo da caricare sul Worker esistente. SHA-256 del modulo: `ebf2162393ed147a5e0a9b6081581242e73c8ccf2d784ecf81591fd63e83a874`.

Il database reale non è stato modificato dall’ambiente di sviluppo. La distribuzione è manuale a cura dell’utente. Binding D1, database, secret e marcatori delle migrazioni vanno conservati.

## Evidenze

- 34 test server superati localmente, incluso il Worker completo su SQLite con dati sintetici. Il test privato è escluso dalla CI pubblica per conservare privati i dati del sorgente originale.
- Autenticazione, adozione legacy senza quote duplicate, saldo distinto dal budget, pagamenti una sola volta, ripresa dopo risposta persa e cold start, collegamento a movimenti esistenti e mesi storici verificati.
- Query SQL per pagamento: 32 prima registrazione, 22 replay, 39 cold start, entro il limite verificato di 50.
- 93 test Swift dei modelli superati in Linux; 109 test unitari iOS superati sul simulatore, che comprende anche i test dello store.
- Sette flussi UI verificati: sei nell’esecuzione [39034285367](https://github.com/azeroualit-cloud/LifeOS/actions/runs/39034285367); fondo, modifica quota futura e collegamento a una spesa esistente nell’esecuzione mirata [39037396255](https://github.com/azeroualit-cloud/LifeOS/actions/runs/39037396255), conclusa con successo.
- Il flusso fondo verifica un tocco al centro della riga, area minima di 44 punti, importo aggiornato dalla spesa selezionata, conferma abilitata, pagamento mostrato e fondo ancora attivo. Il caricamento parte da un contenitore stabile; l’intera riga risponde al tocco.
- Sorgente iOS verificato: SHA-256 `a59829f42ec1944dcc30e42c50878adf9292c57aff93c7d63396b4390b7de15f`. Compilazione per simulatore completata nella stessa esecuzione mirata. I 109 test unitari appartengono all’esecuzione 39034285367; i modelli sono invariati nelle successive correzioni UI.
- Schermate dell’anticipo, dell’obiettivo concluso e della guida controllate visivamente. Le prove UI usano dati demo; il Worker completo è verificato separatamente con dati sintetici.
- Nessun archivio né IPA generato per questo lavoro.

## Limiti operativi

La verifica sintetica non certifica lo stato del database reale dopo il caricamento manuale. Dopo la pubblicazione controllare con un accesso autenticato saldo, budget corrente, Piani e mese precedente. Non creare pagamenti di prova sul conto reale per la sola verifica.

I pagamenti collegati sono protetti dalla modifica/eliminazione rapida che renderebbe incoerente il piano. Gli anticipi storici privi di un mese beneficiario verificabile restano nel motore legacy. Le quote future sono modificabili senza riscrivere i mesi precedenti.
