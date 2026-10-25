# Revisione 0.10.0 (61)

Baseline: archivio pubblico build 60, commit 02c2c089841833a67fc9a223b367710edf7e37b9; integrazione con calendario continuo e completamento persistente del ramo apple-calendar-reminders. Overlay pubblicabile in native-next; integration-53 è una copia di lavoro ignorata da Git.

## Checklist approvata

1. Platino originale ripristinato: 0.87 scuro / 0.23 chiaro.
2. Comandi generali e navigazione neutri.
3. Colori funzionali distinti dall'accent neutro.
4. Liste attività senza fondi delle righe o contenitori di sezione.
5. Superficie circoscritta alla riga in modifica.
6. Un solo titolo modificabile nella riga aperta.
7. Swipe rimosso; cambio stato ed eliminazione inline.
8. Comandi compatti con target di 44 punti; campanella apre la gestione reale dei permessi.
9. Completamento reversibile; ordine completate in coda, sezione di origine preservata anche offline.
10. Abitudini di oggi filtrate nella Dashboard e nel pannello alternativo.
11. Rollover giornaliero e gestione separata delle abitudini conservati dalla build 60.
12. Eventi inclusi nelle attività come proiezioni dell'identità originale, senza duplicare record.
13. Scadenza e giorno programmato restano campi distinti da un evento.
14. Modifica/completamento degli eventi usa le medesime API e identità da entrambe le viste.
15. Notifiche ricalcolate sui dati confermati/locali, giorno/orario modificabili; link al record o giorno originale. Servono autorizzazione iOS e attivazione notifiche nell'app. Nessuna promessa di sincronizzazione in background dal web quando l'app non viene eseguita.
16. Identità delle occorrenze ed editor di serie conservati.
17. Titolo del mese presente una sola volta nel flusso; intestazione fissa solo con controlli.
18. Mesi consecutivi, caricamento lazy e marcatori per cambio mese.
19. Barra compatta e palette turni contestuale; esportazione Apple conservata.
20. Selezione del giorno nel colore del turno; testo scuro sui colori pastello per contrasto.
21. Secondo tocco deseleziona; pittura distinta dalla selezione.
22. Arrivo animato del contenuto delle schede senza ricreare navigazione o posizione.
23. Pressione, cerchio, attenuazione, riordino ed espansione rispettano Riduci movimento.
24. Selezione, dettagli, ritorno a oggi e scroll nativo condividono lo stato.
25. Palette, cambio turno e annullamento mantengono animazioni e feedback.
26. Presentazioni e chiusure native degli editor conservate.
27. Test per testo grande, Riduci movimento, geometria e prestazioni dello scroll; le metriche del simulatore non attestano gli FPS su un iPhone fisico.
28. Patch server con confronto puntuale e rollback: conservazione completate, programmazione abitudini e orario notifiche. Preserva autenticazione, binding e aggiornamenti live estranei. Distribuzione NON eseguita: contesto live diverso, autorizzazione esplicita ancora necessaria dopo il blocco della revisione automatica. Non sostituire il modulo live con una baseline vecchia.

## Verifiche locali

59 test Foundation superati, inclusi catalogo attività, programmazione abitudini, notifiche e routing. Worker reale su SQLite: migrazione idempotente, conservazione completate, sezione originale, programmazione abitudini e orari preservati nelle modifiche. Due test del deploy con controlli di contesto/idempotenza e round trip multipart superati. Playwright: tre viewport, zero errori. Parsing Swift, controllo design system e sintassi workflow superati.

Compilazione SwiftUI e archivio Release superati nella CI Apple 40235736129; 165 test unitari, 7 regressioni, 2 prove UI principali aggiornate e 14 prove compatte senza fallimenti. La verifica finale aggiunge soltanto la raggiungibilità dell’esportazione dalle Impostazioni. Distribuzione backend ancora bloccata.

## Evidenza Apple cumulativa

Esecuzione 40219809250 sul medesimo codice funzionale: 163 test unitari e 40 test UI principali superati; due prove compatte fallivano perché cercavano un'attività completata senza scorrere fino alla sua nuova posizione in fondo. Le prove sono state aggiornate per verificarne raggiungibilità e riapertura. La revisione visiva ha inoltre ridotto lo stile delle icone inline eliminando la spaziatura aggiunta da bordered. Dopo questa modifica locale, la CI riesegue tutti i test unitari, le due prove UI interessate, le sette regressioni mirate e l'intera suite compatta. Le altre 38 prove UI e le metriche calendario hanno già evidenza sul codice funzionale invariato; non si dichiara una nuova esecuzione completa di queste prove.

Distribuzione backend ed esportazione cifrata dei sorgenti live bloccate dalla revisione automatica per mancanza di autorizzazione esplicita. Workflow finale limitato alla build dell'app; nessun deploy né esportazione di sorgenti live. Confronto in sola lettura 40230170470 interrotto su contesto diverso (patch 0), senza scritture.

## Ultimo controllo di raggiungibilità

Run 40235736129: regressioni calendario/attività, Finanza, test unitari e righe modificate, oltre a tutti i 14 casi compatti, superati. Aggiunto accesso stabile a Esporta turni nelle Impostazioni: la lista dei mesi si estende e il comando in fondo non deve essere l’unico percorso. Per questa sola aggiunta si ripetono compilazione, unit test e navigazione dedicata sui due simulatori; le suite precedenti restano nel codice. Nessuna pubblicazione o lettura privata in questa verifica demo.

Run finale 40238702185, commit 9df60f95628b4d5da34b55bd87c86edc902b1972: compilazione Apple, suite unitaria e accesso a Esporta turni dalle Impostazioni su entrambi i simulatori superati. Nessun’altra modifica funzionale rispetto alla suite precedente.

Controllo visivo finale: il nuovo accesso nelle Impostazioni usa Form per margini e scorrimento nativi, anche con i comandi aggiuntivi di un server collegato. Per questa sola composizione UI, si ripetono compilazione e le due prove dedicate; 165 unitari già superati sul codice logico invariato.
