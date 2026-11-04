# Nutrizione — pannello quick add approvato

Render approvato dall’utente il 4 novembre 2026: «ok approvo». Pulsante compatto in Dashboard → pannello con quattro quantità effettive in grammi, calorie automatiche, data e aggiunta sopra la tastiera. Nessun nuovo inserimento per 100 g/porzione/energia manuale. Standard a due colonne; testo accessibile su una colonna e contenuto scorrevole.

Calcolo nuovi inserimenti: 4P + 4C + 9G + 2 fibre (carboidrati disponibili, convenzione UE). Fonte: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A02011R1169-20250401, allegato XIV. È una stima dai nutrienti, non un valore dell’etichetta; non comprende polialcoli/alcol non inseriti. Energia calcolata conservata nello snapshot esistente, senza migrare o ricalcolare lo storico. Nell’editor storico, una modifica della sola data conserva esattamente i vecchi valori; cambiando i nutrienti si usa il nuovo calcolo.

Stesso store, identità della bozza e retry già esistenti; chiusura solo dopo salvataggio confermato, campi conservati in errore, nessun doppio invio durante busy. Fixture DEBUG separata per successo/errore di scrittura, nessuna scrittura HealthKit reale nei test UI sintetici. Test invarianti precedenti su dati, HealthKit e porzioni storiche conservati. Stato: implementazione pronta per verifica; non ancora compilata o accettata come app reale. Nessuna nuova IPA.
