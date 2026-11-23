# Build 95 — checklist delle correzioni (dalla prova su iPhone della 94)

Raccolta dalla revisione dell'utente del 23 novembre 2026 (14 screenshot dell'iPhone e messaggi in chat). Nessuna correzione è ancora applicata. Ogni punto va controllato sugli screenshot del simulatore prima della IPA.

## Finanza
1. «Dove va lo stipendio»: Affitto contato due volte; legenda che somma 153 %. Correggere il calcolo.
2. Mappa delle spese: riquadri minuscoli senza nome; riquadro selezionato quasi invisibile.
3. Budget rimanente: la seconda parte della barra esce dal bordo destro.
4. Azioni Budget / Analisi / Nuovo piano / Movimenti: rifare come nell'anteprima approvata della 93 (`LifeOS build 93 - Finanza e dati online`, artboard `Main`); oggi «Movimenti» è tagliato.
5. Nuovo piano: campi compilati senza etichetta (nome, importo).
6. Movimenti: righe troppo alte, importo in alto invece che centrato; ricerca e filtri sovrapposti e disegnati male.
7. Aggiunta spesa: implementare il modo grafico dell'anteprima 93 (fogli Spesa, Menu spesa, Dividi, Rateizza, Pagamento).
8. Categorie di spesa: ordine e sottocategorie come nell'anteprima 93.

## Analisi (FINANCE-ANALYSIS-RANGE-2026-11-23)
9. Ritmo: mese di inizio scelto dall'utente in app e sito; togliere «da gennaio».
10. Giorno per giorno: calendario 1–31 con la spesa tipica di ogni giorno su tutti i mesi scelti; togliere «novembre 2026».

## Margini e pulsanti (SPACING-SYSTEM / DESIGN-PASS-94)
11. Margini uguali in tutte le schede: 13 pt sopra/sotto, 16 ai lati. Togliere i 10 margini vecchi da 5 pt (Settimana, schede-elenco come «Cose da fare», Calendario, Finanza, Piani).
12. «Cose da fare»: titolo troppo grande; prima riga che tocca il bordo.
13. Pulsanti larghi nelle schede (Peso, Alimento) a 44 pt visibili — in attesa del sì dell'utente (cambia DESIGN-PASS-94).
14. Nutrizione in Dashboard: spazio vuoto sotto Peso/Alimento.
15. Peso/Alimento in basso in Salute: larghezza esattamente uguale alla barra di navigazione.
16. «Oggi» + «Mese / Agenda»: stessi bordi del resto, nessuna asimmetria.
17. Attività: pulsante cartella grande quanto le altre pillole; categoria scelta più evidente.
18. Calendario: riga in più sotto «Mese / Agenda» (icona turni e frecce) da compattare.

## Salute
19. «3174 / 3166»: spazio prima e dopo la barra.
20. Colori: macro caldi sotto obiettivo e verdi a obiettivo raggiunto o superato; calorie verdi nel range consigliato, calde se sotto o molto sopra. Solo due colori.
21. Arco: range consigliato al centro della curva; curva più arcuata come Fitia.
22. Micronutrienti: meno decimali; icona più chiara.

## Calendario
23. Agenda: togliere il blocco «Notte · da ieri 00:00–06:00».
24. Agenda: il primo giorno con lo stesso stile dei giorni seguenti (orario | barretta | titolo).

## Da chiarire
25. Dashboard, testata «Settimana»: cerchiata dall'utente; oggi è il margine di 5 pt (punto 11). Confermare se serve altro.

## Sito (SITE-PARITY)
26. Portare sul sito i punti 9, 10, 19–21 e le correzioni di Finanza che hanno un equivalente web.
