# Revisione Life OS 0.4.0 build 11

Il PDF di Nas chiedeva più densità e coerenza Apple, turni a badge, un pennello comprensibile e numeri finanziari spiegabili. La revisione mantiene SwiftUI, componenti di sistema, temi, SF Symbols e Liquid Glass quando disponibile. Mantiene le quattro sezioni e tutti i collegamenti ai dati già presenti.

## Comportamento

I pulsanti dei mesi nelle liste ora hanno azioni indipendenti: lo stile automatico della riga poteva attivare più comandi. Il budget giornaliero usa il mese selezionato: quello passato è concluso, quello futuro usa tutti i suoi giorni, quello corrente comprende oggi. Il 14 ottobre i giorni dal 14 al 31 sono correttamente 18. Il dettaglio del calcolo usa lo stesso criterio.

La settimana Dashboard e il calendario usano badge rettangolari con la palette Life OS moderatamente più satura. Il pennello mostra i turni e gli orari, spiega di toccare i giorni e offre Annulla/Fine. Si assegnano giorni con tocchi; non è un gesto di trascinamento libero sulla griglia. La navigazione resta stabile e il comando evento rimane raggiungibile sopra la barra.

Le attività hanno categorie orizzontali, righe più compatte e Riordina diretto con maniglie. Il contratto del server consente il riordino delle voci Da fare. I badge Oggi/Domani/Scaduta usano colore e icona senza lampeggi continui. Le urgenze sono considerate anche nei contenuti della Dashboard.

La scheda del giorno mostra data, Empoli, prossimo orario discreto senza etichetta, temperatura con minimo e massimo e prossimo cambio meteo. Open-Meteo è gratuito, con cache 15 minuti e controllo delle richieste duplicate. Il progresso del turno si aggiorna ogni minuto e considera il turno notturno iniziato il giorno precedente. Le routine precedono la finanza.

Il patrimonio nel cerchio è suddiviso tra fondo emergenza e altri risparmi; il resto del cerchio rappresenta quanto manca al prossimo traguardo. Il centro mostra solo il patrimonio; il tocco apre il dettaglio. La soglia del fondo resta l'impostazione condivisa `planning.goal`. Il prossimo traguardo è automatico a scatti di 5.000 €: è una scelta implementativa esplicita, non un nuovo obiettivo personale ricavato dal database. Il mensile necessario è il mancante diviso per i mesi fino a dicembre, incluso quello corrente.

Extra distingue totale previsto e quota del mese. Il pagamento accetta l'importo effettivo e usa i risparmi; il ciclo viene chiuso per tutti i mesi. Le quote mostrate sul pagato derivano dai settlement del server, includendo eventuali pagamenti precedenti già collegati, con centesimi conservati. Il piano storico non viene riscritto e non viene creato un secondo movimento. Il comando Fine sulla tastiera rende raggiungibile il pagamento dopo la modifica dell'importo.

I grafici presentano barre compatte e massimo sei settori nella legenda principale, con tutte le categorie consultabili nel dettaglio. I dati arrivano dal Worker; i test visivi usano esempi sintetici separati.

## Verifica

Run definitivo: https://github.com/azeroualit-cloud/LifeOS/actions/runs/38592379062

- 36 test unitari, 14 UI principali e tre UI compatti: tutti passati.
- Xcode 26.3, iPhone 17 Pro e iPhone SE 3; temi, testo grande, calendario a sei settimane, bordi dello scroll e aggiunta evento.
- Pagamento Extra dopo chiusura tastiera: patrimonio diminuito dell'effettivo, budget mensile invariato.
- Contratto API condiviso riuscito; risposta panoramica osservata: 1,725 secondi, 25.324 byte. Non è una misura della latenza completa su iPhone.
- 35 test locali su modelli/sincronizzazione con adattatori Linux; migrazione SQLite verificata sui test Apple.
- Servizio meteo reale: 48 ore di previsione, due giorni, timezone Europe/Rome.
- Screenshot principali e compatti ispezionati; archive e IPA scaricata verificati per hash, versione e arm64.

IPA: https://github.com/azeroualit-cloud/LifeOS/actions/runs/38592379062/artifacts/11909985517

SHA-256 IPA: `f193cb1e78888ef1248b16fc3ad9f7c63deab400dd2a6358995efee9504daa02`.

Nessuna modifica al Worker del sito o ai dati reali in questa revisione. Nessuna installazione intermedia richiesta. Restano le prove fisiche descritte in docs/PROVA-0.4.md: i simulatori non misurano la fluidità sul telefono dell'utente.
