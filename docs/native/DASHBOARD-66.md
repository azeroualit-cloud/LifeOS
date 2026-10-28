# Dashboard A — build 66

## Ambito

Focus e timeline, accento platino, dati reali. Nessuna modifica a Worker, schema finanziario o classificazione delle attività. Widget avanzati non inclusi.

## Modifiche

- Intestazione con data, saluto e meteo solo se recente e valido.
- Mini settimana e apertura del giorno nel calendario conservate.
- Focus sul turno: prima dell’inizio, turno attivo con tempo residuo, concluso, riposo, ferie e dati mancanti.
- Il turno notturno del giorno precedente continua fino alle 06:00. Le date usano Europe/Rome e gli estremi sono calcolati in ore civili, anche con cambio dell’ora.
- Tempo residuo arrotondato ai minuti, nessun refresh al secondo.
- Al massimo tre prossimi appuntamenti, ordinati dal modello esistente, con data/ora, titolo, luogo e apertura dell’editor. Elenco completo accessibile da Vedi tutti.
- Rimosso il riepilogo digitato che duplicava gli appuntamenti. Nessuna animazione globale di ingresso.
- Conservati gestione/completamento abitudini previste oggi, orari, Salute, stato della connessione e messaggi.
- Spazi e font dai token esistenti; azioni almeno 44 punti, testo multilinea, nessuna dipendenza aggiunta.

## Verifiche

Parsing Swift e design system superati. Quattro test locali sulla logica del focus superati: confini del turno, notte che prosegue nel riposo, assenza di countdown senza lavoro e cambio dell’ora.

Compilazione e test sui simulatori principale e compatto superati: 179 test unitari e 14 esecuzioni UI (4 sul principale, 10 sul compatto), zero errori. Schermate nei temi chiaro e scuro confrontate: turno concluso, timeline con apertura dell’editor, elenco completo, stato vuoto e Salute. Archivio Release 0.10.5 (66) integro, con versioni di app e widget verificate. IPA non firmata, da firmare con il proprio servizio. SHA-256: b000084f399d572dd7a726c1139b3f5cf9e2c9c50f4d36670cf3317c8e2789d6.

CI: https://github.com/azeroualit-cloud/LifeOS/actions/runs/40704651120
Revisione dei sorgenti: aa73ad15ee2e2c523ae4109d62e78aceaf2d1486

Non verificato su dispositivo fisico iPhone 15 Pro/iOS 27.
