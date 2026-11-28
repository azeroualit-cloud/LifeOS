# Build 97 — piano

Elenco dell'utente del 28/11/2026 (registro: voci *-97). Prima i mockup, poi l'implementazione; nessuna IPA senza richiesta.

Diagnosi già fatte:
- Analisi «5 mesi … in un mese tipo di 3925,66»: è la scheda Giorno per giorno; «5 mesi» = mesi mediati, «mese tipo» = somma delle medie dei giorni 1–31 di tutte le uscite (probabilmente anche trasferimenti/investimenti). Da riscrivere o togliere.
- Stipendi per competenza: il grafico mostra al massimo gli ultimi 6 cedolini del periodo (`rows.suffix(6)`); da verificare se mancano i cedolini dopo agosto.
- Sito, categorie: ricerca ~5.600 righe e spostamento in blocco (CATEGORY-TOOLS-96): sicuri rispetto al limite D1 di 5 M righe/giorno.

Piani (PLAN-KINDS-97): Anticipa budget, Fondo (scadenza nessuna / una data / ripetuta, convertibile nei due sensi sui mesi futuri), Utenza stimata, Rateizza. Da confermare: Spesa ricorrente fissa → Fondo con scadenza ripetuta.
Stipendi (SALARY-FROM-MOVEMENTS-97): il server legge solo il foglio Cedolini (fermo ad agosto); aggiungere i movimenti Stipendio.
Modo di lavorare (WORKFLOW-ADVICE-97): un mockup unico di tutta la 97 prima del codice; pagina Controllo dati sul sito.

Mockup unico della 97 (WORKFLOW-ADVICE-97): https://claude.ai/artifact/7KVhGbnW6UeiU8D5akXz5n — in attesa di approvazione.
