# LifeOS 0.9.0 build 39 — modifica in verifica

Base: 0.8.2 build 38, main 83ff3f35789b2906b7c090292e92575f29f5211c. Richiesta del 16 ottobre 2026.

## Risultato implementato

Finanza usa una panoramica aperta senza card: selettore mese, budget rimanente, disponibilità giornaliera e saldo attuale separato. Conserva palette platino, tipografia semantica e componenti del design system corrente. Azioni da sinistra: Budget, Extra, Spesa (prima da destra). Movimenti direttamente sullo sfondo; accesso all’elenco completo e ai filtri. Ripartizione stipendio, ricorrenti e obiettivi sono in Budget; storico e previsione sono in Analisi, accessibile nella barra superiore. Extra conserva navigazione mensile e operazioni esistenti. Nessuna modifica ai calcoli finanziari o al backend.

La barra inferiore è il TabView Apple a quattro destinazioni, con effetti di sistema su iOS 26; non nasconde più la tab bar per disegnare capsule e animazioni sostitutive. Il + contestuale torna nella barra superiore; Extra espone il proprio +. Nessun tab di ricerca fittizio o quinta destinazione.

Home recupera una riga discreta con nome italiano e ora (es. Pomeriggio · 16:42); dopo l’ultimo orario mostra Domani. Nessun riferimento religioso o nome arabo nell’interfaccia. Il dettaglio Orari mostra i cinque orari locali di Empoli, escludendo l’alba. Riusa senza variazioni il calcolo locale già presente; non introduce servizi, posizione GPS o costi. Il dato rimane indicativo, non una nuova certificazione del metodo astronomico.

CalendarScreen.swift è identico alla build 38; NativeStore.swift e i contratti di sincronizzazione sono identici. La barra globale nativa sostituisce quella personalizzata anche quando è aperto il Calendario.

## Verifiche della sessione

53 test XCTest di modelli e azioni demo eseguiti con Swift 6.2.1 su Linux, senza adattare i sorgenti selezionati: 0 errori. Inclusi nuovi casi per budget negativo/mancante, saldo corrente distinto dal mese selezionato, giorni di mesi passati/futuri e prossimi orari su cambio anno, anno bisestile e cambio DST. Questa suite non include NativeStoreTests o test UI.

Parser Swift eseguito su tutti i sorgenti e test; controllo design system passato. Archivio verificato con SHA-256 e CRC; CalendarScreen e NativeStore confrontati byte per byte con la base. UI test aggiornati ai nuovi percorsi, con casi Dynamic Type, snapshot vuoto, azione Spesa a destra, tab bar nativa e aggiunta ripetuta.

Compilazione Apple, unit test completi, UI test sui simulatori, schermate e IPA: ancora da verificare tramite il workflow macOS. Nessun risultato storico viene attribuito a questa build. Installazione e animazioni fisiche richiedono successivamente la prova su iPhone.
