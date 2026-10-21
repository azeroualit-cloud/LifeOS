# Finanza — build 58

La spesa normale registra un singolo pagamento nel mese. Mesi coperti, trattamenti e recuperi non sono proposti nell'editor; una categoria non collega automaticamente la spesa a un piano. Ricorrenze e ripartizioni si gestiscono da Piani, anche partendo dalle vecchie scorciatoie del Budget.

I pagamenti collegati sono apribili nel dettaglio del piano, anche interrotto. Da Spesa, un movimento collegato offre Gestisci pagamento collegato. Elimina pagamento e movimento richiede conferma, storna la sola uscita e conserva gli altri pagamenti. I piani interrotti rimangono interrotti; rimuovere il saldo di un obiettivo lo riapre. Il server conserva uno stato di eliminazione in corso per riprendere dopo timeout o riavvio senza duplicare lo storno. I movimenti condivisi o con importi discordanti non vengono eliminati come se appartenessero interamente al pagamento selezionato.

L'Analisi usa getFinanceCategoryPeriod per una singola aggregazione di 3/6/12 mesi, senza richiamare il modello completo per ogni mese. I risultati devono contenere l'intero periodo prima di essere mostrati. Gli errori HTML di Cloudflare sono tradotti in un messaggio leggibile con Riprova; il contenuto HTML non compare nella pagina.

Prove locali: 39 test server, inclusa due pagamenti sintetici e un piano Palestra interrotto; 25 test Foundation; regressioni Chromium sul Worker realmente servito, incluso errore HTML 500 e ripetizione dell'eliminazione; TypeScript, parsing Swift e design system. Verifica Apple e archivio iPhone eseguiti dal workflow sulla revisione pubblicata; gli esiti e i riferimenti del pacchetto sono registrati nella consegna.

Sorgente iOS autorevole: lifeos-native.zip. Worker pubblico sanificato: worker.js, rigenerabile con backend/worker/build.mjs. Nessuna modifica ai dati reali e nessun deploy Cloudflare: l'utente carica manualmente il Raw e firma l'IPA.
