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
28. Patch server con confronto puntuale e rollback: conservazione completate, programmazione abitudini e orario notifiche. Preserva autenticazione, binding e aggiornamenti live estranei. Distribuzione da verificare nel workflow; non sostituire il modulo live con una baseline vecchia.

## Verifiche locali

57 test Foundation superati, inclusi catalogo attività, programmazione abitudini, notifiche e routing. Worker reale su SQLite: migrazione idempotente, conservazione completate, sezione originale, programmazione abitudini e orari preservati nelle modifiche. Due test del deploy con controlli di contesto/idempotenza e round trip multipart superati. Playwright: tre viewport, zero errori. Parsing Swift, controllo design system e sintassi workflow superati.

Compilazione SwiftUI, test UI, metriche e distribuzione sono in attesa della CI Apple. Non equivalgono al parsing locale.
