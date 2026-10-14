# Revisione interfaccia 0.3.1

Richiesta del 14 ottobre: riferimento visivo fornito da Nas, schermate compatte e curate, palette dei turni originale leggermente più satura, correzione del tremolio ai limiti dello scorrimento e dell'aggiunta eventi. L'utente conferma che i test funzionali svolti passano; il problema corrente è l'esperienza grafica e di interazione.

## Cause e correzioni

La riduzione automatica della tab bar era attiva (`onScrollDown`) e spiega l'icona isolata visibile negli allegati. Ora la barra resta espansa (`never`). I titoli principali sono inline e fissi; i comandi non cambiano struttura quando parte una sincronizzazione. Rimosso il pull-to-refresh dalle schermate principali: resta Sincronizza nel menu e nelle Impostazioni, oltre agli aggiornamenti automatici.

Il calendario non usa più una LazyVGrid dentro una singola cella di List: griglia eager di 35/42 giorni dentro uno ScrollView. Conteggi degli eventi calcolati una volta per rendering. Altezza dei giorni prevedibile, aggiunta eventi nella scheda e dal pulsante superiore. Le prove di gesto certificano raggiungibilità e stabilità della navigazione sul simulatore; la fluidità sul dispositivo fisico resta una verifica distinta.

Dashboard con settimana, turno del giorno, attività, riepilogo finanziario e routine. Finanza con budget e saldo compatti, andamento giornaliero ricavato dalle spese effettive, quote Extra e ultimi movimenti; analisi, ricorrenti e storico restano raggiungibili nei dettagli. Nessun dato finanziario modificato dalla revisione.

Tipografia di sistema senza arrotondamento globale, schede e spaziature ridotte, righe attività allineate a sinistra, separatore delle migliaia esplicito. Colori dalla versione web: mattina blu, pomeriggio verde, notte grigio, riposo arancio, ferie giallo; adattamenti per contrasto nei due temi, senza sostituirli con colori primari puri.

## Verifiche previste

- Suite modelli e sincronizzazione, contratto API condiviso e archive iPhone.
- Quattro sezioni in entrambi i temi, tastiera e testo grande.
- Liste lunghe e trascinamenti ripetuti ai due estremi, tab bar sempre raggiungibile.
- Creazione evento dopo overscroll, apertura editor dal pulsante superiore.
- Apertura di un'attività lunga senza completarla accidentalmente.
- Verifiche supplementari su simulatore iPhone SE di terza generazione.

Consegna di una sola IPA dopo la revisione dei risultati; non chiedere installazioni delle build intermedie.

## Prima revisione eseguita

Run 38557044260: 30 test di logica/sincronizzazione, 7 test UI su iPhone 17 Pro e altri 3 test UI su iPhone SE di terza generazione, tutti passati. Contratto API reale e archive riusciti. Screenshot scaricati e ispezionati nei due temi, sui due formati, con testo grande e dopo i gesti.

Dalle immagini sono emersi aggiustamenti incorporati nella build di consegna: settimana con altezza minima e testo limitato al massimo standard per evitare sovrapposizioni, nomi dei giorni calcolati nel fuso Roma, selettore del mese nel titolo del grafico, menu turni nella scheda del giorno, margine finale per rendere raggiungibile l'aggiunta evento. Aggiunte prove di budget negativo, separatore delle migliaia anche a quattro cifre e ritorno al giorno scelto dalla Dashboard dopo un cambio mese.

La revisione modifica l'interfaccia nativa e i dati demo dei test, non il Worker web o il database condiviso. I test degli eventi usano solo archivi demo locali.

La build 7 corregge anche le etichette del grafico giornaliero usando un asse numerico e unità in euro. Il componente è separato per contenere la complessità delle espressioni SwiftUI. L’ultima compilazione è nel run 38566072884.

Build 8: rimossa la sola etichetta finale aderente al bordo destro del grafico; mantenuta la scala numerica e i riferimenti intermedi 1, 5, 10, 15, 20, 25. Run finale 38567922673.

Esito finale: run 38567922673 riuscito, 31 test unitari + 9 UI principali + 3 UI compatti = 43 esecuzioni senza errori. Contratto API reale e archive riusciti. IPA scaricata, hash/versione/bundle/arm64 verificati. Anteprime principali e compatte ispezionate. Artefatto IPA: 11897507875. Rimane la conferma della fluidità sul dispositivo fisico.
