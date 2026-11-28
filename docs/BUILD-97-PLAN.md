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

Avanzamento notte 28/11 (non ancora compilato in CI): Dashboard (badge turno lungo in 4 parti con riempimento progressivo e 15 min dopo la fine, Cose da fare = Attività/Abitudini, Finanza senza movimenti e barra blu, Nutrizione coi colori Fitia), Salute (arco calorie Fitia, verde/giallo/grigio Fitia, micronutrienti ad anelli, icone Sezioni allineate), Calendario (tocco seleziona, torna a oggi; test aggiornati), Attività (swipe In attesa/Riattiva/Elimina con conferma). Da fare: test Dashboard (Gestisci, elenco), Finanza (mese a un tocco, Trade Republic, Piani e Budget a mappa, obiettivi risparmio), Analisi e stipendi, Cronologia, Incontri come turni, tipi di piano (98), Controllo dati sul sito, candidato 97.

## Stato 28/11, notte (dopo «voglio tutto nella 97»)

Implementato nell'app (sorgente su `codex/build93`):
- Salute: scheda calorie Fitia, verdi/giallo/grigio Fitia, micronutrienti ad anelli, icone Sezioni allineate.
- Cronologia (HISTORY-REDESIGN-97): intervallo 7 g / 30 g / 3 mesi / Date, calendario colorato (verde nel range, giallo sotto, arancione molto sopra, grigio senza dati), tocco = giorno con totali e pasti (modificabili ed eliminabili), medie dell'intervallo e colonne per settimana. Nessun elenco infinito.
- Dashboard: badge turno lungo in 4 parti con riempimento progressivo (anche entro 15 min dalla fine), Attività/Abitudini, Nutrizione Fitia, Finanza senza movimenti e barra blu.
- Calendario: tocco seleziona; torna a oggi cambiando scheda o riaprendo. Incontri (INCONTRI-EASY-ADD-97): nel pannello «Dipingi» scheda Turni/Incontri, persona come pennello, tocco sul giorno aggiunge o toglie, «Annulla».
- Attività: swipe In attesa / Riattiva / Elimina con conferma.
- Finanza: mese a un tocco con menu centrale, Trade Republic nascosto con interruttore, Piani a mappa (Al mese / Da parte), Budget a mappa in tre parti con Budget finale, obiettivi di risparmio semplificati con mesi esclusi, Analisi con «Mese tipo» per categoria.
- Piani (PLAN-KINDS-97): nuovo piano con quattro tipi (Anticipa budget, Fondo con fine facoltativa, Utenza stimata, Rateizza); dal dettaglio di un Fondo «Aggiungi/Cambia la fine» (solo mese corrente e successivi). Pagare con un Fondo: tutto dai risparmi, nessuna parte sui mesi di budget (FUNDS-PAY-FROM-SAVINGS-97).

Server (entrambi i Worker, run verificati con rollback):
- SALARY-FROM-MOVEMENTS-97: `salaryHistory` aggiunge i mesi senza cedolino dai movimenti Stipendio (pagati entro il 10 → mese precedente); lordo 0 per non toccare i totali dei cedolini.
- PLAN-KINDS-97: Fondo con `endMonth`, `setFinanceFundEnd`, `convertFixedPlansToFunds` (5 spese fisse convertite: stessa quota al mese, mesi fino al corrente invariati in `pastSchedule`, originale in `convertedFrom`, reversibile). I pagamenti ricorrenti del sito trovano ancora i piani convertiti.

Sito (`codex/revision77`, deploy verificato): Admin → «Controllo dati» (integratori per dose con valori da 100 g, mesi senza stipendio negli ultimi 6, categorie senza gruppo). Non modifica nulla.

Non fatto in questa build: il sito offre ancora «Spesa ricorrente fissa» nel suo editor dei piani (l'app no); prove fisiche e accettazione dell'utente aperte.
