# Budget unificato — 0.9.8 / 59

Finanza presenta quattro azioni, in ordine: Budget, Nuovo piano, Nuova spesa, Analisi. Nuovo piano apre direttamente il modulo; i piani sono consultabili e gestibili da Budget. Non esiste una seconda sezione Piani.

Il Budget parte dallo stipendio di riferimento del mese selezionato. Ogni piano con quota nel mese, compresi gli impegni storici di piani interrotti, mostra il proprio impatto e il residuo progressivo. I piani attivi nel periodo con quota zero restano visibili. Gli anticipi aumentano il residuo. Le obbligazioni precedenti non adottate restano nel calcolo, senza duplicare le righe già attribuite a un piano. Eventuali impegni residui del riepilogo vengono esplicitati. Infine vengono applicate le spese non già coperte: il budget finale coincide con il riepilogo del server.

Piani futuri e conclusi sono consultabili in un gruppo espandibile nella stessa schermata; da qui rimangono accessibili dettagli, pagamenti e l'eliminazione dei pagamenti collegati introdotta nella build 58. Preservati saldo bancario, obiettivo di risparmio, storico, abitudini e salute. Nessuna migrazione o modifica dei dati reali e nessun deploy Cloudflare.

Calcolo esposto in centesimi su entrambe le piattaforme; test sintetici per anticipo, storico interrotto, quota zero, piano futuro escluso, rimborsi e budget negativo. Verifiche browser contro l'HTML realmente incorporato nel Worker, incluse creazione in demo, persistenza e gestione pagamenti. Il sorgente iOS autorevole resta lifeos-native.zip; SHA fissato nella pipeline IPA. La consegna richiede inoltre compilazione Apple, test unitari e flussi UI su simulatore.
