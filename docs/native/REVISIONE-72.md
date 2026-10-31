# Revisione 72 — correzioni in verifica

## Contratto

- Selettore data: foglio nativo a larghezza intera, separato dalla colonna Inizio/Scadenza. La selezione resta immediata e rimovibile con ×. Il popover precedente ereditava un contenitore stretto e tagliava le colonne del calendario: il test precedente controllava solo apertura/chiusura, non la larghezza.
- Calendario: nessun cerchio grande sopra il badge del turno nel mese e nella settimana. Numeri SF Pro di sistema, 20 pt Regular a dimensione standard, scalati con Dynamic Type; selezione blu di sistema. Le dimensioni interne private di Calendario Apple non sono un’API pubblica: questa è una taratura sul riferimento, non una pretesa di identità certificata. Dashboard conservata.
- Giorno: un’unica riga con ritorno al mese, data selezionata (tocco per oggi) e +; nessuna seconda intestazione o ingranaggio. Subito sotto, settimana con tutti i sette turni. La data selezionata evita di etichettare come oggi un altro giorno.
- Agenda a scorrimento nativo unico: nessuna altezza proporzionale alle ore. Un evento 06–14 mostra inizio e fine, con contenuto compatto; gli eventi interamente contenuti appaiono al suo interno. Sovrapposizioni parziali ed intervalli identici restano fratelli, senza nascondere attività. Attività senza ora finale non ricevono una scadenza inventata. Notte e prosecuzioni da ieri mantengono gli orari.
- Tutto il giorno: una fila di pillole con titolo, scorrevole orizzontalmente dentro lo stesso contenuto verticale. Nessun pannello separato fisso. Il gesto orizzontale per cambiare giorno è sulla settimana, così non interferisce con le pillole.
- Finanza: importo principale 40 pt Semibold invece di 56 pt Bold, senza divisori intorno a mese, budget, conto e titolo dei movimenti. Restano i separatori fra transazioni e tutte le azioni. Corretto anche «1 giorno».

## Riferimenti consultati

Ricerca Dribbble e Behance: [Mobile Calendar App UI Design, Oliver Meyer](https://dribbble.com/shots/26208854-Mobile-Calendar-App-UI-Design), [Calendar App Design Mini Case Study, Eda Hazal Tümer](https://dribbble.com/shots/23911772-Calendar-App-Design-Mini-Case-Study), [raccolta Behance](https://www.behance.net/search/projects/calendar%20app). Il primo riferimento usa superfici e colori tenui per distinguere impegni; il secondo evidenzia l’utilità di indicatori leggibili nelle viste aggregate. Le pillole compatte e la gerarchia temporale sono un adattamento Life OS; nessun asset o layout viene dichiarato copiato integralmente.

## Architettura e verifiche previste

`NativeCalendarTimeline` proietta i record in un albero temporale; `NativeCalendarAgendaBlock` lo rende con altezza determinata dal contenuto, pulsanti distinti e annidamento limitato graficamente per preservare la larghezza. Modello, API, dati e salvataggio locale restano invariati. Nessuna modifica Cloudflare necessaria.

Regressioni mirate: larghezza del calendario dopo tastiera, entrambe le date e cancellazione, unica riga di intestazione, sette badge settimanali, contenimento evento lungo, eventi sovrapposti e notturni, raggiungibilità delle 23:59, percorsi Finanza e schermi compatti. Stato: verifiche Apple da eseguire, nessuna IPA 72 ancora consegnata.
